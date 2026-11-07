"""Validate new VPFL commit headings without third-party dependencies."""

import argparse
import re
import subprocess
import sys
from pathlib import Path


HEADING = re.compile(
    r"^(feat|fix|refactor|perf|docs|test|build|ci|chore)"
    r"(?:\([a-z][a-z0-9_-]*\))?!?: \S(?:.*\S)?$"
)


def validate(message: str) -> list[str]:
    lines = message.splitlines()
    if not message.strip():
        return ["message is empty"]

    errors = []
    if len(lines[0]) > 72:
        errors.append("heading exceeds 72 characters")
    if not HEADING.fullmatch(lines[0]):
        errors.append("heading must use type(scope): description (scope optional)")
    if len(lines) > 1 and lines[1] != "":
        errors.append("separate the body from the heading with a blank line")
    return errors


def git_output(*arguments: str) -> str:
    return subprocess.check_output(("git", *arguments), text=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", type=Path, help="check a commit message file")
    source.add_argument("--range", dest="commit_range", help="check commits in a Git range")
    args = parser.parse_args()

    if args.file:
        messages = [(str(args.file), args.file.read_text())]
    else:
        commits = git_output("rev-list", "--reverse", "--no-merges", args.commit_range).splitlines()
        messages = [
            (commit[:12], git_output("show", "-s", "--format=%B", commit))
            for commit in commits
        ]

    failures = 0
    for source_name, message in messages:
        errors = validate(message)
        for error in errors:
            print(f"{source_name}: {error}", file=sys.stderr)
        failures += bool(errors)
    if not failures:
        print(f"Validated {len(messages)} commit message(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
