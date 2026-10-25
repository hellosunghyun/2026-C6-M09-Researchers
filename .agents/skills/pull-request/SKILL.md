---
name: pull-request
description: Labcord PR 본문을 작성하거나 리뷰할 때 기존 PR 템플릿의 항목과 확인 사항을 적용한다. Notion의 빈 PR 항목에 새 규칙을 만들지 않는다.
---

# Pull Request 작성과 리뷰

기준: [Notion 개발 컨벤션](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498),
2026-10-25 확인, 및 저장소의 `.github/PULL_REQUEST_TEMPLATE.md`.
Notion에는 Pull Request 제목 아래 세부 내용이 없다. 아래 항목은 기존 PR 템플릿에서
가져온 것이며 새 Notion 합의로 취급하지 않는다.

## 적용 절차

PR 작성 시 루트 기준 `.github/PULL_REQUEST_TEMPLATE.md`를 읽고 개요, 작업 내용,
확인 사항, 리뷰 시 중점, 덧붙일 말을 실제 변경에 맞춰 채운다.
브랜치·커밋·Issue 제목 작성은 인접한 `git-workflow/SKILL.md`를 참조한다.

기존 템플릿의 확인 사항을 검토한다.

- 코드 컨벤션 준수
- 불필요한 로그·주석·import 삭제 여부
- 변경한 기능의 정상 동작
- 기존 기능에 대한 영향
- UI 구현·변경 시 구현 화면 첨부

UI를 구현·변경했다면 템플릿의 iPhone/Apple Watch 화면 표에 해당 결과를 첨부한다.
해당하지 않으면 구현 화면 항목을 삭제할 수 있다는 템플릿 안내를 따른다.

## 확인과 예외

확인하지 않은 항목을 완료로 표시하지 않는다. 테스트 환경·주의 사항은 덧붙일 말에
기록한다. 문서만 바꾼 경우 실제로 확인한 문서·링크 결과를 설명한다.
PR 제목 형식·리뷰 승인 수·자동 테스트 의무는 이 Notion 페이지에 명시되어 있지 않다.
이 Skill은 앱 테스트나 배포를 새로 요구하지 않는다.
