#requires -version 5.1
#
# Sharmory for PowerShell — dev-focused functions for your $PROFILE
#
# Add this to your $PROFILE (find its path with: echo $PROFILE):
#   . "$HOME\sharmory\functions.ps1"
#
# Optional tools used if present (all degrade gracefully):
#   git, docker, kubectl, go, node, python, eza, tldr
#
#########################################################################
# 0. INTERNAL HELPERS
#########################################################################

function Test-SharmoryDependency {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "[!] '$Name' is required for this command. Install it and try again." -ForegroundColor Yellow
        return $false
    }
    return $true
}

#########################################################################
# 1. NAVIGATION & FILES
#########################################################################

# Make a directory and cd into it in one step
# Usage: mkcd <dir>
function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Set-Location $Path
}

# Go up N directory levels (default 1)
# Usage: up [n]
function up {
    param([int]$Levels = 1)
    for ($i = 0; $i -lt $Levels; $i++) { Set-Location .. }
}

# Directory listing with icons/color/sort via eza if installed, else a clean Get-ChildItem view
function lsd {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        eza --icons --group-directories-first --long --header --git --time-style=long-iso --sort=modified --reverse --color=always @args
    } else {
        Get-ChildItem @args | Sort-Object LastWriteTime -Descending |
            Format-Table Mode, LastWriteTime, Length, Name -AutoSize
    }
}

# Show a file's Windows permissions (ACL) in a readable form
# Usage: permsof <file>
function permsof {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path"
        return
    }
    $acl = Get-Acl $Path
    Write-Host "[File] $Path"
    Write-Host "   Owner: $($acl.Owner)"
    Write-Host ""
    foreach ($access in $acl.Access) {
        Write-Host ("   {0,-30} {1}" -f $access.IdentityReference, $access.FileSystemRights)
    }
}

# Extract common archive formats based on file extension
# Usage: extract <archive-file>
function extract {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path"
        return
    }
    switch -Wildcard ($Path) {
        "*.zip"    { Expand-Archive -Path $Path -DestinationPath . -Force }
        "*.tar.gz" { tar xzf $Path }
        "*.tgz"    { tar xzf $Path }
        "*.tar"    { tar xf $Path }
        "*.7z"     { if (Test-SharmoryDependency 7z) { 7z x $Path } }
        "*.rar"    { if (Test-SharmoryDependency unrar) { unrar x $Path } }
        default    { Write-Host "Unknown archive type." }
    }
}

# Compress a file or directory into a .zip
# Usage: compress <output.zip> <file-or-dir>
function compress {
    param(
        [Parameter(Mandatory)][string]$Output,
        [Parameter(Mandatory)][string]$Source
    )
    Compress-Archive -Path $Source -DestinationPath $Output -Force
}

# Show sizes of items in the current directory, sorted largest first
function duh {
    Get-ChildItem | ForEach-Object {
        $size = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        } else { $_.Length }
        [PSCustomObject]@{ Name = $_.Name; SizeMB = [math]::Round(($size / 1MB), 2) }
    } | Sort-Object SizeMB -Descending | Format-Table -AutoSize
}

# Show sizes of subdirectories in a path, sorted largest first
# Usage: sizeof [path]
function sizeof {
    param([string]$Path = ".")
    Get-ChildItem $Path -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{ Name = $_.Name; SizeMB = [math]::Round(($size / 1MB), 2) }
    } | Sort-Object SizeMB -Descending | Format-Table -AutoSize
}

# Find files above a given size (in MB, default 100) under a directory
# Usage: findbig [sizeMB] [dir]
function findbig {
    param([int]$SizeMB = 100, [string]$Path = ".")
    Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt ($SizeMB * 1MB) } |
        Sort-Object Length -Descending |
        Select-Object FullName, @{N = "SizeMB"; E = { [math]::Round($_.Length / 1MB, 2) } } |
        Format-Table -AutoSize
}

# Find and optionally remove empty directories under a path
# Usage: emptydirs [dir]
function emptydirs {
    param([string]$Path = ".")
    $found = Get-ChildItem $Path -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { (Get-ChildItem $_.FullName -Force | Measure-Object).Count -eq 0 }
    if (-not $found) {
        Write-Host "No empty directories found."
        return
    }
    $found | Select-Object -ExpandProperty FullName
    $confirm = Read-Host "Delete these empty directories? (y/N)"
    if ($confirm -eq "y") { $found | Remove-Item -Force }
}

# Find duplicate files (by SHA256 hash) within a directory
# Usage: dupfind [dir]
function dupfind {
    param([string]$Path = ".")
    Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
        Get-FileHash -Algorithm SHA256 |
        Group-Object Hash |
        Where-Object Count -gt 1 |
        ForEach-Object {
            Write-Host "---"
            $_.Group.Path | ForEach-Object { Write-Host $_ }
        }
}

# Create a timestamped backup copy of a file
# Usage: bak <file>
function bak {
    param([Parameter(Mandatory)][string]$Path)
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item $Path "$Path.$stamp.bak"
}

# Copy the current working directory path to the clipboard
function cwd {
    (Get-Location).Path | Set-Clipboard
    (Get-Location).Path
    Write-Host "Copied."
}

# Copy a file's contents to the clipboard
# Usage: clipcopy <file>
function clipcopy {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path"
        return
    }
    Get-Content $Path -Raw | Set-Clipboard
    Write-Host "Copied contents of $Path"
}

#########################################################################
# 2. GIT
#########################################################################

# Undo the last git commit but keep the changes staged
function gitundo {
    git reset --soft HEAD~1
    Write-Host "Last commit undone. Changes are staged."
    git status --short
}

# Find local branches already merged into main/master and offer to delete them
function branchclean {
    $base = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    $base = if ($base) { $base -replace '^refs/remotes/origin/', '' } else { "main" }
    $merged = git branch --merged $base | Where-Object { $_ -notmatch '^\*|main|master' } | ForEach-Object { $_.Trim() }
    if (-not $merged) {
        Write-Host "Nothing to clean."
        return
    }
    Write-Host "Merged branches to delete:"
    $merged | ForEach-Object { Write-Host $_ }
    $confirm = Read-Host "Delete these? (y/N)"
    if ($confirm -eq "y") { $merged | ForEach-Object { git branch -d $_ } }
}

# List local git branches sorted by last commit date (most recent activity first)
function branchage {
    git for-each-ref --sort=-committerdate refs/heads/ `
        --format='%(committerdate:relative)|%(refname:short)' |
        ForEach-Object {
            $parts = $_ -split '\|'
            "{0,-25} {1}" -f $parts[0], $parts[1]
        }
}

# Show today's commits authored by you (since midnight)
function gitlog-today {
    $name = git config user.name
    git log --since=midnight --oneline --author="$name"
}

# Git add + commit + push in one step, with a confirmation prompt if on main/master
# Usage: gacp <commit message>
function gacp {
    param([Parameter(Mandatory)][string]$Message)
    $branch = git branch --show-current
    if ($branch -in @("main", "master")) {
        $confirm = Read-Host "[!] You're on '$branch'. Push directly? (y/N)"
        if ($confirm -ne "y") { Write-Host "Aborted."; return }
    }
    git add -A
    git commit -m $Message
    git push origin $branch
}

# Clone a repo and cd straight into it
# Usage: gclone <repo-url> [dir]
function gclone {
    param([Parameter(Mandatory)][string]$Url, [string]$Dir)
    git clone $Url $Dir
    $target = if ($Dir) { $Dir } else { [System.IO.Path]::GetFileNameWithoutExtension($Url) }
    Set-Location $target
}

# Commit "work in progress" — quick checkpoint commit for uncommitted changes
function gwip {
    git add -A
    git commit -m "WIP: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

# Undo the last WIP commit created by gwip (soft reset, keeps changes staged)
function gunwip {
    $msg = git log -1 --pretty=%B
    if ($msg -like "WIP:*") {
        git reset --soft HEAD~1
        Write-Host "WIP commit undone."
    } else {
        Write-Host "Last commit isn't a WIP commit, aborting."
    }
}

# Delete local remote-tracking branches whose remote counterpart is gone
function gitprune {
    git fetch --prune
    git branch -vv | Select-String ": gone\]" | ForEach-Object {
        $branch = ($_ -split '\s+')[1]
        git branch -d $branch
    }
}

# Diff the current branch against main/master (or a given base)
# Usage: prdiff [base-branch]
function prdiff {
    param([string]$Base = "main")
    git diff "$Base...HEAD"
}

# Show contributor commit counts for the current repo, sorted by count
function gitcontributors {
    git log --format='%aN' | Group-Object | Sort-Object Count -Descending |
        Select-Object Count, Name | Format-Table -AutoSize
}

# Show total size of the .git directory
function gitsize {
    $size = (Get-ChildItem .git -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    "{0:N2} MB" -f ($size / 1MB)
}

# List files with unresolved merge conflicts
function gitconflicts {
    git diff --name-only --diff-filter=U
}

# Fetch a .gitignore template from gitignore.io and append it to .gitignore
# Usage: gitignore <lang1,lang2,...>  e.g. gitignore go,node,windows
function gitignore {
    param([Parameter(Mandatory)][string]$Langs)
    Invoke-RestMethod "https://www.toptal.com/developers/gitignore/api/$Langs" |
        Out-File -Append -Encoding utf8 .gitignore
    Write-Host "Appended $Langs templates to .gitignore"
}

#########################################################################
# 3. DOCKER & KUBERNETES
#########################################################################

# Force stop and remove a container by name or ID
# Usage: dockernuke <container-name-or-id>
function dockernuke {
    param([Parameter(Mandatory)][string]$Container)
    docker stop $Container 2>$null
    docker rm -f $Container 2>$null
    Write-Host "Removed: $Container"
}

# List dangling Docker images and offer to remove them
function dockerclean-images {
    $dangling = docker images -f "dangling=true" -q
    if (-not $dangling) {
        Write-Host "No dangling images."
        return
    }
    docker images -f "dangling=true"
    $confirm = Read-Host "Remove these images? (y/N)"
    if ($confirm -eq "y") { docker rmi $dangling }
}

# Remove all unused Docker data (containers, images, networks, build cache)
function dclean {
    docker system prune -af
}

# Tail logs (with timestamps) for a given container
# Usage: dockerlogs <container-name-or-id>
function dockerlogs {
    param([Parameter(Mandatory)][string]$Container)
    docker logs -f --timestamps $Container
}

# Show human-readable sizes of local Docker images
function dockersizes {
    docker images --format "{{.Repository}}:{{.Tag}}`t{{.Size}}"
}

# Show which pods are consuming the most CPU/memory (requires metrics-server)
# Usage: ktop [cpu|memory]
function ktop {
    param([string]$SortBy = "cpu")
    kubectl top pods "--sort-by=$SortBy"
}

# Describe events for the current namespace, most recent last
function kevents {
    kubectl get events --sort-by='.lastTimestamp'
}

#########################################################################
# 4. GO DEVELOPMENT
#########################################################################

# Run Go tests with coverage and open the HTML coverage report in the browser
function covreport {
    go test ./... -coverprofile=$env:TEMP\cover.out
    go tool cover -html=$env:TEMP\cover.out -o $env:TEMP\cover.html
    Start-Process "$env:TEMP\cover.html"
}

# Explain why a given module is in the Go dependency graph
# Usage: gomodwhy <module-path>
function gomodwhy {
    param([Parameter(Mandatory)][string]$Module)
    Write-Host "Why is $Module in the dependency graph?"
    Write-Host "---"
    go mod why -m $Module
}

# Tidy, vet, and format a Go module in one pass
function goclean {
    gofmt -l -w .
    go vet ./...
    go mod tidy
}

# Upgrade all direct and indirect Go dependencies to their latest versions
function goupdate {
    go get -u ./...
    go mod tidy
}

# Run Go benchmarks for the current package with memory stats
# Usage: gobench [pattern]
function gobench {
    param([string]$Pattern = ".")
    go test "-bench=$Pattern" -benchmem ./...
}

#########################################################################
# 5. NODE / NPM
#########################################################################

# Delete node_modules and lockfile, then reinstall from scratch
function npmclean {
    Remove-Item -Recurse -Force node_modules, package-lock.json -ErrorAction SilentlyContinue
    npm install
}

# List the scripts defined in package.json
function npmscripts {
    if (-not (Test-Path package.json)) { Write-Host "No package.json here."; return }
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
    $pkg.scripts.PSObject.Properties | ForEach-Object { "$($_.Name): $($_.Value)" }
}

# Show outdated dependencies
function npmoutdated {
    npm outdated
}

# Print the size of node_modules
function npmsize {
    $size = (Get-ChildItem node_modules -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    "{0:N2} MB" -f ($size / 1MB)
}

#########################################################################
# 6. PYTHON
#########################################################################

# Create and activate a Python virtual environment in .\venv
function venvcreate {
    python -m venv venv
    . .\venv\Scripts\Activate.ps1
    Write-Host "Virtualenv created and activated. Run 'deactivate' to exit."
}

# Remove all __pycache__ dirs and .pyc files recursively
function pyclean {
    Get-ChildItem -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Get-ChildItem -Recurse -File -Filter "*.pyc" -ErrorAction SilentlyContinue | Remove-Item -Force
    Write-Host "Cleaned Python cache files."
}

# Freeze current environment's packages into requirements.txt
function pyfreeze {
    pip freeze | Out-File -Encoding utf8 requirements.txt
    $count = (Get-Content requirements.txt | Measure-Object -Line).Lines
    Write-Host "Wrote $count packages to requirements.txt"
}

#########################################################################
# 7. NETWORKING & APIs
#########################################################################

# Print your public-facing IP address
function myip {
    (Invoke-RestMethod "https://ifconfig.me")
}

# Print your local network IP address
function localip {
    (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.InterfaceAlias -notmatch 'Loopback' -and $_.IPAddress -notlike '169.254*' } |
        Select-Object -First 1).IPAddress
}

# Find and kill whatever process is listening on the given port(s)
# Usage: killport <port> [port ...]
function killport {
    param([Parameter(Mandatory)][int[]]$Ports)
    foreach ($port in $Ports) {
        $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if (-not $conns) {
            Write-Host "[X] Nothing is listening on port $port."
            continue
        }
        foreach ($conn in $conns) {
            Write-Host "[*] Found process (PID: $($conn.OwningProcess)) using port $port."
            Stop-Process -Id $conn.OwningProcess -Force
            Write-Host "[OK] Port $port is now free."
        }
    }
}

# Show which process is listening on a given TCP port
# Usage: portwho <port>
function portwho {
    param([Parameter(Mandatory)][int]$Port)
    Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [PSCustomObject]@{ Port = $Port; PID = $_.OwningProcess; Process = $proc.ProcessName }
        }
}

# Look up A, CNAME, and MX records for a domain
# Usage: dnscheck <domain>
function dnscheck {
    param([Parameter(Mandatory)][string]$Domain)
    Write-Host "A records:"
    Resolve-DnsName $Domain -Type A -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress
    Write-Host "`nCNAME:"
    Resolve-DnsName $Domain -Type CNAME -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NameHost
    Write-Host "`nMX records:"
    Resolve-DnsName $Domain -Type MX -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NameExchange
}

# Fetch just the HTTP status code for a URL and describe what it means
# Usage: httpstatus <url>
function httpstatus {
    param([Parameter(Mandatory)][string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -ErrorAction Stop
        $code = [int]$resp.StatusCode
    } catch {
        $code = [int]$_.Exception.Response.StatusCode
    }
    $msg = switch -Regex ($code) {
        '^2' { "OK" }
        '^3' { "Redirect" }
        '401|403' { "Auth/permission issue" }
        '404' { "Not found" }
        '^5' { "Server error" }
        default { "Unknown" }
    }
    Write-Host "$code - $msg"
}

# Hit a URL, pretty-print JSON response, and show timing/status
# Usage: apihit <url>
function apihit {
    param([Parameter(Mandatory)][string]$Url)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing
    $sw.Stop()
    try {
        $resp.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } catch {
        $resp.Content
    }
    Write-Host "`n[Time] $($sw.Elapsed.TotalSeconds)s | status: $($resp.StatusCode)"
}

# Flush the local DNS cache
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS cache flushed."
}

# Show weather for a location via wttr.in
# Usage: weather [location]
function weather {
    param([string]$Location = "")
    (Invoke-WebRequest "https://wttr.in/$Location" -UseBasicParsing).Content
}

# Quick TCP reachability check on host:port
# Usage: tcpcheck <host> <port>
function tcpcheck {
    param([Parameter(Mandatory)][string]$HostName, [Parameter(Mandatory)][int]$Port)
    $result = Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue
    if ($result.TcpTestSucceeded) {
        Write-Host "[OK] ${HostName}:${Port} is reachable"
    } else {
        Write-Host "[X] ${HostName}:${Port} is not reachable"
    }
}

# Shorten a URL using is.gd
# Usage: shorten <url>
function shorten {
    param([Parameter(Mandatory)][string]$Url)
    Invoke-RestMethod ('https://is.gd/create.php?format=simple&url=' + $Url)
}

#########################################################################
# 8. SECURITY & ENCODING
#########################################################################

# Generate a random base64 password (default 24 bytes)
# Usage: passgen [bytes]
function passgen {
    param([int]$Bytes = 24)
    $rand = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($rand)
    [Convert]::ToBase64String($rand)
}

# Print the contents of your SSH public key(s)
function pubkey {
    Get-ChildItem "$HOME\.ssh\*.pub" -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_ }
}

# Generate a new ed25519 SSH keypair (requires OpenSSH client, ships with modern Windows)
# Usage: genssh <key-name> [email]
function genssh {
    param([Parameter(Mandatory)][string]$Name, [string]$Email = $Name)
    ssh-keygen -t ed25519 -f "$HOME\.ssh\$Name" -C $Email
}

# Base64 encode/decode text
function b64e {
    param([Parameter(Mandatory)][string]$Text)
    [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text))
}
function b64d {
    param([Parameter(Mandatory)][string]$Text)
    [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Text))
}

# URL-encode / URL-decode text
function urlencode {
    param([Parameter(Mandatory)][string]$Text)
    [System.Uri]::EscapeDataString($Text)
}
function urldecode {
    param([Parameter(Mandatory)][string]$Text)
    [System.Uri]::UnescapeDataString($Text)
}

# Compute MD5, SHA1, and SHA256 hashes of a file
# Usage: hashfile <file>
function hashfile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "File not found: $Path"
        return
    }
    Write-Host "MD5:    $((Get-FileHash $Path -Algorithm MD5).Hash)"
    Write-Host "SHA1:   $((Get-FileHash $Path -Algorithm SHA1).Hash)"
    Write-Host "SHA256: $((Get-FileHash $Path -Algorithm SHA256).Hash)"
}

# Generate a random UUID v4
function genuuid {
    [guid]::NewGuid().ToString()
}

#########################################################################
# 9. SYSTEM & PROCESS
#########################################################################

# Show current physical memory usage
function mem {
    Get-CimInstance Win32_OperatingSystem |
        Select-Object @{N = "TotalGB"; E = { [math]::Round($_.TotalVisibleMemorySize / 1MB, 2) } },
                      @{N = "FreeGB"; E = { [math]::Round($_.FreePhysicalMemory / 1MB, 2) } }
}

# Show a snapshot of current CPU/process activity
function cpu {
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name, CPU, Id | Format-Table -AutoSize
}

# Show the process tree for a given PID
# Usage: pidtree <pid>
function pidtree {
    param([Parameter(Mandatory)][int]$ProcessId)
    Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq $ProcessId -or $_.ParentProcessId -eq $ProcessId } |
        Select-Object ProcessId, ParentProcessId, Name | Format-Table -AutoSize
}

# Print the current date and time
function now {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

# Simple countdown timer with a beep when done
# Usage: timer <seconds> [label]
function timer {
    param([Parameter(Mandatory)][int]$Seconds, [string]$Label = "Timer")
    for ($s = $Seconds; $s -gt 0; $s--) {
        Write-Host -NoNewline ("`r{0}: {1:D2}:{2:D2} " -f $Label, [int]($s / 60), ($s % 60))
        Start-Sleep -Seconds 1
    }
    Write-Host "`r$Label`: done!            "
    [console]::beep(800, 400)
}

#########################################################################
# 10. PRODUCTIVITY & MISC
#########################################################################

# Append a timestamped note to today's markdown notes file (~/notes/YYYY-MM-DD.md)
# Usage: note <text>
function note {
    param([Parameter(Mandatory)][string]$Text)
    $dir = "$HOME\notes"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $file = "$dir\$(Get-Date -Format 'yyyy-MM-dd').md"
    "- $(Get-Date -Format 'HH:mm') $Text" | Out-File -Append -Encoding utf8 $file
    Write-Host "Saved to $file"
}

# Pretty-print a JSON file
# Usage: jsonpp <file>
function jsonpp {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content $Path -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 20
}

# Load variables from a .env-style file into environment variables
# Usage: envload [file]  (defaults to .env)
function envload {
    param([string]$Path = ".env")
    if (-not (Test-Path $Path)) {
        Write-Host "No such file: $Path"
        return
    }
    $count = 0
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
            $count++
        }
    }
    Write-Host "Loaded $count vars from $Path"
}

# Find files by name (fuzzy substring match) or search file contents for text
# Usage:
#   ffind -f <filename>   # find files by name
#   ffind <text>          # search file contents for text
function ffind {
    param([string]$FindFlag, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
    if ($FindFlag -eq "-f") {
        $pattern = ($Rest -join " ")
        if (-not $pattern) { Write-Host 'Usage: ffind -f <filename>'; return }
        Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$pattern*" } |
            Select-Object -ExpandProperty FullName
    } else {
        $pattern = (@($FindFlag) + $Rest) -join " "
        if (-not $pattern.Trim()) {
            Write-Host 'Usage:'
            Write-Host '  ffind -f <filename>   # Find files'
            Write-Host '  ffind <text>          # Find text in files'
            return
        }
        Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules|venv|\.venv|__pycache__|dist|build)\\' } |
            Select-String -Pattern $pattern -ErrorAction SilentlyContinue
    }
}

# Look up a command's usage examples via tldr (falls back to Get-Help)
# Usage: cheat <command>
function cheat {
    param([Parameter(Mandatory)][string]$Command)
    if (Get-Command tldr -ErrorAction SilentlyContinue) {
        tldr $Command
    } else {
        Get-Help $Command
    }
}

# Quick command-line calculator
# Usage: calc "2 + 2 * 3"
function calc {
    param([Parameter(Mandatory)][string]$Expression)
    Invoke-Expression $Expression
}

# Generate a QR code for text/URL and display it in the terminal
# Usage: qr <text>
function qr {
    param([Parameter(Mandatory)][string]$Text)
    (Invoke-WebRequest "https://qrenco.de/$Text" -UseBasicParsing).Content
}

#########################################################################
# 11. CI / JENKINS
# (requires $env:JENKINS_URL, $env:JENKINS_USER, $env:JENKINS_TOKEN to be set)
#########################################################################

function Get-SharmoryJenkinsAuth {
    $pair = "$($env:JENKINS_USER):$($env:JENKINS_TOKEN)"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    @{ Authorization = "Basic $([Convert]::ToBase64String($bytes))" }
}

# Get a CSRF crumb from Jenkins (needed for authenticated POST requests)
function jenk-crumb {
    $resp = Invoke-RestMethod -Uri "$($env:JENKINS_URL)/crumbIssuer/api/json" -Headers (Get-SharmoryJenkinsAuth)
    $resp.crumb
}

# Trigger a build for the given Jenkins job name
# Usage: jenk-build <job-name>
function jenk-build {
    param([Parameter(Mandatory)][string]$Job)
    $crumb = jenk-crumb
    $headers = Get-SharmoryJenkinsAuth
    $headers["Jenkins-Crumb"] = $crumb
    Invoke-RestMethod -Method Post -Uri "$($env:JENKINS_URL)/job/$Job/build" -Headers $headers
}

# Fetch the console log of the last build for a Jenkins job
# Usage: jenk-logs <job-name>
function jenk-logs {
    param([Parameter(Mandatory)][string]$Job)
    Invoke-RestMethod -Uri "$($env:JENKINS_URL)/job/$Job/lastBuild/consoleText" -Headers (Get-SharmoryJenkinsAuth)
}

# List all job names available on the configured Jenkins server
function jenk-jobs {
    $resp = Invoke-RestMethod -Uri "$($env:JENKINS_URL)/api/json" -Headers (Get-SharmoryJenkinsAuth)
    $resp.jobs | Select-Object -ExpandProperty name
}

#########################################################################
# 12. SHARMORY MANAGEMENT
#########################################################################

# Update Sharmory to the latest version from GitHub
function sharmory-update {
    $targetDir = Join-Path $HOME "sharmory"
    $targetFile = Join-Path $targetDir "functions.ps1"
    Write-Host "Updating Sharmory from GitHub..."
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    try {
        Invoke-WebRequest "https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.ps1" -OutFile $targetFile -UseBasicParsing
        . $targetFile
        Write-Host "Sharmory successfully updated and reloaded!"
    } catch {
        Write-Host "Failed to update Sharmory: $_"
    }
}

