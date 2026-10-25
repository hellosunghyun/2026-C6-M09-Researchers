---
name: git-workflow
description: Labcord에서 작업 브랜치를 만들거나 커밋 메시지와 Issue 제목을 작성할 때 Notion 개발 컨벤션을 적용한다.
---

# Git 작업과 Issue

기준: [Notion 개발 컨벤션](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498),
2026-10-25 확인. Branch, Commit, Commit Message, Issue 항목을 반영한다.

## 적용 절차

작업 종류, 관련 Issue 번호, 작업자 이름을 확인하고 다음 형식으로 작성한다.

- 브랜치: `종류/#이슈번호-작업자 이름` (원문 예: `feat/#1-Theo`)
- 커밋: `종류/#이슈번호: 커밋메시지` (원문 예: `feat/#1: 메인화면 구현`)
- Issue 제목: `종류: 작업할 내용` (원문 예: `feat: MainView 개발`)

원문은 커밋을 최대한 자주 진행하도록 안내한다. 작업 종류는 다음 표를 따른다.

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

원문의 `perf: 성능 개선cho` 끝 `cho`는 의미가 확인되지 않아 별도 규칙으로 해석하지 않았다.

## 확인과 예외

결과의 종류·번호·작업자 이름이 실제 작업과 맞는지 확인한다. 번호나 작업자를 알 수
없으면 임의로 만들지 않는다. Issue 본문에는 기존 Issue Form을 사용한다.
Notion은 기본 브랜치, squash/rebase, 승인 수, 배포 방식을 이 페이지에서 정하지 않는다.
PR 작성·리뷰 시에는 인접한 `pull-request/SKILL.md`도 읽는다.
