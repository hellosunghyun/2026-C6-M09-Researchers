---
name: code-conventions
description: Labcord Swift 코드를 작성·정리하거나 코드 스타일과 lint 결과를 검토할 때 사용한다.
---

# 코드 스타일과 lint

- 규칙 설명 요청: [Swift 작성 규칙](references/swift-style.md)을 읽어 필요한 규칙만 설명한다. lint의 활성 규칙·범위는 실제 저장소의 `.swiftlint.yml`을 확인한다.
- 검사 요청: 파일을 수정하지 않고 아래 도우미를 실행한다. 저장소 루트와 설정·도구 설치를 확인한 뒤 루트에서 `git diff --check`, `swiftlint --strict`를 실행한다.
- 수정 요청: 명시적으로 요청된 파일과 위반 사항만 수정한다. 변경 diff를 확인하고 strict 검사를 다시 수행한다. 검사 실패를 자동 수정·stage·commit·push로 연결하지 않는다.

저장소 루트에서 실행:

```sh
python3 .agents/skills/code-conventions/scripts/check_lint.py --repo .
```

경로에 공백이 있으면 인자를 따옴표로 감싼다. 도우미는 캐시 쓰기를 피하도록 `--no-cache`를 덧붙이고 Git index 자동 갱신을 해당 명령에서만 끈다. 저장소 설정 변경·자동 설치·fix는 하지 않는다. 도구·설정이 없으면 미실행으로, 실행한 검사는 실제 종료 코드와 결과로 보고한다. 실제 `.github/workflows/swiftlint.yml`의 CI 실행 방식과 로컬 결과를 구분한다.
