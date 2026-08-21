# Architecture

This document explains how Sharmory is structured, how its internal components fit together, and why certain design decisions were made.

---

## High-Level Structure

```
sharmory/
├── functions.zsh       ← Zsh implementation + registry + orchestrator
├── functions.bash      ← Bash 4 implementation (1-to-1 port)
├── functions.ps1       ← PowerShell implementation
├── install.sh          ← Unix installer (curl | bash)
├── install.ps1         ← Windows installer (irm | iex)
├── uninstall.sh        ← Unix uninstaller
├── uninstall.ps1       ← Windows uninstaller
├── test-sharmory.zsh   ← Zsh smoke test runner
├── test-sharmory.bash  ← Bash smoke test runner
├── test-sharmory.ps1   ← PowerShell smoke test runner
├── package.json        ← npm package (sharmory-install CLI)
├── pyproject.toml      ← PyPI package (sharmory-install CLI)
└── packaging/
    ├── homebrew/       ← Homebrew formula
    ├── scoop/          ← Scoop manifest
    ├── npm/            ← npm install script
    └── python/         ← PyPI install package
```

---

## Three-File Parity

Sharmory maintains three parallel implementations. Every user-visible function exists in all three files with identical behavior and the same function name.

This is a deliberate design constraint:

- Users who switch shells (e.g. from Zsh to PowerShell) retain muscle memory.
- CI pipelines can pick the shell that matches their runner.
- The test suite validates parity by running the same logical tests against all three.

`functions.zsh` is the **primary** file. New functions are written there first, then ported. `functions.bash` tracks Zsh 1-to-1. `functions.ps1` uses PowerShell-native idioms to achieve the same outcomes.

---

## Internal Helpers

### `_sharmory_os()`

Detects the current OS and returns `macos`, `linux`, or `unknown`. Called by any function that needs to branch behavior (clipboard tools, DNS flush, memory stats, etc.).

```zsh
_sharmory_os() {
    case "$(uname)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}
```

Calling it as a function (rather than setting a global at source time) avoids polluting the user's environment. The cost is a `uname` fork per call, but this is negligible.

### `_sharmory_need()`

Checks whether an external command is available. Prints a standardized error message and returns 1 if not. Used at the top of any function that depends on an optional tool.

```zsh
_sharmory_need() {
    if ! command -v "$1" &>/dev/null; then
        echo "⚠️  '$1' is required for this command. Install it and try again."
        return 1
    fi
}
```

The PowerShell equivalent is `Test-SharmoryDependency`.

### `unalias` guard

The `unalias --` call at the top of `functions.zsh` and `functions.bash` clears any alias that shares a name with a Sharmory function. This is necessary because plugin managers (oh-my-zsh, Prezto) sometimes define aliases like `gst`, `gco`, and others that Sharmory also defines as functions. Without this guard, Zsh would silently define a function based on an alias, causing unexpected behavior.

The single multi-name call is more efficient than one `unalias` per function — it forks one process instead of 150+.

---

## The Registry

`_SHARMORY_REGISTRY` is a Zsh array defined in `functions.zsh`. Each element is a caret-delimited string with five fields:

```
category^name^description^usage^optional-deps
```

Example:
```zsh
'net^myip^Public-facing IP address^myip^'
```

The registry is the single source of truth for:
- `sharmory list` — tabular catalog
- `sharmory help <name>` — per-function description and usage
- `sharmory run <name>` — function dispatch
- The fzf HUD — real-time fuzzy catalog
- The numbered fallback menu

### Registry parsing

`_sharmory_parse_row()` splits a registry entry into five shell variables: `_sh_cat`, `_sh_name`, `_sh_desc`, `_sh_usage`, `_sh_deps`. It uses Zsh's parameter expansion to split on `^` without spawning a subshell.

```zsh
_sharmory_parse_row() {
    local row=$1
    _sh_cat=${row%%^*}
    local rest=${row#*^}
    _sh_name=${rest%%^*}
    rest=${rest#*^}
    _sh_desc=${rest%%^*}
    rest=${rest#*^}
    _sh_usage=${rest%%^*}
    _sh_deps=${rest#*^}
}
```

### Registry integrity check

`_sharmory_registry_check()` iterates the registry and verifies that every registered name has a corresponding function definition (`typeset -f "$name"`). This is used internally to catch mismatches during development.

---

## The HUD (sharmory command)

`sharmory` with no arguments launches the HUD. It has two modes:

### fzf mode (`_sharmory_hud_fzf`)

If `fzf` is available:
1. Renders all registry entries as tab-delimited rows.
2. Opens an interactive fzf session with `--preview` showing the usage and deps.
3. On selection, calls `_sharmory_prompt_and_run` to display help and optionally prompt for arguments.
4. Loops — the HUD stays open until the user presses Escape.

### Numbered menu mode (`_sharmory_hud_menu`)

If `fzf` is not available:
1. Prints a numbered table of all commands.
2. Presents a `sharmory>` prompt.
3. Accepts: a number, a function name, `list [cat]`, `help <name>`, `doctor`, `setup`, `bench`, `q`.

### `_sharmory_prompt_and_run`

After the user selects a function, this helper:
1. Shows the function's help text.
2. If the usage string contains `<required>`, prompts for arguments.
3. Calls `_sharmory_run` to dispatch.

---

## sharmory-doctor

`sharmory-doctor` is a health check that runs a series of inspections and prints a status table:

| Check | What it verifies |
|---|---|
| Sharmory loaded | `typeset -f sharmory` is truthy |
| Install path | `~/.sharmory/functions.zsh` exists |
| RC file | `~/.zshrc` contains a sharmory source line |
| Shell | Zsh version |
| Git | Installed + `user.name` and `user.email` configured |
| SSH | At least one `~/.ssh/*.pub` key exists |
| Docker | Installed + daemon reachable |
| kubectl | Installed |
| Optional tools | fzf, jq, eza, tldr, go, node, openssl, python3, entr/fswatch |
| Version | Local `$SHARMORY_VERSION` vs latest GitHub release tag |

Exit code is `0` unless Sharmory itself is not loaded.

---

## sharmory-bench

`sharmory-bench` measures how long a **clean Zsh** (no `.zshrc`, no plugins) takes to source `functions.zsh`. It:
1. Spawns `n` clean `zsh -c` subprocesses.
2. In each, loads `zsh/datetime` and measures `$EPOCHREALTIME` before and after `source`.
3. Discards the first run (warmup / disk cache cold).
4. Reports min, avg, max in milliseconds.

This is useful for detecting regressions — a large function addition that introduces complex `compdef` calls or subshell expansions at source time would show up here.

---

## Packaging

### npm (`packaging/npm/install.js`)

A Node.js script that runs when `sharmory-install` is called after `npm install -g sharmory`. It detects the shell, copies the right functions file to `~/.sharmory/`, and patches the RC file — mirroring what `install.sh` does.

### PyPI (`packaging/python/sharmory_install/`)

A Python package with the same installer logic, exposed as `sharmory-install` after `pip install sharmory`.

### Homebrew (`packaging/homebrew/sharmory.rb`)

A Homebrew formula that installs all three function files to the Cellar.

### Scoop (`packaging/scoop/sharmory.json`)

A Scoop manifest for Windows users.

---

## Design Principles

**Single-file sourcing.** Sharmory is designed to be sourced as a single file. No plugin manager, no framework, no module loader. The source time target is under 5 ms.

**Fail gracefully.** Every function that depends on an optional tool degrades cleanly — it either falls back to a simpler implementation or prints a helpful install hint. No function hard-crashes the shell.

**No global side effects.** Sharmory sets two global variables (`SHARMORY_VERSION`, `_SHARMORY_FILE`) and populates `_SHARMORY_REGISTRY`. Everything else is scoped to functions. No `setopt`, no `zstyle`, no `compdef` calls.

**Never `exit`.** All functions use `return`, not `exit`. Calling `exit` inside a sourced file would terminate the user's shell session.
