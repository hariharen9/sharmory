# Optional Dependencies

Sharmory works out of the box with no extra tools. When optional tools are present, specific functions unlock enhanced behavior. All functions degrade gracefully — they either fall back to a simpler implementation or print a friendly install hint.

Run `sharmory doctor` to see which tools are present and which are missing on your system.
Run `sharmory setup` to interactively install the recommended CLI tools.

---

## Recommended Tools

These four tools have the biggest impact. Install all of them for the best experience.

### fzf — Fuzzy Finder

**Install:** `brew install fzf` · `apt install fzf` · `winget install fzf`

Unlocks interactive pickers throughout Sharmory. Without it, several functions simply do not work or fall back to a numbered menu.

Functions that use `fzf`:
- `fcd` — fuzzy cd into a subdirectory
- `ftext` — fuzzy-search file contents
- `gswitch` — fuzzy branch switcher
- `gstash` — interactive stash picker
- `dsh` — pick a running container to shell into
- `k8sctx`, `klogs`, `kexec`, `kdesc` — all Kubernetes interactive pickers
- `fkill` — fuzzy process killer
- `hist` — fuzzy shell history search
- `sharmory` HUD — uses fzf for the interactive catalog; falls back to a numbered text menu

### jq — JSON Processor

**Install:** `brew install jq` · `apt install jq` · `winget install jqlang.jq`

Used for JSON parsing and pretty-printing.

Functions that use `jq`:
- `jsonpp` — pretty-print a JSON file
- `npmscripts` — list package.json scripts
- `diffjson` — semantic JSON diff
- `jwtdecode` — decode a JWT header and payload
- `apihit` — pretty-print the JSON response body
- `ipinfo` — format the ipinfo.io response
- `jenk-crumb`, `jenk-jobs` — Jenkins API responses

### eza — Modern `ls` Replacement

**Install:** `brew install eza` · `apt install eza` · `winget install eza-community.eza`

Used by `lsd` for a richer directory listing with icons, git status, long format, and sort by modification time. Without `eza`, `lsd` falls back to plain `ls -la`.

### tldr — Simplified Man Pages

**Install:** `brew install tldr` · `npm install -g tldr` · `winget install tldr`

Used by `cheat`. Without it, `cheat` falls back to the system `man` pages.

---

## File Watcher Tools

At least one of these is needed for any "watch and re-run" function.

### entr

**Install:** `brew install entr` · `apt install entr`

Preferred watcher on macOS and Linux. Used by:
- `watchrun` — re-run any command when a path changes
- `gowatch` — re-run Go tests on `.go` file changes
- `npmwatch` — re-run an npm script on source file changes
- `pywatch` — re-run pytest on `.py` file changes

### fswatch

**Install:** `brew install fswatch`

macOS alternative to `entr`. `watchrun` uses `fswatch` if `entr` is not present.

### watchexec

**Install:** `winget install watchexec.watchexec` · `scoop install watchexec`

Windows / cross-platform alternative. Used by `gowatch`, `npmwatch`, and `pywatch` on PowerShell, and as an `entr` fallback on Bash.

---

## Language Runtimes

These are not installed by `sharmory setup` — they are too heavyweight for the setup script to manage. Sharmory checks for them in `sharmory doctor` and degrades gracefully when missing.

### python3 (≥ 3.8)

Used by:
- `urlencode`, `urldecode` — URL encoding via `urllib.parse`
- `genuuid` — UUID generation when `uuidgen` is not present
- `calc` — expression evaluation via `python3 -c "print(...)"`
- `pyprofile` — cProfile wrapper

### openssl

Used by:
- `passgen` — random password generation via `openssl rand`
- `certcheck`, `tlscheck` — TLS certificate inspection via `openssl s_client`

Usually pre-installed on macOS and most Linux distributions.

### go

Required for all functions in the **Go Development** category. `sharmory doctor` checks for its presence and reports the path.

### node

Required for all functions in the **Node / npm** category (`nodeinfo`, `nodeversion`, `noderepl`, etc.).

### docker

Required for all functions in the **Docker** category. The daemon must also be running for functions like `dsh`, `denv`, and `dockerclean-images`.

### kubectl

Required for all functions in the **Kubernetes** category.

---

## ncdu — Disk Usage Analyzer

**Install:** `brew install ncdu` · `apt install ncdu`

Used by `diskusage`. Without it, `diskusage` falls back to a `df` + `du` summary.

---

## Summary Table

| Tool | Category | Fallback if missing |
|---|---|---|
| `fzf` | Interactive pickers | Functions return error or use numbered menu |
| `jq` | JSON handling | Raw output or function returns error |
| `eza` | File listing | Falls back to `ls -la` |
| `tldr` | Help | Falls back to `man` |
| `entr` | File watching | Falls back to `fswatch` or returns error |
| `fswatch` | File watching | Falls back to `entr` or returns error |
| `watchexec` | File watching (Windows) | Returns error |
| `python3` | Encoding, calc | Functions return error |
| `openssl` | Crypto / TLS | Functions return error |
| `ncdu` | Disk usage | Falls back to `df`/`du` summary |
| `pstree` | Process tree | Falls back to `ps` |
| `uuidgen` | UUID generation | Falls back to `python3` |
| `govulncheck` | Go vuln scan | Auto-installed by `govscan` on first run |
| `uv` | Python venv | Falls back to `python3 -m venv` |
