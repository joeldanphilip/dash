#!/usr/bin/env python3
"""Reject tracked path names that indicate imported accelerator RTL."""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys


FORBIDDEN = re.compile(r"(^|/)(sha256|sha-256|aes|crypto)(/|[._-])", re.IGNORECASE)
ALLOWED_EXTERNAL_DOC = re.compile(r"^spec/|^README\.md$|^scripts/", re.IGNORECASE)


def main() -> int:
    try:
        output = subprocess.check_output(
            ["git", "ls-files"], text=True, stderr=subprocess.STDOUT
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"repo-boundary: cannot inspect Git index: {exc}", file=sys.stderr)
        return 2

    offenders = []
    for raw in output.splitlines():
        path = pathlib.PurePosixPath(raw).as_posix()
        if FORBIDDEN.search(path) and not ALLOWED_EXTERNAL_DOC.search(path):
            offenders.append(path)

    if offenders:
        print("repo-boundary: forbidden accelerator-like tracked paths:")
        print("\n".join(f"  {path}" for path in offenders))
        return 1

    print(f"repo-boundary: PASS ({len(output.splitlines())} tracked paths checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
