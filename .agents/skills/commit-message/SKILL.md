---
name: commit-message
description: Labcord 커밋 메시지를 작성·검토하거나 변경을 커밋 단위로 정리할 때 사용한다.
---

# 커밋 메시지 작성·검사

메시지는 `종류/#이슈번호: 커밋메시지`로 작성한다. 예: `feat/#1: 메인화면 구현`. 커밋은 최대한 자주 진행한다. 글자 수 제한이나 본문·푸터 의무는 추가하지 않는다.

- 규칙 설명 요청: 형식과 종류를 설명한다. 종류 구분이 필요하면 [작업 종류](../commit-type/SKILL.md)를 읽는다.
- 메시지 작성 요청: `git diff --cached`와 실제 이슈 번호를 확인해 초안만 작성한다. 자동 stage·commit·push는 하지 않는다.
- 형식 검사 요청: 아래 명령으로 초안 문자열 또는 메시지 파일을 검사한다. 이슈 존재·변경 내용과의 일치는 별도로 확인한다.
- 커밋 실행 요청: 사용자가 지정한 범위의 staged diff와 메시지를 확인하고 커밋한다. push는 별도 요청 범위에 있을 때만 수행한다.

저장소 루트에서 둘 중 하나를 실행한다. 파일 경로의 공백은 따옴표로 감싼다.

```sh
python3 .agents/skills/commit-type/scripts/check_format.py commit --message 'docs/#32: 작업 규칙 정리'
python3 .agents/skills/commit-type/scripts/check_format.py commit --file '/tmp/commit message.txt'
```

검사 실패를 자동 수정이나 커밋 실행으로 연결하지 않는다. 실제 이슈 번호를 모르거나 staged 변경이 없으면 그 상태를 알리고 추정값을 사용하지 않는다.
