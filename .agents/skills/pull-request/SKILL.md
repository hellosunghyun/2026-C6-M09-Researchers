---
name: pull-request
description: Labcord PR 초안과 구현 화면 자료를 작성할 때 기존 PR 템플릿의 본문 구성과 UI 첨부 안내를 적용한다. 코드 리뷰는 별도 review Skill에서 다룬다.
---

# Pull Request 작성

기준: [Notion 개발 컨벤션](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498),
2026-10-25 확인, 및 저장소의 `.github/PULL_REQUEST_TEMPLATE.md`.
Notion에는 Pull Request 제목 아래 세부 내용이 없다. 아래 항목은 기존 PR 템플릿에서
가져온 것이며 새 Notion 합의로 취급하지 않는다.

PR 작성 시 루트 기준 `.github/PULL_REQUEST_TEMPLATE.md`를 읽고 개요, 작업 내용,
확인 사항, 리뷰 시 중점, 덧붙일 말을 실제 변경에 맞춰 채운다.
템플릿의 확인 사항 점검 기준은 `../review/SKILL.md`를 참조한다.

UI를 구현·변경했다면 템플릿의 iPhone/Apple Watch 화면 표에 해당 결과를 첨부한다.
해당하지 않으면 구현 화면 항목을 삭제할 수 있다는 템플릿 안내를 따른다.

확인하지 않은 항목을 완료로 표시하지 않는다. 테스트 환경·주의 사항은 덧붙일 말에
기록한다. 문서만 바꾼 경우 실제로 확인한 문서·링크 결과를 설명한다.
PR 제목 형식·리뷰 승인 수·자동 테스트 의무는 이 Notion 페이지에 명시되어 있지 않다.
이 Skill은 앱 테스트나 배포를 새로 요구하거나 PR 게시 권한을 부여하지 않는다.

Notion과 템플릿이 바뀌면 각각 대조한다. 자동 동기화는 없다. 검증 범위는 형식 검사와
이번 작업의 명시적 파일 읽기·적용이며, 새 세션 및 다른 에이전트의 자동 탐색·선택은
검증하지 않았다. 자동 탐색을 지원하지 않으면 필요한 SKILL.md 경로를 요청에 명시한다.
