# Sharmory

[![GitHub release](https://img.shields.io/github/v/release/hariharen9/sharmory?label=latest)](https://github.com/hariharen9/sharmory/releases)
[![GitHub downloads](https://img.shields.io/github/downloads/hariharen9/sharmory/total?label=GitHub%20downloads)](https://github.com/hariharen9/sharmory/releases)
[![npm downloads](https://img.shields.io/npm/dm/sharmory?label=npm%20downloads%2Fmo)](https://www.npmjs.com/package/sharmory)
[![PyPI downloads](https://img.shields.io/pypi/dm/sharmory?label=PyPI%20downloads%2Fmo)](https://pypi.org/project/sharmory/)

A single-file library of dev-focused shell functions for **Zsh, Bash, and PowerShell** — Git shortcuts,
Docker/K8s helpers, Go/Node/Python workflow utilities, networking checks, security/encoding helpers, and
general productivity tools. No plugin manager, no framework — just source one file.

The GitHub badge counts **Release page asset downloads** (source zip/tarball). Homebrew tap, Scoop, `curl | bash`, and `irm | iex` are not included in that number. npm and PyPI have their own counters.

## 🚀 Quick Install (1-Line)

**macOS / Linux / WSL (Zsh or Bash — auto-detected)**
```bash
curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/install.sh | bash
```

The installer detects your login shell and configures the right file automatically:
- **Zsh** → installs `functions.zsh`, patches `~/.zshrc`
- **Bash** → installs `functions.bash`, patches `~/.bashrc`

Both files are always downloaded to `~/.sharmory/` so you can switch shells without re-installing.

**Windows (PowerShell 5.1+ & PowerShell Core 7+)**
```powershell
irm https://raw.githubusercontent.com/hariharen9/sharmory/main/install.ps1 | iex
```

**Package managers**

| Manager | Install |
|---|---|
| Homebrew | `brew tap hariharen9/tap && brew install sharmory` — then source `functions.zsh` (Zsh) or `functions.bash` (Bash) from `$(brew --prefix)/opt/sharmory/` |
| Scoop | `scoop bucket add hariharen9 https://github.com/hariharen9/scoop-bucket && scoop install sharmory` — then dot-source `functions.ps1` in `$PROFILE` |
| npm | `npm install -g sharmory && sharmory-install` — auto-detects Zsh or Bash |
| pip | `pip install sharmory && sharmory-install` — auto-detects Zsh or Bash |

## Command HUD

Type `sharmory` with no arguments for an interactive catalog (fzf if installed,
otherwise a numbered menu). You can also query it non-interactively:

```bash
sharmory                  # interactive HUD
sharmory list             # full catalog
sharmory list git         # one category
sharmory help killport    # description + usage
sharmory run now          # run a catalogued command
sharmory doctor           # environment health check
sharmory setup            # install optional tools (fzf, jq, eza, tldr)
sharmory bench            # source-time benchmark (clean shell)
```

`sharmory-setup` is the same as `sharmory setup`. It only offers small CLI helpers — not Docker, Kubernetes, Go, Node, or Python. You can skip any tool.

---

## 🔄 Updating & Maintenance

To update Sharmory to the latest version at any time, run:

```bash
sharmory-update
```

*(Works natively in Zsh, Bash, and PowerShell).*

---

## 📦 Manual Installation (Optional)

<details>
<summary><b>Manual Zsh Setup</b></summary>

```bash
git clone https://github.com/hariharen9/sharmory.git ~/.sharmory
echo 'source ~/.sharmory/functions.zsh' >> ~/.zshrc
source ~/.zshrc
```

Or without git:
```bash
curl -o ~/.sharmory/functions.zsh https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.zsh
echo '[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh' >> ~/.zshrc
```
</details>

<details>
<summary><b>Manual Bash Setup</b></summary>

Requires **Bash 4.0+**. macOS ships Bash 3.2 — install a modern version first: `brew install bash`.

```bash
git clone https://github.com/hariharen9/sharmory.git ~/.sharmory
echo '[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash' >> ~/.bashrc
source ~/.bashrc
```

Or without git:
```bash
curl -o ~/.sharmory/functions.bash https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.bash
echo '[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash' >> ~/.bashrc
```
</details>

<details>
<summary><b>Manual PowerShell Setup</b></summary>

```powershell
# Create profile if it doesn't exist yet
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

# Clone and source Sharmory
git clone https://github.com/hariharen9/sharmory.git "$HOME\sharmory"
Add-Content $PROFILE '. "$HOME\sharmory\functions.ps1"'
. $PROFILE
```
</details>

---

## Optional dependencies

Most functions work with only core system tools. A few optional tools provide enhanced capabilities:

| Tool | Used by |
|---|---|
| `fzf` | `fcd`, `ftext`, `dsh`, `k8sctx`, `klogs`, `kexec`, `fkill`, `gswitch` |
| `jq` | `npmscripts`, `jenk-crumb`, `jenk-jobs`, `jsonpp` |
| `eza` | `lsd` |
| `entr` or `fswatch` | `watchrun`, `gowatch` |
| `tldr` | `cheat` (falls back to `man` / `Get-Help`) |

Every function checks for its dependency and fails gracefully (or falls back to a
standard alternative) if it is missing.

## Categories

- **Navigation & Files** — `mkcd`, `up`, `lsd`, `fcd`, `ftext`, `permsof`, `extract`, `compress`, `duh`, `sizeof`, `findbig`, `emptydirs`, `dupfind`, `bak`, `cwd`, `clipcopy`, `clip`, `treelist`, `recent`, `swap`, `trash`, `watchrun`
- **Git** — `gacp`, `gclone`, `gswitch`, `gstash`, `grebase`, `gcamend`, `gdiffstage`, `grecentbranch`, `gpr`, `gopen`, `gwip`, `gunwip`, `gitundo`, `gitprune`, `branchclean`, `branchage`, `prdiff`, `gitlog-today`, `gitlog-graph`, `gitcontributors`, `gitsize`, `gitconflicts`, `gitignore`, `gitbranch-rename`, `gcleanup`
- **Docker** — `dockernuke`, `dockerclean-images`, `dclean`, `dockerlogs`, `dockersizes`, `denv`, `dbuild`, `dsh`
- **Kubernetes** — `kns`, `ktop`, `kevents`, `kdesc`, `kport`, `k8sctx`, `klogs`, `kexec`
- **Go** — `gonew`, `gowatch`, `covreport`, `goclean`, `goupdate`, `gomodwhy`, `gobench`
- **Node/npm** — `npmclean`, `npmscripts`, `npmoutdated`, `npmsize`
- **Python** — `venvcreate`, `pyclean`, `pyfreeze`
- **Networking** — `myip`, `localip`, `killport`, `portwho`, `openports`, `portscan`, `dnscheck`, `certcheck`, `tlscheck`, `ipinfo`, `httpstatus`, `apihit`, `headers`, `flushdns`, `tcpcheck`, `pingcheck`, `weather`, `shorten`, `sshconfig`, `proxy`
- **Security & Encoding** — `passgen`, `genuuid`, `genssh`, `pubkey`, `b64e`, `b64d`, `urlencode`, `urldecode`, `hashfile`, `jwtdecode`, `dotenv-check`
- **System & Process** — `mem`, `cpu`, `sysinfo`, `pidtree`, `fkill`, `ports`, `openports`, `now`, `timer`, `diskusage`, `envdiff`
- **Productivity** — `note`, `todo`, `hist`, `mkproject`, `mktemplate`, `envload`, `envswitch`, `ffind`, `cheat`, `calc`, `qr`, `jsonpp`, `diffjson`, `epoch`, `retry`
- **CI/Jenkins** — `jenk-crumb`, `jenk-build`, `jenk-logs`, `jenk-jobs`
  (needs `JENKINS_URL`, `JENKINS_USER`, `JENKINS_TOKEN` env vars)
- **Management** — `sharmory`, `sharmory list`, `sharmory help`, `sharmory run`, `sharmory doctor`, `sharmory setup`, `sharmory bench`, `sharmory-update`

---

## Function Reference

### 📁 Navigation & Files

| Command | Usage | Description |
|---|---|---|
| `mkcd` | `mkcd <dir>` | Create a directory and `cd` into it in one step |
| `up` | `up [n]` | Go up `n` directory levels (default 1) |
| `lsd` | `lsd` | Directory listing — uses `eza` with icons/git info if installed, falls back to a clean table |
| `permsof` | `permsof <file>` | Show Unix permissions (Zsh) or Windows ACL (PS) for a file |
| `extract` | `extract <archive>` | Extract any common archive format — `.zip`, `.tar.gz`, `.7z`, etc. — by extension |
| `compress` | `compress <out.zip> <path>` | Compress a file or directory to a zip archive |
| `duh` | `duh` | Human-readable sizes of every item in the current directory |
| `sizeof` | `sizeof [path]` | Sizes of all subdirectories, largest first |
| `findbig` | `findbig [sizeMB] [dir]` | Find files above a given size in MB (default 100 MB) |
| `emptydirs` | `emptydirs [dir]` | List empty directories; prompts to remove them |
| `dupfind` | `dupfind [dir]` | Find duplicate files by SHA-256 hash |
| `bak` | `bak <file>` | Timestamped backup copy: `file.txt` → `file.txt.2024-01-15_120000.bak` |
| `cwd` | `cwd` | Copy the current working directory path to the clipboard |
| `clipcopy` | `clipcopy <file>` | Copy a file's contents to the clipboard |
| `clip` | `clip [file]` | Copy stdin or a file to the clipboard; works in pipes: `echo foo \| clip` |
| `treelist` | `treelist [dir] [depth]` | Recursive tree listing; uses the system `tree` command if available |
| `recent` | `recent [n]` | List the `n` most recently modified files (default 10) |
| `swap` | `swap <a> <b>` | Atomically swap two filenames using a temp file |
| `trash` | `trash <path>` | Move a file or directory to the Recycle Bin / Trash instead of deleting it |
| `fcd` | `fcd` | Interactively pick a subdirectory with `fzf` and `cd` into it |
| `ftext` | `ftext` | Fuzzy-search all file contents with `fzf` and open the matching file in `$EDITOR` |
| `watchrun` | `watchrun <path> <cmd>` | Re-run a shell command whenever files under `<path>` change (uses `entr` / `watchexec`) |

### 🌿 Git

| Command | Usage | Description |
|---|---|---|
| `gacp` | `gacp <message>` | `git add -A && git commit -m … && git push` in one shot |
| `gclone` | `gclone <url> [dir]` | Clone a repo and immediately `cd` into it |
| `gswitch` | `gswitch` | Fuzzy-pick a local branch with `fzf` and check it out |
| `gstash` | `gstash` | Interactive stash picker via `fzf` — apply or drop entries |
| `grebase` | `grebase [n]` | Interactive rebase of the last `n` commits (default 2) |
| `gcamend` | `gcamend <message>` | Amend the last commit with a new message |
| `gdiffstage` | `gdiffstage` | Show the staged diff (`git diff --cached`) |
| `grecentbranch` | `grecentbranch [n]` | List recently checked-out branches from the reflog (default 10) |
| `gpr` | `gpr` | Open a pull-request URL for the current branch on GitHub, GitLab, or Bitbucket |
| `gopen` | `gopen` | Open the `origin` remote URL in a browser |
| `gwip` | `gwip` | Commit everything as a `WIP` checkpoint (safe mid-work save) |
| `gunwip` | `gunwip` | Undo the last `gwip` commit, restoring the working tree |
| `gitundo` | `gitundo` | Soft-reset the last commit, keeping all changes staged |
| `gitprune` | `gitprune` | Delete local branches whose upstream remote is gone |
| `branchclean` | `branchclean` | Delete local branches already merged into `main`/`master` |
| `branchage` | `branchage` | List local branches sorted by last commit date |
| `prdiff` | `prdiff [base]` | Diff the current branch against a base branch (default `main`) |
| `gitlog-today` | `gitlog-today` | Show your commits since midnight |
| `gitlog-graph` | `gitlog-graph` | Pretty one-line graph log with color and decorations |
| `gitcontributors` | `gitcontributors` | Commit counts by author across the whole repo |
| `gitsize` | `gitsize` | Print the size of the `.git` directory |
| `gitconflicts` | `gitconflicts` | List files that still have unresolved merge conflict markers |
| `gitignore` | `gitignore <lang,...>` | Append a language template from gitignore.io to `.gitignore` |
| `gitbranch-rename` | `gitbranch-rename <old> <new>` | Rename a branch both locally and on the remote |
| `gcleanup` | `gcleanup` | Prune remote refs, delete merged branches, and run `go mod tidy` if applicable |

### 🐳 Docker

| Command | Usage | Description |
|---|---|---|
| `dockernuke` | `dockernuke <container>` | Force-stop and remove a container in one command |
| `dockerclean-images` | `dockerclean-images` | Remove all dangling (untagged) Docker images |
| `dclean` | `dclean` | `docker system prune` — remove stopped containers, dangling images, unused networks |
| `dockerlogs` | `dockerlogs <container>` | Tail container logs with timestamps |
| `dockersizes` | `dockersizes` | List local images with human-readable sizes |
| `denv` | `denv <container>` | Print all environment variables inside a running container |
| `dbuild` | `dbuild [tag]` | Build an image tagged from the current directory name |
| `dsh` | `dsh` | Fuzzy-pick a running container with `fzf` and open an interactive shell inside it |

### ☸️ Kubernetes

| Command | Usage | Description |
|---|---|---|
| `kns` | `kns <namespace>` | Set the current `kubectl` namespace for all subsequent commands |
| `ktop` | `ktop [cpu\|memory]` | Show pods ranked by CPU or memory usage via `kubectl top` |
| `kevents` | `kevents` | List namespace events sorted by timestamp, most recent last |
| `kdesc` | `kdesc [pod]` | Describe a pod — fuzzy-pick with `fzf` if no name given |
| `kport` | `kport <local> <pod> <remote>` | Port-forward from a local port to a pod port |
| `k8sctx` | `k8sctx` | Fuzzy-pick a kubectl context and namespace and switch to both |
| `klogs` | `klogs` | Fuzzy-pick a pod with `fzf` and stream its logs |
| `kexec` | `kexec [shell]` | Fuzzy-pick a pod with `fzf` and exec into it (default shell: `sh`) |

### 🐹 Go

| Command | Usage | Description |
|---|---|---|
| `gonew` | `gonew <module-path> [dir]` | Scaffold a new Go module — creates directory, runs `go mod init`, writes `main.go` |
| `gowatch` | `gowatch [./...]` | Re-run `go test` on every file save (uses `watchexec`/`entr`) |
| `covreport` | `covreport` | Run tests with coverage and open the HTML coverage report |
| `goclean` | `goclean` | Run `gofmt`, `go vet`, and `go mod tidy` |
| `goupdate` | `goupdate` | Upgrade all module dependencies to their latest versions |
| `gomodwhy` | `gomodwhy <module>` | Explain why a module is in the dependency graph |
| `gobench` | `gobench [pattern]` | Run benchmarks with memory stats (`-benchmem`) |

### 📦 Node / npm

| Command | Usage | Description |
|---|---|---|
| `npmclean` | `npmclean` | Delete `node_modules`, clear cache, and reinstall — auto-detects npm / yarn / pnpm |
| `npmscripts` | `npmscripts` | Pretty-print all scripts defined in `package.json` |
| `npmoutdated` | `npmoutdated` | Show outdated dependencies with current vs latest versions |
| `npmsize` | `npmsize` | Print the total size of `node_modules` |

### 🐍 Python

| Command | Usage | Description |
|---|---|---|
| `venvcreate` | `venvcreate` | Create a `.venv` virtual environment in the current directory and activate it |
| `pyclean` | `pyclean` | Recursively remove `__pycache__` directories and `.pyc` files |
| `pyfreeze` | `pyfreeze` | Run `pip freeze` and write the output to `requirements.txt` |

### 🌐 Networking & APIs

| Command | Usage | Description |
|---|---|---|
| `myip` | `myip` | Print your public-facing IP address |
| `localip` | `localip` | Print your local network IP address |
| `killport` | `killport <port> [...]` | Kill the process listening on one or more TCP ports |
| `portwho` | `portwho <port>` | Show which process is listening on a given TCP port |
| `openports` | `openports` | List all listening ports with exposure flag — `EXPOSED` if bound to `0.0.0.0`/`::` |
| `portscan` | `portscan <host> <start> [end]` | TCP connect-scan a port range on a remote host |
| `dnscheck` | `dnscheck <domain>` | Look up A, CNAME, and MX records for a domain |
| `certcheck` | `certcheck <host> [port]` | Show TLS certificate expiry date for a host |
| `tlscheck` | `tlscheck <host> [port]` | Print the full TLS certificate chain (subject, issuer, validity, SANs) |
| `ipinfo` | `ipinfo [ip]` | IP geolocation, ASN, and org via ipinfo.io — omit `ip` for your own public IP |
| `httpstatus` | `httpstatus <url>` | Print the HTTP status code for a URL |
| `apihit` | `apihit <url>` | GET a URL, pretty-print the JSON response, and show timing |
| `headers` | `headers <url>` | Print all HTTP response headers for a URL |
| `flushdns` | `flushdns` | Flush the local DNS cache |
| `tcpcheck` | `tcpcheck <host> <port>` | Test TCP reachability to a host and port |
| `pingcheck` | `pingcheck <host>` | Send 5 pings to a host and report reachability |
| `weather` | `weather [location]` | Fetch a terminal weather report from wttr.in |
| `shorten` | `shorten <url>` | Shorten a URL using is.gd |
| `sshconfig` | `sshconfig` | List all `Host` entries from `~/.ssh/config` with their hostname and user |
| `proxy` | `proxy <on [host:port]\|off\|status>` | Toggle or inspect `http_proxy` / `https_proxy` environment variables |

### 🔒 Security & Encoding

| Command | Usage | Description |
|---|---|---|
| `passgen` | `passgen [bytes]` | Generate a random base64 password (default 24 bytes) |
| `genuuid` | `genuuid` | Generate a random UUID v4 |
| `genssh` | `genssh <name> [email]` | Generate an ed25519 SSH keypair in `~/.ssh/` |
| `pubkey` | `pubkey` | Print all SSH public keys found in `~/.ssh/` |
| `b64e` | `b64e <text>` | Base64-encode a string |
| `b64d` | `b64d <text>` | Base64-decode a string |
| `urlencode` | `urlencode <text>` | URL-encode a string (percent-encoding) |
| `urldecode` | `urldecode <text>` | URL-decode a percent-encoded string |
| `hashfile` | `hashfile <file>` | Print MD5, SHA-1, and SHA-256 hashes of a file |
| `jwtdecode` | `jwtdecode <token>` | Decode and pretty-print a JWT header and payload (no verification) |
| `dotenv-check` | `dotenv-check [file]` | Lint a `.env` file — find duplicates, bad quoting, and missing values |

### 🖥️ System & Process

| Command | Usage | Description |
|---|---|---|
| `mem` | `mem` | Show physical memory usage (used / total) |
| `cpu` | `cpu` | Snapshot of CPU load and top processes by CPU |
| `sysinfo` | `sysinfo` | One-screen system summary — OS, CPU, RAM, uptime, disk |
| `pidtree` | `pidtree <pid>` | Print the process tree for a given PID |
| `fkill` | `fkill` | Fuzzy-pick a running process with `fzf` and kill it |
| `ports` | `ports` | List all listening TCP ports |
| `openports` | `openports` | List listening ports and flag any exposed to `0.0.0.0`/`::` |
| `now` | `now` | Print the current date and time (`YYYY-MM-DD HH:MM:SS`) |
| `timer` | `timer <seconds> [label]` | Countdown timer with a beep/notification when done |
| `diskusage` | `diskusage [path]` | Disk usage summary — uses `ncdu` if available |
| `envdiff` | `envdiff <file1> <file2>` | Diff two `.env` files key-by-key, showing only changed or missing keys |

### ✅ Productivity & Misc

| Command | Usage | Description |
|---|---|---|
| `note` | `note <text>` | Append a timestamped note to today's file in `~/notes/YYYY-MM-DD.md` |
| `note today` | `note today` | Print today's note file |
| `note list` | `note list` | List all note files sorted by date |
| `note search` | `note search <text>` | Search across all note files |
| `todo` | `todo <text>` | Append a `[ ]` entry to `~/todo.md` |
| `todo` (list) | `todo` | Print `~/todo.md` |
| `todo done` | `todo done <pattern>` | Mark the first matching open `[ ]` item as `[x]` |
| `hist` | `hist` | Fuzzy-search shell history with `fzf` and paste the selection into the prompt |
| `mkproject` | `mkproject <name> [go\|node\|python]` | Scaffold a new project — creates README, `.gitignore`, `.env.example`, and starter files |
| `mktemplate` | `mktemplate <template> <project>` | Create a new project from a custom template in `~/.sharmory/templates/<name>/` |
| `envload` | `envload [file]` | Source a `.env` file into the current shell session |
| `envswitch` | `envswitch [profile]` | Load a named env profile from `~/.sharmory/envprofiles/<name>.env` |
| `ffind` | `ffind <text>` | Grep file contents recursively, excluding common junk directories |
| `ffind -f` | `ffind -f <name>` | Find files by name (substring match) |
| `cheat` | `cheat <command>` | Show usage examples via `tldr`; falls back to `man` / `Get-Help` |
| `calc` | `calc <expression>` | Quick command-line calculator |
| `qr` | `qr <text>` | Generate a QR code for text or a URL in the terminal |
| `jsonpp` | `jsonpp <file>` | Pretty-print a JSON file (`jq` on Zsh, `ConvertFrom-Json` on PS) |
| `diffjson` | `diffjson <a> <b>` | Semantic diff of two JSON files — normalizes formatting before comparing |
| `epoch` | `epoch [value]` | Convert between Unix epoch and human-readable datetime; no args prints current epoch |
| `retry` | `retry <n> <cmd> [args...]` | Re-run a command up to `n` times with exponential backoff on failure |

### 🔧 CI / Jenkins

> Requires `JENKINS_URL`, `JENKINS_USER`, and `JENKINS_TOKEN` environment variables.

| Command | Usage | Description |
|---|---|---|
| `jenk-crumb` | `jenk-crumb` | Fetch a Jenkins CSRF crumb (needed for authenticated POST requests) |
| `jenk-build` | `jenk-build <job>` | Trigger a build for a Jenkins job |
| `jenk-logs` | `jenk-logs <job>` | Fetch and print the console log of the last build of a job |
| `jenk-jobs` | `jenk-jobs` | List all Jenkins job names |

### 🛠️ Sharmory Management

| Command | Usage | Description |
|---|---|---|
| `sharmory` | `sharmory` | Launch the interactive HUD — `fzf` picker or numbered menu |
| `sharmory list` | `sharmory list [category]` | Print the full catalog or filter to one category |
| `sharmory help` | `sharmory help <name>` | Show description, usage, and optional deps for a command |
| `sharmory run` | `sharmory run <name> [args]` | Run any catalogued command by name |
| `sharmory doctor` | `sharmory doctor` | Environment health check — shell, git identity, SSH keys, Docker daemon, optional tools, version |
| `sharmory setup` | `sharmory setup` | Install optional CLI tools (`fzf`, `jq`, `eza`, `tldr`) |
| `sharmory bench` | `sharmory bench [n]` | Measure Sharmory's source time in a clean shell (default 10 runs) |
| `sharmory-update` | `sharmory-update` | Download and apply the latest `functions.zsh` / `functions.bash` / `functions.ps1` from GitHub |

## Testing

All three implementations ship a sandboxed self-test that exercises every function
without touching your real system: no real docker/kubectl calls, no real network
requests, no real processes killed, no real files outside a throwaway temp directory.
External tools that would otherwise hit the network or a live daemon (`docker`,
`kubectl`, `curl`/`Invoke-RestMethod`, `dig`/`Resolve-DnsName`, `ssh-keygen`, `fzf`,
etc.) are mocked for the duration of the run, and the whole sandbox is deleted
afterward whether the run passes or fails.

**Zsh (macOS/Linux):**

```bash
chmod +x test-sharmory.zsh
./test-sharmory.zsh                          # tests functions.zsh in the same directory
./test-sharmory.zsh path/to/functions.zsh    # or point at a specific file
```

**Bash (macOS/Linux — requires Bash 4.0+):**

```bash
chmod +x test-sharmory.bash
./test-sharmory.bash                         # tests functions.bash in the same directory
./test-sharmory.bash path/to/functions.bash  # or point at a specific file
```

> **macOS note:** The system `bash` is 3.2. Run the test with a modern Bash:
> `brew install bash && /opt/homebrew/bin/bash test-sharmory.bash`

**Windows:**

```powershell
.\test-sharmory.ps1
.\test-sharmory.ps1 -FunctionsPath path\to\functions.ps1
```

Each run prints a PASS/FAIL/SKIP line per function and a summary count.

Exit code is `0` if everything passed or was cleanly skipped, `1` if anything
actually failed — safe to wire into CI.

**Platform Verification:** All three implementations (Zsh, Bash, PowerShell) are verified end-to-end against live interpreters with fully sandboxed test suites. In Zsh, early testing caught variable collisions with the special `$path` array. In Bash, the test runner was adapted to work with Bash 3.2 (macOS default) as well as Bash 4.0+ (required for the functions themselves). In PowerShell, testing verified parser compatibility across Windows PowerShell 5.1 and modern PowerShell Core (7+).

## ⚠️ Plugin Manager Compatibility

> If you use oh-my-zsh or another plugin manager, some function names may already exist as aliases. Sharmory automatically clears any conflicts at load time — sourcing it will always be clean.

## 🗑️ Uninstalling

### macOS / Linux / WSL (Zsh or Bash)
```bash
curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.sh | bash
```

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.ps1 | iex
```

## Contributing

PRs adding new functions welcome. Keep the style consistent:

- one function, one job
- `Usage:` line printed when required args are missing
- guard against missing optional dependencies rather than hard-failing
- a one- or two-line comment above the function explaining what it does
- new functions must be added to **all three files** (`functions.zsh`, `functions.bash`, `functions.ps1`) and the registry in each, with a matching test case in each test file

## License

MIT

<!-- # Custom Footer -->
<p align="center">
  <img src="https://raw.githubusercontent.com/trinib/trinib/82213791fa9ff58d3ca768ddd6de2489ec23ffca/images/footer.svg" width="100%">
</p>