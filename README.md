# Sharmory

A single-file library of dev-focused zsh functions — git shortcuts, docker/k8s helpers,
Go/Node/Python workflow utilities, networking checks, security/encoding helpers, and
general productivity tools. No plugin manager, no framework — just source one file.

## Install

```bash
git clone https://github.com/<your-username>/Sharmory.git ~/.Sharmory
echo 'source ~/.Sharmory/functions.zsh' >> ~/.zshrc
source ~/.zshrc
```

Or, without cloning:

```bash
curl -o ~/.Sharmory-functions.zsh https://raw.githubusercontent.com/<your-username>/Sharmory/main/functions.zsh
echo 'source ~/.Sharmory-functions.zsh' >> ~/.zshrc
```

## Optional dependencies

Most functions work with only core Unix tools. A few are more useful with:

| Tool | Used by |
|---|---|
| `fzf` | `fcd`, `ftext`, `dsh`, `k8sctx`, `klogs`, `kexec`, `fkill`, `gswitch` |
| `jq` | `npmscripts`, `jenk-crumb`, `jenk-jobs`, `jsonpp` |
| `eza` | `lsd` |
| `entr` or `fswatch` | `watchrun`, `gowatch` |
| `tldr` | `cheat` (falls back to `man`) |

Every function checks for its dependency and fails gracefully (or falls back to a
plain alternative) if it's missing.

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

Most people plugging this into their `.zshrc` want a single `source` line and to be
done with it. If you only want a subset, categories are clearly delimited with
`# N. CATEGORY NAME` headers — just delete what you don't want.

## Windows (PowerShell)

A full PowerShell port lives in `functions.ps1`, covering the same 70+ functions
across the same categories. Add it to your `$PROFILE`:

```powershell
# find your profile path
echo $PROFILE

# create the profile file if it doesn't exist yet
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }

# add this line to it (edit with notepad $PROFILE, or run the line below)
Add-Content $PROFILE '. "$HOME\Sharmory\functions.ps1"'
```

Then drop `functions.ps1` at `~/Sharmory/functions.ps1` (or wherever you point the
dot-source at) and restart your terminal, or run `. $PROFILE` to reload immediately.

Notes on the PowerShell version:

- Requires PowerShell 5.1+ (ships with Windows 10/11) or PowerShell 7+.
- Uses native Windows cmdlets where possible (`Get-NetTCPConnection`, `Get-Acl`,
  `Get-FileHash`, `Resolve-DnsName`, `Compress-Archive`) instead of Unix tools.
- `fzf`-dependent functions (`fcd`, `ftext`, `dsh`, `k8sctx`, `klogs`, `kexec`,
  `fkill`, `gswitch`) still need `fzf.exe` — install via `winget install fzf` or
  `scoop install fzf`.
- `extract` handles `.zip` natively; `.tar.gz`/`.tar`/`.tgz` need `tar` (bundled
  with modern Windows); `.7z`/`.rar` need 7-Zip/WinRAR on PATH.
- A few zsh-only functions (`emptydirs`'s interactive `y/N` prompts, `killport`
  force-kill fallback) are simplified since Windows process/signal handling
  differs from POSIX.
- Not run through a live PowerShell interpreter to verify — written carefully by
  hand and checked for balanced braces/parens, but treat it as a first cut and
  sanity-check the functions you actually plan to use before relying on it.

If you're on Windows and want the exact same zsh experience instead of a native
port, **WSL** is the other option: install `zsh` inside WSL and source
`functions.zsh` unmodified — every function there works as-is since WSL is a real
Linux userspace.

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
to loop forever (`watchrun`, `gowatch`) — those two are existence-checked only, not
executed, since no timeout can safely bound an intentionally infinite watch loop
running for real.

Exit code is `0` if everything passed or was cleanly skipped, `1` if anything
actually failed — safe to wire into CI.

**Honesty note:** the zsh test script was actually run end-to-end while building
this repo, and its run caught (and this fixed) three real bugs — `up`, `sizeof`,
and `watchrun` used a local variable named `path`, which collides with zsh's
special `$path` array (linked to `$PATH`) and silently broke command lookup inside
those functions. The PowerShell test script was written and structurally
validated (balanced braces/parens, correct here-string syntax) but not executed
against a live PowerShell interpreter, since none was available in the environment
this was built in — run it once yourself before you trust it in CI.

## Contributing

PRs adding new functions welcome. Keep the style consistent:

- one function, one job
- `Usage:` line printed when required args are missing
- guard against missing optional dependencies rather than hard-failing
- a one- or two-line comment above the function explaining what it does

## License

MIT
