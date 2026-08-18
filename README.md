# Sharmory

A single-file library of dev-focused zsh & PowerShell functions — git shortcuts, docker/k8s helpers,
Go/Node/Python workflow utilities, networking checks, security/encoding helpers, and
general productivity tools. No plugin manager, no framework — just source one file.

## Install

### Zsh (macOS / Linux / WSL)

```bash
git clone https://github.com/hariharen9/sharmory.git ~/.sharmory
echo 'source ~/.sharmory/functions.zsh' >> ~/.zshrc
source ~/.zshrc
```

Or, without cloning:

```bash
curl -o ~/.sharmory-functions.zsh https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.zsh
echo 'source ~/.sharmory-functions.zsh' >> ~/.zshrc
```

### Windows (PowerShell 5.1+ & PowerShell 7+)

Add it to your `$PROFILE`:

```powershell
# Create profile if it doesn't exist yet
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

# Clone and source Sharmory
git clone https://github.com/hariharen9/sharmory.git "$HOME\sharmory"
Add-Content $PROFILE '. "$HOME\sharmory\functions.ps1"'
. $PROFILE
```

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

- **Navigation & Files** — `mkcd`, `up`, `lsd`, `fcd`, `ftext`, `permsof`, `extract`,
  `compress`, `duh`, `sizeof`, `findbig`, `emptydirs`, `dupfind`, `bak`, `cwd`,
  `clipcopy`, `watchrun`
- **Git** — `gitundo`, `branchclean`, `branchage`, `gitlog-today`, `gacp`, `gclone`,
  `gwip`, `gunwip`, `gitprune`, `gswitch`, `prdiff`, `gitcontributors`, `gitsize`,
  `gitconflicts`, `gitignore`
- **Docker & Kubernetes** — `dockernuke`, `dockerclean-images`, `dclean`, `dockerlogs`,
  `dsh`, `dockersizes`, `k8sctx`, `klogs`, `kexec`, `ktop`, `kevents`
- **Go** — `covreport`, `gomodwhy`, `goclean`, `goupdate`, `gobench`, `gonew`, `gowatch`
- **Node/npm** — `npmclean`, `npmscripts`, `npmoutdated`, `npmsize`
- **Python** — `venvcreate`, `pyclean`, `pyfreeze`
- **Networking** — `myip`, `localip`, `killport`, `portwho`, `certcheck`, `dnscheck`,
  `httpstatus`, `apihit`, `flushdns`, `weather`, `tcpcheck`, `shorten`
- **Security & Encoding** — `passgen`, `pubkey`, `genssh`, `b64e`/`b64d`,
  `urlencode`/`urldecode`, `hashfile`, `genuuid`
- **System & Process** — `mem`, `cpu`, `pidtree`, `fkill`, `now`, `timer`
- **Productivity** — `note`, `jsonpp`, `envload`, `ffind`, `cheat`, `calc`, `qr`
- **CI/Jenkins** — `jenk-crumb`, `jenk-build`, `jenk-logs`, `jenk-jobs`
  (needs `JENKINS_URL`, `JENKINS_USER`, `JENKINS_TOKEN` env vars)

Every function has `-h`/usage text or a comment directly above it explaining what it
does — run `grep -B2 '^myfunction()' functions.zsh` or just open the file.

## Why one file?

Most developers plugging this into their shell profile want a single `source` line and to be
done with it. If you only want a subset, categories are clearly delimited with
`# N. CATEGORY NAME` headers — just copy or delete what you want.

## Testing

Both platforms ship a sandboxed self-test that exercises every function without
touching your real system: no real docker/kubectl calls, no real network requests,
no real processes killed, no real files outside a throwaway temp directory. External
tools that would otherwise hit the network or a live daemon (`docker`, `kubectl`,
`curl`/`Invoke-RestMethod`, `dig`/`Resolve-DnsName`, `ssh-keygen`, `fzf`, etc.) are
mocked for the duration of the run, and the whole sandbox is deleted afterward
whether the run passes or fails.

**macOS/Linux:**

```bash
chmod +x test-sharmory.zsh
./test-sharmory.zsh          # tests functions.zsh in the same directory
./test-sharmory.zsh path/to/functions.zsh   # or point at a specific file
```

**Windows:**

```powershell
.\test-sharmory.ps1
.\test-sharmory.ps1 -FunctionsPath path\to\functions.ps1
```

Each run prints a PASS/FAIL/SKIP line per function and a summary count. Functions
are marked SKIP rather than FAIL when an optional dependency genuinely isn't
installed (`jq`, `entr`/`fswatch`, `python3`, `git`), or when a function is designed
to loop forever (`watchrun`, `gowatch`).

Exit code is `0` if everything passed or was cleanly skipped, `1` if anything
actually failed — safe to wire into CI.

**Platform Verification:** Both the Zsh and PowerShell implementations are verified end-to-end against live interpreters with 100% sandboxed test suites. In Zsh, early testing caught variable collisions with the special `$path` array. In PowerShell, testing verified parser compatibility across Windows PowerShell 5.1 and modern PowerShell Core (7+), ensuring clean dot-sourcing into `$PROFILE` with zero startup errors.

## Contributing

PRs adding new functions welcome. Keep the style consistent:

- one function, one job
- `Usage:` line printed when required args are missing
- guard against missing optional dependencies rather than hard-failing
- a one- or two-line comment above the function explaining what it does

## License

MIT
