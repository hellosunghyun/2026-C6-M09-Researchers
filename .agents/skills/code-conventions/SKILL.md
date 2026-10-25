---
name: code-conventions
description: Labcord Swift 코드를 작성·정리하거나 lint 결과를 검토할 때 기존 .swiftlint.yml에서 확인되는 코드 규칙을 적용한다.
---

# Swift 코드 컨벤션

출처: 저장소의 `.swiftlint.yml`과 `.github/workflows/swiftlint.yml`, 2026-10-25 확인.
Notion에는 별도 상세 코드 스타일 규칙이 없어 기존 설정을 기준으로 한다.

루트 `.swiftlint.yml`을 먼저 읽는다. 현재 opt-in은 empty_count, first_where,
sorted_imports, trailing_closure, closure_spacing이다. 줄 길이는 warning 99 / error 150이며
trailing_whitespace, trailing_newline, colon, comma는 error로 설정되어 있다.
문서의 요약과 실제 설정이 다르면 실제 파일을 확인하고 차이를 알린다.

해당 Swift 변경이 설정과 맞는지 확인하고 수행한 lint 결과나 미수행 이유를 보고한다.
기존 CI는 SwiftLint strict를 실행한다. 새로운 formatter, 규칙, Git hook, 앱 테스트를
추가하거나 기존 CI를 변경하라는 뜻은 아니다. PR 전체의 동작·회귀 확인은
`../review/SKILL.md`에서 다룬다.

설정 변경 시 이 요약을 대조한다. 자동 동기화는 없다.
