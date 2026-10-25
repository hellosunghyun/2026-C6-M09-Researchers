# Labcord 에이전트 작업 안내

팀 규칙의 기준은 [Notion 개발 컨벤션](https://sassy-cloth-fbe.notion.site/3fa06046c66e804eb90bcfb3d7341498)이다.
2026-10-25 공개 페이지의 Branch, Commit, Commit Message, Pattern/Architecture,
Issue, Pull Request 항목을 직접 확인해 반영했다. Notion에는 TCA를 사용할 예정이라고
적혀 있으며 현재 프로젝트는 TCA를 사용한다. 추가 아키텍처나 코드 스타일 규칙은
해당 원문에 명시되어 있지 않다.

작업 상황에 맞는 파일을 읽는다.

- 브랜치 생성, 커밋, Issue 작성: [.agents/skills/git-workflow/SKILL.md](.agents/skills/git-workflow/SKILL.md)
- PR 작성·리뷰: [.agents/skills/pull-request/SKILL.md](.agents/skills/pull-request/SKILL.md)

PR과 SwiftLint 관련 세부 사항은 기존 `.github/PULL_REQUEST_TEMPLATE.md`,
`.github/ISSUE_TEMPLATE/`, `.swiftlint.yml`, `.github/workflows/`를 참고한다.
Skill은 기존 파일의 규칙을 대체하지 않는다.

## 관리와 지원 범위

Notion 변경 시 원문과 해당 Skill을 함께 대조하고 확인 날짜를 갱신한다. Notion에 없는
규칙을 팀 합의로 추가하거나, 빈 Pull Request 항목을 추정해서 채우지 않는다.
원문을 읽을 수 없으면 해당 규칙의 최신 여부를 확인하지 못했다고 알린다.
자동 동기화는 없다. 서로 다른 내용이 발견되면 차이를 알리고 임의로 합의하지 않는다.

각 Skill은 [Agent Skills 형식](https://agentskills.io/specification)의 `name`,
`description` frontmatter와 본문으로 구성한다. 검증 범위는 파일 형식 확인과 이 작업의
명시적 파일 읽기·적용이다. 새 세션의 Codex 자동 탐색, Claude Code/Cursor 등 다른
에이전트의 자동 로딩·선택은 검증하지 않았다. 자동 로딩을 지원하지 않는 환경에서는
이 파일과 필요한 `SKILL.md`를 작업 요청에서 명시적으로 참조할 수 있다.

이 파일들은 에이전트를 위한 참조 문서다. 앱, 패키지, 빌드, CI, Git hook을 변경하지
않으므로 에이전트를 사용하지 않는 팀원의 기존 개발 흐름에는 추가 실행 단계가 없다.
