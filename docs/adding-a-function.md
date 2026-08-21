# Adding a New Function to Sharmory

This guide covers the complete, end-to-end process for adding a new shell function to Sharmory. Every new function touches **5 mandatory places** and optionally a 6th for tests.

---

## Overview

Sharmory ships three parallel implementations of every function — one per supported shell. When you add a function, you must implement it in all three and register it in the catalog. The table below shows what each file is responsible for:

| File | Shell | Notes |
|---|---|---|
| `functions.zsh` | Zsh | Primary file; also owns the `_SHARMORY_REGISTRY` catalog |
| `functions.bash` | Bash 4+ | 1-to-1 port of the Zsh file, Bash idioms only |
| `functions.ps1` | PowerShell 5.1+ | Equivalent logic using PS cmdlets |

---

## Step 1 — Implement in `functions.zsh`

Open `functions.zsh` and add your function in the **correct numbered section**:

| Section | Category |
|---|---|
| 1 | Navigation & Files |
| 2 | Git |
| 3 | Docker & Kubernetes |
| 4 | Go Development |
| 5 | Node / npm |
| 6 | Python |
| 7 | Networking & APIs |
| 8 | Security & Encoding |
| 9 | System & Process |
| 10 | Productivity & Misc |
| 11 | CI / Jenkins |
| 12 | Sharmory Management (meta) |

If the category is genuinely new, add a new numbered section header.

### Function template (Zsh)

```zsh
# One-line description of what the function does
# Usage: myfunc <required-arg> [optional-arg]
myfunc() {
    if [[ -z "$1" ]]; then
        echo "Usage: myfunc <required-arg> [optional-arg]"
        return 1
    fi
    _sharmory_need sometool || return 1   # only if an external tool is required
    local arg=$1
    # ... implementation ...
}
```

### Conventions

- Write a `# Usage:` comment directly above the function definition.
- Use `_sharmory_need <tool>` for optional external dependencies — it prints a friendly error and returns 1 if the tool is missing.
- Use `_sharmory_os` to branch macOS vs Linux behavior (`macos` | `linux` | `unknown`).
- Always `return 1` on bad input and print the `Usage:` line.
- Never `exit` — only `return`. Exiting would kill the user's shell session.

---

## Step 2 — Port to `functions.bash`

Open `functions.bash` and add the same function. The logic must be identical, but written in Bash 4 idioms.

### Key differences from Zsh

| Zsh | Bash equivalent |
|---|---|
| `read "var?prompt "` | `read -r -p "prompt " var` |
| `typeset -g VAR` | `VAR=value` (global by default outside functions) |
| `${(%):-%x}` (current file path) | `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"` |
| `${(l:n:: :)}` (pad string) | `printf '%*s' n ''` |
| `local -A assoc` (associative array) | `local -A assoc` (Bash 4+ only) |
| `print -z "$cmd"` (put on cmdline) | No equivalent — omit or use `echo` |

### Function template (Bash)

```bash
# One-line description of what the function does
# Usage: myfunc <required-arg> [optional-arg]
myfunc() {
    if [[ -z "$1" ]]; then
        echo "Usage: myfunc <required-arg> [optional-arg]"
        return 1
    fi
    _sharmory_need sometool || return 1
    local arg=$1
    # ... implementation ...
}
```

---

## Step 3 — Port to `functions.ps1`

Open `functions.ps1` and add the PowerShell equivalent. Use native PS cmdlets — never rely on `curl`, `lsof`, `grep`, etc. being available on Windows.

### Common substitutions

| Unix tool | PowerShell equivalent |
|---|---|
| `curl -s <url>` | `Invoke-RestMethod <url>` or `Invoke-WebRequest` |
| `lsof -i :<port>` | `Get-NetTCPConnection -LocalPort <port>` |
| `kill <pid>` | `Stop-Process -Id <pid> -Force` |
| `grep`, `awk`, `sed` | PowerShell pipeline (`Where-Object`, `ForEach-Object`, `-replace`, `-match`) |
| `echo "msg"` | `Write-Host "msg"` |
| `_sharmory_need tool` | `Test-SharmoryDependency tool` |

### Function template (PowerShell)

```powershell
# One-line description of what the function does
# Usage: myfunc <required-arg> [optional-arg]
function myfunc {
    param(
        [Parameter(Mandatory)][string]$RequiredArg,
        [string]$OptionalArg
    )
    if (-not (Test-SharmoryDependency sometool)) { return }   # only if needed
    # ... implementation ...
}
```

---

## Step 4 — Add to the `unalias` block

In **both** `functions.zsh` and `functions.bash`, the top of the file contains a long `unalias --` call. Add your function name to it. This prevents "defining function based on alias" parse errors when a plugin manager (oh-my-zsh, Prezto) has already claimed the name.

```zsh
unalias -- \
    mkcd up lsd fcd ...
    myfunc \            # ← add your function name here
    ...
    2>/dev/null; true
```

> `functions.ps1` does not have an `unalias` block — skip this step for it.

---

## Step 5 — Register in `_SHARMORY_REGISTRY`

This is the most important step for discoverability. The registry lives at the bottom of `functions.zsh` and powers `sharmory list`, `sharmory help <name>`, and the interactive fzf HUD.

Add one entry in the array using the **caret-delimited** format:

```
'category^name^description^usage^optional-deps'
```

### Fields

| Field | Description |
|---|---|
| `category` | One of: `files`, `git`, `docker`, `k8s`, `go`, `node`, `python`, `net`, `security`, `system`, `prod`, `jenkins`, `meta` |
| `name` | Exact function name — must match the function definition |
| `description` | Single-line summary shown in `sharmory list` |
| `usage` | Usage string shown in `sharmory help` — use `<required>` and `[optional]` notation |
| `optional-deps` | Comma-separated tool names the function uses, or empty if none |

### Example

```zsh
'net^myfunc^Check reachability of a host on a port^myfunc <host> <port>^curl'
```

Place it inside the block for its category for readability:

```zsh
_SHARMORY_REGISTRY=(
    ...
    'net^myip^Public-facing IP address^myip^'
    'net^myfunc^Check reachability of a host on a port^myfunc <host> <port>^curl'   # ← new
    ...
)
```

> A function that exists in the code but is **not** in the registry will work when called directly, but will be invisible to `sharmory list`, `sharmory help`, and the HUD.

---

## Step 6 — Write tests

Each shell has its own smoke-test runner that mocks all external commands (no real network calls, no real Docker/k8s, no real git remotes):

| Test file | Tests |
|---|---|
| `test-sharmory.zsh` | Zsh implementation |
| `test-sharmory.bash` | Bash implementation |
| `test-sharmory.ps1` | PowerShell implementation |

### Test pattern (Zsh / Bash)

```zsh
_test "myfunc — basic usage" "
    source \"\$ENVFILE\"
    myfunc somearg
    echo exit:\$?
" "exit:0"

_test "myfunc — missing arg prints usage" "
    source \"\$ENVFILE\"
    out=\$(myfunc 2>&1)
    echo \"\$out\" | grep -q 'Usage:' && echo ok || echo fail
" "ok"
```

Each test runs in a subprocess inside a throwaway `$SANDBOX` temp directory. Mock binaries live in `$MOCKBIN` and are on `$PATH` for the duration of the test run.

### Running the tests

```bash
# Zsh
./test-sharmory.zsh

# Bash
bash test-sharmory.bash

# PowerShell
pwsh ./test-sharmory.ps1
```

Exit code `0` means all tests passed or were skipped. Exit code `1` means at least one test failed.

---

## Step 7 — Bump the version

Update the version constant in all three function files:

**`functions.zsh`**
```zsh
typeset -g SHARMORY_VERSION="x.y.z"
```

**`functions.bash`**
```bash
SHARMORY_VERSION="x.y.z"
```

**`functions.ps1`**
```powershell
$script:SharmoryVersion = "x.y.z"
```

---

## Step 8 — Update the README (if user-facing)

`README.md` contains a command reference table. If the new function is something users should know about, add a row. The `sharmory list` command auto-generates an up-to-date catalog from the registry, so at minimum the registry entry is sufficient.

---

## Complete Checklist

Copy this checklist into your PR description:

```
[ ] functions.zsh  — function implemented in the correct section
[ ] functions.bash — function ported with Bash 4 idioms
[ ] functions.ps1  — function ported with PowerShell idioms
[ ] unalias block  — name added to functions.zsh and functions.bash
[ ] _SHARMORY_REGISTRY — one entry added in functions.zsh
[ ] test-sharmory.zsh  — smoke tests added
[ ] test-sharmory.bash — smoke tests added
[ ] test-sharmory.ps1  — smoke tests added
[ ] SHARMORY_VERSION bumped in all 3 files
[ ] README.md updated (if user-facing)
```
