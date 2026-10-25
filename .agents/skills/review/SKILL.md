---
name: review
description: Labcord PR과 변경 결과를 리뷰하거나 리뷰·승인 절차를 확인할 때 사용한다.
---

# 코드 리뷰와 결과 작성

리뷰는 Code Rabbit의 1차 리뷰 후 팀원 최소 2명의 코드 리뷰와 Approve를 거쳐 merge하는 순서다.

- 규칙 설명 요청: 이 절차만 설명한다. 리뷰 요청·승인·merge를 실행하지 않는다.
- 검토 요청: 실제 diff·검증 자료와 `.github/PULL_REQUEST_TEMPLATE.md`의 확인 사항을 대조한다. Swift 스타일은 [코드 컨벤션](../code-conventions/SKILL.md)을 필요한 경우 읽는다. 결과 표현은 [리뷰 사례](references/review-examples.md)를 참고한다.
- 리뷰 게시 요청: 명시된 저장소·PR·리뷰 행동 범위에서만 실행한다. 검토 요청만으로 댓글·Approve·수정 요청을 게시하거나 reviewer를 추가하지 않는다.

확인된 문제·영향·검증 근거와 미검증 항목을 구분한다. 점검을 이유로 작업 범위 밖 코드나 기존 로그를 수정하거나 앱 자동 테스트를 새로 의무화하지 않는다.
