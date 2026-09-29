#!/usr/bin/env python3
"""PostToolUse hook for Write — launches revdiff when a new plan file is created.

Intercepts Write tool calls where file_path matches docs/plans/*.md (not completed/).
Launches revdiff TUI for the user to review and annotate the plan.
If annotations found, outputs them to stderr with exit 2 so Claude addresses them.
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

PLUGINS_CACHE = Path.home() / ".claude" / "plugins" / "cache" / "revdiff"


def find_launcher() -> str:
    for p in sorted(PLUGINS_CACHE.glob("revdiff-planning/*/scripts/launch-plan-review.sh"), reverse=True):
        return str(p)
    for p in sorted(PLUGINS_CACHE.glob("revdiff/*/.claude-plugin/skills/revdiff/scripts/launch-revdiff.sh"), reverse=True):
        return str(p)
    return ""


def main() -> None:
    raw = sys.stdin.read()
    if not raw.strip():
        return

    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        return

    file_path = event.get("tool_input", {}).get("file_path", "")
    if not file_path:
        return

    if not re.search(r"docs/plans/[^/]+\.md$", file_path):
        return

    if "/completed/" in file_path:
        return

    if not Path(file_path).exists():
        return

    if not shutil.which("revdiff"):
        return

    launcher = find_launcher()
    if not launcher:
        return

    try:
        result = subprocess.run(
            [launcher, file_path],
            capture_output=True, text=True, timeout=345600,
        )
        annotations = result.stdout.strip()
        if annotations:
            print(
                "user reviewed the plan in revdiff and added annotations. "
                "each annotation references a specific line and contains the user's feedback.\n\n"
                f"{annotations}\n\n"
                "adjust the plan to address each annotation, then offer the updated plan for review.",
                file=sys.stderr,
            )
            sys.exit(2)
    except (subprocess.TimeoutExpired, OSError):
        return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\r\033[K", end="")
        sys.exit(130)
