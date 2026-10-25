---
name: commit-message
description: Labcord 커밋 메시지를 쓰거나 커밋 단위를 정리할 때 Notion의 종류/이슈번호 형식과 자주 커밋하라는 안내를 적용한다.
---

# 커밋 메시지와 빈도

출처: [Notion 개발 컨벤션의 Commit 및 Commit Message](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498), 2026-10-25 확인.

종류와 실제 Issue 번호를 확인한 뒤 `종류/#이슈번호: 커밋메시지`로 작성한다.
원문 예시는 `feat/#1: 메인화면 구현`이다. 종류 선택은 `../commit-type/SKILL.md`를 읽는다.

원문은 커밋을 최대한 자주 진행하도록 안내한다. 메시지의 종류·번호·설명이 실제
변경 내용과 맞는지 확인한다. Issue 번호를 모르거나 작업이 여러 Issue에 걸치면
가짜 번호를 만들거나 원문에 없는 복수 번호 형식을 팀 규칙으로 정하지 않는다.
원문에는 글자 수 제한, 본문/푸터 의무, squash/rebase 방식이 없다.

규칙 변경 시 원문과 이 파일을 대조한다. 이 Skill은 커밋 생성 권한이나 push 권한을
새로 부여하지 않는다.
