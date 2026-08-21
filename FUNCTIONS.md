# Sharmory — Function Reference

All functions are available in Bash, Zsh, and PowerShell. Sorted alphabetically.

---

| Function | Description | Usage |
|---|---|---|
| `alias-list` | List user-defined aliases in a clean aligned table | `alias-list [pattern]` |
| `apidiff` | Diff two JSON API responses (URLs or local files) | `apidiff <a> <b>` |
| `apihit` | GET a URL, pretty-print JSON response, show timing | `apihit <url> [curl-args...]` |
| `apimock` | Spin up a local json-server mock API from a JSON file | `apimock <file.json> [port]` |
| `apiwatch` | Poll an endpoint; log HTTP status + response time each hit | `apiwatch <url> [interval-seconds]` |
| `b64d` | Base64-decode text | `b64d <base64-text>` |
| `b64e` | Base64-encode text | `b64e <text>` |
| `bak` | Create a timestamped backup copy of a file | `bak <file>` |
| `basec` | Convert a number between hex, decimal, octal, and binary | `basec <number>` |
| `bench` | Time N runs of a command and report min/max/avg | `bench <runs> <command...>` |
| `branchage` | Local branches sorted by last commit date | `branchage` |
| `branchclean` | Delete local branches already merged into main/master | `branchclean` |
| `calc` | Quick command-line calculator | `calc <expression>` |
| `certcheck` | TLS certificate expiry date and days remaining for a domain | `certcheck <domain>` |
| `cheat` | Look up usage examples via tldr, fallback to man | `cheat <command>` |
| `clip` | Copy stdin or a file to the clipboard (pipe-friendly) | `clip [file]` |
| `clipcopy` | Copy a file's contents to the clipboard | `clipcopy <file>` |
| `colorconv` | Convert hex color to RGB or RGB to hex | `colorconv <#rrggbb>` or `colorconv <r> <g> <b>` |
| `compress` | Compress a file or directory to .tar.gz, .tar.bz2, or .zip | `compress <output> <path>` |
| `covreport` | Run tests with coverage and open the HTML report | `covreport` |
| `cpu` | Snapshot of CPU and process activity | `cpu` |
| `cpuwatch` | Live CPU load monitor, refreshes every second | `cpuwatch [interval-seconds]` |
| `cronlist` | List (numbered) crontab entries | `cronlist` |
| `cronadd` | Append a new cron job | `cronadd "<schedule>" "<command>"` |
| `cronedit` | Open the crontab in $EDITOR | `cronedit` |
| `cronhuman` | Translate a 5-field cron expression to plain English | `cronhuman "<min> <hour> <dom> <month> <dow>"` |
| `cronnext` | Show the next N scheduled run times for an expression | `cronnext "<schedule>" [count]` |
| `cronrm` | Fuzzy-pick and remove a cron job | `cronrm` |
| `curltime` | Detailed HTTP timing: DNS / TCP / TLS / TTFB / total | `curltime <url>` |
| `cwd` | Copy the current working directory path to the clipboard | `cwd` |
| `dbforward` | Port-forward to a picked k8s service with a connect hint | `dbforward <local-port> <remote-port>` |
| `dbuild` | Build a Docker image (tag defaults to the directory name) | `dbuild [tag]` |
| `dclean` | Prune all unused Docker data (containers, images, networks, cache) | `dclean` |
| `dcdown` | Tear down docker-compose services | `dcdown` |
| `dcup` | Bring up docker-compose services in the background | `dcup` |
| `denv` | Print all environment variables of a running container | `denv <container>` |
| `dhealth` | Show health status of all containers that define a healthcheck | `dhealth` |
| `diffjson` | Semantic diff of two JSON files (normalised with jq) | `diffjson <file-a> <file-b>` |
| `diffdir` | Recursively diff two directories | `diffdir <dir-a> <dir-b>` |
| `dimages` | Fuzzy-pick a local image to run, inspect, or delete | `dimages` |
| `diskusage` | Disk usage via ncdu, or a df/du summary if absent | `diskusage [path]` |
| `dnscheck` | Look up A, CNAME, and MX records for a domain | `dnscheck <domain>` |
| `dockerclean-images` | List dangling images and offer to remove them | `dockerclean-images` |
| `dockerlogs` | Tail container logs with timestamps | `dockerlogs <container>` |
| `dockernuke` | Force stop and remove a container | `dockernuke <container>` |
| `dockersizes` | Human-readable sizes of local Docker images | `dockersizes` |
| `dotenv-check` | Lint a .env file for empty values, duplicates, and unquoted secrets | `dotenv-check [file]` |
| `dports` | Show published port mappings for all running containers | `dports` |
| `dsh` | Fuzzy-pick a running container and open a shell inside it | `dsh` |
| `dstats` | One-shot resource usage snapshot for all running containers | `dstats` |
| `duh` | Disk usage of everything in the current directory, sorted by size | `duh` |
| `dupfind` | Find duplicate files by MD5/SHA256 hash | `dupfind [dir]` |
| `dvols` | Human-readable sizes of local Docker volumes | `dvols` |
| `emptydirs` | Find (and optionally remove) empty directories | `emptydirs [dir]` |
| `envdiff` | Diff two .env files showing added, removed, and changed keys | `envdiff <file1> <file2>` |
| `envexport` | Print export KEY='value' lines from a .env file | `envexport [file]` |
| `envgen` | Generate a .env.example from .env — keeps keys, strips values | `envgen [src] [out]` |
| `envload` | Load variables from a .env-style file into the current shell | `envload [file]` |
| `envmask` | Print a .env file with secret-looking values partially masked | `envmask [file]` |
| `envrequire` | Assert that a list of env vars are all set; exits non-zero with a missing-keys list | `envrequire VAR1 VAR2 ...` |
| `envswitch` | Load a named env profile from ~/.sharmory/envprofiles/ | `envswitch [profile-name]` |
| `envsync` | Compare .env vs .env.example and report keys missing from either side | `envsync [env] [example]` |
| `epoch` | Convert between Unix epoch and human-readable datetime | `epoch [epoch\|date]` |
| `extract` | Auto-extract archives by extension (.tar.gz, .zip, .7z, etc.) | `extract <archive-file>` |
| `fcd` | Fuzzy cd into a subdirectory | `fcd` |
| `ffind` | Find files by name or search file contents for text | `ffind <text>` or `ffind -f <filename>` |
| `findbig` | Find files above a given size (default 100M) | `findbig [size] [dir]` |
| `fkill` | Fuzzy-pick a process and kill it | `fkill` |
| `flushdns` | Flush the local DNS cache | `flushdns` |
| `ftext` | Fuzzy-search file contents and open the match in $EDITOR | `ftext` |
| `gacp` | git add + commit + push in one step (prompts on main/master) | `gacp <commit message>` |
| `gcamend` | Amend the last commit message without touching the stage | `gcamend <new message>` |
| `gdiffstage` | Show what is currently staged (ready to commit) | `gdiffstage` |
| `gemclean` | Uninstall old/duplicate gem versions, keeping only the latest of each | `gemclean` |
| `genuuid` | Generate a random UUID v4 | `genuuid` |
| `genssh` | Generate a new ed25519 SSH keypair | `genssh <key-name> [email]` |
| `gitbranch-rename` | Rename a branch locally and on the remote | `gitbranch-rename <old> <new>` |
| `gitcleanup` | Prune remotes, delete merged branches, tidy Go module | `gcleanup` |
| `gitconflicts` | List files with unresolved merge conflicts | `gitconflicts` |
| `gitcontributors` | Commit counts by author, sorted descending | `gitcontributors` |
| `gitignore` | Append a gitignore.io template to .gitignore | `gitignore <lang1,lang2,...>` |
| `gitlog-graph` | Pretty one-line graph log for the whole repo | `gitlog-graph` |
| `gitlog-today` | Your commits since midnight | `gitlog-today` |
| `gitprune` | Delete local branches whose remote counterpart is gone | `gitprune` |
| `gitsize` | Total size of the .git directory | `gitsize` |
| `gitundo` | Undo the last commit, keep changes staged | `gitundo` |
| `goclean` | Run gofmt, go vet, and go mod tidy in one pass | `goclean` |
| `gobench` | Run benchmarks with memory stats | `gobench [pattern]` |
| `gobuild` | Build a Go binary (output name defaults to directory name) | `gobuild [output]` |
| `gocover-func` | Show coverage percentage per function | `gocover-func` |
| `goenv` | Show all Go environment variables | `goenv` |
| `goimpl` | Show go doc for a type (or guru implements if available) | `goimpl <TypeName>` |
| `golist` | List all packages in the current module | `golist` |
| `gomod-name` | Print the module name from go.mod | `gomod-name` |
| `gomodwhy` | Explain why a module is in the dependency graph | `gomodwhy <module-path>` |
| `gonew` | Scaffold a minimal new Go module with a starter main.go | `gonew <module-path>` |
| `gopen` | Open the origin remote URL in a browser | `gopen` |
| `goupdate` | Upgrade all direct and indirect Go dependencies | `goupdate` |
| `govscan` | Scan dependencies for known vulnerabilities | `govscan` |
| `goversion` | Go version and key paths (GOROOT, GOPATH, GOMODCACHE) | `goversion` |
| `gorace` | Run tests with the race detector enabled | `gorace [./...]` |
| `gotest` | Run go test -v | `gotest [./...]` |
| `gowatch` | Re-run tests whenever a .go file changes | `gowatch` |
| `goxbuild` | Cross-compile a Go binary for a target OS and architecture | `goxbuild <GOOS> <GOARCH> [output]` |
| `gpr` | Open the PR/MR creation page for the current branch | `gpr` |
| `gradlesize` | Report size of the local Gradle cache | `gradlesize` |
| `gcleanup` | Prune remotes, delete merged branches, tidy Go module | `gcleanup` |
| `gclone` | Clone a repo and cd straight into it | `gclone <repo-url> [dir]` |
| `grebase` | Interactive rebase N commits back | `grebase [n]` |
| `grecentbranch` | Recently checked-out branches from the reflog | `grecentbranch [n]` |
| `greview` | Open the last open PR for the current branch in the browser | `greview` |
| `gstash` | Interactive stash picker — pop, apply, or drop via fzf | `gstash` |
| `gstats` | Per-author commit counts and lines added/deleted | `gstats [--since <date>]` |
| `gunwip` | Undo the last gwip commit (soft reset, keeps changes staged) | `gunwip` |
| `gswitch` | Fuzzy-pick a branch to switch to (local + remote) | `gswitch` |
| `gwip` | Quick checkpoint commit of all uncommitted changes | `gwip` |
| `hashfile` | Compute MD5, SHA1, and SHA256 hashes of a file | `hashfile <file>` |
| `headers` | Show full HTTP response headers for a URL | `headers <url>` |
| `hist` | Fuzzy-search shell history and paste the selection on the command line | `hist` |
| `httpstatus` | Fetch just the HTTP status code for a URL | `httpstatus <url>` |
| `ipinfo` | IP geolocation and ASN via ipinfo.io | `ipinfo [ip]` |
| `jarinfo` | Inspect a jar's manifest and top-level contents | `jarinfo <path-to-jar>` |
| `javaver` | Fuzzy-pick and switch JAVA_HOME (jenv/sdkman aware) | `javaver` |
| `jenk-build` | Trigger a build for a Jenkins job | `jenk-build <job-name>` |
| `jenk-crumb` | Get a Jenkins CSRF crumb (needed for POST requests) | `jenk-crumb` |
| `jenk-jobs` | List all job names on the configured Jenkins server | `jenk-jobs` |
| `jenk-logs` | Fetch the console log of the last build | `jenk-logs <job-name>` |
| `jsonpp` | Pretty-print a JSON file | `jsonpp <file>` |
| `jwtdecode` | Decode a JWT header and payload (no signature verification) | `jwtdecode <token>` |
| `k8sctx` | Fuzzy-switch kubectl context and namespace | `k8sctx` |
| `kcopy` | Copy a file to/from a picked pod | `kcp <local-path> <pod-path>` |
| `kdel` | Force-delete a picked (possibly stuck) pod | `kdel` |
| `kdesc` | Fuzzy-pick a pod and run kubectl describe on it | `kdesc` |
| `kevents` | Namespace events sorted by timestamp | `kevents` |
| `kexec` | Fuzzy-pick a pod and exec a shell into it | `kexec` |
| `killport` | Find and kill whatever process is listening on a port | `killport <port> [port ...]` |
| `klogs` | Fuzzy-pick a pod and stream its logs | `klogs` |
| `kns` | Set the current kubectl namespace without changing context | `kns <namespace>` |
| `kport` | Port-forward from localhost to a pod | `kport <local-port> <pod> <remote-port>` |
| `kcp` | Copy a file to/from a picked pod | `kcp <local-path> <pod-path>` |
| `krestart` | Rollout-restart a picked deployment | `krestart` |
| `kscale` | Scale a picked deployment to a given replica count | `kscale <replicas>` |
| `ksecret` | Decode and print the data of a picked secret | `ksecret` |
| `ktop` | Pods sorted by CPU or memory consumption | `ktop [cpu\|memory]` |
| `licensegen` | Generate a LICENSE file (MIT or Apache 2.0) | `licensegen <mit\|apache2> [author] [year]` |
| `localip` | Your local network IP address | `localip` |
| `lsd` | Enhanced directory listing (icons, git status, sort by modified) | `lsd` |
| `m2size` | Report size of the local Maven repository cache | `m2size` |
| `mem` | Current physical memory usage | `mem` |
| `memwatch` | Live memory usage monitor, refreshes every second | `memwatch [interval-seconds]` |
| `mkcd` | Make a directory and cd into it in one step | `mkcd <dir>` |
| `mkproject` | Scaffold a project directory with README, .gitignore, .env.example | `mkproject <name> [go\|node\|python]` |
| `mktemplate` | Create a project from a user-defined template in ~/.sharmory/templates/ | `mktemplate <template> <project>` |
| `mkvite` | Scaffold a Vite+React app — create, strip boilerplate, install, git init | `mkvite <app-name> [template]` |
| `mkviteapi` | Scaffold a companion Express or Fastify API folder | `mkviteapi [name] [--fastify]` |
| `mvntree` | Print the Maven dependency tree for the current project | `mvntree` |
| `myc` | Connect to MySQL using MYSQL_* env vars (or defaults) | `myc` |
| `myip` | Your public-facing IP address | `myip` |
| `nodeinfo` | Summary of the current Node project (name, scripts, deps) | `nodeinfo` |
| `noderepl` | Node.js REPL with project node_modules on NODE_PATH | `noderepl` |
| `nodeversion` | Node.js, npm, yarn, and pnpm versions | `nodeversion` |
| `note` | Append or view timestamped notes in ~/notes/YYYY-MM-DD.md | `note <text\|today\|list\|search <text>>` |
| `now` | Print current date and time (YYYY-MM-DD HH:MM:SS) | `now` |
| `npmaudit` | Run npm audit | `npmaudit` |
| `npmclean` | Delete node_modules + lockfile and reinstall from scratch | `npmclean` |
| `npmdedup` | Deduplicate and flatten the npm dependency tree | `npmdedup` |
| `npmglobal` | List globally installed npm packages | `npmglobal` |
| `npmlink` | Link this package globally or into a target project | `npmlink [target-dir]` |
| `npmoutdated` | Show outdated npm dependencies | `npmoutdated` |
| `npmscripts` | List scripts defined in package.json | `npmscripts` |
| `npmsize` | Size of the node_modules directory | `npmsize` |
| `npmwatch` | Watch files and re-run an npm script on change | `npmwatch [script]` |
| `npxrun` | Run a package with npx | `npxrun <package> [args...]` |
| `nvmuse` | Switch Node.js version via nvm or fnm | `nvmuse <version>` |
| `openapipp` | Validate and lint an OpenAPI/Swagger spec with Redocly | `openapipp <spec-file>` |
| `openat` | Open $EDITOR at a specific file and line | `openat <file>[:<line>]` |
| `openports` | Listening ports flagged by network exposure (0.0.0.0 / ::) | `openports` |
| `passgen` | Generate a random base64 password | `passgen [bytes]` |
| `permsof` | Show file permissions broken down by owner/group/other | `permsof <file>` |
| `pgc` | Connect to Postgres using PG* env vars (or defaults) | `pgc` |
| `pgdump` | Dump the current Postgres database to a timestamped .sql file | `pgdump <database>` |
| `pidtree` | Show the process tree for a given PID | `pidtree <pid>` |
| `pingcheck` | Send 5 pings to a host and print a RTT/loss summary | `pingcheck <host>` |
| `pipinstall` | Install packages from requirements.txt | `pipinstall` |
| `ports` | List all listening TCP/UDP ports with process name and PID | `ports` |
| `portscan` | Scan a TCP port range using /dev/tcp (no nmap needed) | `portscan <host> <start> [end]` |
| `portwho` | Show which process is listening on a given TCP port | `portwho <port>` |
| `prdiff` | Diff the current branch against a base branch | `prdiff [base-branch]` |
| `proxy` | Toggle http_proxy / https_proxy environment variables | `proxy <on [host:port]\|off\|status>` |
| `pubkey` | Print the contents of your SSH public keys | `pubkey` |
| `pyclean` | Remove all __pycache__ directories and .pyc files | `pyclean` |
| `pycheck` | Lint with ruff/flake8 and type-check with mypy | `pycheck [path]` |
| `pydeps` | List all installed pip packages | `pydeps` |
| `pyfreeze` | Write pip freeze output to requirements.txt | `pyfreeze` |
| `pyprofile` | Profile a script with cProfile, print top hotspots | `pyprofile <script.py> [args...]` |
| `pyrequirements-diff` | Diff pip freeze output against requirements.txt | `pyrequirements-diff` |
| `pyrun` | Run a Python script using the active venv interpreter | `pyrun <script.py> [args...]` |
| `pytest-run` | Run pytest with verbose output | `pytest-run [args...]` |
| `pyupgrade` | Upgrade all packages from requirements.txt | `pyupgrade` |
| `pyvenv` | Create .venv and activate it (uses uv if available) | `pyvenv` |
| `pyversion` | Python/pip versions and active venv path | `pyversion` |
| `pywatch` | Watch .py files and re-run pytest on change | `pywatch [test-path]` |
| `qr` | Generate a QR code for text/URL in the terminal | `qr <text>` |
| `rboutdated` | List outdated gems from the current Gemfile.lock | `rboutdated` |
| `rbver` | Fuzzy-pick and switch the active Ruby version (rbenv/rvm aware) | `rbver` |
| `reactcomp` | Scaffold a React component with barrel export (TS-aware) | `reactcomp <ComponentName> [dir]` |
| `recent` | Show the N most recently modified files | `recent [n]` |
| `redisc` | Connect to Redis using REDIS_* env vars | `redisc` |
| `retry` | Retry a command N times with exponential backoff | `retry <max-attempts> <command> [args...]` |
| `rspecf` | Re-run only the last-failed RSpec examples | `rspecf [args...]` |
| `serve` | Serve the current directory over HTTP | `serve [port]` |
| `shorten` | Shorten a URL using is.gd | `shorten <url>` |
| `sizeof` | Sizes of subdirectories under a path, largest first | `sizeof [path]` |
| `speed` | Internet speed test (speedtest-cli, fast, or curl fallback) | `speed` |
| `sshconfig` | List all Host entries from ~/.ssh/config | `sshconfig` |
| `sshcopy` | Copy your SSH public key to a remote host's authorized_keys | `sshcopy <user@host> [identity-file]` |
| `swap` | Atomically swap two filenames | `swap <file-a> <file-b>` |
| `sysinfo` | One-screen system summary (OS, CPU, RAM, disk, uptime, load) | `sysinfo` |
| `tcpcheck` | Quick TCP reachability check on host:port | `tcpcheck <host> <port>` |
| `timer` | Countdown timer with a beep/notification when done | `timer <seconds> [label]` |
| `tlscheck` | Full TLS certificate chain info for a domain | `tlscheck <domain>` |
| `todo` | Append or list entries in ~/todo.md, mark items done | `todo [text]` or `todo done <pattern>` |
| `todogrep` | Find TODO/FIXME/HACK/XXX comments across the codebase | `todogrep [dir]` |
| `trash` | Move a file or directory to the system trash | `trash <file-or-dir>` |
| `treelist` | Recursive tree listing with optional depth limit | `treelist [dir] [depth]` |
| `tscheck` | TypeScript type-check without emitting files | `tscheck` |
| `tunnel` | Open a quick ngrok tunnel to a local port | `tunnel <port>` |
| `up` | Go up N directory levels | `up [n]` |
| `urldecode` | URL-decode text | `urldecode <text>` |
| `urlencode` | URL-encode text | `urlencode <text>` |
| `venvcreate` | Create and activate a ./venv virtual environment | `venvcreate` |
| `vitebuild` | Production build with dist bundle size breakdown | `vitebuild` |
| `viteclean` | Wipe node_modules/dist/lockfile and reinstall clean | `viteclean` |
| `vitedev` | Start the Vite dev server and open the browser | `vitedev` |
| `viteenv` | Copy .env.example → .env if .env doesn't exist | `viteenv` |
| `vitelint` | Run ESLint + Prettier check + TypeScript typecheck in one pass | `vitelint [--fix]` |
| `watchrun` | Re-run a command whenever a path changes | `watchrun <path> -- <command...>` |
| `weather` | Weather for a location via wttr.in | `weather [location]` |
| `worktree` | Fuzzy-manage git worktrees: add, switch, or remove | `worktree <add\|switch\|remove>` |
| `sharmory` | Interactive HUD — fzf catalog if available, numbered menu otherwise | `sharmory` |
| `sharmory bench` | Measure how long a clean shell takes to source Sharmory | `sharmory bench [runs]` |
| `sharmory doctor` | Environment health check — versions, install path, optional tools | `sharmory doctor` |
| `sharmory-setup` | Interactively install optional CLI tools (fzf, jq, eza, tldr, entr) | `sharmory-setup` |
| `sharmory-update` | Download the latest Sharmory from GitHub and reload it | `sharmory-update` |
