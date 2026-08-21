# Shell Compatibility

Sharmory ships three parallel implementations — one per supported shell. This document covers the compatibility matrix, known limitations, and platform-specific notes.

---

## Supported Shells

| Shell | File | Minimum version | Notes |
|---|---|---|---|
| Zsh | `functions.zsh` | 5.0 | Primary implementation; owns `_SHARMORY_REGISTRY` and the HUD |
| Bash | `functions.bash` | 4.0 | Full feature parity with Zsh; requires `local -A` (associative arrays) |
| PowerShell | `functions.ps1` | 5.1 | Full Windows support; also works on PowerShell Core 7+ (macOS/Linux) |

---

## Zsh

Zsh is the primary shell. The registry, HUD, `sharmory-doctor`, `sharmory-bench`, and `sharmory-setup` are all defined in `functions.zsh`.

### Minimum version

Zsh 5.0+ is required. Most modern systems ship 5.8 or later. Check with `zsh --version`.

### Plugin manager compatibility

Sharmory clears any aliases that conflict with its function names at load time via a single `unalias --` call near the top of `functions.zsh`. This prevents the "defining function based on alias" parse errors that occur when oh-my-zsh, Prezto, or Zinit have pre-defined a name Sharmory also uses.

The guard is intentionally a single call for all names — one fork instead of one per name.

### `emulate -L zsh`

The test runner calls `emulate -L zsh` to reset all Zsh options to their defaults inside the test subprocess. This is intentional — it ensures tests are not affected by user `.zshrc` customisations.

### `$EPOCHREALTIME`

`sharmory-bench` loads `zsh/datetime` to access `$EPOCHREALTIME` for millisecond-precision timing. This module is included in all standard Zsh distributions.

---

## Bash

`functions.bash` is a 1-to-1 port of the Zsh implementation, written in portable Bash 4 idioms.

### Bash 4.0 requirement

Bash 4.0 introduced associative arrays (`declare -A` / `local -A`). Several functions — `dotenv-check`, `envdiff` — use associative arrays for duplicate key detection.

**macOS ships Bash 3.2 by default** (due to the GPL v3 license change in Bash 4). To use `functions.bash` on macOS, install a modern Bash first:

```bash
brew install bash
```

Then either invoke it explicitly:
```bash
/opt/homebrew/bin/bash
```

Or change your login shell:
```bash
chsh -s /opt/homebrew/bin/bash
```

### Read syntax differences

Zsh's interactive `read "var?prompt "` syntax is not valid in Bash. All prompts in `functions.bash` use `read -r -p "prompt " var` instead.

### No `print -z`

The `hist` function in Zsh uses `print -z "$selected"` to paste the selection onto the readline buffer. This is Zsh-only and has no Bash equivalent. The Bash version of `hist` simply echoes the selection instead.

### PATH expansion in `treelist`

The fallback `treelist` implementation uses pure-shell depth calculation. The Zsh version uses `${(l:n:: :)}` for padding; the Bash version uses `printf '%*s' n ''`.

---

## PowerShell

`functions.ps1` uses native PowerShell cmdlets throughout. It works on both Windows PowerShell 5.1 and PowerShell Core 7+ on all platforms.

### Windows PowerShell 5.1 vs PowerShell Core 7+

Both are supported. PowerShell Core 7+ is recommended for cross-platform use (macOS / Linux). Check your version with `$PSVersionTable.PSVersion`.

### Execution policy

On a fresh Windows machine, the execution policy may block sourcing `.ps1` files. Allow user scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### No `_SHARMORY_REGISTRY`

The registry, HUD, `sharmory-doctor`, `sharmory-bench`, and `sharmory-setup` are only implemented in Zsh (and partially in Bash). `functions.ps1` exposes each function individually but does not include the meta-orchestrator. The meta functions (`sharmory`, `sharmory-doctor`, etc.) are not available in PowerShell.

### No `unalias` block

PowerShell does not have a concept of aliases conflicting with function definitions in the same way as Zsh/Bash. There is no `unalias` call in `functions.ps1`.

### Windows clipboard

`cwd`, `clipcopy`, and `clip` use `Set-Clipboard`, which is built into PowerShell 5.1+. No extra tool is needed on Windows.

### File watcher

`watchrun`, `gowatch`, `npmwatch`, and `pywatch` require `watchexec` on Windows and PowerShell. `entr` and `fswatch` are Unix-only.

### Unix tools that do not exist on Windows

PowerShell equivalents are used throughout `functions.ps1`:

| Unix | PowerShell |
|---|---|
| `curl` | `Invoke-RestMethod` / `Invoke-WebRequest` |
| `lsof -i :<port>` | `Get-NetTCPConnection -LocalPort <port>` |
| `kill <pid>` | `Stop-Process -Id <pid> -Force` |
| `dig` | `Resolve-DnsName` |
| `free -h` | `Get-CimInstance Win32_OperatingSystem` |
| `df -h` | `Get-PSDrive` |
| `pbcopy` / `xclip` | `Set-Clipboard` |
| `open` / `xdg-open` | `Start-Process` |

### `dsh` on Windows

`dsh` shells into a container with `docker exec -it ... sh -c "..."`. This requires Docker Desktop for Windows to be running and the container to have `sh` or `bash` available.

---

## WSL (Windows Subsystem for Linux)

WSL is treated as Linux. Use `install.sh` (not `install.ps1`) inside a WSL terminal. The detected shell will be Zsh or Bash depending on your WSL configuration.

WSL and Windows PowerShell are independent environments — `functions.zsh` inside WSL and `functions.ps1` inside PowerShell are separate installs.

---

## Platform Branching in Code

Both `functions.zsh` and `functions.bash` use `_sharmory_os` to branch macOS vs Linux behavior:

```bash
_sharmory_os() {
    case "$(uname)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}
```

Functions that branch on OS: `cwd`, `clipcopy`, `clip`, `trash`, `localip`, `flushdns`, `mem`, `cpu`, `ports`, `openports`, `sysinfo`, `certcheck`, `killport`, `recent`, `pingcheck`.

PowerShell does not need this helper — it uses native Windows cmdlets throughout.
