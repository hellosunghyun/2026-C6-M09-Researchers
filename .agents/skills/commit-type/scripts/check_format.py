#!/usr/bin/env python3
"""Check team naming syntax without reading or changing Git state."""

import argparse
from pathlib import Path
import re
import sys


KINDS = (
    "feat", "fix", "docs", "style", "design", "test", "refactor", "build",
    "ci", "perf", "chore", "rename", "remove", "add",
)
KIND_PATTERN = "(?:" + "|".join(KINDS) + ")"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="kind", required=True)
    branch = commands.add_parser("branch", help="Check a proposed branch name only")
    branch.add_argument("name")
    commit = commands.add_parser("commit", help="Check a proposed commit subject only")
    value = commit.add_mutually_exclusive_group(required=True)
    value.add_argument("--message")
    value.add_argument("--file", type=Path)
    args = parser.parse_args()

    if args.kind == "branch":
        text = args.name
        valid = re.fullmatch(KIND_PATTERN + r"/#[0-9]+-[^\r\n]+", text)
        expected = "종류/#이슈번호-작업자 이름"
        scope = "Git ref 유효성·이슈 존재·작업자 확인은 별도입니다."
    else:
        try:
            message = args.file.read_text(encoding="utf-8") if args.file else args.message
        except (OSError, UnicodeError) as error:
            print(f"미실행: 메시지 파일을 읽을 수 없습니다: {error}", file=sys.stderr)
            return 2
        # Body/footer content is unrestricted; only the first line is the subject.
        text = message.split("\n", 1)[0].removesuffix("\r")
        valid = re.fullmatch(KIND_PATTERN + r"/#[0-9]+: [^\r\n]+", text)
        expected = "종류/#이슈번호: 커밋메시지"
        scope = "이슈 존재·diff와 메시지의 일치는 별도입니다."

    if not valid:
        print(f"형식 불일치: {expected} ({', '.join(KINDS)})", file=sys.stderr)
        return 1
    print(f"형식 통과. {scope}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
