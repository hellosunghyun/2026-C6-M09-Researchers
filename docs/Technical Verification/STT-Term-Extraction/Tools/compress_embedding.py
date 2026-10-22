"""동결된 8비트 모델의 단어 임베딩만 재압축하고 다른 가중치는 보존한다.

기존 palette 256개를 출현 빈도로 가중한 1차원 동적 계획법으로 묶어 제곱 오차를
최소화한다. 압축 과정에서는 문서나 참조 라벨을 사용하지 않는다.

사용법::

    python3 compress_embedding.py --source baseline.mlpackage --output-dir output

기존 ``coremltools==9.0``과 NumPy 환경을 사용한다.
이 도구는 패키지를 설치하거나 업그레이드하지 않는다.
"""
from pathlib import Path
import argparse
import copy
import gc
import hashlib
import json
import math

import numpy as np
import coremltools as ct
from coremltools.proto import MIL_pb2 as mil
from coremltools.libmilstoragepython import _BlobStorageReader as Reader
from coremltools.libmilstoragepython import _BlobStorageWriter as Writer
from coremltools.optimize._utils import pack_elements_into_bits, restore_elements_from_packed_bits

EXPECTED_SHA = 'c580fd82d354025b05c647c490a7c6da311e8798d66ea7f379dfc1891e165889'
ORIGINAL_SCRIPT_PATH = 'work/embedding_compression_20261021_043/build_models.py'
ORIGINAL_SCRIPT_SHA256 = 'c665b0bf9ad9d5aded3282be5b546ca0cb300dbe9e0f90266388dc36455c351a'
EMBEDDING = 'body_embeddings_word_embeddings_weight_to_fp16_palettized'
METHODS = {mil.FLOAT16: 'fp16', mil.FLOAT32: 'float', mil.UINT8: 'uint8', mil.INT32: 'int32'}

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def dump(p, value):
    tmp = p.with_suffix(p.suffix + '.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(p)

def block(spec):
    return next(iter(spec.mlProgram.functions['main'].block_specializations.values()))

def optimal_palette(lut, counts, bits):
    order = np.argsort(lut.astype(np.float64), kind='stable')
    x, w = lut[order].astype(np.float64), counts[order].astype(np.float64)
    assert np.all(w > 0), 'Handle unused palette values explicitly before compression'
    n, k = len(x), 2 ** bits
    sw = np.r_[0., np.cumsum(w)]
    sx = np.r_[0., np.cumsum(w*x)]
    sx2 = np.r_[0., np.cumsum(w*x*x)]
    cost = np.full((n+1, n+1), np.inf)
    for j in range(1, n+1):
        i = np.arange(j)
        cost[i,j] = np.maximum(0., sx2[j]-sx2[i]-(sx[j]-sx[i])**2/(sw[j]-sw[i]))
    dp = np.full((k+1,n+1), np.inf)
    prev = np.full((k+1,n+1), -1, dtype=int)
    dp[0,0] = 0
    for c in range(1,k+1):
        for j in range(c,n+1):
            v = dp[c-1,c-1:j] + cost[c-1:j,j]
            a = int(np.argmin(v))+c-1
            dp[c,j], prev[c,j] = v[a-c+1], a
    mapping = np.empty(n, dtype=np.uint8)
    centers = np.empty(k, dtype=np.float16)
    j = n
    for c in range(k,0,-1):
        i = prev[c,j]
        centers[c-1] = (sx[j]-sx[i])/(sw[j]-sw[i])
        mapping[order[i:j]] = c-1
        j = i
    assert j == 0
    error = centers[mapping].astype(np.float64)-lut.astype(np.float64)
    return centers, mapping, {'weighted_mse': float(np.sum(w*error[order]**2)/sum(w)), 'max_abs_error': float(np.max(np.abs(error)))}

def pack_verified(indices, mapping, bits):
    # 청크 크기를 8의 배수로 맞춰 청크 사이에 padding이 생기지 않게 한다.
    parts = []
    for start in range(0, len(indices), 1 << 20):
        mapped = mapping[indices[start:start+(1 << 20)]]
        packed = pack_elements_into_bits(mapped, bits)
        restored = restore_elements_from_packed_bits(packed, bits, len(mapped))
        assert np.array_equal(mapped, restored)
        parts.append(packed)
    result = np.concatenate(parts)
    assert len(result) == math.ceil(len(indices)*bits/8)
    return result

def build(source, output_dir, bits):
    weights = source / 'Data/com.apple.CoreML/weights/weight.bin'
    out = output_dir / ('embedding%d.mlpackage' % bits)
    receipt = output_dir / ('embedding%d_BUILD.json' % bits)
    if receipt.exists():
        row = json.loads(receipt.read_text())
        assert sha(out/'Data/com.apple.CoreML/weights/weight.bin') == row['weight_sha256']
        assert sha(out/'Data/com.apple.CoreML/model.mlmodel') == row['model_sha256']
        assert row.get('provenance', {}).get('original_script_sha256') == ORIGINAL_SCRIPT_SHA256
        print('reuse', bits, flush=True)
        return row
    assert not out.exists(), 'Preserve incomplete package for inspection'
    assert sha(weights) == EXPECTED_SHA
    original = ct.models.MLModel(str(source), skip_model_load=True).get_spec()
    spec = copy.deepcopy(original)
    reader = Reader(str(weights))
    embedding = next(o for o in block(spec).operations if o.outputs and o.outputs[0].name == EMBEDDING)
    indices = reader.read_uint8_data(embedding.attributes['indices'].blobFileValue.offset)
    lut = reader.read_fp16_data(embedding.attributes['lut'].blobFileValue.offset).view(np.float16)
    counts = np.bincount(indices, minlength=len(lut))
    centers, mapping, errors = optimal_palette(lut, counts, bits)
    packed = pack_verified(indices, mapping, bits)
    print('palette ready', bits, errors, flush=True)
    scratch = output_dir / ('weights%d' % bits)
    scratch.mkdir(exist_ok=True)
    path = scratch/'weight.bin'
    assert not path.exists(), 'Preserve incomplete weight file for inspection'
    writer = Writer(str(path))
    payloads = []
    for o in block(spec).operations:
        for key, a in sorted(o.attributes.items()):
            if a.WhichOneof('value') != 'blobFileValue':
                continue
            method = METHODS[a.type.tensorType.dataType]
            arr = getattr(reader, 'read_%s_data' % method)(a.blobFileValue.offset)
            changed = bool(o.outputs and o.outputs[0].name == EMBEDDING and key in ['indices', 'lut'])
            if changed:
                arr = packed if key == 'indices' else centers.view(np.uint16)
                a.type.tensorType.dimensions[0].constant.size = len(arr)
            a.blobFileValue.offset = getattr(writer, 'write_%s_data' % method)(np.ascontiguousarray(arr))
            payloads.append((o.outputs[0].name, key, method, a.blobFileValue.offset, hashlib.sha256(arr.tobytes()).hexdigest(), changed))
    del writer
    gc.collect()
    verify_reader = Reader(str(path))
    for name, key, method, offset, expected, changed in payloads:
        arr = getattr(verify_reader, 'read_%s_data' % method)(offset)
        assert hashlib.sha256(arr.tobytes()).hexdigest() == expected, (name, key)
    # 저장 offset을 정규화해 임베딩 palette 외의 연산 그래프가 같은지 검증한다.
    a, b = copy.deepcopy(original), copy.deepcopy(spec)
    for old, new in zip(block(a).operations, block(b).operations):
        assert old.type == new.type
        for key, attr in old.attributes.items():
            if attr.WhichOneof('value') == 'blobFileValue':
                new.attributes[key].blobFileValue.offset = attr.blobFileValue.offset
        if old.outputs and old.outputs[0].name == EMBEDDING:
            new.CopyFrom(old)
    assert a == b, 'Non-embedding graph modification'
    model = ct.models.MLModel(spec, weights_dir=str(scratch), skip_model_load=True)
    model.save(str(out))
    row = {'bits': bits, 'source_weight_sha256': EXPECTED_SHA, 'method': 'weighted optimal contiguous 1D SSE clustering of frozen eight-bit palette; FP16 centers', 'compression_uses_documents_or_labels': False, 'embedding_shape': [250037,384], 'embedding_index_bytes': len(packed), 'package_bytes': sum(f.stat().st_size for f in out.rglob('*') if f.is_file()), 'weight_bytes': (out/'Data/com.apple.CoreML/weights/weight.bin').stat().st_size, 'weight_sha256': sha(out/'Data/com.apple.CoreML/weights/weight.bin'), 'model_sha256': sha(out/'Data/com.apple.CoreML/model.mlmodel'), 'non_embedding_graph_exact': True, 'all_serialized_payloads_roundtrip_verified': True, 'unchanged_other_payload_count': sum(not r[-1] for r in payloads), 'changed_payload_count': sum(r[-1] for r in payloads), 'input_output_contract_unchanged': spec.description == original.description, 'specification_version': spec.specificationVersion, 'embedding_error_relative_to_frozen8bit': errors, 'coremltools': ct.__version__, 'provenance': {'original_script': ORIGINAL_SCRIPT_PATH, 'original_script_sha256': ORIGINAL_SCRIPT_SHA256, 'cli_path_parameterization_only': True, 'source': str(source), 'output_dir': str(output_dir)}}
    assert sha(weights) == EXPECTED_SHA
    dump(receipt,row)
    print(json.dumps(row), flush=True)
    return row

def parse_args():
    parser = argparse.ArgumentParser(
        description='Create 6-bit and 4-bit embedding-only Core ML candidates.'
    )
    parser.add_argument(
        '--source', required=True, type=Path,
        help='frozen baseline .mlpackage directory',
    )
    parser.add_argument(
        '--output-dir', required=True, type=Path,
        help='directory for candidate packages, scratch weights, and receipts',
    )
    return parser.parse_args()


def main():
    args = parse_args()
    source = args.source.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    if not source.is_dir():
        raise SystemExit(f'--source is not an existing .mlpackage directory: {source}')
    if source == output_dir or source in output_dir.parents:
        raise SystemExit('--output-dir must be outside --source')
    weights = source / 'Data/com.apple.CoreML/weights/weight.bin'
    if not weights.is_file():
        raise SystemExit(f'baseline weight.bin not found: {weights}')
    if sha(weights) != EXPECTED_SHA:
        raise SystemExit('source weight SHA-256 differs from the frozen baseline')
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = [build(source, output_dir, bits) for bits in [6, 4]]
    dump(output_dir / 'MODEL_BUILDS.json', rows)


if __name__ == '__main__':
    main()
