# Changelog

> Lists every public shell function introduced per commit.
> Functions are deduplicated across `functions.bash`, `functions.zsh`, and `functions.ps1`.

---

## 2026-08-18 — initial commit
> Commit `bc9e1494` · 96 function(s) added

- `mkcd()`
- `up()`
- `lsd()`
- `fcd()`
- `ftext()`
- `permsof()`
- `extract()`
- `compress()`
- `duh()`
- `sizeof()`
- `findbig()`
- `emptydirs()`
- `dupfind()`
- `bak()`
- `cwd()`
- `clipcopy()`
- `watchrun()`
- `gitundo()`
- `branchclean()`
- `branchage()`
- `gacp()`
- `gclone()`
- `gwip()`
- `gunwip()`
- `gitprune()`
- `gswitch()`
- `prdiff()`
- `gitcontributors()`
- `gitsize()`
- `gitconflicts()`
- `gitignore()`
- `dockernuke()`
- `dclean()`
- `dockerlogs()`
- `dsh()`
- `dockersizes()`
- `k8sctx()`
- `klogs()`
- `kexec()`
- `ktop()`
- `kevents()`
- `covreport()`
- `gomodwhy()`
- `goclean()`
- `goupdate()`
- `gobench()`
- `gonew()`
- `gowatch()`
- `npmclean()`
- `npmscripts()`
- `npmoutdated()`
- `npmsize()`
- `venvcreate()`
- `pyclean()`
- `pyfreeze()`
- `myip()`
- `localip()`
- `killport()`
- `portwho()`
- `certcheck()`
- `dnscheck()`
- `httpstatus()`
- `apihit()`
- `flushdns()`
- `weather()`
- `tcpcheck()`
- `shorten()`
- `passgen()`
- `pubkey()`
- `genssh()`
- `b64e()`
- `b64d()`
- `urlencode()`
- `urldecode()`
- `hashfile()`
- `genuuid()`
- `mem()`
- `cpu()`
- `pidtree()`
- `fkill()`
- `now()`
- `timer()`
- `note()`
- `jsonpp()`
- `envload()`
- `ffind()`
- `cheat()`
- `calc()`
- `qr()`
- `gitlog-today()`
- `dockerclean-images()`
- `Get-SharmoryJenkinsAuth()`
- `jenk-crumb()`
- `jenk-build()`
- `jenk-logs()`
- `jenk-jobs()`

---

## 2026-08-18 — feat: add 1-line installers, uninstaller scripts, and sharmory-update self-updater
> Commit `37563f34` · 1 function(s) added

- `sharmory-update()`

---

## 2026-08-19 — added new zsh functions
> Commit `ab83ffe3` · 27 function(s) added

- `treelist()`
- `recent()`
- `swap()`
- `trash()`
- `gstash()`
- `grebase()`
- `gopen()`
- `gcleanup()`
- `denv()`
- `dbuild()`
- `kns()`
- `kdesc()`
- `kport()`
- `pingcheck()`
- `sshconfig()`
- `headers()`
- `proxy()`
- `jwtdecode()`
- `diskusage()`
- `envdiff()`
- `ports()`
- `sysinfo()`
- `todo()`
- `mkproject()`
- `epoch()`
- `diffjson()`
- `retry()`

---

## 2026-08-19 — Added "sharmory" command
> Commit `09598787` · 14 function(s) added

- `sharmory()`
- `Get-SharmoryRegistry()`
- `Get-SharmoryRegistryEntry()`
- `Show-SharmoryUsage()`
- `Show-SharmoryList()`
- `Show-SharmoryHelp()`
- `Invoke-SharmoryRun()`
- `Invoke-SharmoryPromptAndRun()`
- `Start-SharmoryHudFzf()`
- `Start-SharmoryHudMenu()`
- `Start-SharmoryHud()`
- `Get-SharmoryInstallHint()`
- `Write-SharmoryDoctorLine()`
- `sharmory-doctor()`

---

## 2026-08-19 — Ported all new functions to windows
> Commit `8ac5ae35` · 30 function(s) added

- `treelist()`
- `recent()`
- `swap()`
- `trash()`
- `gstash()`
- `grebase()`
- `gopen()`
- `gitbranch-rename()`
- `gitlog-graph()`
- `gcleanup()`
- `denv()`
- `dbuild()`
- `kns()`
- `kdesc()`
- `kport()`
- `pingcheck()`
- `sshconfig()`
- `headers()`
- `proxy()`
- `jwtdecode()`
- `dotenv-check()`
- `diskusage()`
- `envdiff()`
- `ports()`
- `sysinfo()`
- `todo()`
- `mkproject()`
- `epoch()`
- `diffjson()`
- `retry()`

---

## 2026-08-19 — Added sharmory-setup to install optional deps
> Commit `2cf2296b` · 4 function(s) added

- `Get-SharmorySetupWhy()`
- `Get-SharmoryWingetId()`
- `Install-SharmoryOptionalTool()`
- `sharmory-setup()`

---

## 2026-08-19 — Added sharmory bench command for benchmarking
> Commit `e18a904b` · 1 function(s) added

- `sharmory-bench()`

---

## 2026-08-20 — Added few more zsh functions
> Commit `8a599c36` · 10 function(s) added

- `grecentbranch()`
- `gcamend()`
- `gdiffstage()`
- `tlscheck()`
- `portscan()`
- `ipinfo()`
- `hist()`
- `mktemplate()`
- `envswitch()`
- `openports()`

---

## 2026-08-20 — Added more functions and enhanced README
> Commit `8a776f61` · 24 function(s) added

- `clip()`
- `gpr()`
- `fcd()`
- `ftext()`
- `watchrun()`
- `gswitch()`
- `gcamend()`
- `grecentbranch()`
- `gdiffstage()`
- `dsh()`
- `k8sctx()`
- `klogs()`
- `kexec()`
- `gonew()`
- `gowatch()`
- `certcheck()`
- `tlscheck()`
- `portscan()`
- `ipinfo()`
- `fkill()`
- `openports()`
- `hist()`
- `mktemplate()`
- `envswitch()`

---

## 2026-08-21 — Added BASH support
> Commit `934344ab` · 129 function(s) added

- `mkcd()`
- `up()`
- `lsd()`
- `fcd()`
- `ftext()`
- `permsof()`
- `extract()`
- `compress()`
- `duh()`
- `sizeof()`
- `findbig()`
- `emptydirs()`
- `dupfind()`
- `bak()`
- `cwd()`
- `clipcopy()`
- `clip()`
- `watchrun()`
- `treelist()`
- `recent()`
- `swap()`
- `trash()`
- `gitundo()`
- `branchclean()`
- `branchage()`
- `gacp()`
- `gclone()`
- `gwip()`
- `gunwip()`
- `gitprune()`
- `gswitch()`
- `prdiff()`
- `gitcontributors()`
- `gitsize()`
- `gitconflicts()`
- `gitignore()`
- `gstash()`
- `grebase()`
- `gopen()`
- `gpr()`
- `gcleanup()`
- `grecentbranch()`
- `gcamend()`
- `gdiffstage()`
- `dockernuke()`
- `dclean()`
- `dockerlogs()`
- `dsh()`
- `dockersizes()`
- `k8sctx()`
- `klogs()`
- `kexec()`
- `ktop()`
- `kevents()`
- `denv()`
- `dbuild()`
- `kns()`
- `kdesc()`
- `kport()`
- `covreport()`
- `gomodwhy()`
- `goclean()`
- `goupdate()`
- `gobench()`
- `gonew()`
- `gowatch()`
- `npmclean()`
- `npmscripts()`
- `npmoutdated()`
- `npmsize()`
- `venvcreate()`
- `pyclean()`
- `pyfreeze()`
- `myip()`
- `localip()`
- `killport()`
- `portwho()`
- `certcheck()`
- `dnscheck()`
- `httpstatus()`
- `apihit()`
- `flushdns()`
- `weather()`
- `tcpcheck()`
- `shorten()`
- `tlscheck()`
- `portscan()`
- `ipinfo()`
- `pingcheck()`
- `sshconfig()`
- `headers()`
- `proxy()`
- `passgen()`
- `pubkey()`
- `genssh()`
- `b64e()`
- `b64d()`
- `urlencode()`
- `urldecode()`
- `hashfile()`
- `genuuid()`
- `jwtdecode()`
- `mem()`
- `cpu()`
- `pidtree()`
- `fkill()`
- `now()`
- `timer()`
- `diskusage()`
- `envdiff()`
- `ports()`
- `sysinfo()`
- `note()`
- `jsonpp()`
- `envload()`
- `ffind()`
- `todo()`
- `mkproject()`
- `epoch()`
- `diffjson()`
- `retry()`
- `cheat()`
- `calc()`
- `qr()`
- `hist()`
- `mktemplate()`
- `envswitch()`
- `openports()`
- `sharmory()`

---

## 2026-08-21 — Added more go/node/py functions
> Commit `e437e53e` · 33 function(s) added

- `gorace()`
- `gobuild()`
- `goxbuild()`
- `goenv()`
- `golist()`
- `goversion()`
- `gotest()`
- `govscan()`
- `goimpl()`
- `nodeversion()`
- `nvmuse()`
- `tscheck()`
- `npxrun()`
- `npmglobal()`
- `npmlink()`
- `noderepl()`
- `npmaudit()`
- `nodeinfo()`
- `npmdedup()`
- `npmwatch()`
- `pipinstall()`
- `pyversion()`
- `pycheck()`
- `pywatch()`
- `pydeps()`
- `pyupgrade()`
- `pyrun()`
- `pyprofile()`
- `pyvenv()`
- `gocover-func()`
- `gomod-name()`
- `pytest-run()`
- `pyrequirements-diff()`

---

## 2026-08-21 — Added more functions
> Commit `b67c953d` · 67 function(s) added

- `greview()`
- `gstats()`
- `dimages()`
- `dstats()`
- `dcup()`
- `dcdown()`
- `dhealth()`
- `dvols()`
- `dports()`
- `krestart()`
- `kscale()`
- `kdel()`
- `ksecret()`
- `kcp()`
- `gemclean()`
- `rbver()`
- `rboutdated()`
- `rspecf()`
- `m2size()`
- `gradlesize()`
- `jarinfo()`
- `javaver()`
- `mvntree()`
- `pgc()`
- `myc()`
- `redisc()`
- `pgdump()`
- `dbforward()`
- `serve()`
- `todogrep()`
- `basec()`
- `colorconv()`
- `tunnel()`
- `bench()`
- `diffdir()`
- `openat()`
- `worktree()`
- `licensegen()`
- `mkvite()`
- `vitedev()`
- `vitebuild()`
- `viteclean()`
- `reactcomp()`
- `viteenv()`
- `vitelint()`
- `mkviteapi()`
- `cronlist()`
- `cronadd()`
- `cronrm()`
- `cronedit()`
- `cronhuman()`
- `cronnext()`
- `apiwatch()`
- `apimock()`
- `apidiff()`
- `curltime()`
- `openapipp()`
- `envgen()`
- `envrequire()`
- `envexport()`
- `envmask()`
- `envsync()`
- `cpuwatch()`
- `memwatch()`
- `speed()`
- `sshcopy()`
- `alias-list()`

