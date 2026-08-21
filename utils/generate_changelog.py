#!/usr/bin/env python3
"""
generate_changelog.py
Walks every commit in the repo and produces CHANGELOG.md listing
the shell functions added in each commit (detected from functions.bash,
functions.zsh, and functions.ps1 diffs).

Since all three files have 1-1 parity, each function is listed only once
per commit (deduplicated globally across all three files).
Private helpers (names starting with _) and internal test helpers
(Test-Sharmory*) are excluded.
"""

import re
import subprocess
from datetime import datetime


# Files to scan for new function definitions (order determines attribution priority)
FUNCTION_FILES = ["functions.bash", "functions.zsh", "functions.ps1"]

# Matches added bash/zsh style:  +funcname() {
BASH_PATTERN = re.compile(r"^\+([a-zA-Z][a-zA-Z0-9_]*)\(\)")
# Matches added bash keyword style:  +function funcname {
BASH_KW_PATTERN = re.compile(r"^\+function\s+([a-zA-Z][a-zA-Z0-9_]*)\s*[\({]")
# Matches added PowerShell style:  +function Verb-Noun {
# Excludes internal test helpers like Test-SharmoryDependency
PS_PATTERN = re.compile(r"^\+function\s+([a-zA-Z][a-zA-Z0-9_-]*)\s*[\({]", re.IGNORECASE)
PS_EXCLUDE = re.compile(r"^Test-Sharmory", re.IGNORECASE)


def is_public(name):
    """Return True if the function name should be included in the changelog."""
    if name.startswith("_"):
        return False
    if PS_EXCLUDE.match(name):
        return False
    return True


def git(*args):
    result = subprocess.run(
        ["git"] + list(args),
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def get_commits():
    """Return list of commits oldest-first."""
    log = git("log", "--reverse", "--format=%H\x1f%s\x1f%ci")
    commits = []
    for line in log.splitlines():
        parts = line.split("\x1f", 2)
        if len(parts) == 3:
            commits.append({"hash": parts[0], "subject": parts[1], "date": parts[2][:10]})
    return commits


def get_added_functions(commit_hash):
    """
    Return a deduplicated list of public functions added in this commit.
    Scans all three function files but counts each function only once.
    """
    seen = set()
    added = []

    for fname in FUNCTION_FILES:
        try:
            diff = git("show", commit_hash, "--", fname)
        except subprocess.CalledProcessError:
            continue

        for line in diff.splitlines():
            # Only look at added lines (start with +, not +++)
            if not line.startswith("+") or line.startswith("+++"):
                continue

            for pat in (BASH_PATTERN, BASH_KW_PATTERN, PS_PATTERN):
                m = pat.match(line)
                if m:
                    func = m.group(1)
                    if func not in seen and is_public(func):
                        seen.add(func)
                        added.append(func)
                    break

    return added


def format_section(commit, funcs):
    """Return a markdown section string for one commit."""
    lines = []
    lines.append(f"## {commit['date']} — {commit['subject']}")
    lines.append(f"> Commit `{commit['hash'][:8]}` · {len(funcs)} function(s) added\n")
    for f in funcs:
        lines.append(f"- `{f}()`")
    lines.append("")
    return "\n".join(lines)


def main():
    commits = get_commits()
    sections = []
    total_funcs = 0

    for commit in commits:
        funcs = get_added_functions(commit["hash"])
        if funcs:
            sections.append(format_section(commit, funcs))
            total_funcs += len(funcs)

    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M")
    header = f"""# Changelog

> Lists every public shell function introduced per commit.
> Functions are deduplicated across `functions.bash`, `functions.zsh`, and `functions.ps1`.

---

"""
    changelog = header + "\n---\n\n".join(sections) + "\n"

    with open("CHANGELOG.md", "w") as fh:
        fh.write(changelog)

    print(f"✓ CHANGELOG.md written — {len(sections)} commits, {total_funcs} functions tracked.")


if __name__ == "__main__":
    main()
