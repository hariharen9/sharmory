# Contributing to Sharmory

Thank you for contributing. This document covers the workflow, code standards, and review process.

---

## Before You Start

- **New functions** — read [`docs/adding-a-function.md`](adding-a-function.md) first. It has a complete checklist for every step.
- **Bug fixes** — open an issue first if the fix is non-trivial, so we can align before you write code.
- **Questions** — open a GitHub Discussion rather than an issue.

---

## Development Setup

No build step is required. Sharmory is plain shell scripts.

```bash
git clone https://github.com/hariharen9/sharmory.git
cd sharmory
```

Test your changes by sourcing the file directly:
```bash
source functions.zsh   # Zsh
source functions.bash  # Bash
. ./functions.ps1      # PowerShell
```

---

## Branch Naming

| Type | Pattern | Example |
|---|---|---|
| New function | `feat/function-name` | `feat/gitlog-summary` |
| Bug fix | `fix/short-description` | `fix/gacp-newline-in-message` |
| Documentation | `docs/topic` | `docs/adding-a-function` |
| Refactor | `refactor/short-description` | `refactor/sharmory-registry` |

Work off `main`. There are no long-lived feature branches.

---

## Commit Style

Use the **Conventional Commits** format:

```
<type>(<scope>): <short summary>
```

Common types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

Examples:
```
feat(git): add gitlog-summary function
fix(gacp): handle commit messages with newlines
docs(contributing): add branch naming guide
test(zsh): add smoke tests for envdiff
chore: bump version to 1.1.0
```

Keep the subject line under 72 characters. Add a body if the change needs explanation.

---

## Making Changes

### 1. Implement in all 3 files

Every user-facing function must exist in `functions.zsh`, `functions.bash`, and `functions.ps1`. See [`docs/adding-a-function.md`](adding-a-function.md) for the full process.

Internal helpers (prefixed `_sharmory_`) only need to exist in the file that uses them.

### 2. Follow existing style

- Use 4-space indentation in all three files.
- Write a `# Usage: funcname <arg>` comment above every function.
- Use `_sharmory_need` (Zsh/Bash) or `Test-SharmoryDependency` (PS) for optional external tools — never hard-require them.
- Never use `exit` inside a function — always `return`.
- Keep functions focused. One function, one job.

### 3. Do not add dead code

- No functions that are not registered in `_SHARMORY_REGISTRY`.
- No `echo "debug"` lines.
- No commented-out alternative implementations.

### 4. Cross-platform behavior

If a function branches on OS, it must handle all three cases: `macos`, `linux`, and a safe fallback. For PowerShell, use native cmdlets — never assume `curl`, `grep`, or `awk` are available.

---

## Running Tests

Run the test suite for the shell you changed. All three must pass before opening a PR.

```bash
# Zsh
./test-sharmory.zsh

# Bash
bash test-sharmory.bash

# PowerShell
pwsh ./test-sharmory.ps1
```

Exit code `0` = all tests passed or were intentionally skipped.
Exit code `1` = at least one test failed.

Tests run in a sandboxed temp directory with mocked external commands. See [`docs/testing.md`](testing.md) for a deep-dive on the test harness.

---

## Pull Request Checklist

Copy this into your PR description:

```
[ ] functions.zsh  — function implemented in the correct section
[ ] functions.bash — function ported with Bash 4 idioms
[ ] functions.ps1  — function ported with PowerShell idioms
[ ] unalias block  — name added to functions.zsh and functions.bash
[ ] _SHARMORY_REGISTRY — one entry added in functions.zsh
[ ] test-sharmory.zsh  — smoke tests pass
[ ] test-sharmory.bash — smoke tests pass
[ ] test-sharmory.ps1  — smoke tests pass
[ ] SHARMORY_VERSION bumped in all 3 files
[ ] README.md updated (if user-facing)
```

---

## Code Review

Reviews focus on:
- **Correctness** — does the function do what the description says?
- **Graceful degradation** — does it fail safely when optional tools are missing?
- **Cross-platform parity** — does the PS version behave equivalently to the Zsh/Bash versions?
- **No `exit`** — functions must use `return`, not `exit`.
- **Test coverage** — every new code path needs at least one smoke test.

A PR that touches only one shell file will not be merged. All three must be updated together.

---

## Versioning

Sharmory uses [Semantic Versioning](https://semver.org/):

- **Patch** (`x.y.Z`) — bug fixes, documentation, test additions
- **Minor** (`x.Y.0`) — new functions, backwards-compatible behavior changes
- **Major** (`X.0.0`) — breaking changes (function renamed or removed, argument order changed)

Bump the version in all three files as part of your PR. See [`docs/release-checklist.md`](release-checklist.md) for the full release process.

---

## Reporting Bugs

Open a GitHub issue with:
1. Your OS and shell version (`uname -a`, `zsh --version` / `bash --version` / `$PSVersionTable`)
2. The function name and the command you ran
3. The full output (including any error messages)
4. What you expected to happen

If `sharmory doctor` output is relevant, include it.
