---
name: commit-message
description: Labcord 커밋 메시지를 작성·검토하거나 변경을 커밋 단위로 정리할 때 사용한다.
---

# 커밋 메시지와 단위

- 메시지는 `종류/#이슈번호: 커밋메시지`로 작성한다. 예: `feat/#1: 메인화면 구현`.
- staged diff에 맞는 종류와 실제 이슈 번호를 사용하고, 변경 내용을 구체적으로 설명한다.
- 커밋은 최대한 자주 진행한다.
- 이슈 번호를 확인하지 못하면 임의의 번호를 만들지 않는다.
- 글자 수 제한, 본문·푸터 의무, squash·rebase 방식을 새 팀 규칙으로 추가하지 않는다.

종류는 feat(기능), fix(버그), docs(문서), style(코드 스타일), design(UI), test(테스트), refactor(프로덕션 리팩토링), build(빌드), ci(CI), perf(성능), chore(기타 수정), rename(이름만 변경), remove(삭제만), add(패키지·파일 추가) 중 변경 내용에 맞게 선택한다.
