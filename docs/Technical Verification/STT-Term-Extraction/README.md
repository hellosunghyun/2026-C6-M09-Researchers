# iPhone STT 힌트 용어 추출 결과

파싱된 한국어·영어 실험 문서에서 STT 힌트 후보를 추출하기 위한 시험 모델과 연구 보고서다.

- `Model/Embedding4.mlpackage`: 임베딩만 4비트로 압축한 Core ML 모델, 약 69.92MB
- `Model/Assets/`: 토크나이저·문자 사전·용어 사전·절 제목 규칙
- [모델 카드](./Model/MODEL_CARD.md): 가중치 해시·실행 조건·한계
- [연구 보고서](./REPORT.md): 자료 수집·모델 비교·iPhone 17 측정·개발 평가 결과

전체 Swift 구현·테스트·실행 방법은 포크의 [`archive/#25`](https://github.com/hellosunghyun/2026-C6-M09-Researchers/tree/archive/%2325/docs/Technical%20Verification/STT-Term-Extraction)에 보관한다. 이 PR은 결과물과 리포트만 포함하며 앱 타깃을 변경하지 않는다. 원문·학습 문서·라벨·체크포인트는 포함하지 않는다.

개발자료의 용어 회수율은 실제 STT 개선 수치가 아니다. 사람 검수와 동일 녹음의 힌트 전후 평가, 새 순위 옵션의 실기기 비용 검증이 남아 있다.
