---
name: git-branch
description: Labcord 작업 브랜치를 만들거나 이름과 분기·통합 흐름을 검토할 때 사용한다.
---

# 브랜치 이름과 흐름

이름은 `종류/#이슈번호-작업자 이름`으로 작성한다. 예: `feat/#1-Theo`. 종류 선택이 필요하면 [작업 종류](../commit-type/SKILL.md)를 읽는다.

- 규칙 설명 요청: 아래 흐름과 이름 형식만 설명한다.
- 이름 검사 요청: 아래 검사 도우미로 형식을 확인한다. 실제 이슈·작업자는 따로 확인한다. 도우미는 Git ref 유효성이나 브랜치 존재를 판정하지 않는다.
- 생성·전환 요청: 작업 트리·현재 브랜치·분기 기준을 읽기 전용으로 확인하고 기존 사용자 변경을 보존한다. 요청된 브랜치 작업만 실행한다. 흐름 설명을 merge·배포 허가로 해석하지 않는다.

저장소 루트에서 실행:

```sh
python3 .agents/skills/commit-type/scripts/check_format.py branch 'docs/#32-Devin'
```

배포 가능한 코드는 main, 다음 배포의 개발 코드는 develop에서 관리한다. 기능 작업은 develop에서 분기해 develop으로 통합한다. 배포 준비는 develop에서 release를 분기해 검증·수정한 뒤 main과 develop에 통합한다. 긴급 수정은 main에서 hotfix를 분기하고 완료 후 main과 develop에 반영한다.

형식 검사는 공백·길이·대소문자 등에 새로운 브랜치 정책을 만들지 않는다. Git 자체의 ref 제약과 팀 명명 형식을 구분한다. 검사 실패 시 브랜치를 만들거나 이름을 바꾸지 않는다.
