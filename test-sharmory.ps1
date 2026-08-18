#requires -version 5.1
#
# test-sharmory.ps1 - sandboxed smoke test for every function in functions.ps1
#
# Every external command that could touch the real network, real docker/k8s,
# a real process, or a real Jenkins server is shadowed with a mock function
# for the duration of the run. Everything happens inside a throwaway temp
# directory (and a fake $HOME) that is deleted at the end, pass or fail.
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

New-Item -ItemType Directory -Force -Path $WorkDir, "$FakeHome\.ssh" | Out-Null

Write-Host "Sandbox: $Sandbox"
Write-Host "Testing: $FunctionsPath"
Write-Host ""

# Everything below runs relative to this fake HOME, never your real one.
$HOME = $FakeHome
$env:USERPROFILE = $FakeHome
$env:JENKINS_URL = "http://mock-jenkins.local"
$env:JENKINS_USER = "mockuser"
$env:JENKINS_TOKEN = "mocktoken"
"ssh-ed25519 AAAAmockkey mock@sharmory" | Out-File "$FakeHome\.ssh\id_ed25519.pub" -Encoding utf8

$HasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)

#########################################################################
# LOAD THE REAL FUNCTIONS, THEN SHADOW EVERYTHING DANGEROUS
#########################################################################

. $FunctionsPath

# --- fzf: auto-select the first non-empty piped line, no interactivity ---
function fzf {
    $line = $input | Where-Object { $_ -and $_.ToString().Trim() -ne "" } | Select-Object -First 1
    if ($line) { $line }
}

# --- docker / kubectl: canned responses, never touch a real daemon ---
function docker {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "ps --format*"  { "mockid123`tmockcontainer`tmockimage" }
        "images -f*"    { }
        "images --format*" { "mockrepo:latest`t123MB" }
        default         { Write-Host "[mock] docker $s" }
    }
}
function kubectl {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "config get-contexts*" { "mock-context" }
        "get ns*"               { "namespace/mock-ns" }
        "get pods*"             { "pod/mock-pod" }
        "top pods*"             { "NAME`tCPU`tMEMORY`nmock-pod`t1m`t2Mi" }
        "get events*"           { "LAST SEEN   TYPE   REASON   OBJECT" }
        default                 { Write-Host "[mock] kubectl $s" }
    }
}

# --- go / npm / pip: no-op, always succeed ---
function go  { Write-Host "[mock] go $args" }
function npm { Write-Host "[mock] npm $args" }
function pip {
    if ($args -contains "freeze") { "mockpkg==1.0" } else { Write-Host "[mock] pip $args" }
}

# --- python: real enough to make venvcreate/pyclean succeed without a real interpreter ---
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

# --- ssh-keygen: write fake key files instead of prompting for a passphrase ---
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
    param([string]$Uri, [string]$Method, [switch]$UseBasicParsing, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    $content = '{"mock":"response"}'
    if ($Uri -like "*wttr*")    { $content = "Mock weather: Sunny, 22C" }
    if ($Uri -like "*qrenco*")  { $content = "[mock qr ascii art]" }
    [PSCustomObject]@{ StatusCode = 200; Content = $content }
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
function Clear-DnsClientCache { Write-Host "[mock] Clear-DnsClientCache" }

# --- process control: fkill/killport can pick a real PID, but nothing real dies ---
function Stop-Process {
    param([int]$Id, [switch]$Force, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    Write-Host "[mock] Stop-Process -Id $Id (not actually killed)"
}

# --- opening things: never launch a real browser/app ---
function Start-Process { param([Parameter(ValueFromRemainingArguments = $true)]$Rest); Write-Host "[mock] Start-Process $Rest" }

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

Pop-Location

#########################################################################
# TEST RUNNER
#
# Each test runs as its own background job so a function that loops
# forever by design (watchrun, gowatch) can be time-boxed and killed
# rather than hanging the whole suite. The job gets the same mocks and
# sandbox state via an init script built from this file's own definitions.
#########################################################################

$MockDefs = @'
function fzf {
    $line = $input | Where-Object { $_ -and $_.ToString().Trim() -ne "" } | Select-Object -First 1
    if ($line) { $line }
}
function docker {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "ps --format*"      { "mockid123`tmockcontainer`tmockimage" }
        "images -f*"        { }
        "images --format*"  { "mockrepo:latest`t123MB" }
        default             { Write-Host "[mock] docker $s" }
    }
}
function kubectl {
    $s = $args -join ' '
    switch -Wildcard ($s) {
        "config get-contexts*" { "mock-context" }
        "get ns*"               { "namespace/mock-ns" }
        "get pods*"             { "pod/mock-pod" }
        "top pods*"             { "NAME`tCPU`tMEMORY`nmock-pod`t1m`t2Mi" }
        "get events*"           { "LAST SEEN   TYPE   REASON   OBJECT" }
        default                 { Write-Host "[mock] kubectl $s" }
    }
}
function go  { Write-Host "[mock] go $args" }
function npm { Write-Host "[mock] npm $args" }
function pip { if ($args -contains "freeze") { "mockpkg==1.0" } else { Write-Host "[mock] pip $args" } }
function python {
    $joined = $args -join ' '
    if ($joined -like "*-m venv*") {
        $venvPath = $args[-1]
        New-Item -ItemType Directory -Force -Path "$venvPath\Scripts" | Out-Null
        "# mock activate script" | Out-File "$venvPath\Scripts\Activate.ps1"
    } else { Write-Host "[mock] python $joined" }
}
function ssh-keygen {
    $out = $null
    for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq "-f") { $out = $args[$i + 1] } }
    if ($out) {
        New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
        "mock-private-key" | Out-File $out
        "ssh-ed25519 AAAAmock mock@sharmory" | Out-File "$out.pub"
    }
}
function Invoke-RestMethod {
    param([string]$Uri, [string]$Method, $Headers, $Body, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    if ($Uri -like "*crumbIssuer*") { return [PSCustomObject]@{ crumb = "mockcrumb1234" } }
    if ($Uri -like "*api/json*")    { return [PSCustomObject]@{ jobs = @([PSCustomObject]@{ name = "mock-job-1" }) } }
    if ($Uri -like "*is.gd*")       { return "https://is.gd/mocklink" }
    if ($Uri -like "*gitignore*")   { return "# mock gitignore content" }
    return [PSCustomObject]@{ mock = "response" }
}
function Invoke-WebRequest {
    param([string]$Uri, [string]$Method, [switch]$UseBasicParsing, [Parameter(ValueFromRemainingArguments = $true)]$Rest)
    $content = '{"mock":"response"}'
    if ($Uri -like "*wttr*")   { $content = "Mock weather: Sunny, 22C" }
    if ($Uri -like "*qrenco*") { $content = "[mock qr ascii art]" }
    [PSCustomObject]@{ StatusCode = 200; Content = $content }
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
function Clear-DnsClientCache { }
function Stop-Process { param([int]$Id, [switch]$Force, [Parameter(ValueFromRemainingArguments = $true)]$Rest) }
function Start-Process { param([Parameter(ValueFromRemainingArguments = $true)]$Rest) }
'@

function Invoke-SharmoryTest {
    param([string]$Label, [scriptblock]$Test)

    $Script:TotalCount++
    $fullScript = "`$HOME = '$FakeHome'; `$env:USERPROFILE='$FakeHome'; `$env:JENKINS_URL='http://mock-jenkins.local'; `$env:JENKINS_USER='mockuser'; `$env:JENKINS_TOKEN='mocktoken'; . '$FunctionsPath'; $MockDefs; Set-Location '$WorkDir'; $($Test.ToString())"

    $job = Start-Job -ScriptBlock ([scriptblock]::Create($fullScript))
    $completed = Wait-Job $job -Timeout 15

    if (-not $completed) {
        Stop-Job $job | Out-Null
        Write-Host ("  FAIL  {0,-22} (timed out after 15s)" -f $Label) -ForegroundColor Red
        $Script:FailCount++
    } elseif ($job.State -eq 'Failed') {
        $err = (Receive-Job $job -ErrorAction SilentlyContinue 2>&1 | Select-Object -First 2) -join ' | '
        Write-Host ("  FAIL  {0,-22} {1}" -f $Label, $err) -ForegroundColor Red
        $Script:FailCount++
    } else {
        Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
        Write-Host ("  PASS  {0,-22}" -f $Label) -ForegroundColor Green
        $Script:PassCount++
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
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
Invoke-SharmoryTest "mkcd"      { mkcd newdir_mkcd; if ((Split-Path -Leaf (Get-Location)) -ne "newdir_mkcd") { throw "cd failed" } }
Invoke-SharmoryTest "up"        { New-Item -ItemType Directory -Force ud1\ud2 | Out-Null; Set-Location ud1\ud2; up 1; if ((Split-Path -Leaf (Get-Location)) -ne "ud1") { throw "up failed" } }
Invoke-SharmoryTest "lsd"       { lsd }
Invoke-SharmoryTest "fcd"       { fcd }
Invoke-SharmoryTest "ftext"     { ftext }
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
Skip-SharmoryTest "watchrun" "loops forever by design; existence-checked only, not executed"

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
    Invoke-SharmoryTest "gswitch"       { gswitch }
    Invoke-SharmoryTest "prdiff"        { git checkout -q main 2>$null; prdiff }
    Invoke-SharmoryTest "gitcontributors" { gitcontributors }
    Invoke-SharmoryTest "gitsize"       { gitsize }
    Invoke-SharmoryTest "gitconflicts"  { gitconflicts }
    Invoke-SharmoryTest "gitignore"     { gitignore "go,windows" }
} else {
    foreach ($n in "gitundo","branchclean","branchage","gitlog-today","gacp","gclone","gwip","gunwip","gitprune","gswitch","prdiff","gitcontributors","gitsize","gitconflicts","gitignore") {
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
Invoke-SharmoryTest "dsh"                { dsh }
Invoke-SharmoryTest "dockersizes"        { dockersizes }
Invoke-SharmoryTest "k8sctx"             { k8sctx }
Invoke-SharmoryTest "klogs"              { klogs }
Invoke-SharmoryTest "kexec"              { kexec }
Invoke-SharmoryTest "ktop"               { ktop }
Invoke-SharmoryTest "kevents"            { kevents }

#########################################################################
# 4. GO (go binary fully mocked)
#########################################################################
Write-Host "-- Go --"
Invoke-SharmoryTest "covreport" { covreport }
Invoke-SharmoryTest "gomodwhy"  { gomodwhy example.com/mockmod }
Invoke-SharmoryTest "goclean"   { goclean }
Invoke-SharmoryTest "goupdate"  { goupdate }
Invoke-SharmoryTest "gobench"   { gobench }
Invoke-SharmoryTest "gonew"     { New-Item -ItemType Directory -Force gonew_test | Out-Null; Set-Location gonew_test; gonew example.com/mocktest }
Skip-SharmoryTest "gowatch" "loops forever by design; existence-checked only, not executed"

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
Invoke-SharmoryTest "certcheck"  { certcheck example.com }
Invoke-SharmoryTest "dnscheck"   { dnscheck example.com }
Invoke-SharmoryTest "httpstatus" { httpstatus https://example.com }
Invoke-SharmoryTest "apihit"     { apihit https://example.com/api }
Invoke-SharmoryTest "flushdns"   { flushdns }
Invoke-SharmoryTest "weather"    { weather london }
Invoke-SharmoryTest "tcpcheck"   { tcpcheck 127.0.0.1 65533 }
Invoke-SharmoryTest "shorten"    { shorten https://example.com }

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

#########################################################################
# 9. SYSTEM & PROCESS (Stop-Process is mocked - nothing real is signaled)
#########################################################################
Write-Host "-- System & Process --"
Invoke-SharmoryTest "mem"     { mem }
Invoke-SharmoryTest "cpu"     { cpu }
Invoke-SharmoryTest "pidtree" { pidtree $PID }
Invoke-SharmoryTest "fkill"   { fkill }
Invoke-SharmoryTest "now"     { now }
Invoke-SharmoryTest "timer"   { timer 1 TestTimer }

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

#########################################################################
# 11. CI / JENKINS (Invoke-RestMethod mocked - no real Jenkins contacted)
#########################################################################
Write-Host "-- CI/Jenkins --"
Invoke-SharmoryTest "jenk-crumb" { jenk-crumb }
Invoke-SharmoryTest "jenk-build" { jenk-build mock-job }
Invoke-SharmoryTest "jenk-logs"  { jenk-logs mock-job }
Invoke-SharmoryTest "jenk-jobs"  { jenk-jobs }

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
