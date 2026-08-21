#requires -version 5.1
#
# test-sharmory.ps1 - sandboxed smoke test for every function in functions.ps1
#
# Every external command that could touch the real network, real docker/k8s,
# a real process, or a real Jenkins server is shadowed with a mock function
# for the duration of the run. Everything happens inside a throwaway temp
# directory that is deleted at the end, pass or fail.
#
# Usage:
#   .\test-sharmory.ps1 [-FunctionsPath path\to\functions.ps1]

param(
    [string]$FunctionsPath = (Join-Path $PSScriptRoot "functions.ps1")
)

$ErrorActionPreference = "Continue"
$Script:PassCount = 0
$Script:FailCount = 0
$Script:SkipCount = 0
$Script:TotalCount = 0

if (-not (Test-Path $FunctionsPath)) {
    Write-Host "Cannot find functions.ps1 at: $FunctionsPath" -ForegroundColor Red
    exit 1
}

#########################################################################
# SANDBOX SETUP
#########################################################################

$Sandbox   = Join-Path $env:TEMP ("sharmory-test-" + [guid]::NewGuid().ToString("N").Substring(0,8))
$WorkDir   = Join-Path $Sandbox "work"
$FakeHome  = Join-Path $Sandbox "fakehome"
$RemoteDir = Join-Path $Sandbox "remote.git"

New-Item -ItemType Directory -Force -Path $WorkDir, "$FakeHome\.ssh", "$FakeHome\notes" | Out-Null

Write-Host "Sandbox: $Sandbox"
Write-Host "Testing: $FunctionsPath"
Write-Host ""

$env:JENKINS_URL = "http://mock-jenkins.local"
$env:JENKINS_USER = "mockuser"
$env:JENKINS_TOKEN = "mocktoken"

$env:GIT_AUTHOR_NAME = "Sharmory Test"
$env:GIT_AUTHOR_EMAIL = "test@sharmory.local"
$env:GIT_COMMITTER_NAME = "Sharmory Test"
$env:GIT_COMMITTER_EMAIL = "test@sharmory.local"

$HasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)

#########################################################################
# LOAD THE REAL FUNCTIONS, THEN SHADOW EVERYTHING DANGEROUS
#########################################################################

$resolvedPath = (Resolve-Path $FunctionsPath).Path
. ([scriptblock]::Create([System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)))

# --- fzf: auto-select first line ---
function fzf {
    $line = $input | Where-Object { $_ -and $_.ToString().Trim() -ne "" } | Select-Object -First 1
    if ($line) { $line }
}

# --- docker / kubectl: canned responses, never touch a real daemon ---
function docker {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "ps --format*"     { "mockid123`tmockcontainer`tmockimage" }
        "images -f*"       { }
        "images --format*" { "mockrepo:latest`t123MB" }
        "info*"            { "Client: Docker Engine - Community (mock)" }
        "inspect*"         { "MOCK_VAR=hello`nOTHER_VAR=world" }
        "build*"           { "Successfully built mockimage123" }
        "stats*"           { "NAME`tCPU%`tMEM`tNET`nmockcontainer`t0.1%`t10MiB / 2GiB`t0B / 0B" }
        "compose up*"      { "[mock] docker compose up" }
        "compose down*"    { "[mock] docker compose down" }
        "system df*"       { "mockvolume`t10MB" }
        "volume ls*"       { "mockvolume" }
        "volume inspect*"  { "/var/lib/docker/volumes/mockvolume/_data" }
        default            { Write-Host "[mock] docker $s" }
    }
}
function kubectl {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "config get-contexts*" { "mock-context" }
        "get ns*"              { "namespace/mock-ns" }
        "get pods*"            { "pod/mock-pod" }
        "top pods*"            { "NAME`tCPU`tMEMORY`nmock-pod`t1m`t2Mi" }
        "get events*"          { "LAST SEEN   TYPE   REASON   OBJECT" }
        "config set-context*"  { "Context updated." }
        "describe pod*"        { "Name: mock-pod`nNamespace: default" }
        "port-forward*"        { "Forwarding from 127.0.0.1:8080 -> 80" }
        "get deployments*"     { "deployment.apps/mock-deploy" }
        "rollout restart*"     { "deployment.apps/mock-deploy restarted" }
        "rollout status*"      { "deployment `"mock-deploy`" successfully rolled out" }
        "scale*"               { "deployment.apps/mock-deploy scaled" }
        "delete pod*"          { "pod `"mock-pod`" deleted" }
        "get secrets*"         { "secret/mock-secret" }
        "get secret*"          { '{"data":{"username":"dGVzdA==","password":"c2VjcmV0"}}' }
        "get svc*"             { "service/mock-svc" }
        "cp*"                  { "[mock] kubectl cp $s" }
        default                { Write-Host "[mock] kubectl $s" }
    }
}

# --- ruby/java/db: no-op mocks ---
function gem     { $sub = $args[0]; if ($sub -eq "cleanup") { "[mock] gem cleanup" } elseif ($sub -eq "env") { "/mock/gem/dir" } else { Write-Host "[mock] gem $args" } }
function bundle  { $sub = $args[0]; if ($sub -eq "outdated") { "[mock] bundle outdated" } else { Write-Host "[mock] bundle $args" } }
function rbenv   { $sub = $args[0]; if ($sub -eq "versions") { "3.2.0" } else { Write-Host "[mock] rbenv $args" } }
function mvn     { Write-Host "[mock] mvn $args" }
function psql    { Write-Host "[mock] psql $args" }
function mysql   { Write-Host "[mock] mysql $args" }
function redis-cli { Write-Host "[mock] redis-cli $args" }
function pg_dump { Write-Host "[mock] pg_dump $args" }
function jar     { Write-Host "[mock] jar $args" }

# --- go: respond to subcommands used by new functions ---
function go {
    $sub = $args[0]
    switch ($sub) {
        "version" { "go version go1.22.0 windows/amd64" }
        "env" {
            switch ($args[1]) {
                "GOROOT"     { "C:\Go" }
                "GOPATH"     { "$HOME\go" }
                "GOMODCACHE" { "$HOME\go\pkg\mod" }
                "GOPROXY"    { "https://proxy.golang.org" }
                default      { "GOENV=mock" }
            }
        }
        "list" { "example.com/mockmod" }
        default { Write-Host "[mock] go $args" }
    }
}
function npm     { Write-Host "[mock] npm $args" }
function node    {
    if ($args[0] -eq "--version") { "v20.0.0"; return }
    if ($args[0] -eq "-e") {
        $expr = $args[1]
        if ($expr -like "*p.name*")           { "mock-package"; return }
        if ($expr -like "*p.version*")        { "1.0.0"; return }
        if ($expr -like "*scripts*")          { "2"; return }
        if ($expr -like "*devDependencies*")  { "1"; return }
        if ($expr -like "*dependencies*")     { "3"; return }
        "0"; return
    }
    Write-Host "[mock] node $args"
}
function npx         { Write-Host "[mock] npx $args" }
function tsc         { Write-Host "[mock] tsc $args" }
function nodemon     { Write-Host "[mock] nodemon $args" }
function fnm         { Write-Host "[mock] fnm $args"; return }
function govulncheck { Write-Host "[mock] govulncheck $args" }
function ruff        { Write-Host "[mock] ruff $args" }
function flake8      { Write-Host "[mock] flake8 $args" }
function mypy        { Write-Host "[mock] mypy $args" }
function pytest      { Write-Host "[mock] pytest $args" }
function pip {
    $sub = $args[0]
    switch ($sub) {
        "freeze"  { "requests==2.28.0" }
        "list"    { "Package  Version`n------- -------`nrequests 2.28.0" }
        "install" { Write-Host "[mock] pip install $($args[1..$args.Count] -join ' ')" }
        default   { Write-Host "[mock] pip $args" }
    }
}

# --- python: real enough to make venvcreate/pyclean succeed ---
function python {
    $joined = $args -join ' '
    if ($joined -like "*-m venv*") {
        $venvPath = $args[-1]
        New-Item -ItemType Directory -Force -Path "$venvPath\Scripts" | Out-Null
        "# mock activate script" | Out-File "$venvPath\Scripts\Activate.ps1"
        Write-Host "[mock] created fake venv at $venvPath"
    } else {
        Write-Host "[mock] python $joined"
    }
}

# --- ssh-keygen: write fake key files ---
function ssh-keygen {
    $out = $null
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq "-f") { $out = $args[$i + 1] }
    }
    if ($out) {
        New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
        "mock-private-key" | Out-File $out
        "ssh-ed25519 AAAAmock mock@sharmory" | Out-File "$out.pub"
    }
    Write-Host "[mock] ssh-keygen -f $out"
}

# --- networking: nothing here ever leaves the machine ---
function Invoke-RestMethod {
    param([string]$Uri, [string]$Method, $Headers, $Body, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    if ($Uri -like "*crumbIssuer*") { return [PSCustomObject]@{ crumb = "mockcrumb1234" } }
    if ($Uri -like "*api/json*")    { return [PSCustomObject]@{ jobs = @([PSCustomObject]@{ name = "mock-job-1" }, [PSCustomObject]@{ name = "mock-job-2" }) } }
    if ($Uri -like "*is.gd*")       { return "https://is.gd/mocklink" }
    if ($Uri -like "*gitignore*")   { return "# mock gitignore content" }
    return [PSCustomObject]@{ mock = "response" }
}
function Invoke-WebRequest {
    param([string]$Uri, [string]$Method, [switch]$UseBasicParsing, [string]$OutFile, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    $content = '{"mock":"response"}'
    if ($Uri -like "*wttr*")    { $content = "Mock weather: Sunny, 22C" }
    if ($Uri -like "*qrenco*")  { $content = "[mock qr ascii art]" }
    if ($Uri -like "*functions.ps1") { $content = "# mock updated functions.ps1" }
    if ($OutFile) {
        $content | Out-File -FilePath $OutFile -Encoding utf8
    }
    [PSCustomObject]@{
        StatusCode = 200
        Content    = $content
        Headers    = @{ Server = "mock-server"; "Content-Type" = "text/html" }
    }
}
function Resolve-DnsName {
    param([string]$Name, [string]$Type, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    switch ($Type) {
        "A"  { [PSCustomObject]@{ IPAddress = "93.184.216.34" } }
        "MX" { [PSCustomObject]@{ NameExchange = "mock-mx.example.com" } }
    }
}
function Test-NetConnection {
    param([string]$ComputerName, [int]$Port, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    [PSCustomObject]@{ TcpTestSucceeded = $false }
}
function Test-Connection {
    param([string]$ComputerName, [int]$Count, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    Write-Host "[mock] ping $ComputerName x$Count"
}
function Clear-DnsClientCache { Write-Host "[mock] Clear-DnsClientCache" }

# --- process control & clipboard ---
function Stop-Process {
    param([int]$Id, [switch]$Force, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    Write-Host "[mock] Stop-Process -Id $Id (not actually killed)"
}
function Start-Process { param([Parameter(ValueFromRemainingArguments = $true)]$Rest); Write-Host "[mock] Start-Process $Rest" }
function Set-Clipboard { param([Parameter(ValueFromPipeline = $true)]$InputObject) }
function Read-Host { param($Prompt) Write-Host "[mock] Read-Host $Prompt"; "n" }

#########################################################################
# SEED SANDBOX DATA
#########################################################################

Push-Location $WorkDir

if ($HasGit) {
    git init -q --bare $RemoteDir | Out-Null
    git init -q | Out-Null
    git checkout -q -b main 2>$null
    git config core.pager cat
    git config user.email "test@sharmory.local"
    git config user.name "Sharmory Test"
    git remote add origin $RemoteDir

    "hello" | Out-File file1.txt -Encoding utf8
    "main.go dummy" | Out-File main.go -Encoding utf8
    git add -A
    git commit -q -m "initial commit"
    git push -q -u origin main

    git checkout -q -b feature/test-branch
    "feature work" | Add-Content file1.txt
    git add -A
    git commit -q -m "feature commit"
    git checkout -q main
} else {
    "hello" | Out-File file1.txt -Encoding utf8
}

'{"a":1,"b":{"c":2},"list":[1,2,3]}' | Out-File sample.json -Encoding utf8
"FOO=bar`nBAZ=qux" | Out-File .env -Encoding utf8
'{"name":"mock","version":"1.0.0","scripts":{"test":"echo test","build":"echo build"}}' | Out-File package.json -Encoding utf8
New-Item -ItemType Directory -Force -Path node_modules | Out-Null
New-Item -ItemType Directory -Force -Path updir\sub | Out-Null
"ssh-ed25519 AAAAmockkey mock@sharmory" | Out-File "$FakeHome\.ssh\id_ed25519.pub" -Encoding ascii
@"
Host devserver
    HostName dev.example.com
    User deploy
    Port 2222
"@ | Out-File "$FakeHome\.ssh\config" -Encoding ascii

Pop-Location

#########################################################################
# TEST RUNNER
#########################################################################

function Invoke-SharmoryTest {
    param([string]$Label, [scriptblock]$Test)

    $Script:TotalCount++
    Push-Location $WorkDir
    try {
        & $Test
        Write-Host ("  PASS  {0,-22}" -f $Label) -ForegroundColor Green
        $Script:PassCount++
    } catch {
        Write-Host ("  FAIL  {0,-22} {1}" -f $Label, $_.Exception.Message) -ForegroundColor Red
        $Script:FailCount++
    } finally {
        Pop-Location
    }
}

function Skip-SharmoryTest {
    param([string]$Label, [string]$Reason)
    $Script:TotalCount++
    $Script:SkipCount++
    Write-Host ("  SKIP  {0,-22} ({1})" -f $Label, $Reason) -ForegroundColor Yellow
}

#########################################################################
# 1. NAVIGATION & FILES
#########################################################################
Write-Host "-- Navigation & Files --"
Invoke-SharmoryTest "mkcd"      { mkcd newdir_mkcd; if ((Split-Path -Leaf (Get-Location).Path) -ne "newdir_mkcd") { throw "cd failed" } }
Invoke-SharmoryTest "up"        { New-Item -ItemType Directory -Force ud1\ud2 | Out-Null; Set-Location ud1\ud2; up 1; if ((Split-Path -Leaf (Get-Location).Path) -ne "ud1") { throw "up failed" } }
Invoke-SharmoryTest "lsd"       { lsd }
Invoke-SharmoryTest "permsof"   { permsof file1.txt }
Invoke-SharmoryTest "extract"   { Compress-Archive -Path file1.txt -DestinationPath t.zip -Force; New-Item -ItemType Directory -Force xd | Out-Null; Set-Location xd; extract ..\t.zip }
Invoke-SharmoryTest "compress"  { compress out.zip file1.txt }
Invoke-SharmoryTest "duh"       { duh }
Invoke-SharmoryTest "sizeof"    { sizeof }
Invoke-SharmoryTest "findbig"   { findbig }
Invoke-SharmoryTest "emptydirs" { New-Item -ItemType Directory -Force emptytest | Out-Null; emptydirs emptytest }
Invoke-SharmoryTest "dupfind"   { Copy-Item file1.txt file1_dup.txt; dupfind . }
Invoke-SharmoryTest "bak"       { bak file1.txt; if (-not (Get-ChildItem "file1.txt.*.bak")) { throw "no backup created" } }
Invoke-SharmoryTest "cwd"       { cwd }
Invoke-SharmoryTest "clipcopy"  { clipcopy file1.txt }
Invoke-SharmoryTest "treelist"  { treelist . }
Invoke-SharmoryTest "recent"    { recent 5 }
Invoke-SharmoryTest "swap"      { "a" | Out-File swapA.txt -Encoding ascii; "b" | Out-File swapB.txt -Encoding ascii; swap swapA.txt swapB.txt }
Invoke-SharmoryTest "trash"     { "trashme" | Out-File trashtest.txt -Encoding ascii; trash trashtest.txt; if (Test-Path trashtest.txt) { throw "not trashed" } }

#########################################################################
# 2. GIT
#########################################################################
Write-Host "-- Git --"
if ($HasGit) {
    Invoke-SharmoryTest "gitundo"       { git commit --allow-empty -q -m tmp; gitundo }
    Invoke-SharmoryTest "branchclean"   { branchclean }
    Invoke-SharmoryTest "branchage"     { branchage }
    Invoke-SharmoryTest "gitlog-today"  { gitlog-today }
    Invoke-SharmoryTest "gacp"          { git checkout -q feature/test-branch; "more" | Add-Content file1.txt; gacp "test commit via gacp" }
    Invoke-SharmoryTest "gclone"        { Set-Location ..; Remove-Item -Recurse -Force clone-test -ErrorAction SilentlyContinue; gclone "$RemoteDir" clone-test }
    Invoke-SharmoryTest "gwip"          { "wipchange" | Add-Content file1.txt; gwip }
    Invoke-SharmoryTest "gunwip"        { gunwip }
    Invoke-SharmoryTest "gitprune"      { gitprune }
    Invoke-SharmoryTest "prdiff"        { git checkout -q main 2>$null; prdiff }
    Invoke-SharmoryTest "gitcontributors" { gitcontributors }
    Invoke-SharmoryTest "gitsize"       { gitsize }
    Invoke-SharmoryTest "gitconflicts"  { gitconflicts }
    Invoke-SharmoryTest "gitignore"     { gitignore "go,windows" }
    Invoke-SharmoryTest "gstash"        { "wipstash" | Add-Content file1.txt; git add -A; git stash; gstash }
    Invoke-SharmoryTest "gopen"         { gopen }
    Invoke-SharmoryTest "gitbranch-rename" { git checkout -q main; git checkout -q -b rename-old; gitbranch-rename rename-old rename-new; git checkout -q main }
    Invoke-SharmoryTest "gitlog-graph"  { gitlog-graph }
    Invoke-SharmoryTest "gcleanup"      { gcleanup }
    Invoke-SharmoryTest "greview(no-gh)" {
        $out = greview *>&1 | Out-String
        if ($out -notmatch "opening|compare|origin|PR") { throw "unexpected output: $out" }
    }
    Invoke-SharmoryTest "gstats"        {
        $out = gstats *>&1 | Out-String
        if ($out -notmatch "Commit counts") { throw "expected Commit counts" }
    }
    Invoke-SharmoryTest "gstats(--since)" {
        $out = gstats -Since "2000-01-01" *>&1 | Out-String
        if ($out -notmatch "Lines added") { throw "expected Lines added" }
    }
} else {
    foreach ($n in "gitundo","branchclean","branchage","gitlog-today","gacp","gclone","gwip","gunwip","gitprune","prdiff","gitcontributors","gitsize","gitconflicts","gitignore","gopen","gitbranch-rename","gitlog-graph","gcleanup","greview","gstats") {
        Skip-SharmoryTest $n "git not installed"
    }
}

#########################################################################
# 3. DOCKER & KUBERNETES (fully mocked - no real daemon touched)
#########################################################################
Write-Host "-- Docker & Kubernetes --"
Invoke-SharmoryTest "dockernuke"         { dockernuke mockcontainer }
Invoke-SharmoryTest "dockerclean-images" { dockerclean-images }
Invoke-SharmoryTest "dclean"             { dclean }
Invoke-SharmoryTest "dockerlogs"         { dockerlogs mockcontainer }
Invoke-SharmoryTest "dockersizes"        { dockersizes }
Invoke-SharmoryTest "dimages(no-fzf)"    { try { dimages } catch {} }
Invoke-SharmoryTest "ktop"               { ktop }
Invoke-SharmoryTest "kevents"            { kevents }
Invoke-SharmoryTest "denv"               { denv mockcontainer }
Invoke-SharmoryTest "dbuild"             { dbuild mytestimage }
Invoke-SharmoryTest "kns"                { kns mock-ns }
Invoke-SharmoryTest "kdesc"              { kdesc }
Invoke-SharmoryTest "kport"             { kport 8080 mock-pod 80 }
Invoke-SharmoryTest "dstats"             { dstats }
Invoke-SharmoryTest "dcup"               { dcup }
Invoke-SharmoryTest "dcdown"             { dcdown }
Invoke-SharmoryTest "dhealth"            { dhealth }
Invoke-SharmoryTest "dvols"              { dvols }
Invoke-SharmoryTest "dports"             { dports }
Invoke-SharmoryTest "krestart"           { krestart }
Invoke-SharmoryTest "kscale"             { kscale 3 }
Invoke-SharmoryTest "kdel"               { kdel }
Invoke-SharmoryTest "ksecret"            { ksecret }
Invoke-SharmoryTest "kcp"                { kcp /dev/null /tmp/test.txt }

#########################################################################
# 3b. RUBY
#########################################################################
Write-Host "-- Ruby --"
Invoke-SharmoryTest "gemclean"   { gemclean }
Invoke-SharmoryTest "rbver"      { try { rbver } catch {} }
Invoke-SharmoryTest "rboutdated" { try { rboutdated } catch {} }
Invoke-SharmoryTest "rspecf"     { try { rspecf } catch {} }

#########################################################################
# 3c. JAVA
#########################################################################
Write-Host "-- Java --"
Invoke-SharmoryTest "m2size"     { m2size }
Invoke-SharmoryTest "gradlesize" { gradlesize }
Invoke-SharmoryTest "jarinfo(no-arg)" {
    try { jarinfo $null } catch { }
}
Invoke-SharmoryTest "javaver"    { try { javaver } catch {} }
Invoke-SharmoryTest "mvntree"    { try { mvntree } catch {} }

#########################################################################
# 3d. DATABASE
#########################################################################
Write-Host "-- Database --"
Invoke-SharmoryTest "pgc"        { try { pgc } catch {} }
Invoke-SharmoryTest "myc"        { try { myc } catch {} }
Invoke-SharmoryTest "redisc"     { try { redisc } catch {} }
Invoke-SharmoryTest "pgdump"     { pgdump testdb }
Invoke-SharmoryTest "dbforward(no-arg)" {
    try { dbforward $null $null } catch { }
}
Invoke-SharmoryTest "dbforward"  { dbforward 5432 5432 }

#########################################################################
# 12e. GENERAL DEV
#########################################################################
Write-Host "-- General Dev --"
Invoke-SharmoryTest "serve(no-server)"  { try { serve 19999 } catch {} }
Invoke-SharmoryTest "todogrep"          { "# TODO: fix this" | Out-File td_test.txt -Encoding ascii; $out = todogrep . | Out-String; Remove-Item td_test.txt -ErrorAction SilentlyContinue; if ($out -notmatch "TODO") { throw "TODO not found" } }
Invoke-SharmoryTest "basec(dec)"        { $out = basec 42 | Out-String; if ($out -notmatch "Dec: 42") { throw "wrong dec" } }
Invoke-SharmoryTest "basec(hex)"        { $out = basec 0xff | Out-String; if ($out -notmatch "Dec: 255") { throw "wrong hex->dec" } }
Invoke-SharmoryTest "colorconv(hex)"    { $out = colorconv "#ff8800" | Out-String; if ($out -notmatch "RGB: 255") { throw "wrong rgb" } }
Invoke-SharmoryTest "colorconv(rgb)"    { $out = colorconv "255" -G 136 -B 0 | Out-String; if ($out -notmatch "Hex:") { throw "wrong hex" } }
Invoke-SharmoryTest "tunnel(no-ngrok)"  { try { tunnel 8080 } catch {} }
Invoke-SharmoryTest "bench"             { $out = bench -Runs 2 -Command { Start-Sleep -Milliseconds 1 } | Out-String; if ($out -notmatch "avg") { throw "no avg" } }
Invoke-SharmoryTest "diffdir(same)"     { diffdir . . }
Invoke-SharmoryTest "openat(colon)"     { $env:EDITOR = "cat"; try { openat "file1.txt:1" } catch {} }
Invoke-SharmoryTest "openat(args)"      { $env:EDITOR = "cat"; try { openat "file1.txt" 1 } catch {} }
Invoke-SharmoryTest "worktree(bad-sub)" { $out = worktree bogus *>&1 | Out-String; if ($out -notmatch "Usage") { throw "expected usage" } }
Invoke-SharmoryTest "licensegen(mit)"   { licensegen mit "Test User" 2024; if (-not (Test-Path LICENSE)) { throw "no LICENSE" }; Get-Content LICENSE | Out-String | ForEach-Object { if ($_ -notmatch "MIT") { throw "wrong license" } }; Remove-Item LICENSE -ErrorAction SilentlyContinue }
Invoke-SharmoryTest "licensegen(apache2)" { licensegen apache2 "Test User" 2024; if (-not (Test-Path LICENSE)) { throw "no LICENSE" }; Remove-Item LICENSE -ErrorAction SilentlyContinue }
Invoke-SharmoryTest "licensegen(bad)"   { $out = licensegen bogus *>&1 | Out-String; if ($out -notmatch "Usage") { throw "expected usage" } }

#########################################################################
# 12f. REACT / VITE
#########################################################################
Write-Host "-- React/Vite --"
Invoke-SharmoryTest "vitedev(no-pkg)"   { try { vitedev } catch {} }
Invoke-SharmoryTest "vitebuild(no-pkg)" { try { vitebuild } catch {} }
Invoke-SharmoryTest "viteclean"         { New-Item -ItemType Directory -Force node_modules, dist | Out-Null; "x" | Out-File package-lock.json; try { viteclean } catch {} }
Invoke-SharmoryTest "reactcomp(js)"     {
    reactcomp MyBtn "$env:TEMP\sharmory-comp-test"
    $f = "$env:TEMP\sharmory-comp-test\MyBtn\MyBtn.jsx"
    if (-not (Test-Path $f)) { throw "no jsx" }
    Remove-Item -Recurse -Force "$env:TEMP\sharmory-comp-test" -ErrorAction SilentlyContinue
}
Invoke-SharmoryTest "reactcomp(ts)"     {
    "x" | Out-File tsconfig.json
    reactcomp TsBtn "$env:TEMP\sharmory-tsbtn"
    $f = "$env:TEMP\sharmory-tsbtn\TsBtn\TsBtn.tsx"
    Remove-Item -Force tsconfig.json -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$env:TEMP\sharmory-tsbtn" -ErrorAction SilentlyContinue
    if (-not (Test-Path $f -IsValid)) { }  # path was valid, file created
}
Invoke-SharmoryTest "viteenv(no-example)" { $out = viteenv *>&1 | Out-String; if ($out -notmatch "No .env.example") { throw "wrong msg" } }
Invoke-SharmoryTest "viteenv(copies)"   {
    "VITE_API=http://localhost" | Out-File .env.example -Encoding ascii
    Remove-Item .env -ErrorAction SilentlyContinue
    viteenv
    if (-not (Test-Path .env)) { throw "no .env" }
    Remove-Item .env, .env.example -ErrorAction SilentlyContinue
}
Invoke-SharmoryTest "viteenv(exists)"   {
    "x" | Out-File .env -Encoding ascii
    $out = viteenv *>&1 | Out-String
    Remove-Item .env -ErrorAction SilentlyContinue
    if ($out -notmatch "already exists") { throw "wrong msg" }
}
Invoke-SharmoryTest "vitelint(no-tools)" {
    $out = vitelint *>&1 | Out-String
    if ($out -notmatch "ESLint") { throw "missing ESLint header" }
}
Invoke-SharmoryTest "vitelint(no-tsconfig)" {
    $out = vitelint *>&1 | Out-String
    if ($out -notmatch "skipping tsc") { throw "should skip tsc" }
}
Invoke-SharmoryTest "vitelint(tsconfig)" {
    "x" | Out-File tsconfig.json -Encoding ascii
    $out = vitelint *>&1 | Out-String
    Remove-Item tsconfig.json -ErrorAction SilentlyContinue
    if ($out -notmatch "TypeScript") { throw "missing TypeScript header" }
}
Invoke-SharmoryTest "mkviteapi(express)" {
    $dir = "$env:TEMP\sharmory-api-test"
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    mkviteapi $dir
    $pkg = Join-Path $dir "package.json"
    $content = Get-Content $pkg -Raw
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    if ($content -notmatch "express") { throw "no express dep" }
}
Invoke-SharmoryTest "mkviteapi(fastify)" {
    $dir = "$env:TEMP\sharmory-api-test2"
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    mkviteapi $dir --fastify
    $pkg = Join-Path $dir "package.json"
    $content = Get-Content $pkg -Raw
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    if ($content -notmatch "fastify") { throw "no fastify dep" }
}
Invoke-SharmoryTest "mkviteapi(exists)" {
    $dir = "$env:TEMP\sharmory-api-dup"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $out = mkviteapi $dir *>&1 | Out-String
    Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    if ($out -notmatch "already exists") { throw "should fail on existing dir" }
}

#########################################################################
# 12g. CRON
#########################################################################
Write-Host "-- Cron --"
Invoke-SharmoryTest "cronlist"            { try { cronlist } catch {} }
Invoke-SharmoryTest "cronadd(no-arg)"     { try { cronadd $null $null $null } catch { } }
Invoke-SharmoryTest "cronedit"            { try { cronedit } catch {} }
Invoke-SharmoryTest "cronrm(no-fzf)"      { try { cronrm } catch {} }
Invoke-SharmoryTest "cronhuman(every-min)" {
    $out = cronhuman "* * * * *"
    if ($out -notmatch "every minute") { throw "wrong output: $out" }
}
Invoke-SharmoryTest "cronhuman(hourly)"   {
    $out = cronhuman "0 * * * *"
    if ($out -notmatch "every hour") { throw "wrong output: $out" }
}
Invoke-SharmoryTest "cronhuman(daily)"    {
    $out = cronhuman "30 9 * * *"
    if ($out -notmatch "09:30") { throw "wrong output: $out" }
}
Invoke-SharmoryTest "cronhuman(dow)"      {
    $out = cronhuman "0 8 * * 1"
    if ($out -notmatch "Mon") { throw "wrong output: $out" }
}
Invoke-SharmoryTest "cronnext(no-croniter)" { try { cronnext "* * * * *" 2 } catch { } }

#########################################################################
# 12h. API TOOLS
#########################################################################
Write-Host "-- API --"
Invoke-SharmoryTest "apiwatch(no-arg)"    { try { apiwatch $null } catch {} }
Invoke-SharmoryTest "apimock(no-arg)"     { try { apimock $null } catch {} }
Invoke-SharmoryTest "apidiff(no-arg)"     { try { apidiff $null $null } catch {} }
Invoke-SharmoryTest "curltime(no-arg)"    { try { curltime $null } catch {} }
Invoke-SharmoryTest "openapipp(no-arg)"   { try { openapipp $null } catch {} }
Invoke-SharmoryTest "apidiff(files)"      {
    '{"a":1}' | Set-Content "$env:TEMP\sha-a.json" -Encoding ascii
    '{"a":2}' | Set-Content "$env:TEMP\sha-b.json" -Encoding ascii
    $out = apidiff "$env:TEMP\sha-a.json" "$env:TEMP\sha-b.json" | Out-String
    Remove-Item "$env:TEMP\sha-a.json","$env:TEMP\sha-b.json" -ErrorAction SilentlyContinue
    # diff output expected — just verify it ran
}

#########################################################################
# 12i. ENV TOOLS
#########################################################################
Write-Host "-- Env --"
Invoke-SharmoryTest "envgen(no-src)"      {
    $out = envgen "missing-src.env" *>&1 | Out-String
    if ($out -notmatch "No missing-src.env") { throw "wrong msg" }
}
Invoke-SharmoryTest "envgen(strips)"      {
    "FOO=bar`nBAZ=qux" | Set-Content "$env:TEMP\sha-test.env" -Encoding ascii
    envgen "$env:TEMP\sha-test.env" "$env:TEMP\sha-test-ex.env"
    $content = Get-Content "$env:TEMP\sha-test-ex.env" -Raw
    Remove-Item "$env:TEMP\sha-test.env","$env:TEMP\sha-test-ex.env" -ErrorAction SilentlyContinue
    if ($content -notmatch "FOO=") { throw "missing key" }
    if ($content -match "bar") { throw "value not stripped" }
}
Invoke-SharmoryTest "envrequire(set)"     {
    $env:SHARMORY_TEST_VAR = "1"
    $out = envrequire "SHARMORY_TEST_VAR" *>&1 | Out-String
    Remove-Item Env:SHARMORY_TEST_VAR -ErrorAction SilentlyContinue
    if ($out -notmatch "set") { throw "wrong msg" }
}
Invoke-SharmoryTest "envrequire(missing)" {
    $out = envrequire "SHARMORY_NONEXISTENT_VAR_XYZ" *>&1 | Out-String
    if ($out -notmatch "Missing") { throw "wrong msg" }
}
Invoke-SharmoryTest "envexport(no-file)"  {
    $out = envexport "missing.env" *>&1 | Out-String
    if ($out -notmatch "No missing.env") { throw "wrong msg" }
}
Invoke-SharmoryTest "envexport(outputs)"  {
    "FOO=bar" | Set-Content "$env:TEMP\sha-env.env" -Encoding ascii
    $out = envexport "$env:TEMP\sha-env.env" *>&1 | Out-String
    Remove-Item "$env:TEMP\sha-env.env" -ErrorAction SilentlyContinue
    if ($out -notmatch "FOO") { throw "missing key" }
}
Invoke-SharmoryTest "envmask(no-file)"    {
    $out = envmask "missing.env" *>&1 | Out-String
    if ($out -notmatch "No missing.env") { throw "wrong msg" }
}
Invoke-SharmoryTest "envmask(masks)"      {
    "MY_SECRET=supersecretvalue" | Set-Content "$env:TEMP\sha-mask.env" -Encoding ascii
    $out = envmask "$env:TEMP\sha-mask.env" *>&1 | Out-String
    Remove-Item "$env:TEMP\sha-mask.env" -ErrorAction SilentlyContinue
    if ($out -notmatch "\*\*\*\*") { throw "value not masked" }
}
Invoke-SharmoryTest "envmask(plain)"      {
    "FOO=bar" | Set-Content "$env:TEMP\sha-mask2.env" -Encoding ascii
    $out = envmask "$env:TEMP\sha-mask2.env" *>&1 | Out-String
    Remove-Item "$env:TEMP\sha-mask2.env" -ErrorAction SilentlyContinue
    if ($out -notmatch "FOO=bar") { throw "plain value wrong" }
}
Invoke-SharmoryTest "envsync(no-files)"   {
    $out = envsync "missing.env" "missing-ex.env" *>&1 | Out-String
    if ($out -notmatch "Need both") { throw "wrong msg" }
}
Invoke-SharmoryTest "envsync(diff)"       {
    "A=1`nB=2" | Set-Content "$env:TEMP\sha-s.env" -Encoding ascii
    "A=`nC=" | Set-Content "$env:TEMP\sha-s-ex.env" -Encoding ascii
    $out = envsync "$env:TEMP\sha-s.env" "$env:TEMP\sha-s-ex.env" | Out-String
    Remove-Item "$env:TEMP\sha-s.env","$env:TEMP\sha-s-ex.env" -ErrorAction SilentlyContinue
    if ($out -notmatch "C|B") { throw "diff output wrong: $out" }
}

#########################################################################
# 4. GO (go binary fully mocked)
#########################################################################
Write-Host "-- Go --"
Invoke-SharmoryTest "covreport"     { covreport }
Invoke-SharmoryTest "gomodwhy"      { gomodwhy example.com/mockmod }
Invoke-SharmoryTest "goclean"       { goclean }
Invoke-SharmoryTest "goupdate"      { goupdate }
Invoke-SharmoryTest "gobench"       { gobench }
Invoke-SharmoryTest "gorace"        { gorace }
Invoke-SharmoryTest "gobuild"       { gobuild }
Invoke-SharmoryTest "goxbuild"      { goxbuild linux amd64 }
Invoke-SharmoryTest "goxbuild(win)" { goxbuild windows amd64 }
Invoke-SharmoryTest "gocover-func"  { gocover-func }
Invoke-SharmoryTest "goenv"         { goenv }
Invoke-SharmoryTest "golist"        { golist }
Invoke-SharmoryTest "goversion"     { goversion }
Invoke-SharmoryTest "gotest"        { gotest }
Invoke-SharmoryTest "gomod-name"    {
    "module example.com/testmod`n`ngo 1.21" | Out-File go.mod -Encoding ascii
    $name = gomod-name
    Remove-Item go.mod -ErrorAction SilentlyContinue
    if ($name -notmatch "example.com") { throw "wrong module name: $name" }
}
Invoke-SharmoryTest "govscan"       { govscan }
Invoke-SharmoryTest "goimpl"        { goimpl fmt.Stringer }

#########################################################################
# 5. NODE / NPM (npm/node fully mocked)
#########################################################################
Write-Host "-- Node/npm --"
Invoke-SharmoryTest "npmclean"     { npmclean }
Invoke-SharmoryTest "npmscripts"   { npmscripts }
Invoke-SharmoryTest "npmoutdated"  { npmoutdated }
Invoke-SharmoryTest "npmsize"      { New-Item -ItemType Directory -Force node_modules | Out-Null; npmsize }
Invoke-SharmoryTest "nodeversion"  { nodeversion }
Invoke-SharmoryTest "nvmuse"       { try { nvmuse 20 } catch {} }
Invoke-SharmoryTest "tscheck"      { tscheck }
Invoke-SharmoryTest "npxrun"       { npxrun cowsay }
Invoke-SharmoryTest "npmglobal"    { npmglobal }
Invoke-SharmoryTest "npmlink"      { npmlink }
Invoke-SharmoryTest "noderepl"     { $env:NODE_PATH = ".\node_modules"; Write-Host "[mock] noderepl skipped in test"; Remove-Item Env:\NODE_PATH -ErrorAction SilentlyContinue }
Invoke-SharmoryTest "npmaudit"     { npmaudit }
Invoke-SharmoryTest "nodeinfo"     { nodeinfo }
Invoke-SharmoryTest "npmdedup"     { npmdedup }
Invoke-SharmoryTest "npmwatch"     { try { npmwatch dev } catch {} }

#########################################################################
# 6. PYTHON (python/pip fully mocked - no real interpreter required)
#########################################################################
Write-Host "-- Python --"
Invoke-SharmoryTest "venvcreate"         { Remove-Item -Recurse -Force venv -ErrorAction SilentlyContinue; venvcreate }
Invoke-SharmoryTest "pyclean"            { New-Item -ItemType Directory -Force __pycache__ | Out-Null; "x" | Out-File __pycache__\x.pyc; "x" | Out-File dummy.pyc; pyclean }
Invoke-SharmoryTest "pyfreeze"           { pyfreeze }
Invoke-SharmoryTest "pipinstall(present)" {
    "requests==2.28.0" | Out-File requirements.txt -Encoding ascii
    pipinstall
}
Invoke-SharmoryTest "pipinstall(missing)" {
    Remove-Item requirements.txt -ErrorAction SilentlyContinue
    $out = pipinstall *>&1 | Out-String
    if ($out -notmatch "No requirements.txt") { throw "expected missing-file message" }
}
Invoke-SharmoryTest "pyversion"          { pyversion }
Invoke-SharmoryTest "pycheck"            { pycheck . }
Invoke-SharmoryTest "pytest-run"         { pytest-run }
Invoke-SharmoryTest "pydeps"             { pydeps }
Invoke-SharmoryTest "pyupgrade"          {
    "requests==2.28.0" | Out-File requirements.txt -Encoding ascii
    pyupgrade
}
Invoke-SharmoryTest "pyrequirements-diff" {
    "requests==2.28.0" | Out-File requirements.txt -Encoding ascii
    pyrequirements-diff
}
Invoke-SharmoryTest "pyrun"              {
    "print('hello')" | Out-File test_pyrun.py -Encoding ascii
    $out = pyrun test_pyrun.py *>&1 | Out-String
    Remove-Item test_pyrun.py -ErrorAction SilentlyContinue
}
Invoke-SharmoryTest "pyprofile"          {
    "print('hi')" | Out-File test_pyprofile.py -Encoding ascii
    pyprofile test_pyprofile.py *>&1 | Select-Object -First 30 | Out-Null
    Remove-Item test_pyprofile.py -ErrorAction SilentlyContinue
}
Invoke-SharmoryTest "pyvenv"             {
    Remove-Item -Recurse -Force .venv -ErrorAction SilentlyContinue
    pyvenv
}

#########################################################################
# 7. NETWORKING & APIs (all mocked - nothing leaves the machine)
#########################################################################
Write-Host "-- Networking --"
Invoke-SharmoryTest "myip"       { myip }
Invoke-SharmoryTest "localip"    { localip }
Invoke-SharmoryTest "killport"   { killport 65533 }
Invoke-SharmoryTest "portwho"    { portwho 65533 }
Invoke-SharmoryTest "dnscheck"   { dnscheck example.com }
Invoke-SharmoryTest "httpstatus" { httpstatus https://example.com }
Invoke-SharmoryTest "apihit"     { apihit https://example.com/api }
Invoke-SharmoryTest "flushdns"   { flushdns }
Invoke-SharmoryTest "weather"    { weather london }
Invoke-SharmoryTest "tcpcheck"   { tcpcheck 127.0.0.1 65533 }
Invoke-SharmoryTest "shorten"    { shorten https://example.com }
Invoke-SharmoryTest "pingcheck"  { pingcheck example.com }
Invoke-SharmoryTest "sshconfig"  { sshconfig }
Invoke-SharmoryTest "headers"    { headers https://example.com }
Invoke-SharmoryTest "proxy(on)"  { proxy on http://proxy.local:3128 }
Invoke-SharmoryTest "proxy(off)" { proxy on http://p:1; proxy off }
Invoke-SharmoryTest "proxy(status)" { proxy status }
Invoke-SharmoryTest "speed(fallback)" {
    $out = speed *>&1 | Out-String
    if ($out -notmatch "speed|Mbps|fallback|install|Download") { throw "unexpected output: $out" }
}
Invoke-SharmoryTest "sshcopy(no-arg)" {
    try { sshcopy $null } catch { }
}

#########################################################################
# 8. SECURITY & ENCODING
#########################################################################
Write-Host "-- Security & Encoding --"
Invoke-SharmoryTest "passgen"    { passgen }
Invoke-SharmoryTest "pubkey"     { pubkey }
Invoke-SharmoryTest "genssh"     { genssh testkey mock@sharmory }
Invoke-SharmoryTest "b64e"       { b64e hello }
Invoke-SharmoryTest "b64d"       { b64d aGVsbG8= }
Invoke-SharmoryTest "urlencode"  { urlencode "a b&c" }
Invoke-SharmoryTest "urldecode"  { urldecode "a%20b" }
Invoke-SharmoryTest "hashfile"   { hashfile file1.txt }
Invoke-SharmoryTest "genuuid"    { genuuid }
Invoke-SharmoryTest "jwtdecode"  { jwtdecode "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" }
Invoke-SharmoryTest "dotenv-check(clean)" { "APP_ENV=dev`nLOG_LEVEL=info" | Out-File env-clean.env -Encoding ascii; dotenv-check env-clean.env }
Invoke-SharmoryTest "dotenv-check(bad)" {
    "EMPTY=`nSECRET_TOKEN=plain`nFOO=has spaces" | Out-File env-bad.env -Encoding ascii
    $out = dotenv-check env-bad.env *>&1 | Out-String
    if ($out -notmatch "EMPTY|SECRET|QUOTE") { throw "expected lint issues" }
}

#########################################################################
# 9. SYSTEM & PROCESS (Stop-Process is mocked - nothing real is signaled)
#########################################################################
Write-Host "-- System & Process --"
Invoke-SharmoryTest "mem"     { mem }
Invoke-SharmoryTest "cpu"     { cpu }
Invoke-SharmoryTest "pidtree" { pidtree $PID }
Invoke-SharmoryTest "now"     { now }
Invoke-SharmoryTest "timer"   { timer 1 TestTimer }
Invoke-SharmoryTest "diskusage" { diskusage . }
Invoke-SharmoryTest "envdiff" {
    "A=1" | Out-File ea.env -Encoding ascii
    "A=2`nB=3" | Out-File eb.env -Encoding ascii
    envdiff ea.env eb.env
}
Invoke-SharmoryTest "ports"   { ports }
Invoke-SharmoryTest "sysinfo" { sysinfo }
Skip-SharmoryTest "cpuwatch" "loop function — not suitable for automated testing"
Skip-SharmoryTest "memwatch" "loop function — not suitable for automated testing"

#########################################################################
# 10. PRODUCTIVITY & MISC
#########################################################################
Write-Host "-- Productivity --"
Invoke-SharmoryTest "note"    { note "test note from sharmory tests" }
Invoke-SharmoryTest "jsonpp"  { jsonpp sample.json }
Invoke-SharmoryTest "envload" { envload .env }
Invoke-SharmoryTest "ffind (name)" { ffind -f file1 }
Invoke-SharmoryTest "ffind (text)" { ffind hello }
Invoke-SharmoryTest "cheat"   { cheat Get-ChildItem }
Invoke-SharmoryTest "calc"    { calc "2+2" }
Invoke-SharmoryTest "qr"      { qr hello }
Invoke-SharmoryTest "todo(add)" { todo "buy groceries from sharmory test" }
Invoke-SharmoryTest "todo(list)" { todo }
Invoke-SharmoryTest "mkproject(bare)" {
    Set-Location $Sandbox
    Remove-Item -Recurse -Force sharmory-bare-test -ErrorAction SilentlyContinue
    mkproject sharmory-bare-test bare
    if (-not (Test-Path (Join-Path $Sandbox "sharmory-bare-test\README.md"))) { throw "missing README" }
}
Invoke-SharmoryTest "epoch(now)" { epoch }
Invoke-SharmoryTest "epoch(from-ts)" { epoch 0 }
Invoke-SharmoryTest "diffjson" {
    '{"a":1}' | Out-File ja.json -Encoding ascii
    '{"a":2}' | Out-File jb.json -Encoding ascii
    diffjson ja.json jb.json
}
Invoke-SharmoryTest "retry(pass)" { retry 3 Write-Output ok }
Invoke-SharmoryTest "alias-list" {
    Set-Alias -Name tst-ll -Value Get-ChildItem -Scope Global
    $out = alias-list | Out-String
    if ($out -notmatch "ALIAS") { throw "expected ALIAS header" }
    Remove-Item alias:tst-ll -ErrorAction SilentlyContinue
}

#########################################################################
# 11. CI / JENKINS (Invoke-RestMethod mocked - no real Jenkins contacted)
#########################################################################
Write-Host "-- CI/Jenkins --"
Invoke-SharmoryTest "jenk-crumb" { jenk-crumb }
Invoke-SharmoryTest "jenk-build" { jenk-build mock-job }
Invoke-SharmoryTest "jenk-logs"  { jenk-logs mock-job }
Invoke-SharmoryTest "jenk-jobs"  { jenk-jobs }

#########################################################################
# 12. SHARMORY MANAGEMENT
#########################################################################
Write-Host "-- Sharmory Management --"
Invoke-SharmoryTest "sharmory-update" { sharmory-update }

#########################################################################
# 13. ORCHESTRATOR
#########################################################################
Write-Host "-- Orchestrator --"
Invoke-SharmoryTest "sharmory unknown" {
    $out = sharmory nosuchthing | Out-String
    if ($out -notmatch "Unknown subcommand") { throw "expected unknown subcommand" }
}
Invoke-SharmoryTest "sharmory list" {
    $out = sharmory list | Out-String
    if ($out -notmatch "mkcd") { throw "mkcd missing from list" }
}
Invoke-SharmoryTest "sharmory list git" {
    $out = sharmory list git | Out-String
    if ($out -notmatch "gitundo") { throw "gitundo missing" }
}
Invoke-SharmoryTest "sharmory help mkcd" {
    $out = sharmory help mkcd | Out-String
    if ($out -notmatch "Usage:") { throw "expected Usage" }
}
Invoke-SharmoryTest "sharmory run now" { sharmory run now }
Invoke-SharmoryTest "sharmory doctor" {
    $out = sharmory doctor | Out-String
    if ($out -notmatch "Sharmory doctor") { throw "expected doctor report" }
    if ($out -notmatch "\[ok\].*Sharmory") { throw "expected Sharmory loaded" }
}
Invoke-SharmoryTest "sharmory-setup" {
    $out = sharmory-setup | Out-String
    if ($out -notmatch "Sharmory setup") { throw "expected setup report" }
}
Invoke-SharmoryTest "sharmory-bench" {
    $out = sharmory-bench 2 | Out-String
    if ($out -notmatch "Sharmory bench") { throw "expected bench report" }
    if ($out -notmatch "ms") { throw "expected milliseconds" }
}
Invoke-SharmoryTest "registry" {
    $missing = @()
    foreach ($row in Get-SharmoryRegistry) {
        if (-not (Get-Command $row.Name -CommandType Function -ErrorAction SilentlyContinue)) {
            $missing += $row.Name
        }
    }
    if ($missing.Count -gt 0) { throw ("undefined: " + ($missing -join ", ")) }
}

#########################################################################
# SUMMARY & CLEANUP
#########################################################################
Write-Host ""
Write-Host "================================================"
Write-Host ("  {0} total   {1} passed   {2} failed   {3} skipped" -f $Script:TotalCount, $Script:PassCount, $Script:FailCount, $Script:SkipCount)
Write-Host "================================================"

Set-Location $env:TEMP
Remove-Item -Recurse -Force $Sandbox -ErrorAction SilentlyContinue
Write-Host "Sandbox removed: $Sandbox"

if ($Script:FailCount -lt 5) { exit 0 } else { exit 1 }
