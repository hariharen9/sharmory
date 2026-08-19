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

. $FunctionsPath

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
        default                { Write-Host "[mock] kubectl $s" }
    }
}

# --- go / npm / pip: no-op, always succeed ---
function go  { Write-Host "[mock] go $args" }
function npm { Write-Host "[mock] npm $args" }
function pip {
    if ($args -contains "freeze") { "mockpkg==1.0" } else { Write-Host "[mock] pip $args" }
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
} else {
    foreach ($n in "gitundo","branchclean","branchage","gitlog-today","gacp","gclone","gwip","gunwip","gitprune","prdiff","gitcontributors","gitsize","gitconflicts","gitignore","gopen","gitbranch-rename","gitlog-graph","gcleanup") {
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
Invoke-SharmoryTest "ktop"               { ktop }
Invoke-SharmoryTest "kevents"            { kevents }
Invoke-SharmoryTest "denv"               { denv mockcontainer }
Invoke-SharmoryTest "dbuild"             { dbuild mytestimage }
Invoke-SharmoryTest "kns"                { kns mock-ns }
Invoke-SharmoryTest "kdesc"              { kdesc }
Invoke-SharmoryTest "kport"              { kport 8080 mock-pod 80 }

#########################################################################
# 4. GO (go binary fully mocked)
#########################################################################
Write-Host "-- Go --"
Invoke-SharmoryTest "covreport" { covreport }
Invoke-SharmoryTest "gomodwhy"  { gomodwhy example.com/mockmod }
Invoke-SharmoryTest "goclean"   { goclean }
Invoke-SharmoryTest "goupdate"  { goupdate }
Invoke-SharmoryTest "gobench"   { gobench }

#########################################################################
# 5. NODE / NPM (npm binary fully mocked)
#########################################################################
Write-Host "-- Node/npm --"
Invoke-SharmoryTest "npmclean"    { npmclean }
Invoke-SharmoryTest "npmscripts"  { npmscripts }
Invoke-SharmoryTest "npmoutdated" { npmoutdated }
Invoke-SharmoryTest "npmsize"     { New-Item -ItemType Directory -Force node_modules | Out-Null; npmsize }

#########################################################################
# 6. PYTHON (python/pip fully mocked - no real interpreter required)
#########################################################################
Write-Host "-- Python --"
Invoke-SharmoryTest "venvcreate" { Remove-Item -Recurse -Force venv -ErrorAction SilentlyContinue; venvcreate }
Invoke-SharmoryTest "pyclean"    { New-Item -ItemType Directory -Force __pycache__ | Out-Null; "x" | Out-File __pycache__\x.pyc; "x" | Out-File dummy.pyc; pyclean }
Invoke-SharmoryTest "pyfreeze"   { pyfreeze }

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

if ($Script:FailCount -eq 0) { exit 0 } else { exit 1 }
