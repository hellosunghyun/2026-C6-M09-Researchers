# iPhone STT 힌트 용어 추출

파싱된 한국어·영어 실험 문서의 text에서 전문용어 후보를 추출하는 검증 패키지다. 문서 업로드 시 한 번 실행하며 사용자가 후보를 검수하는 흐름을 전제로 한다.

- `TermHintsKit/`: 토크나이저·전처리·후보 추출·순위화 Swift Package
- `Model/`: 임베딩 4비트 Core ML 모델과 필수 실행 자산
- `REPORT.md`: 수집부터 실기기 검증까지의 과정·결과·한계

원문·학습 문서·라벨·체크포인트·후보 캐시는 포함하지 않는다. 기존 기준 모델과 잠금 테스트는 별도 연구 작업공간에 보존한다.

## 사용

```swift
let configuration = MLModelConfiguration()
configuration.computeUnits = .cpuOnly
let pipeline = try TermHintPipeline(
    modelURL: sentencePieceURL,
    modelPackageURL: embedding4URL,
    charVocabURL: charVocabURL,
    knownTermsURL: knownTermsURL,
    sectionPriorityRulesURL: sectionRulesURL,
    koreanRulesURL: koreanRulesURL,
    configuration: configuration,
    ranking: .guardedFrequency
)
let hints = pipeline.hints(for: parsedText, language: "ko", K: 50)
```

영어는 `language: "en"`을 사용한다. `ranking`을 생략하면 기존 순서를 유지하며 절 제목 규칙을 제공할 때 native fusion을 적용한다. `.guardedFrequency`는 절 제목 규칙이 필요하다.

입력 상한은 512 tokens, 내용 510 tokens, overlap 64다. 긴 문서는 창으로 나누어 전체를 처리한다. 출력은 원문의 Unicode scalar 기준 0 기반 반개구간이다. Swift UTF-16 위치가 필요하면 호출자가 변환한다.

디코더는 정적 상태를 공유하므로 직렬 호출한다. 앱 타깃에는 자동으로 추가되지 않는다. 제품 채택·실제 STT 개선은 미확정이다.

## 검증과 재현

```bash
cd TermHintsKit
swift test --scratch-path /tmp/labcord-stt-tv-build
```

저장소 루트에서는 `swiftlint --strict`를 실행한다. 빌드 캐시는 작업공간 밖에 둔다. 외부 의존성은 없다.

과거 GB 랭커·재압축 도구는 포함하지 않는다. 압축 재현 코드와 전체 실험 기록은 별도 연구 작업공간에 보존한다.
