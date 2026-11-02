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
- **R117 실행 연결은 미완료입니다.** `R117TermExtractor`는 비어 있지 않은 입력에
  `runtimeNotIntegrated`를 던집니다. 빈 배열의 정상 성공으로 처리하지 않습니다.

## 모델 연결에 남은 작업

전달받은 ZIP의 SHA-256은
`1a1d6bdd58fa354157064b9dbe5883a6959564508f1c99b05cbe213682821e56`입니다.
ZIP 자체에는 신규 본문에서 후보를 생성하는 런타임이 포함돼 있지 않습니다.

- Tailscale로 가져온 후보 생성용 4비트 모델, SentencePiece 모델, 문자 어휘표,
  기존 알려진 용어 자산과 Swift TermHintsKit 구현을 대조합니다.
- 후보 생성 모델의 tokenizer·문자 좌표·window logits 병합과 R117 입력의 후보 ID·순서·
  feature 좌표·표시 좌표를 일치시켜야 합니다. 기존 Swift 후보 생성기의 결과를 곧바로
  R117 평가에 쓰인 동일 후보 pool이라고 가정하지 않습니다.
- R117의 문서 상대 특징 769차원, teacher/F 점수 계산과 alias·중첩 최종 선택을 이식합니다.
  단순 점수 상위 50개로 대체하지 않습니다.
- 전달 설정의 deployment_seed는 null입니다. seed42·43·44 중 배포 head 결정이 필요합니다.
- 참조 구현과 같은 본문에서 후보·좌표·점수·최종 선택을 비교한 후 앱 리소스와 연결합니다.
  macOS 후보 생성 실행은 iPhone 실행이나 R117 최종 선택 검증을 대신하지 않습니다.

Foundation Models 사용 가능 조건과 컨텍스트 오류는
[Apple 공식 문서](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)를
기준으로 확인합니다. 실제 기기에서 분류 추론과 STT 개선 효과는 별도 검증이 필요합니다.
