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
- **원본과의 완전한 수치·순서 일치는 통과하지 못했습니다.** 아래 원본 대조 결과를 참고합니다.
  코드 연결·빌드 성공을 기존 평가 수치 재현으로 해석하지 않습니다.

Foundation Models 사용 가능 조건과 컨텍스트 오류는
[Apple 공식 문서](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)를
기준으로 확인합니다. 이번 검증 범위는 시뮬레이터이며 실기기 검증은 수행하지 않습니다.

## 시뮬레이터 검증

2026-11-02, Simlock의 iPhone 17 / iOS 27.0에서 확인했습니다. T3 Device 패널로 세션을
열고 반환된 bound agent-device CLI로 앱을 조작했습니다. worker/gateway의 agent-device
capability와 실행 경로를 복구한 뒤 세션이 열렸으며, 다른 기기 세션은 조작하지 않았습니다.

### 통과

- Researchers와 ResearchWatch Watch App의 Simulator 대상 build, SwiftLint strict 통과.
  Watch 빌드는 공유 디자인 시스템 컴파일 확인이며 Watch 기능·통신 검증이 아닙니다.
- 기본 규칙 7개, AddedToken 좌표 4개, 파이프라인·성능 2개로 총 13개 테스트 실행 통과.
- 짧은 영문 본문에서 파싱 → R117 → Foundation Models → SwiftData 저장·재조회 →
  speechContextualStrings 전달을 확인했습니다. Foundation Models는 available이고
  해당 입력에서 fallback 라벨이 사용되지 않았습니다.
- 실제 앱에서 합성 프로토콜 이미지를 선택해 OCR 분석, 용어 50개와 5분·30초 타이머
  검토·저장을 확인했습니다. 이 입력의 일부 분류는 fallback이어서 검토 안내를 표시했습니다.
- Figma 등록·분석 결과 화면과 비교해 업로드 카드, 제목·뒤로 가기, 하단 버튼,
  용어 칩의 높이·테두리를 조정하고 Simulator 화면을 확인했습니다.
- 짧은 영문 입력의 warm 추출 3회는 0.576 / 0.639 / 0.745초, 평균 0.653초입니다.
  cold 초기 추출 로그는 7.095초입니다. XCTest Memory Peak Physical 평균은
  192,831.565kB입니다. Simulator 테스트 프로세스 측정이며 실기기·장문 성능 보장은 아닙니다.

### 원본 대조: 일부 실패

기존에 저장된 한국어 protocol_33812 산출물을 대조했습니다. 새로운 앱 출력을 정답으로
사용하지 않았습니다. 참조 원문·용어는 저장소에 커밋하지 않고 선택적 fixture로만 사용합니다.

- 저장된 canonical raw pool을 넣은 shortlist는 1,367개 행의 원문·좌표·순서가 모두 일치합니다.
- 모델을 새로 실행한 후보도 raw 후보의 개수·키는 같지만, raw 점수의 최대 절대 차이는
  0.0151305795입니다. native 순서는 다르고 guarded 순서는 같습니다.
- fresh pool로 만든 feature 행은 1,367개 중 615개 위치가 다릅니다.
- 최종 50개 용어의 집합은 같지만 순서가 달라 완전 일치 테스트는 실패했습니다.
  차이는 fresh 후보 생성 단계부터 확인됩니다. 실행 환경에 따른 CoreML 수치 차이인지 등
  근본 원인은 아직 확정하지 않았습니다. 순서 비교를 완화해 통과 처리하지 않습니다.

대조 fixture v2 SHA-256:
`1e27ffc7b42aa8bdec488c40f3c80fac61800c290ac35a4d331380b3c59be1f0`.
재현 방법과 필드는 `Tests/LabcordiOSTests/Fixtures/README.md`에 정리했습니다.

### 실행 방법

앱과 같은 전이 의존성 버전을 유지하도록 package의 Package.resolved를 함께 관리합니다.
T3에서 소유한 Simlock 세션을 먼저 열고, 실제 Simulator UDID와 device-set 경로를 사용합니다.
lease ID와 Simulator UDID는 서로 다릅니다.

```sh
cd Packages/ResearchersModules
xcodebuild test -scheme LabcordiOSTests \
  -destination 'platform=iOS Simulator,id=<Simulator UDID>' \
  -DVTSimulatorSetLocation=<Simlock device-set 경로> \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -resultBundlePath <새 경로>.xcresult
```

일반 Simulator 기본 device set을 쓰면 DVTSimulatorSetLocation 옵션은 생략합니다.
참조 fixture가 없으면 원본 대조 테스트 4개는 XCTSkip이며 기본 13개 통과와 구분합니다.
fixture가 있으면 알려진 원본 순서 불일치 테스트 2개가 실패합니다.

### 미실행·제약

- Simulator 카메라 불가 오류로 실제 사진·영상 촬영과 실험 시작 이후 흐름은 미검증입니다.
- 마이크용 통제 음원이 없어 실제 전사 정확도와 contextualStrings의 인식 개선은 미검증입니다.
  저장한 용어가 전사 요청에 연결되는 데이터 경로와 실제 인식 개선을 구분합니다.
- 실기기 검증은 사용자 지정 범위에 따라 수행하지 않았습니다. CI도 이번 로컬 검사와 별개입니다.
