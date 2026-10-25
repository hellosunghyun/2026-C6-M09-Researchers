---
name: commit-type
description: Labcord 변경 내용에 맞는 커밋 종류를 고르거나 feat/style/design/test/refactor 등의 구분을 검토할 때 사용한다.
---

# 커밋 종류 선택

출처: [Notion 개발 컨벤션의 Commit](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498), 2026-10-25 확인.

실제 변경을 아래 용도와 대조해 종류를 고른다. 이 파일은 종류 선택을 담당하고,
메시지 형식과 커밋 빈도는 `../commit-message/SKILL.md`에서 다룬다.

| 종류 | 원문의 용도 |
| --- | --- |
| feat | 새로운 기능 추가 |
| fix | 버그 수정 |
| docs | 문서 수정 |
| style | 코드 스타일 변경 (코드 포매팅, 세미콜론 누락 등) |
| design | 사용자 UI 디자인 변경 (스타일링 등) |
| test | 테스트 코드, 리팩토링 (Test Code) |
| refactor | 리팩토링 (Production Code) |
| build | 빌드 파일 수정 |
| ci | CI 설정 파일 수정 |
| perf | 성능 개선 |
| chore | 자잘한 수정이나 빌드 업데이트 |
| rename | 파일 혹은 폴더명을 수정만 한 경우 |
| remove | 파일을 삭제만 한 경우 |
| add | 패키지, 파일 추가 |

종류의 의미가 실제 변경과 맞는지 확인한다. 특히 코드 스타일과 UI 디자인,
테스트 코드 리팩토링과 프로덕션 리팩토링을 원문의 구분대로 읽는다.
원문의 `perf: 성능 개선cho` 끝 `cho`는 의미가 불명확해 새 종류나 규칙으로 해석하지 않았다.
유형을 고른다는 이유로 테스트·배포·기능 변경 작업을 새로 추가하지 않는다.

규칙 변경 시 원문과 표를 대조한다. 유형 정의는 이 파일에서만 관리한다.
