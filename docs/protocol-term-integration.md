# 프로토콜 용어 연동

## 처리 흐름

1. `ProtocolAnalysisClient`가 외부 OmniParser 패키지로 문서를 읽습니다.
2. 타이머는 파싱한 본문에서 `ProtocolTimerExtractor`가 숫자·시간 단위를 찾아 추출합니다.
3. 용어는 R117 후보 생성·재정렬·선택을 거친 뒤 Foundation Models로 분류하는 구조입니다.
4. 분류 결과는 시약·재료, 샘플·분석 대상, 실험 용어, 단위로 검토 화면에 전달합니다.
5. 검토 후 저장한 용어는 실험 상세의 `speechContextualStrings`를 통해 녹음 시작 시
   `SFSpeechAudioBufferRecognitionRequest.contextualStrings`에 전달됩니다.

## 현재 구현 범위

- Foundation Models 분류는 최대 25개씩 요청하며 각 요청마다 새 세션을 만듭니다.
  원문 앞 1,200자를 맥락으로 사용하므로 후반부 의미 해석에는 한계가 있습니다.
- 응답은 요청한 원문 용어와 정확히 일치하고 중복 라벨이 없을 때만 채택합니다.
  모델이 생성한 새 용어·번역·표면 변경은 반영하지 않습니다.
- 모델 사용 불가·분류 실패·응답 누락은 단위 표기 규칙으로 단위를 구분하고 나머지는
  실험 용어에 보관합니다. 시약·샘플의 정확한 분류가 완료됐다는 의미는 아닙니다.
- 자동 추출 결과는 22자로 자르지 않습니다. 직접 입력의 기존 길이 검사는 유지합니다.
- 취소된 분류는 결과를 반환하지 않습니다. 분석 요청 식별자와 취소 상태가 오래된 결과를 막습니다.
- 문서 파싱에 성공했지만 용어 추출이 실패하면 본문·타이머는 유지하고 직접 입력 안내를 표시합니다.
- `R117TermExtractor`는 actor에서 후보 생성 → shortlist → 특징·teacher/F 계산 →
  seed42 head → alias·중첩 최종 선택을 실행하도록 연결했습니다.
- 모델·자산은 `LabcordiOS/Resources/R117`에 포함하고 SwiftPM `Bundle.module`로 읽습니다.
- 원본 decoder의 가변 설정과 모델 호출은 공유 worker actor로 직렬화합니다.
  window·후보 반복 사이와 결과 반환 전 취소를 확인합니다.
- OSLog subsystem `com.labcord`, category `R117`에 추출 소요 시간을 기록합니다.
  모델 초기 로딩을 포함할 수 있으며 메모리·전사 개선 측정값은 아닙니다.

## 모델 자산과 원본 대응

전달받은 ZIP의 SHA-256은
`1a1d6bdd58fa354157064b9dbe5883a6959564508f1c99b05cbe213682821e56`입니다.
ZIP 자체에는 신규 본문에서 후보를 생성하는 런타임이 포함돼 있지 않습니다.

- 후보 생성 모델은 `work/unicode_model_20261022_054/Model/Unicode4.mlpackage`와
  그 디렉터리의 Assets입니다. `overnight_improvement_20261023_073`의 fresh/native/PROCESS
  기록에서 사용 모델·자산을 확인했습니다. 구버전 ship_model 후보 모델은 앱에 넣지 않습니다.
- 후보 생성 코드는 `reach90_20261022_055/pool_runtime`입니다. SectionPriority,
  DocumentFrequencyRanking과 admission, shortlist v2.1 규칙을 Swift로 연결했습니다.
- `ASSET_MANIFEST.json`에 각 파일의 크기·SHA-256을 기록했습니다. 순수 자산 합계는
  160,161,456 bytes입니다. 추가 후보 모델·자산 때문에 전체 앱 자산은 전달 ZIP의
  100MB 조건보다 큽니다.
- 후보 생성 모델의 tokenizer·문자 좌표·window logits 병합과 R117 입력의 후보 ID·순서·
  feature 좌표·표시 좌표를 일치시켜야 합니다. 기존 Swift 후보 생성기의 결과를 곧바로
  R117 평가에 쓰인 동일 후보 pool이라고 가정하지 않습니다.
- R117의 문서 상대 특징 769차원, teacher/F 점수 계산과 alias·중첩 최종 선택을 이식했습니다.
  단순 점수 상위 50개로 대체하지 않습니다.
- 전달 설정의 deployment_seed=null은 원본 기록으로 보존합니다. 앱 배포 head는
  `R117TermExtractor.deploymentHeadFunction`의 `r117_seed42`로 선택했습니다.
  기존 압축본 same87 개발평가의 한영 동일 가중 문서 macro Recall@50은 seed42
  72.5202%, seed43 72.3501%, seed44 72.3045%입니다. 한국어도 seed42가 가장 높고
  영어는 세 seed가 같습니다. 이는 독립 평가나 실제 ASR 개선 검증이 아니며,
  선택한 함수는 실제 head 호출에 사용합니다.
- **원본 수치 parity는 미검증입니다.** canonical JSON 토크나이저, 부동소수점 누적,
  Unicode 경계와 완전 동점 alias 선택은 시뮬레이터에서 원본과 비교해야 합니다.
  코드 연결·빌드 성공을 기존 평가 수치 재현으로 해석하지 않습니다.

Foundation Models 사용 가능 조건과 컨텍스트 오류는
[Apple 공식 문서](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)를
기준으로 확인합니다. 이번 검증 범위는 시뮬레이터이며 실기기 검증은 수행하지 않습니다.

## 시뮬레이터 검증

- Researchers의 iOS Simulator 대상 build 통과
- LabcordiOS 스킴의 iOS Simulator 대상 build-for-testing 통과
- SwiftLint strict·diff 공백 검사 통과
- LabcordiOSTests에 중첩·alias·표면 좌표·zscore·특징 순서·타이머·전체 모델 실행
  테스트 7개 추가. 테스트 실행 결과는 아직 없습니다.
- T3 device_list가 Authentication required를 반환해 시뮬레이터 실행·화면 비교·분류·전사·
  처리시간·메모리·원본 parity 검증은 미실행입니다. Simlock도 T3 기기 도구에서 호스트를
  열어 사용합니다. 인증을 우회해 다른 기기 세션을 조작하지 않습니다.

인증 복구 후 열린 Simlock 시뮬레이터의 실제 ID로 실행합니다.

```sh
xcodebuild test -project Researchers.xcodeproj -scheme LabcordiOS \
  -destination 'platform=iOS Simulator,id=<열어 둔 시뮬레이터 ID>' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO
```

모델 사용이 불가능한 시뮬레이터의 fallback 결과를 Foundation Model 추론 성공으로
보고하지 않습니다. 마이크 입력·전사에 필요한 음원이 없으면 해당 시나리오도 미실행입니다.
