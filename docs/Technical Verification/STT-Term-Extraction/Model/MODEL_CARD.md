# 4비트 시험 모델

- 모델: `Embedding4.mlpackage`, 약 69.92MB
- 압축 대상: 단어 임베딩만, 나머지 가중치는 기존 8비트 유지
- 4비트 weight SHA-256: `2f9150c6aae9dd8cced7b3ebfb3e864e6abaa161324f3e3bb3f0f39a09262ebc`
- 보존된 8비트 원본 weight SHA-256: `c580fd82d354025b05c647c490a7c6da311e8798d66ea7f379dfc1891e165889`
- 기존 실기기 조건: CPU_ONLY, window512, overlap64, native fusion
- 새 검증 옵션: guardedFrequency, K50; 실기기 비용 미측정
- 필수 자산: sentencepiece.bpe.model, char_vocab.json, known_terms.json, korean_rules.json, section_priority_rules.json

4비트·8비트 가중치와 실행 증거는 보존한다. 모델 패키지 단일 최대 파일은 69,711,616바이트다. 앱 타깃에는 자동으로 추가하지 않으며 호출자가 모델과 자산 URL을 제공한다.

압축은 기존 8비트 palette를 사용한 가중 제곱오차 최소화로 16개 중심에 대응시키고 FP16 중심과 packed4 인덱스를 저장한다. 평가 문서나 라벨을 압축에 사용하지 않았다. 압축 재현 코드와 원본 해시는 별도 연구 작업공간에 보존한다.

수집 원문·학습 문서·라벨은 배포하지 않는다. 품질 평가를 통과했다고 학습·재배포 허가가 생기는 것은 아니다. 실제 STT 개선과 제품 채택은 아직 확정하지 않았다.
