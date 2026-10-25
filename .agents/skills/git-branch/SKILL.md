---
name: git-branch
description: Labcord 작업 브랜치를 만들거나 이름과 분기·통합 흐름을 검토할 때 사용한다.
---

# 브랜치 이름과 흐름

- 이름은 `종류/#이슈번호-작업자 이름`으로 작성한다. 예: `feat/#1-Theo`.
- 실제 작업 종류·이슈 번호·작업자를 사용하며 예시 값을 그대로 사용하지 않는다.
- 배포 가능한 코드는 `main`, 다음 배포의 개발 코드는 `develop`에서 관리한다.
- 기능 작업은 `develop`에서 분기하고 완료 후 `develop`으로 통합한다.
- 배포 준비는 `develop`에서 `release`를 분기해 검증·수정한 뒤 `main`과 `develop`에 통합한다.
- 운영 긴급 수정은 `main`에서 `hotfix`를 분기하고 완료 후 `main`과 `develop`에 반영한다.
- 브랜치 이름의 종류는 기능 추가 feat, 버그 수정 fix, 문서 docs, 코드 스타일 style, UI design, 테스트 test, 프로덕션 리팩토링 refactor, 빌드 build, CI ci, 성능 perf, 기타 chore, 이름 변경 rename, 삭제 remove, 패키지·파일 추가 add 중 실제 작업에 맞게 고른다.

브랜치 생성·전환 전 기존 사용자 변경을 보존한다. 이 Skill은 merge·배포 권한을 부여하지 않는다.
