# Sharmory Function Reference

Complete catalog of all functions, organized by category. Every function is available in Zsh, Bash, and PowerShell unless noted.

Run `sharmory list` for a live version of this catalog, or `sharmory help <name>` for details on a specific function.

---

## Navigation & Files

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `mkcd` | Make a directory and cd into it in one step | `mkcd <dir>` | |
| `up` | Go up N directory levels | `up [n]` | |
| `lsd` | Enhanced directory listing (icons, git status, sort by modified) | `lsd` | `eza` |
| `fcd` | Fuzzy cd into a subdirectory | `fcd` | `fzf` |
| `ftext` | Fuzzy-search file contents and open the match in `$EDITOR` | `ftext` | `fzf` |
| `permsof` | Show file permissions broken down by owner/group/other | `permsof <file>` | |
| `extract` | Auto-extract archives by extension (.tar.gz, .zip, .7z, etc.) | `extract <archive-file>` | |
| `compress` | Compress a file or directory to .tar.gz, .tar.bz2, or .zip | `compress <output> <path>` | |
| `duh` | Disk usage of everything in the current directory, sorted by size | `duh` | |
| `sizeof` | Sizes of subdirectories under a path, largest first | `sizeof [path]` | |
| `findbig` | Find files above a given size (default 100M) | `findbig [size] [dir]` | |
| `emptydirs` | Find (and optionally remove) empty directories | `emptydirs [dir]` | |
| `dupfind` | Find duplicate files by MD5/SHA256 hash | `dupfind [dir]` | |
| `bak` | Create a timestamped backup copy of a file | `bak <file>` | |
| `cwd` | Copy the current working directory path to the clipboard | `cwd` | |
| `clipcopy` | Copy a file's contents to the clipboard | `clipcopy <file>` | |
| `clip` | Copy stdin or a file to the clipboard (pipe-friendly) | `clip [file]` | |
| `watchrun` | Re-run a command whenever a path changes | `watchrun <path> -- <command...>` | `entr`, `fswatch` |
| `treelist` | Recursive tree listing with optional depth limit | `treelist [dir] [depth]` | `tree` |
| `recent` | Show the N most recently modified files | `recent [n]` | |
| `swap` | Atomically swap two filenames | `swap <file-a> <file-b>` | |
| `trash` | Move a file or directory to the system trash | `trash <file-or-dir>` | |

---

## Git

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `gitundo` | Undo the last commit, keep changes staged | `gitundo` | |
| `branchclean` | Delete local branches already merged into main/master | `branchclean` | |
| `branchage` | Local branches sorted by last commit date | `branchage` | |
| `gitlog-today` | Your commits since midnight | `gitlog-today` | |
| `gacp` | git add + commit + push in one step (prompts on main/master) | `gacp <commit message>` | |
| `gclone` | Clone a repo and cd straight into it | `gclone <repo-url> [dir]` | |
| `gwip` | Quick checkpoint commit of all uncommitted changes | `gwip` | |
| `gunwip` | Undo the last `gwip` commit (soft reset, keeps changes staged) | `gunwip` | |
| `gitprune` | Delete local branches whose remote counterpart is gone | `gitprune` | |
| `gswitch` | Fuzzy-pick a branch to switch to (local + remote) | `gswitch` | `fzf` |
| `prdiff` | Diff the current branch against a base branch | `prdiff [base-branch]` | |
| `gitcontributors` | Commit counts by author, sorted descending | `gitcontributors` | |
| `gitsize` | Total size of the `.git` directory | `gitsize` | |
| `gitconflicts` | List files with unresolved merge conflicts | `gitconflicts` | |
| `gitignore` | Append a gitignore.io template to `.gitignore` | `gitignore <lang1,lang2,...>` | |
| `gstash` | Interactive stash picker — pop, apply, or drop via fzf | `gstash` | `fzf` |
| `grebase` | Interactive rebase N commits back | `grebase [n]` | |
| `gopen` | Open the origin remote URL in a browser | `gopen` | |
| `gpr` | Open the PR/MR creation page for the current branch | `gpr` | |
| `gitbranch-rename` | Rename a branch locally and on the remote | `gitbranch-rename <old> <new>` | |
| `gitlog-graph` | Pretty one-line graph log for the whole repo | `gitlog-graph` | |
| `gcleanup` | Prune remotes, delete merged branches, tidy Go module | `gcleanup` | |
| `grecentbranch` | Recently checked-out branches from the reflog | `grecentbranch [n]` | |
| `gcamend` | Amend the last commit message without touching the stage | `gcamend <new message>` | |
| `gdiffstage` | Show what is currently staged (ready to commit) | `gdiffstage` | |
| `greview` | Open the last open PR for the current branch in the browser | `greview` | `gh` |
| `gstats` | Per-author commit counts and lines added/deleted | `gstats [--since <date>]` | |

---

## Docker

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `dockernuke` | Force stop and remove a container | `dockernuke <container>` | |
| `dockerclean-images` | List dangling images and offer to remove them | `dockerclean-images` | |
| `dclean` | Prune all unused Docker data (containers, images, networks, cache) | `dclean` | |
| `dockerlogs` | Tail container logs with timestamps | `dockerlogs <container>` | |
| `dsh` | Fuzzy-pick a running container and open a shell inside it | `dsh` | `fzf` |
| `dockersizes` | Human-readable sizes of local Docker images | `dockersizes` | |
| `dimages` | Fuzzy-pick a local image to run, inspect, or delete | `dimages` | `fzf` |
| `denv` | Print all environment variables of a running container | `denv <container>` | |
| `dbuild` | Build a Docker image (tag defaults to the directory name) | `dbuild [tag]` | |
| `dstats` | One-shot resource usage snapshot for all running containers | `dstats` | |
| `dcup` | Bring up docker-compose services in the background | `dcup` | |
| `dcdown` | Tear down docker-compose services | `dcdown` | |
| `dhealth` | Show health status of all containers that define a healthcheck | `dhealth` | |
| `dvols` | Human-readable sizes of local Docker volumes | `dvols` | |
| `dports` | Show published port mappings for all running containers | `dports` | |

---

## Kubernetes

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `k8sctx` | Fuzzy-switch kubectl context and namespace | `k8sctx` | `fzf`, `kubectl` |
| `klogs` | Fuzzy-pick a pod and stream its logs | `klogs` | `fzf`, `kubectl` |
| `kexec` | Fuzzy-pick a pod and exec a shell into it | `kexec` | `fzf`, `kubectl` |
| `ktop` | Pods sorted by CPU or memory consumption | `ktop [cpu\|memory]` | `kubectl` |
| `kevents` | Namespace events sorted by timestamp | `kevents` | `kubectl` |
| `kns` | Set the current kubectl namespace without changing context | `kns <namespace>` | `kubectl` |
| `kdesc` | Fuzzy-pick a pod and run `kubectl describe` on it | `kdesc` | `fzf`, `kubectl` |
| `kport` | Port-forward from localhost to a pod | `kport <local-port> <pod> <remote-port>` | `kubectl` |
| `krestart` | Rollout-restart a picked deployment | `krestart` | `fzf`, `kubectl` |
| `kscale` | Scale a picked deployment to a given replica count | `kscale <replicas>` | `fzf`, `kubectl` |
| `kdel` | Force-delete a picked (possibly stuck) pod | `kdel` | `fzf`, `kubectl` |
| `ksecret` | Decode and print the data of a picked secret | `ksecret` | `fzf`, `kubectl` |
| `kcp` | Copy a file to/from a picked pod | `kcp <local-path> <pod-path>` | `fzf`, `kubectl` |

---

## Go Development

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `covreport` | Run tests with coverage and open the HTML report | `covreport` | |
| `gomodwhy` | Explain why a module is in the dependency graph | `gomodwhy <module-path>` | |
| `goclean` | Run `gofmt`, `go vet`, and `go mod tidy` in one pass | `goclean` | |
| `goupdate` | Upgrade all direct and indirect Go dependencies | `goupdate` | |
| `gobench` | Run benchmarks with memory stats | `gobench [pattern]` | |
| `gonew` | Scaffold a minimal new Go module with a starter `main.go` | `gonew <module-path>` | |
| `gowatch` | Re-run tests whenever a `.go` file changes | `gowatch` | `entr` |
| `gorace` | Run tests with the race detector enabled | `gorace [./...]` | |
| `gobuild` | Build a Go binary (output name defaults to directory name) | `gobuild [output]` | |
| `goxbuild` | Cross-compile a Go binary for a target OS and architecture | `goxbuild <GOOS> <GOARCH> [output]` | |
| `gocover-func` | Show coverage percentage per function | `gocover-func` | |
| `goenv` | Show all Go environment variables | `goenv` | |
| `golist` | List all packages in the current module | `golist` | |
| `goversion` | Go version and key paths (GOROOT, GOPATH, GOMODCACHE) | `goversion` | |
| `gotest` | Run `go test -v` | `gotest [./...]` | |
| `gomod-name` | Print the module name from `go.mod` | `gomod-name` | |
| `govscan` | Scan dependencies for known vulnerabilities | `govscan` | `govulncheck` (auto-installed) |
| `goimpl` | Show `go doc` for a type (or `guru implements` if available) | `goimpl <TypeName>` | |

---

## Node / npm

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `npmclean` | Delete `node_modules` + lockfile and reinstall from scratch | `npmclean` | |
| `npmscripts` | List scripts defined in `package.json` | `npmscripts` | `jq` |
| `npmoutdated` | Show outdated npm dependencies | `npmoutdated` | |
| `npmsize` | Size of the `node_modules` directory | `npmsize` | |
| `nodeversion` | Node.js, npm, yarn, and pnpm versions | `nodeversion` | |
| `nvmuse` | Switch Node.js version via nvm or fnm | `nvmuse <version>` | `nvm`, `fnm` |
| `tscheck` | TypeScript type-check without emitting files | `tscheck` | `tsc` |
| `npxrun` | Run a package with npx | `npxrun <package> [args...]` | |
| `npmglobal` | List globally installed npm packages | `npmglobal` | |
| `npmlink` | Link this package globally or into a target project | `npmlink [target-dir]` | |
| `noderepl` | Node.js REPL with project `node_modules` on `NODE_PATH` | `noderepl` | |
| `npmaudit` | Run `npm audit` | `npmaudit` | |
| `nodeinfo` | Summary of the current Node project (name, scripts, deps) | `nodeinfo` | |
| `npmdedup` | Deduplicate and flatten the npm dependency tree | `npmdedup` | |
| `npmwatch` | Watch files and re-run an npm script on change | `npmwatch [script]` | `nodemon`, `entr` |

---

## Python

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `venvcreate` | Create and activate a `./venv` virtual environment | `venvcreate` | |
| `pyclean` | Remove all `__pycache__` directories and `.pyc` files | `pyclean` | |
| `pyfreeze` | Write `pip freeze` output to `requirements.txt` | `pyfreeze` | |
| `pipinstall` | Install packages from `requirements.txt` | `pipinstall` | |
| `pyversion` | Python/pip versions and active venv path | `pyversion` | |
| `pycheck` | Lint with ruff/flake8 and type-check with mypy | `pycheck [path]` | `ruff`, `flake8`, `mypy` |
| `pytest-run` | Run pytest with verbose output | `pytest-run [args...]` | `pytest` |
| `pywatch` | Watch `.py` files and re-run pytest on change | `pywatch [test-path]` | `entr`, `watchexec` |
| `pydeps` | List all installed pip packages | `pydeps` | |
| `pyupgrade` | Upgrade all packages from `requirements.txt` | `pyupgrade` | |
| `pyrequirements-diff` | Diff `pip freeze` output against `requirements.txt` | `pyrequirements-diff` | |
| `pyrun` | Run a Python script using the active venv interpreter | `pyrun <script.py> [args...]` | |
| `pyprofile` | Profile a script with `cProfile`, print top hotspots | `pyprofile <script.py> [args...]` | |
| `pyvenv` | Create `.venv` and activate it (uses `uv` if available) | `pyvenv` | `uv` (optional) |

---

## Networking & APIs

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `myip` | Your public-facing IP address | `myip` | |
| `localip` | Your local network IP address | `localip` | |
| `killport` | Find and kill whatever process is listening on a port | `killport <port> [port ...]` | |
| `portwho` | Show which process is listening on a given TCP port | `portwho <port>` | |
| `certcheck` | TLS certificate expiry date and days remaining for a domain | `certcheck <domain>` | `openssl` |
| `dnscheck` | Look up A, CNAME, and MX records for a domain | `dnscheck <domain>` | `dig` |
| `httpstatus` | Fetch just the HTTP status code for a URL | `httpstatus <url>` | |
| `apihit` | GET a URL, pretty-print JSON response, show timing | `apihit <url> [curl-args...]` | `jq` |
| `flushdns` | Flush the local DNS cache | `flushdns` | |
| `weather` | Weather for a location via wttr.in | `weather [location]` | |
| `tcpcheck` | Quick TCP reachability check on host:port | `tcpcheck <host> <port>` | |
| `shorten` | Shorten a URL using is.gd | `shorten <url>` | |
| `tlscheck` | Full TLS certificate chain info for a domain | `tlscheck <domain>` | `openssl` |
| `portscan` | Scan a TCP port range using `/dev/tcp` (no nmap needed) | `portscan <host> <start> [end]` | |
| `ipinfo` | IP geolocation and ASN via ipinfo.io | `ipinfo [ip]` | `jq` |
| `pingcheck` | Send 5 pings to a host and print a RTT/loss summary | `pingcheck <host>` | |
| `sshconfig` | List all Host entries from `~/.ssh/config` | `sshconfig` | |
| `headers` | Show full HTTP response headers for a URL | `headers <url>` | |
| `proxy` | Toggle `http_proxy` / `https_proxy` environment variables | `proxy <on [host:port]\|off\|status>` | |
| `speed` | Internet speed test (speedtest-cli, fast, or curl fallback) | `speed` | `speedtest-cli`, `fast` |
| `sshcopy` | Copy your SSH public key to a remote host's authorized_keys | `sshcopy <user@host> [identity-file]` | |

---

## Security & Encoding

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `passgen` | Generate a random base64 password | `passgen [bytes]` | `openssl` |
| `pubkey` | Print the contents of your SSH public keys | `pubkey` | |
| `genssh` | Generate a new ed25519 SSH keypair | `genssh <key-name> [email]` | |
| `b64e` | Base64-encode text | `b64e <text>` | |
| `b64d` | Base64-decode text | `b64d <base64-text>` | |
| `urlencode` | URL-encode text | `urlencode <text>` | `python3` |
| `urldecode` | URL-decode text | `urldecode <text>` | `python3` |
| `hashfile` | Compute MD5, SHA1, and SHA256 hashes of a file | `hashfile <file>` | |
| `genuuid` | Generate a random UUID v4 | `genuuid` | `uuidgen` or `python3` |
| `jwtdecode` | Decode a JWT header and payload (no signature verification) | `jwtdecode <token>` | `jq` |
| `dotenv-check` | Lint a `.env` file for empty values, duplicates, and unquoted secrets | `dotenv-check [file]` | |

---

## System & Process

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `mem` | Current physical memory usage | `mem` | |
| `cpu` | Snapshot of CPU and process activity | `cpu` | |
| `pidtree` | Show the process tree for a given PID | `pidtree <pid>` | `pstree` |
| `fkill` | Fuzzy-pick a process and kill it | `fkill` | `fzf` |
| `now` | Print current date and time (YYYY-MM-DD HH:MM:SS) | `now` | |
| `timer` | Countdown timer with a beep/notification when done | `timer <seconds> [label]` | |
| `diskusage` | Disk usage via `ncdu`, or a `df`/`du` summary if absent | `diskusage [path]` | `ncdu` |
| `envdiff` | Diff two `.env` files showing added, removed, and changed keys | `envdiff <file1> <file2>` | |
| `ports` | List all listening TCP/UDP ports with process name and PID | `ports` | |
| `sysinfo` | One-screen system summary (OS, CPU, RAM, disk, uptime, load) | `sysinfo` | |
| `openports` | Listening ports flagged by network exposure (0.0.0.0 / ::) | `openports` | |
| `cpuwatch` | Live CPU load monitor, refreshes every second | `cpuwatch [interval-seconds]` | |
| `memwatch` | Live memory usage monitor, refreshes every second | `memwatch [interval-seconds]` | |

---

## Productivity & Misc

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `note` | Append or view timestamped notes in `~/notes/YYYY-MM-DD.md` | `note <text\|today\|list\|search <text>>` | |
| `jsonpp` | Pretty-print a JSON file | `jsonpp <file>` | `jq` |
| `envload` | Load variables from a `.env`-style file into the current shell | `envload [file]` | |
| `ffind` | Find files by name or search file contents for text | `ffind <text>` / `ffind -f <filename>` | |
| `cheat` | Look up usage examples via `tldr`, fallback to `man` | `cheat <command>` | `tldr` |
| `calc` | Quick command-line calculator | `calc <expression>` | `python3` |
| `qr` | Generate a QR code for text/URL in the terminal | `qr <text>` | |
| `todo` | Append or list entries in `~/todo.md`, mark items done | `todo [text]` / `todo done <pattern>` | |
| `mkproject` | Scaffold a project directory with README, .gitignore, .env.example | `mkproject <name> [go\|node\|python]` | |
| `epoch` | Convert between Unix epoch and human-readable datetime | `epoch [epoch\|date]` | |
| `diffjson` | Semantic diff of two JSON files (normalised with jq) | `diffjson <file-a> <file-b>` | `jq` |
| `retry` | Retry a command N times with exponential backoff | `retry <max-attempts> <command> [args...]` | |
| `hist` | Fuzzy-search shell history and paste the selection on the command line | `hist` | `fzf` |
| `mktemplate` | Create a project from a user-defined template in `~/.sharmory/templates/` | `mktemplate <template> <project>` | |
| `envswitch` | Load a named env profile from `~/.sharmory/envprofiles/` | `envswitch [profile-name]` | |
| `alias-list` | List user-defined aliases in a clean aligned table | `alias-list [pattern]` | |

---

## Ruby

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `gemclean` | Uninstall old/duplicate gem versions, keeping only the latest of each | `gemclean` | `gem` |
| `rbver` | Fuzzy-pick and switch the active Ruby version (rbenv/rvm aware) | `rbver` | `fzf`, `rbenv` or `rvm` |
| `rboutdated` | List outdated gems from the current Gemfile.lock | `rboutdated` | `bundle` |
| `rspecf` | Re-run only the last-failed RSpec examples | `rspecf [args...]` | `bundle`, `rspec` |

---

## Java

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `m2size` | Report size of the local Maven repository cache | `m2size` | |
| `gradlesize` | Report size of the local Gradle cache | `gradlesize` | |
| `jarinfo` | Inspect a jar's manifest and top-level contents | `jarinfo <path-to-jar>` | `unzip` (Unix), `jar` (Windows) |
| `javaver` | Fuzzy-pick and switch JAVA_HOME (jenv/sdkman aware) | `javaver` | `fzf`, `jenv` or `sdkman` |
| `mvntree` | Print the Maven dependency tree for the current project | `mvntree` | `mvn` |

---

## Database

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `pgc` | Connect to Postgres using PG* env vars (or defaults) | `pgc` | `psql` |
| `myc` | Connect to MySQL using MYSQL_* env vars (or defaults) | `myc` | `mysql` |
| `redisc` | Connect to Redis using REDIS_* env vars | `redisc` | `redis-cli` |
| `pgdump` | Dump the current Postgres database to a timestamped .sql file | `pgdump <database>` | `pg_dump` |
| `dbforward` | Port-forward to a picked k8s service with a connect hint | `dbforward <local-port> <remote-port>` | `fzf`, `kubectl` |

---

## General Dev

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `serve` | Serve the current directory over HTTP | `serve [port]` | `python3` or `npx` |
| `todogrep` | Find TODO/FIXME/HACK/XXX comments across the codebase | `todogrep [dir]` | |
| `basec` | Convert a number between hex, decimal, octal, and binary | `basec <number>` | `bc` |
| `colorconv` | Convert hex color to RGB or RGB to hex | `colorconv <#rrggbb>` \| `colorconv <r> <g> <b>` | |
| `tunnel` | Open a quick ngrok tunnel to a local port | `tunnel <port>` | `ngrok` |
| `bench` | Time N runs of a command and report min/max/avg | `bench <runs> <command...>` | `bc` |
| `diffdir` | Recursively diff two directories | `diffdir <dir-a> <dir-b>` | |
| `openat` | Open `$EDITOR` at a specific file and line | `openat <file>[:<line>]` | |
| `worktree` | Fuzzy-manage git worktrees: add, switch, or remove | `worktree <add\|switch\|remove>` | `fzf` |
| `licensegen` | Generate a LICENSE file (MIT or Apache 2.0) | `licensegen <mit\|apache2> [author] [year]` | |

---

## React / Vite

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `mkvite` | Scaffold a Vite+React app — create, strip boilerplate, install, git init | `mkvite <app-name> [template]` | `npx` |
| `vitedev` | Start the Vite dev server and open the browser | `vitedev` | `npm` |
| `vitebuild` | Production build with dist bundle size breakdown | `vitebuild` | `npm` |
| `viteclean` | Wipe `node_modules`/`dist`/lockfile and reinstall clean | `viteclean` | `npm` |
| `reactcomp` | Scaffold a React component with barrel export (TS-aware) | `reactcomp <ComponentName> [dir]` | |
| `viteenv` | Copy `.env.example` → `.env` if `.env` doesn't exist | `viteenv` | |
| `vitelint` | Run ESLint + Prettier check + TypeScript typecheck in one pass | `vitelint [--fix]` | `npm` |
| `mkviteapi` | Scaffold a companion Express or Fastify API folder | `mkviteapi [name] [--fastify]` | |

---

## Cron

> **PowerShell note:** these functions target the Windows Task Scheduler under a dedicated `\Sharmory\` task folder — the same verb names are used on all platforms.

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `cronlist` | List (numbered) crontab entries | `cronlist` | |
| `cronadd` | Append a new cron job | `cronadd "<schedule>" "<command>"` | |
| `cronrm` | Fuzzy-pick and remove a cron job | `cronrm` | `fzf` |
| `cronedit` | Open the crontab in `$EDITOR` | `cronedit` | |
| `cronhuman` | Translate a 5-field cron expression to plain English (pure shell, no deps) | `cronhuman "<min> <hour> <dom> <month> <dow>"` | |
| `cronnext` | Show the next N scheduled run times for an expression | `cronnext "<schedule>" [count]` | `python3` + `croniter` |

---

## API Tools

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `apiwatch` | Poll an endpoint; log HTTP status + response time each hit | `apiwatch <url> [interval-seconds]` | `curl` |
| `apimock` | Spin up a local `json-server` mock API from a JSON file | `apimock <file.json> [port]` | `npx` |
| `apidiff` | Diff two JSON API responses (URLs or local files) | `apidiff <a> <b>` | `jq` |
| `curltime` | Detailed HTTP timing: DNS / TCP / TLS / TTFB / total | `curltime <url>` | `curl` |
| `openapipp` | Validate and lint an OpenAPI/Swagger spec with Redocly | `openapipp <spec-file>` | `npx` |

---

## Env Tools

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `envgen` | Generate a `.env.example` from `.env` — keeps keys, strips values | `envgen [src] [out]` | |
| `envrequire` | Assert that a list of env vars are all set; exits non-zero with a missing-keys list | `envrequire VAR1 VAR2 ...` | |
| `envexport` | Print `export KEY='value'` lines from a `.env` file (for pasting into a remote shell) | `envexport [file]` | |
| `envmask` | Print a `.env` file with secret-looking values partially masked | `envmask [file]` | |
| `envsync` | Compare `.env` vs `.env.example` and report keys missing from either side | `envsync [env] [example]` | |

---

## CI / Jenkins

These functions require the environment variables `JENKINS_URL`, `JENKINS_USER`, and `JENKINS_TOKEN` to be set.

| Function | Description | Usage | Optional deps |
|---|---|---|---|
| `jenk-crumb` | Get a Jenkins CSRF crumb (needed for POST requests) | `jenk-crumb` | `jq` |
| `jenk-build` | Trigger a build for a Jenkins job | `jenk-build <job-name>` | |
| `jenk-logs` | Fetch the console log of the last build | `jenk-logs <job-name>` | |
| `jenk-jobs` | List all job names on the configured Jenkins server | `jenk-jobs` | `jq` |

---

## Sharmory Management (Meta)

| Function | Description | Usage |
|---|---|---|
| `sharmory` | Interactive HUD — fzf catalog if available, numbered menu otherwise | `sharmory` |
| `sharmory list` | Print the full catalog, optionally filtered by category | `sharmory list [category]` |
| `sharmory help` | Describe a function with its usage and optional deps | `sharmory help <name>` |
| `sharmory run` | Run a catalogued function by name | `sharmory run <name> [args...]` |
| `sharmory doctor` | Environment health check — versions, install path, optional tools | `sharmory doctor` |
| `sharmory setup` | Interactively install optional CLI tools (fzf, jq, eza, tldr, entr) | `sharmory setup` |
| `sharmory bench` | Measure how long a clean shell takes to source Sharmory | `sharmory bench [runs]` |
| `sharmory-update` | Download the latest Sharmory from GitHub and reload it | `sharmory-update` |
