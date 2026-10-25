#!/usr/bin/env python3
"""Run read-only whitespace and strict SwiftLint checks at the repository root."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


def run(command, root, env):
    print(f"검사: {' '.join(command)} (cwd: {root})", flush=True)
    result = subprocess.run(command, cwd=root, env=env, check=False)
    print(f"종료 코드: {result.returncode}", flush=True)
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True, help="Repository root or subdirectory")
    args = parser.parse_args()
    if not args.repo.is_dir():
        print("미실행: 저장소 경로가 디렉터리가 아닙니다.", file=sys.stderr)
        return 2
    git = shutil.which("git")
    if not git:
        print("미실행: git이 설치되어 있지 않습니다. 자동 설치하지 않습니다.", file=sys.stderr)
        return 127
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    location = subprocess.run(
        [git, "-C", str(args.repo.resolve()), "rev-parse", "--show-toplevel"],
        env=env, capture_output=True, text=True, check=False,
    )
    if location.returncode:
        print(location.stderr, file=sys.stderr, end="")
        print("미실행: Git 작업 트리 루트를 확인할 수 없습니다.", file=sys.stderr)
        return location.returncode
    root = Path(location.stdout.rstrip("\n"))
    whitespace = run([git, "-c", "diff.autoRefreshIndex=false", "diff", "--check"], root, env)
    config = root / ".swiftlint.yml"
    try:
        with config.open("rb") as stream:
            stream.read(1)
    except OSError as error:
        print(f"lint 미실행: 루트 .swiftlint.yml을 읽을 수 없습니다: {error}", file=sys.stderr)
        return whitespace or 2
    swiftlint = shutil.which("swiftlint")
    if not swiftlint:
        print("lint 미실행: swiftlint가 설치되어 있지 않습니다. 자동 설치하지 않습니다.", file=sys.stderr)
        return whitespace or 127
    lint = run([swiftlint, "--strict", "--no-cache"], root, env)
    return whitespace or lint


if __name__ == "__main__":
    # Preserve tool failure as failure even when the other check succeeds.
    sys.exit(main())
