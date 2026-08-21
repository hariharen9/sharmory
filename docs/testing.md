# Testing

Sharmory has a sandboxed smoke-test suite for each of its three shells. This document explains how the test harness works, how to run tests, and how to write new tests.

---

## Overview

| File | Shell | Run with |
|---|---|---|
| `test-sharmory.zsh` | Zsh | `./test-sharmory.zsh` |
| `test-sharmory.bash` | Bash | `bash test-sharmory.bash` |
| `test-sharmory.ps1` | PowerShell | `pwsh ./test-sharmory.ps1` |

All three runners follow the same design:

1. Create a **disposable sandbox** in a temp directory.
2. Populate it with **mock binaries** that never touch the real network, real Docker/k8s, or real processes.
3. Create a **seed work directory** with a real git repo, sample files, a `.env`, a `package.json`, and test fixtures.
4. Run each test as an **isolated subprocess** that sources the functions file fresh.
5. Collect results, print a summary, and exit `0` (all pass/skip) or `1` (any failure).

---

## Running the Tests

```bash
# Zsh
./test-sharmory.zsh

# Bash
bash test-sharmory.bash

# PowerShell
pwsh ./test-sharmory.ps1

# Targeting a different functions file
./test-sharmory.zsh /path/to/functions.zsh
```

A passing run looks like:

```
Sandbox: /tmp/sharmory-test.abcXYZ
Testing: /Users/you/.sharmory/functions.zsh

──── Navigation & Files ────────────────────────────────
  PASS  mkcd — creates and enters directory
  PASS  up — go up 1 level
  PASS  lsd — fallback ls when eza absent
  ...

──── Summary ────────────────────────────────
  PASS  142   FAIL  0   SKIP  3
  All tests passed.
```

Exit code `0` = all tests passed or skipped.
Exit code `1` = at least one test failed.

Skipped tests are tests that require a tool (`entr`, `fswatch`, `jq`, etc.) that is not present on the test machine. They are never counted as failures.

---

## Sandbox Layout

```
/tmp/sharmory-test.XXXXXX/
├── mockbin/          ← fake binaries (docker, kubectl, curl, git remote, …)
├── fakehome/         ← fake $HOME (isolated from your real home directory)
│   └── .ssh/
│       ├── id_ed25519.pub
│       └── config
├── work/             ← the working directory for every test
│   ├── .git/         ← real git repo with a seeded history
│   ├── file1.txt
│   ├── main.go
│   ├── sample.json
│   ├── .env
│   ├── .env.clean
│   ├── .env.bad
│   ├── package.json
│   ├── a.json
│   ├── b.json
│   └── node_modules/
├── remote.git/       ← bare remote repo for push/fetch tests
├── env.zsh           ← environment file sourced by every test subprocess
└── results/          ← one .res file per test, read at the end
```

The entire sandbox is deleted on exit, whether tests pass or fail (`trap cleanup EXIT INT TERM`).

---

## Mock Binaries

Every external tool that Sharmory might call has a mock in `$MOCKBIN`. Mocks:

- **Never touch the real network** (curl, dig, ping return canned responses)
- **Never touch real Docker or Kubernetes** (docker, kubectl return canned JSON/text)
- **Never modify real processes** (kill is overridden to `echo "[mock] kill $*"`)
- **Never require root** (sudo is overridden to `echo "[mock] sudo $*"; "$@"`)

### Key mocks

| Mock | Behavior |
|---|---|
| `fzf` | Auto-selects the first non-empty line from stdin — no interactive TTY needed |
| `docker` | Returns canned container/image lists and build output |
| `kubectl` | Returns canned pod/context/namespace lists |
| `curl` | Returns `{"mock":"response"}` for generic URLs; specific canned bodies for Jenkins, functions.zsh download, etc. |
| `openssl` | Delegates to the real `openssl` except for `s_client` (returns a fake cert placeholder) |
| `git` | Real git is used — the sandbox contains a real initialized repo with seeded history |
| `ssh-keygen` | Writes fake key files instead of prompting for a passphrase |
| `npm`, `yarn`, `pnpm`, `node` | No-ops that always exit 0; `node -e` returns canned values for `nodeinfo` |
| `pip` | Returns `requests==2.28.0` for `freeze`, clean output for `list` |
| `ping` | Returns canned 5-packet output with realistic RTT values |
| `dig` | Returns `93.184.216.34` for A records, canned MX record |

### Environment file (`env.zsh`)

Every test subprocess sources `$ENVFILE`, which:
- Prepends `$MOCKBIN` to `$PATH`
- Sets `$HOME` to `$FAKEHOME` (isolates from your real `~`)
- Sets `PAGER=cat`, `EDITOR=cat`, `GIT_PAGER=cat` (prevents interactive pagers)
- Sets Jenkins env vars for Jenkins tests
- Overrides `kill` and `sudo`
- Sets git author identity for `mkproject` and `gacp` tests
- Sources `functions.zsh` (or the target functions file)

---

## Writing Tests

### Test functions

**`run`** — runs the test in the background (parallel):
```zsh
run "function-name — description of what is tested" "
    source \"\$ENVFILE\"
    # ... test body ...
"
```

**`runs`** — runs the test sequentially (use for tests that mutate shared state like git):
```zsh
runs "gacp — commits and pushes" "
    source \"\$ENVFILE\"
    gacp 'test commit'
    echo exit:\$?
"
```

**`skip`** — unconditionally skips a test with a reason:
```zsh
skip "watchrun — requires entr or fswatch" "neither entr nor fswatch installed"
```

A test **passes** when the subprocess exits with code `0`. It **fails** when the subprocess exits non-zero.

### Checking output

To assert on output, grep for a string and `echo ok` / `echo fail`:
```zsh
run "certcheck — prints expiry line" "
    source \"\$ENVFILE\"
    out=\$(certcheck example.com 2>&1)
    echo \"\$out\" | grep -q 'Expires' && echo ok || echo fail
"
```

Or check exit code directly:
```zsh
run "mkcd — creates directory" "
    source \"\$ENVFILE\"
    mkcd /tmp/sharmory-mkcd-test-\$\$
    echo exit:\$?
    rm -rf /tmp/sharmory-mkcd-test-\$\$
"
```

### Conditional skip

Skip a test when a dependency is missing:
```zsh
if (( HAS_JQ )); then
    run "jsonpp — pretty-prints JSON" "
        source \"\$ENVFILE\"
        jsonpp sample.json | grep -q 'mock' && echo ok || echo fail
    "
else
    skip "jsonpp — pretty-prints JSON" "jq not installed"
fi
```

Pre-detected flags available in all three test files: `HAS_JQ`, `HAS_PY`, `HAS_PIP`, `HAS_TAR`, `HAS_ENTR`, `HAS_FSWATCH`.

### Tests that modify git state

Use `runs` (sequential) for any test that commits, pushes, resets, or checks out — git state is shared across all tests in `$WORKDIR`. Parallel tests that mutate git will race:

```zsh
runs "gwip — creates a WIP commit" "
    source \"\$ENVFILE\"
    echo change >> file1.txt
    gwip
    git log --oneline | grep -q 'WIP:' && echo ok || echo fail
"
```

---

## Test Result Format

Each test writes a result file to `$RESULTSDIR/<seq>.res` with one of:

```
PASS <label>
FAIL <label>\x00<exit-code>\x00<log-snippet>
SKIP <label>\x00<reason>
```

Results are collected in insertion order after all background jobs complete, so the printed output always matches the source order of the tests regardless of which finished first.

---

## Timeout

If `timeout` (GNU coreutils) or `gtimeout` (via `brew install coreutils` on macOS) is available, each test subprocess is given a **10-second hard timeout**. Functions that loop indefinitely by design (`watchrun`, `gowatch`) are skipped when no timeout binary is available.

---

## Adding Tests for a New Function

1. Find the section in the test file that matches your function's category.
2. Add a `run` call (or `runs` if it mutates git state).
3. If the function requires an optional tool, wrap in an `if (( HAS_xxx ))` guard.
4. Test at least: **happy path** (returns 0), **missing required arg** (returns 1 and prints `Usage:`).

Example for a hypothetical `mynet` function:
```zsh
run "mynet — basic usage" "
    source \"\$ENVFILE\"
    mynet example.com
    echo exit:\$?
"

run "mynet — missing arg prints usage" "
    source \"\$ENVFILE\"
    out=\$(mynet 2>&1)
    echo \"\$out\" | grep -q 'Usage:' && echo ok || echo fail
"
```
