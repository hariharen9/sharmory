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

# Recursive tree listing; uses `tree` if present
# Usage: treelist [dir] [depth]
function treelist {
    param([string]$Path = ".", [int]$Depth = 0)
    if (-not (Test-Path $Path)) {
        Write-Host "Not found: $Path"
        return
    }
    if ((Get-Command tree -CommandType Application -ErrorAction SilentlyContinue) -and $Depth -eq 0) {
        tree /F $Path
        return
    }
    $base = (Resolve-Path $Path).Path.TrimEnd("\")
    Get-ChildItem $base -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.git(\\|$)' } |
        ForEach-Object {
            $rel = $_.FullName.Substring($base.Length).TrimStart("\")
            $level = if ($rel) { $rel.Split("\").Count } else { 0 }
            if ($Depth -gt 0 -and $level -gt $Depth) { return }
            Write-Host (("  " * $level) + $_.Name)
        }
}

# Show the N most recently modified files in the current directory tree
# Usage: recent [n]
function recent {
    param([int]$Count = 10)
    Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.git\\' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Count -ExpandProperty FullName
}

# Swap two filenames using a temp file
# Usage: swap <file-a> <file-b>
function swap {
    param(
        [Parameter(Mandatory)][string]$PathA,
        [Parameter(Mandatory)][string]$PathB
    )
    if (-not (Test-Path $PathA)) { Write-Host "Not found: $PathA"; return }
    if (-not (Test-Path $PathB)) { Write-Host "Not found: $PathB"; return }
    $tmp = "$PathA.$([guid]::NewGuid().ToString('N').Substring(0, 8)).swaptmp"
    Move-Item -LiteralPath $PathA -Destination $tmp
    Move-Item -LiteralPath $PathB -Destination $PathA
    Move-Item -LiteralPath $tmp -Destination $PathB
    Write-Host "Swapped: $PathA <-> $PathB"
}

# Move a file or directory to the Recycle Bin
# Usage: trash <file-or-dir>
function trash {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "Not found: $Path"
        return
    }
    $full = (Resolve-Path $Path).Path
    $item = Get-Item -LiteralPath $full
    Add-Type -AssemblyName Microsoft.VisualBasic
    if ($item.PSIsContainer) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($full, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($full, 'OnlyErrorDialogs', 'SendToRecycleBin')
    }
    Write-Host "Trashed: $Path"
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

# Interactive git stash picker — pop, apply, or drop via fzf
function gstash {
    if (-not (Test-SharmoryDependency fzf)) { return }
    $entry = git stash list | fzf --prompt="stash> "
    if (-not $entry) { return }
    $stashRef = ($entry -split ":")[0]
    $action = Read-Host "Action for $stashRef - (p)op  (a)pply  (d)rop  [p/a/d]"
    switch ($action) {
        "p" { git stash pop $stashRef }
        "a" { git stash apply $stashRef }
        "d" { git stash drop $stashRef }
        default { Write-Host "Aborted." }
    }
}

# Interactive rebase N commits
# Usage: grebase [n]
function grebase {
    param([string]$Count)
    if (-not $Count) {
        $Count = Read-Host "How many commits back do you want to rebase?"
    }
    if ($Count -notmatch '^[0-9]+$') {
        Write-Host "Expected a positive integer, got: $Count"
        return
    }
    git rebase -i "HEAD~$Count"
}

# Open the current repo's origin URL in the browser
function gopen {
    $remote = git remote get-url origin 2>$null
    if (-not $remote) {
        Write-Host "No 'origin' remote found."
        return
    }
    $url = $remote.Trim()
    if ($url -match '^git@([^:]+):(.+)$') {
        $url = "https://$($Matches[1])/$($Matches[2])"
    }
    $url = $url -replace '\.git$', ''
    Write-Host "Opening: $url"
    Start-Process $url
}

# Rename a git branch locally and on the remote
# Usage: gitbranch-rename <old-name> <new-name>
function gitbranch-rename {
    param(
        [Parameter(Mandatory)][string]$OldName,
        [Parameter(Mandatory)][string]$NewName
    )
    git branch -m $OldName $NewName
    git push origin --delete $OldName 2>$null
    git push origin -u $NewName
    Write-Host "Renamed '$OldName' -> '$NewName' locally and on remote."
}

# Pretty one-line graph log
function gitlog-graph {
    git log --graph --oneline --decorate --all --color @args
}

# Prune remotes, delete merged branches, tidy Go module if present
function gcleanup {
    Write-Host "==> gitprune"
    gitprune
    Write-Host "==> branchclean"
    branchclean
    if (Test-Path go.mod) {
        Write-Host "==> goclean"
        goclean
    }
    Write-Host "Done."
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

# Print all environment variables of a running container
# Usage: denv <container-name-or-id>
function denv {
    param([Parameter(Mandatory)][string]$Container)
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' $Container
}

# Build a Docker image; tag defaults to the current directory name
# Usage: dbuild [tag]
function dbuild {
    param([string]$Tag = (Split-Path (Get-Location) -Leaf))
    Write-Host "Building image: $Tag"
    docker build -t $Tag .
}

# Set the current kubectl namespace
# Usage: kns <namespace>
function kns {
    param([Parameter(Mandatory)][string]$Namespace)
    kubectl config set-context --current --namespace=$Namespace
    Write-Host "Namespace set to: $Namespace"
}

# Describe a pod (fzf picker, or pass a name)
# Usage: kdesc [pod-name]
function kdesc {
    param([string]$Pod)
    if (-not $Pod) {
        if (-not (Test-SharmoryDependency fzf)) { return }
        $picked = kubectl get pods -o name | fzf --prompt="describe pod> "
        if (-not $picked) { return }
        $Pod = $picked -replace '^pod/', ''
    }
    kubectl describe pod $Pod
}

# Forward a local port to a pod
# Usage: kport <local-port> <pod-name> <remote-port>
function kport {
    param(
        [Parameter(Mandatory)][int]$LocalPort,
        [Parameter(Mandatory)][string]$Pod,
        [Parameter(Mandatory)][int]$RemotePort
    )
    Write-Host "Forwarding localhost:$LocalPort -> pod/$Pod`:$RemotePort (Ctrl-C to stop)"
    kubectl port-forward "pod/$Pod" "${LocalPort}:${RemotePort}"
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

# Send a few pings and print reachability
# Usage: pingcheck <host>
function pingcheck {
    param([Parameter(Mandatory)][string]$HostName)
    Write-Host "Pinging $HostName (5 packets)..."
    Test-Connection -ComputerName $HostName -Count 5 -ErrorAction SilentlyContinue
}

# List Host entries from ~/.ssh/config
function sshconfig {
    $cfg = Join-Path $HOME ".ssh\config"
    if (-not (Test-Path $cfg)) {
        Write-Host "No ~/.ssh/config found."
        return
    }
    $hostName = $null; $hostname = $null; $user = $null; $port = $null
    function Write-SharmorySshHost {
        if ($script:SshHost -and $script:SshHostname) {
            $who = if ($script:SshUser) { "$($script:SshUser)@" } else { "" }
            $p = if ($script:SshPort) { ":$($script:SshPort)" } else { "" }
            Write-Host ("  {0,-20} -> {1}{2}{3}" -f $script:SshHost, $who, $script:SshHostname, $p)
        }
    }
    $script:SshHost = $null; $script:SshHostname = $null; $script:SshUser = $null; $script:SshPort = $null
    Get-Content $cfg | ForEach-Object {
        $line = $_.TrimEnd()
        if ($line -match '^[Hh]ost\s+(\S+)') {
            Write-SharmorySshHost
            $script:SshHost = $Matches[1]
            $script:SshHostname = $null; $script:SshUser = $null; $script:SshPort = $null
        } elseif ($line -match '^\s*HostName\s+(\S+)') {
            $script:SshHostname = $Matches[1]
        } elseif ($line -match '^\s*User\s+(\S+)') {
            $script:SshUser = $Matches[1]
        } elseif ($line -match '^\s*Port\s+(\S+)') {
            $script:SshPort = $Matches[1]
        }
    }
    Write-SharmorySshHost
}

# Show HTTP response headers for a URL
# Usage: headers <url>
function headers {
    param([Parameter(Mandatory)][string]$Url)
    $resp = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing
    $resp.Headers.GetEnumerator() | ForEach-Object { "{0}: {1}" -f $_.Key, $_.Value }
}

# Toggle http_proxy / https_proxy env vars
# Usage: proxy on [host:port]  |  proxy off  |  proxy status
function proxy {
    param([string]$Action = "status", [string]$Address)
    switch ($Action) {
        "on" {
            if (-not $Address) { $Address = "http://127.0.0.1:8080" }
            $env:http_proxy = $Address
            $env:https_proxy = $Address
            $env:HTTP_PROXY = $Address
            $env:HTTPS_PROXY = $Address
            $env:no_proxy = "localhost,127.0.0.1,::1"
            $env:NO_PROXY = $env:no_proxy
            Write-Host "Proxy ON -> $Address"
        }
        "off" {
            Remove-Item Env:http_proxy, Env:https_proxy, Env:HTTP_PROXY, Env:HTTPS_PROXY, Env:no_proxy, Env:NO_PROXY -ErrorAction SilentlyContinue
            Write-Host "Proxy OFF."
        }
        "status" {
            $hp = $env:http_proxy; if (-not $hp) { $hp = "<not set>" }
            $hsp = $env:https_proxy; if (-not $hsp) { $hsp = "<not set>" }
            Write-Host "http_proxy  = $hp"
            Write-Host "https_proxy = $hsp"
        }
        default {
            Write-Host "Usage: proxy <on [host:port]|off|status>"
        }
    }
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

# Decode a JWT header and payload (no signature verification)
# Usage: jwtdecode <token>
function jwtdecode {
    param([Parameter(Mandatory)][string]$Token)
    $parts = $Token.Split(".")
    if ($parts.Count -lt 2) {
        Write-Host "Not a JWT."
        return
    }
    function ConvertFrom-SharmoryJwtPart([string]$Part) {
        $s = $Part.Replace("-", "+").Replace("_", "/")
        switch ($s.Length % 4) {
            2 { $s += "==" }
            3 { $s += "=" }
        }
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))
    }
    Write-Host "=== Header ==="
    $header = ConvertFrom-SharmoryJwtPart $parts[0]
    $payload = ConvertFrom-SharmoryJwtPart $parts[1]
    try { $header | ConvertFrom-Json | ConvertTo-Json -Depth 10 } catch { $header }
    Write-Host "=== Payload ==="
    try { $payload | ConvertFrom-Json | ConvertTo-Json -Depth 10 } catch { $payload }
}

# Lint a .env file for empty values, dupes, unquoted spaces, and plaintext secrets
# Usage: dotenv-check [file]
function dotenv-check {
    param([string]$Path = ".env")
    if (-not (Test-Path $Path)) {
        Write-Host "No such file: $Path"
        return
    }
    $issues = 0
    $seen = @{}
    $lineno = 0
    $script:DotenvIssues = 0
    Get-Content $Path | ForEach-Object {
        $lineno++
        $line = $_
        if ($line -match '^\s*$' -or $line -match '^\s*#') { return }
        if ($line -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') {
            Write-Host ("  [WARN] line {0}: not a valid KEY=value pair: {1}" -f $lineno, $line)
            $script:DotenvIssues++
            return
        }
        $key = $line.Substring(0, $line.IndexOf("="))
        $value = $line.Substring($line.IndexOf("=") + 1)
        if ($seen.ContainsKey($key)) {
            Write-Host ("  [DUPE] line {0}: duplicate key '{1}'" -f $lineno, $key)
            $script:DotenvIssues++
        }
        $seen[$key] = $true
        if ([string]::IsNullOrEmpty($value)) {
            Write-Host ("  [EMPTY] line {0}: '{1}' has no value" -f $lineno, $key)
            $script:DotenvIssues++
            return
        }
        $quoted = ($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))
        if (-not $quoted -and $value -match '\s') {
            Write-Host ("  [QUOTE] line {0}: '{1}' value contains spaces but is not quoted" -f $lineno, $key)
            $script:DotenvIssues++
        }
        if ($key -match 'SECRET|PASSWORD|PASSWD|TOKEN|API_KEY|APIKEY|PRIVATE_KEY|AUTH') {
            if (-not $quoted -and $value -notmatch '^\$\{') {
                Write-Host ("  [SECRET] line {0}: '{1}' looks like a secret - consider quoting or using a vault" -f $lineno, $key)
                $script:DotenvIssues++
            }
        }
    }
    $issues = $script:DotenvIssues
    $script:DotenvIssues = 0
    if (-not $issues) {
        Write-Host "  $Path looks clean (no issues found)."
    } else {
        Write-Host ("  {0} issue(s) found in {1}" -f $issues, $Path)
    }
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

# Disk usage summary for a path
# Usage: diskusage [path]
function diskusage {
    param([string]$Path = ".")
    Write-Host "=== Filesystem usage ==="
    Get-PSDrive -PSProvider FileSystem | Format-Table Name, @{N = "UsedGB"; E = { [math]::Round(($_.Used / 1GB), 2) } }, @{N = "FreeGB"; E = { [math]::Round(($_.Free / 1GB), 2) } } -AutoSize
    Write-Host "=== Largest directories under $Path ==="
    Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        [PSCustomObject]@{ Name = $_.Name; SizeMB = [math]::Round(($size / 1MB), 2) }
    } | Sort-Object SizeMB -Descending | Select-Object -First 20 | Format-Table -AutoSize
}

# Diff two .env files by key
# Usage: envdiff <file1> <file2>
function envdiff {
    param(
        [Parameter(Mandatory)][string]$FileA,
        [Parameter(Mandatory)][string]$FileB
    )
    if (-not (Test-Path $FileA)) { Write-Host "Not found: $FileA"; return }
    if (-not (Test-Path $FileB)) { Write-Host "Not found: $FileB"; return }
    $parse = {
        param($p)
        $h = @{}
        Get-Content $p | ForEach-Object {
            if ($_ -match '^\s*$' -or $_ -match '^\s*#') { return }
            if ($_ -notmatch '^[A-Za-z_][A-Za-z0-9_]*=') { return }
            $h[$_.Substring(0, $_.IndexOf("="))] = $_.Substring($_.IndexOf("=") + 1)
        }
        $h
    }
    $a = & $parse $FileA
    $b = & $parse $FileB
    $changed = 0
    foreach ($k in $a.Keys) {
        if (-not $b.ContainsKey($k)) {
            Write-Host ("  - {0}={1}" -f $k, $a[$k])
            $changed++
        } elseif ($a[$k] -ne $b[$k]) {
            Write-Host ("  ~ {0}: {1} -> {2}" -f $k, $a[$k], $b[$k])
            $changed++
        }
    }
    foreach ($k in $b.Keys) {
        if (-not $a.ContainsKey($k)) {
            Write-Host ("  + {0}={1}" -f $k, $b[$k])
            $changed++
        }
    }
    if ($changed -eq 0) {
        Write-Host "  No differences found."
    } else {
        Write-Host ("  {0} difference(s) between {1} and {2}" -f $changed, $FileA, $FileB)
    }
}

# Listening TCP ports with process name and PID
function ports {
    Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Sort-Object LocalPort |
        ForEach-Object {
            $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                Proto   = "TCP"
                Port    = $_.LocalPort
                Process = $proc.ProcessName
                PID     = $_.OwningProcess
            }
        } | Format-Table -AutoSize
}

# One-screen system summary
function sysinfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host "======================================="
    Write-Host "          System Information"
    Write-Host "======================================="
    Write-Host ("  OS       : {0}" -f $os.Caption)
    Write-Host ("  Version  : {0}" -f $os.Version)
    Write-Host ("  CPU      : {0}" -f $cpuInfo.Name)
    Write-Host ("  Cores    : {0} logical" -f $cs.NumberOfLogicalProcessors)
    Write-Host ("  RAM      : {0:N1} GB total" -f ($cs.TotalPhysicalMemory / 1GB))
    Write-Host ("  Uptime   : {0}" -f (New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).ToString())
    Write-Host ""
    Write-Host "  Disk usage:"
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        Write-Host ("    {0}: used {1:N1} GB / free {2:N1} GB" -f $_.Name, ($_.Used / 1GB), ($_.Free / 1GB))
    }
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

# Append a timestamped entry to ~/todo.md; no args lists todos
# Usage: todo [text]
function todo {
    param([string]$Text)
    $file = Join-Path $HOME "todo.md"
    if (-not $Text) {
        if (Test-Path $file) { Get-Content $file } else { Write-Host 'No todo file yet. Run: todo [text]' }
        return
    }
    if (-not (Test-Path $file)) { "# Todos`n" | Out-File -Encoding utf8 $file }
    ("- [ ] {0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"), $Text) | Out-File -Append -Encoding utf8 $file
    Write-Host "Added: $Text"
}

# Scaffold a project directory with README, .gitignore, and .env.example
# Usage: mkproject <name> [go|node|python]
function mkproject {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Template = "bare"
    )
    if (Test-Path $Name) {
        Write-Host "Directory '$Name' already exists."
        return
    }
    New-Item -ItemType Directory -Force -Path $Name | Out-Null
    Set-Location $Name
    @"
# $Name

> Add project description here.

## Getting Started

## License

MIT
"@ | Out-File -Encoding utf8 README.md
    @"
# Copy this file to .env and fill in your values

APP_ENV=development
LOG_LEVEL=info
"@ | Out-File -Encoding utf8 .env.example

    switch ($Template) {
        "go" {
            "*.out`n*.test`nvendor/`n*.log`n.env`n" | Out-File -Encoding utf8 .gitignore
            go mod init $Name 2>$null
            @'
package main

import "fmt"

func main() {
	fmt.Println("Hello!")
}
'@ | Out-File -Encoding utf8 main.go
        }
        "node" {
            "node_modules/`ndist/`n.env`n*.log`n" | Out-File -Encoding utf8 .gitignore
            (@{ name = $Name; version = "0.1.0"; description = ""; main = "index.js"; scripts = @{ start = "node index.js" } } | ConvertTo-Json) | Out-File -Encoding utf8 package.json
            "console.log('Hello from $Name!');" | Out-File -Encoding utf8 index.js
        }
        "python" {
            "venv/`n__pycache__/`n*.pyc`n.env`n*.egg-info/`ndist/`nbuild/`n" | Out-File -Encoding utf8 .gitignore
            "# $Name`n`nrequirements:`n" | Out-File -Encoding utf8 requirements.txt
            @'
def main():
    print("Hello!")

if __name__ == "__main__":
    main()
'@ | Out-File -Encoding utf8 main.py
        }
        default {
            ".env`n*.log`n" | Out-File -Encoding utf8 .gitignore
        }
    }

    git init -q
    git add -A
    git commit -q -m "Initial commit ($Template)"
    Write-Host "Project '$Name' created with template '$Template'"
    Write-Host "   $(Get-Location)"
}

# Convert between Unix epoch and human-readable datetime
# Usage: epoch | epoch <epoch> | epoch <date>
function epoch {
    param([string]$Value)
    if (-not $Value) {
        $now = [DateTimeOffset]::Now
        Write-Host ("Epoch   : {0}" -f $now.ToUnixTimeSeconds())
        Write-Host ("Human   : {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
        return
    }
    if ($Value -match '^[0-9]+$') {
        [DateTimeOffset]::FromUnixTimeSeconds([int64]$Value).LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss zzz")
    } else {
        ([DateTimeOffset]::Parse($Value)).ToUnixTimeSeconds()
    }
}

# Diff two JSON files after normalizing
# Usage: diffjson <file-a> <file-b>
function diffjson {
    param(
        [Parameter(Mandatory)][string]$FileA,
        [Parameter(Mandatory)][string]$FileB
    )
    if (-not (Test-Path $FileA)) { Write-Host "Not found: $FileA"; return }
    if (-not (Test-Path $FileB)) { Write-Host "Not found: $FileB"; return }
    $ja = (Get-Content $FileA -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 20)
    $jb = (Get-Content $FileB -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 20)
    if ($ja -eq $jb) { return }
    Compare-Object ($ja -split "`n") ($jb -split "`n") | ForEach-Object {
        if ($_.SideIndicator -eq "<=") { Write-Host ("- {0}" -f $_.InputObject) }
        else { Write-Host ("+ {0}" -f $_.InputObject) }
    }
}

# Retry a command with exponential backoff
# Usage: retry <max-attempts> <command> [args...]
function retry {
    param(
        [Parameter(Mandatory, Position = 0)][int]$MaxAttempts,
        [Parameter(Mandatory, Position = 1)][string]$CommandName,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$RetryArgs
    )
    $attempt = 1
    $wait = 1
    while ($true) {
        $ok = $true
        try {
            if ($RetryArgs) { & $CommandName @RetryArgs } else { & $CommandName }
            if (-not $?) { $ok = $false }
        } catch {
            $ok = $false
        }
        if ($ok) {
            if ($attempt -gt 1) { Write-Host "Succeeded on attempt $attempt." }
            return
        }
        if ($attempt -ge $MaxAttempts) {
            Write-Host ("Command failed after {0} attempt(s): {1}" -f $MaxAttempts, $CommandName)
            return
        }
        Write-Host ("Attempt {0}/{1} failed. Retrying in {2}s..." -f $attempt, $MaxAttempts, $wait)
        Start-Sleep -Seconds $wait
        $wait = $wait * 2
        $attempt++
    }
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

#########################################################################
# 13. ORCHESTRATOR — HUD, catalog, doctor
#########################################################################

function Get-SharmoryRegistry {
    @(
        [pscustomobject]@{ Category = "files"; Name = "mkcd"; Description = "Make a directory and cd into it"; Usage = "mkcd <dir>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "up"; Description = "Go up N directory levels"; Usage = "up [n]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "lsd"; Description = "List directory (eza if present)"; Usage = "lsd"; Deps = "eza" }
        [pscustomobject]@{ Category = "files"; Name = "permsof"; Description = "Show file ACL permissions"; Usage = "permsof <file>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "extract"; Description = "Extract an archive by extension"; Usage = "extract <archive-file>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "compress"; Description = "Compress a file or directory to zip"; Usage = "compress <output.zip> <path>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "duh"; Description = "Sizes of items in the current directory"; Usage = "duh"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "sizeof"; Description = "Sizes of subdirectories, largest first"; Usage = "sizeof [path]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "findbig"; Description = "Find files above a given size in MB"; Usage = "findbig [sizeMB] [dir]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "emptydirs"; Description = "Find and optionally remove empty directories"; Usage = "emptydirs [dir]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "dupfind"; Description = "Find duplicate files by SHA256"; Usage = "dupfind [dir]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "bak"; Description = "Timestamped backup copy of a file"; Usage = "bak <file>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "cwd"; Description = "Copy the working directory path to the clipboard"; Usage = "cwd"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "clipcopy"; Description = "Copy a file contents to the clipboard"; Usage = "clipcopy <file>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "treelist"; Description = "Recursive tree listing"; Usage = "treelist [dir] [depth]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "recent"; Description = "Most recently modified files"; Usage = "recent [n]"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "swap"; Description = "Swap two filenames"; Usage = "swap <file-a> <file-b>"; Deps = "" }
        [pscustomobject]@{ Category = "files"; Name = "trash"; Description = "Move a path to the Recycle Bin"; Usage = "trash <file-or-dir>"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitundo"; Description = "Undo last commit, keep changes staged"; Usage = "gitundo"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "branchclean"; Description = "Delete local branches already merged"; Usage = "branchclean"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "branchage"; Description = "Local branches sorted by last commit date"; Usage = "branchage"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitlog-today"; Description = "Your commits since midnight"; Usage = "gitlog-today"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gacp"; Description = "Add, commit, and push"; Usage = "gacp <commit message>"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gclone"; Description = "Clone a repo and cd into it"; Usage = "gclone <repo-url> [dir]"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gwip"; Description = "Checkpoint commit of uncommitted work"; Usage = "gwip"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gunwip"; Description = "Undo the last gwip commit"; Usage = "gunwip"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitprune"; Description = "Delete local branches whose remotes are gone"; Usage = "gitprune"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "prdiff"; Description = "Diff current branch against a base"; Usage = "prdiff [base-branch]"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitcontributors"; Description = "Commit counts by author"; Usage = "gitcontributors"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitsize"; Description = "Size of the .git directory"; Usage = "gitsize"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitconflicts"; Description = "List unresolved merge conflict files"; Usage = "gitconflicts"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitignore"; Description = "Append a gitignore.io template"; Usage = "gitignore <lang1,lang2,...>"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gstash"; Description = "Interactive stash picker"; Usage = "gstash"; Deps = "fzf" }
        [pscustomobject]@{ Category = "git"; Name = "grebase"; Description = "Interactive rebase N commits"; Usage = "grebase [n]"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gopen"; Description = "Open the origin remote in a browser"; Usage = "gopen"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitbranch-rename"; Description = "Rename a branch locally and on the remote"; Usage = "gitbranch-rename <old> <new>"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gitlog-graph"; Description = "Pretty one-line graph log"; Usage = "gitlog-graph"; Deps = "" }
        [pscustomobject]@{ Category = "git"; Name = "gcleanup"; Description = "Prune remotes, delete merged branches, tidy Go"; Usage = "gcleanup"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dockernuke"; Description = "Force stop and remove a container"; Usage = "dockernuke <container>"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dockerclean-images"; Description = "Remove dangling Docker images"; Usage = "dockerclean-images"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dclean"; Description = "Prune unused Docker data"; Usage = "dclean"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dockerlogs"; Description = "Tail container logs with timestamps"; Usage = "dockerlogs <container>"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dockersizes"; Description = "Human-readable local image sizes"; Usage = "dockersizes"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "denv"; Description = "Print a container environment"; Usage = "denv <container>"; Deps = "" }
        [pscustomobject]@{ Category = "docker"; Name = "dbuild"; Description = "Build an image tagged from the directory name"; Usage = "dbuild [tag]"; Deps = "" }
        [pscustomobject]@{ Category = "k8s"; Name = "ktop"; Description = "Pods by CPU or memory"; Usage = "ktop [cpu|memory]"; Deps = "kubectl" }
        [pscustomobject]@{ Category = "k8s"; Name = "kevents"; Description = "Namespace events, most recent last"; Usage = "kevents"; Deps = "kubectl" }
        [pscustomobject]@{ Category = "k8s"; Name = "kns"; Description = "Set the current kubectl namespace"; Usage = "kns <namespace>"; Deps = "kubectl" }
        [pscustomobject]@{ Category = "k8s"; Name = "kdesc"; Description = "Describe a pod (fzf or name)"; Usage = "kdesc [pod-name]"; Deps = "fzf,kubectl" }
        [pscustomobject]@{ Category = "k8s"; Name = "kport"; Description = "Port-forward to a pod"; Usage = "kport <local-port> <pod> <remote-port>"; Deps = "kubectl" }
        [pscustomobject]@{ Category = "go"; Name = "covreport"; Description = "Go tests with HTML coverage report"; Usage = "covreport"; Deps = "" }
        [pscustomobject]@{ Category = "go"; Name = "gomodwhy"; Description = "Why a module is in the Go graph"; Usage = "gomodwhy <module-path>"; Deps = "" }
        [pscustomobject]@{ Category = "go"; Name = "goclean"; Description = "gofmt, vet, and mod tidy"; Usage = "goclean"; Deps = "" }
        [pscustomobject]@{ Category = "go"; Name = "goupdate"; Description = "Upgrade Go module dependencies"; Usage = "goupdate"; Deps = "" }
        [pscustomobject]@{ Category = "go"; Name = "gobench"; Description = "Run Go benchmarks with memory stats"; Usage = "gobench [pattern]"; Deps = "" }
        [pscustomobject]@{ Category = "node"; Name = "npmclean"; Description = "Delete node_modules and reinstall"; Usage = "npmclean"; Deps = "" }
        [pscustomobject]@{ Category = "node"; Name = "npmscripts"; Description = "List package.json scripts"; Usage = "npmscripts"; Deps = "" }
        [pscustomobject]@{ Category = "node"; Name = "npmoutdated"; Description = "Show outdated npm dependencies"; Usage = "npmoutdated"; Deps = "" }
        [pscustomobject]@{ Category = "node"; Name = "npmsize"; Description = "Size of node_modules"; Usage = "npmsize"; Deps = "" }
        [pscustomobject]@{ Category = "python"; Name = "venvcreate"; Description = "Create and activate .\venv"; Usage = "venvcreate"; Deps = "" }
        [pscustomobject]@{ Category = "python"; Name = "pyclean"; Description = "Remove __pycache__ and .pyc files"; Usage = "pyclean"; Deps = "" }
        [pscustomobject]@{ Category = "python"; Name = "pyfreeze"; Description = "Write requirements.txt from pip freeze"; Usage = "pyfreeze"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "myip"; Description = "Public-facing IP address"; Usage = "myip"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "localip"; Description = "Local network IP address"; Usage = "localip"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "killport"; Description = "Kill whatever is listening on a port"; Usage = "killport <port> [port ...]"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "portwho"; Description = "Process listening on a TCP port"; Usage = "portwho <port>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "dnscheck"; Description = "A, CNAME, and MX records"; Usage = "dnscheck <domain>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "httpstatus"; Description = "HTTP status code for a URL"; Usage = "httpstatus <url>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "apihit"; Description = "GET a URL, pretty-print JSON, show timing"; Usage = "apihit <url>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "flushdns"; Description = "Flush the local DNS cache"; Usage = "flushdns"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "weather"; Description = "Weather via wttr.in"; Usage = "weather [location]"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "tcpcheck"; Description = "TCP reachability check"; Usage = "tcpcheck <host> <port>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "shorten"; Description = "Shorten a URL with is.gd"; Usage = "shorten <url>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "pingcheck"; Description = "Five pings to a host"; Usage = "pingcheck <host>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "sshconfig"; Description = "Host entries from ~/.ssh/config"; Usage = "sshconfig"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "headers"; Description = "HTTP response headers"; Usage = "headers <url>"; Deps = "" }
        [pscustomobject]@{ Category = "net"; Name = "proxy"; Description = "Toggle http(s)_proxy env vars"; Usage = "proxy <on [host:port]|off|status>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "passgen"; Description = "Random base64 password"; Usage = "passgen [bytes]"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "pubkey"; Description = "Print SSH public keys"; Usage = "pubkey"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "genssh"; Description = "Generate an ed25519 SSH keypair"; Usage = "genssh <key-name> [email]"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "b64e"; Description = "Base64-encode text"; Usage = "b64e <text>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "b64d"; Description = "Base64-decode text"; Usage = "b64d <base64-text>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "urlencode"; Description = "URL-encode text"; Usage = "urlencode <text>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "urldecode"; Description = "URL-decode text"; Usage = "urldecode <text>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "hashfile"; Description = "MD5, SHA1, and SHA256 of a file"; Usage = "hashfile <file>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "genuuid"; Description = "Random UUID v4"; Usage = "genuuid"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "jwtdecode"; Description = "Decode a JWT header and payload"; Usage = "jwtdecode <token>"; Deps = "" }
        [pscustomobject]@{ Category = "security"; Name = "dotenv-check"; Description = "Lint a .env file"; Usage = "dotenv-check [file]"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "mem"; Description = "Physical memory usage"; Usage = "mem"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "cpu"; Description = "Snapshot of CPU/process activity"; Usage = "cpu"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "pidtree"; Description = "Process tree for a PID"; Usage = "pidtree <pid>"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "now"; Description = "Current date and time"; Usage = "now"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "timer"; Description = "Countdown timer"; Usage = "timer <seconds> [label]"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "diskusage"; Description = "Disk usage summary"; Usage = "diskusage [path]"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "envdiff"; Description = "Diff two .env files by key"; Usage = "envdiff <file1> <file2>"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "ports"; Description = "Listening TCP ports"; Usage = "ports"; Deps = "" }
        [pscustomobject]@{ Category = "system"; Name = "sysinfo"; Description = "One-screen system summary"; Usage = "sysinfo"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "note"; Description = "Append a timestamped note to ~/notes"; Usage = "note <text>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "jsonpp"; Description = "Pretty-print a JSON file"; Usage = "jsonpp <file>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "envload"; Description = "Load a .env file into the environment"; Usage = "envload [file]"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "ffind"; Description = "Find files by name or search contents"; Usage = "ffind <text> | ffind -f <filename>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "cheat"; Description = "tldr or Get-Help for a command"; Usage = "cheat <command>"; Deps = "tldr" }
        [pscustomobject]@{ Category = "prod"; Name = "calc"; Description = "Command-line calculator"; Usage = "calc <expression>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "qr"; Description = "QR code in the terminal"; Usage = "qr <text>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "todo"; Description = "Append or list entries in ~/todo.md"; Usage = "todo [text]"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "mkproject"; Description = "Scaffold a project directory"; Usage = "mkproject <name> [go|node|python]"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "epoch"; Description = "Unix epoch and human datetime"; Usage = "epoch [epoch|date]"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "diffjson"; Description = "Normalized diff of two JSON files"; Usage = "diffjson <file-a> <file-b>"; Deps = "" }
        [pscustomobject]@{ Category = "prod"; Name = "retry"; Description = "Retry a command with exponential backoff"; Usage = "retry <max-attempts> <command> [args...]"; Deps = "" }
        [pscustomobject]@{ Category = "jenkins"; Name = "jenk-crumb"; Description = "Jenkins CSRF crumb"; Usage = "jenk-crumb"; Deps = "" }
        [pscustomobject]@{ Category = "jenkins"; Name = "jenk-build"; Description = "Trigger a Jenkins job build"; Usage = "jenk-build <job-name>"; Deps = "" }
        [pscustomobject]@{ Category = "jenkins"; Name = "jenk-logs"; Description = "Console log of the last Jenkins build"; Usage = "jenk-logs <job-name>"; Deps = "" }
        [pscustomobject]@{ Category = "jenkins"; Name = "jenk-jobs"; Description = "List Jenkins job names"; Usage = "jenk-jobs"; Deps = "" }
        [pscustomobject]@{ Category = "meta"; Name = "sharmory"; Description = "Interactive catalog and dispatcher"; Usage = "sharmory [list|help|run|doctor]"; Deps = "" }
        [pscustomobject]@{ Category = "meta"; Name = "sharmory-doctor"; Description = "Environment health check"; Usage = "sharmory doctor"; Deps = "" }
        [pscustomobject]@{ Category = "meta"; Name = "sharmory-setup"; Description = "Install optional CLI tools (fzf, jq, ...)"; Usage = "sharmory-setup"; Deps = "" }
        [pscustomobject]@{ Category = "meta"; Name = "sharmory-update"; Description = "Download the latest Sharmory from GitHub"; Usage = "sharmory-update"; Deps = "" }
    )
}

function Get-SharmoryRegistryEntry {
    param([Parameter(Mandatory)][string]$Name)
    Get-SharmoryRegistry | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
}

function Show-SharmoryUsage {
    @"
Usage: sharmory [list|help|run|doctor|setup] [args]

  sharmory                    Interactive HUD (fzf, or a numbered menu)
  sharmory list [category]    List commands
  sharmory help [name]        Explain a command (or this orchestrator)
  sharmory run <name> [args]  Run a catalogued command
  sharmory doctor             Environment health check
  sharmory setup              Install optional CLI tools (fzf, jq, eza, tldr)

Categories: files git docker k8s go node python net security system prod jenkins meta
"@
}

function Show-SharmoryList {
    param([string]$Category)
    $rows = Get-SharmoryRegistry
    if ($Category) {
        $rows = $rows | Where-Object { $_.Category -eq $Category }
    }
    if (-not $rows) {
        Write-Output "No commands in category: $Category"
        return
    }
    Write-Output ("{0,-10} {1,-22} {2}" -f "CATEGORY", "NAME", "DESCRIPTION")
    Write-Output ("{0,-10} {1,-22} {2}" -f "--------", "----", "-----------")
    foreach ($r in $rows) {
        Write-Output ("{0,-10} {1,-22} {2}" -f $r.Category, $r.Name, $r.Description)
    }
}

function Show-SharmoryHelp {
    param([string]$Name)
    if (-not $Name -or $Name -eq "sharmory") {
        Show-SharmoryUsage
        return
    }
    $row = Get-SharmoryRegistryEntry $Name
    if (-not $row) {
        Write-Output "Unknown command: $Name"
        Write-Output "Try: sharmory list"
        return
    }
    Write-Output "$($row.Name)  ($($row.Category))"
    Write-Output "  $($row.Description)"
    Write-Output "  Usage: $($row.Usage)"
    if ($row.Deps) {
        Write-Output "  Optional: $($row.Deps)"
    }
}

function Invoke-SharmoryRun {
    param(
        [string]$Name,
        [string[]]$RunArgs
    )
    if (-not $Name) {
        Write-Output "Usage: sharmory run <name> [args...]"
        return
    }
    if ($Name -eq "sharmory") {
        Show-SharmoryUsage
        return
    }
    if ($Name -eq "sharmory-doctor" -or $Name -eq "doctor") {
        sharmory-doctor
        return
    }
    if ($Name -eq "sharmory-setup" -or $Name -eq "setup") {
        sharmory-setup
        return
    }
    $row = Get-SharmoryRegistryEntry $Name
    if (-not $row) {
        Write-Output "Unknown command: $Name"
        return
    }
    $fn = Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue
    if (-not $fn) {
        Write-Output "Not defined in this shell: $Name"
        return
    }
    if ($RunArgs -and $RunArgs.Count -gt 0) {
        & $Name @RunArgs
    } else {
        & $Name
    }
}

function Test-SharmoryNeedsArgs {
    param([string]$Usage)
    return ($Usage -like "*<*")
}

function Invoke-SharmoryPromptAndRun {
    param([string]$Name)
    if ($Name -eq "sharmory") {
        Show-SharmoryUsage
        return
    }
    if ($Name -eq "sharmory-doctor" -or $Name -eq "doctor") {
        sharmory-doctor
        return
    }
    if ($Name -eq "sharmory-setup" -or $Name -eq "setup") {
        sharmory-setup
        return
    }
    $row = Get-SharmoryRegistryEntry $Name
    if (-not $row) {
        Write-Output "Unknown command: $Name"
        return
    }
    Write-Host ""
    Show-SharmoryHelp $Name
    if (Test-SharmoryNeedsArgs $row.Usage) {
        $line = Read-Host "args (empty cancels)"
        if (-not $line) {
            Write-Host "Cancelled."
            return
        }
        $split = $line -split '\s+', 0, "RegexMatch"
        Invoke-SharmoryRun $Name $split
    } else {
        Invoke-SharmoryRun $Name @()
    }
}

function Start-SharmoryHudFzf {
    $entries = Get-SharmoryRegistry
    while ($true) {
        $tsv = foreach ($r in $entries) {
            $dep = if ($r.Deps) { $r.Deps } else { "none" }
            "{0}`t{1}`t{2}`t{3}`t{4}" -f $r.Category, $r.Name, $r.Description, $r.Usage, $dep
        }
        $selection = $tsv | fzf --delimiter="`t" --with-nth=1,2,3 --prompt="sharmory> " --header="Enter to run, Esc to quit" --preview="printf 'Usage: %s\nOptional: %s\n' {4} {5}" --preview-window="down,3:wrap"
        if (-not $selection) { return }
        $name = ($selection -split "`t")[1]
        Invoke-SharmoryPromptAndRun $name
        Write-Host ""
    }
}

function Start-SharmoryHudMenu {
    $entries = @(Get-SharmoryRegistry)
    Write-Host "Sharmory HUD  (no fzf - numbered menu)"
    Write-Host "Commands: list [cat] | help <name> | <number> | <name> | doctor | setup | q"
    Write-Host ""
    Write-Host ("  {0,3}  {1,-10} {2,-22} {3}" -f "#", "CATEGORY", "NAME", "DESCRIPTION")
    $i = 1
    foreach ($r in $entries) {
        Write-Host ("  {0,3}  {1,-10} {2,-22} {3}" -f $i, $r.Category, $r.Name, $r.Description)
        $i++
    }
    while ($true) {
        $line = Read-Host "sharmory"
        if ($null -eq $line) { return }
        $line = $line.Trim()
        if (-not $line) { continue }
        $parts = $line -split '\s+', 2
        $cmd = $parts[0]
        $rest = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        switch -Regex ($cmd) {
            '^(q|quit|exit)$' { return }
            '^doctor$' { sharmory-doctor }
            '^setup$' { sharmory-setup }
            '^list$' { Show-SharmoryList $rest }
            '^help$' {
                if ($rest) { Show-SharmoryHelp $rest } else { Show-SharmoryUsage }
            }
            '^\d+$' {
                $idx = [int]$cmd
                if ($idx -lt 1 -or $idx -gt $entries.Count) {
                    Write-Output "No command numbered $idx"
                } else {
                    Invoke-SharmoryPromptAndRun $entries[$idx - 1].Name
                }
            }
            default { Invoke-SharmoryPromptAndRun $cmd }
        }
        Write-Host ""
    }
}

function Start-SharmoryHud {
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        Start-SharmoryHudFzf
    } else {
        Start-SharmoryHudMenu
    }
}

function Get-SharmoryInstallHint {
    param([string]$Tool)
    switch ($Tool) {
        "fzf" { "winget install fzf  |  brew install fzf  |  apt install fzf" }
        "jq" { "winget install jqlang.jq  |  brew install jq  |  apt install jq" }
        "eza" { "winget install eza-community.eza  |  brew install eza" }
        "tldr" { "winget install tldr  |  npm install -g tldr  |  brew install tldr" }
        "python" { "winget install Python.Python.3.12  |  brew install python" }
        "go" { "winget install GoLang.Go  |  brew install go" }
        "node" { "winget install OpenJS.NodeJS  |  brew install node" }
        "openssl" { "winget install ShiningLight.OpenSSL  |  brew install openssl" }
        default { "install $Tool via your package manager" }
    }
}

function Get-SharmorySetupWhy {
    param([string]$Tool)
    switch ($Tool) {
        "fzf" { "fuzzy HUD, gstash, kdesc" }
        "jq" { "jsonpp, Jenkins helpers" }
        "eza" { "richer lsd listings" }
        "tldr" { "cheat examples" }
        default { "optional Sharmory helper" }
    }
}

function Get-SharmoryWingetId {
    param([string]$Tool)
    switch ($Tool) {
        "fzf" { "junegunn.fzf" }
        "jq" { "jqlang.jq" }
        "eza" { "eza-community.eza" }
        "tldr" { "tldr" }
        default { $Tool }
    }
}

function Install-SharmoryOptionalTool {
    param([string]$Tool)
    $id = Get-SharmoryWingetId $Tool
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "-> winget install --id $id"
        winget install --id $id -e --accept-package-agreements --accept-source-agreements
        return
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "-> scoop install $Tool"
        scoop install $Tool
        return
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "-> choco install $Tool -y"
        choco install $Tool -y
        return
    }
    Write-Host "No winget, scoop, or chocolatey found."
    Write-Host ("  " + (Get-SharmoryInstallHint $Tool))
}

# Install optional CLI enhancers. Never installs Docker/K8s/Go/Node/Python.
function sharmory-setup {
    $tools = @("fzf", "jq", "eza", "tldr")
    Write-Output "Sharmory setup"
    Write-Output "Optional CLI tools only. Skips Docker, Kubernetes, Go, Node, and Python."
    Write-Output ""

    $missing = @()
    foreach ($t in $tools) {
        if (Get-Command $t -ErrorAction SilentlyContinue) {
            Write-Output ("  [ok]   {0,-8} {1}" -f $t, (Get-SharmorySetupWhy $t))
        } else {
            Write-Output ("  [miss] {0,-8} {1}" -f $t, (Get-SharmorySetupWhy $t))
            $missing += $t
        }
    }

    if ($missing.Count -eq 0) {
        Write-Output ""
        Write-Output "Nothing to install."
        return
    }

    if (-not (Test-SharmoryInteractiveInput)) {
        Write-Output ""
        Write-Output "Not a TTY - no installs. Re-run sharmory-setup in a terminal, or:"
        foreach ($t in $missing) {
            Write-Output ("  " + (Get-SharmoryInstallHint $t))
        }
        return
    }

    Write-Host ""
    Write-Host "For each missing tool: [i]nstall  [s]kip  [a] skip all remaining  [q]uit"
    foreach ($t in $missing) {
        Write-Host ""
        Write-Host "$t - $(Get-SharmorySetupWhy $t)"
        Write-Host ("  hint: " + (Get-SharmoryInstallHint $t))
        $choice = Read-Host "  [i/s/a/q]"
        if ($null -eq $choice) { return }
        $choice = $choice.Trim().ToLower()
        switch -Regex ($choice) {
            '^(i|install|y|yes)$' { Install-SharmoryOptionalTool $t }
            '^(a|all)$' { Write-Host "Skipping remaining tools."; return }
            '^(q|quit)$' { Write-Host "Stopped."; return }
            default { Write-Host "Skipped $t." }
        }
    }
    Write-Host ""
    Write-Host "Done. New tools are available in new shells (or after refreshing PATH)."
}

function Write-SharmoryDoctorLine {
    param([string]$Status, [string]$Label, [string]$Detail)
    Write-Output ("  [{0}] {1,-12} {2}" -f $Status, $Label, $Detail)
}

function sharmory-doctor {
    $ok = 0; $warn = 0; $miss = 0
    Write-Output "Sharmory doctor"
    Write-Output ""

    $loaded = [bool](Get-Command sharmory -CommandType Function -ErrorAction SilentlyContinue)
    if ($loaded) {
        Write-SharmoryDoctorLine "ok" "Sharmory" "loaded"
        $ok++
    } else {
        Write-SharmoryDoctorLine "miss" "Sharmory" "not sourced"
        $miss++
    }

    $installPath = Join-Path $HOME "sharmory\functions.ps1"
    if (Test-Path $installPath) {
        Write-SharmoryDoctorLine "ok" "Install" $installPath
        $ok++
    } else {
        Write-SharmoryDoctorLine "warn" "Install" "canonical path not found ($installPath)"
        $warn++
    }

    Write-SharmoryDoctorLine "ok" "Shell" ("PowerShell {0}" -f $PSVersionTable.PSVersion)
    $ok++

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gver = (git --version 2>$null)
        $gname = (git config user.name 2>$null)
        $gmail = (git config user.email 2>$null)
        if ($gname -and $gmail) {
            Write-SharmoryDoctorLine "ok" "Git" "$gver ($gname <$gmail>)"
            $ok++
        } else {
            Write-SharmoryDoctorLine "warn" "Git" "$gver (user.name/email not set)"
            $warn++
        }
    } else {
        Write-SharmoryDoctorLine "miss" "Git" "not installed"
        $miss++
    }

    $pubs = @(Get-ChildItem "$HOME\.ssh\*.pub" -ErrorAction SilentlyContinue)
    if ($pubs.Count -gt 0) {
        Write-SharmoryDoctorLine "ok" "SSH" "$($pubs.Count) public key(s) in ~/.ssh"
        $ok++
    } else {
        Write-SharmoryDoctorLine "warn" "SSH" "no ~/.ssh/*.pub keys found"
        $warn++
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerCmd = Get-Command docker
        $daemonOk = $false
        if ($dockerCmd.CommandType -eq "Function") {
            $daemonOk = $true
        } else {
            docker info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { $daemonOk = $true }
        }
        if ($daemonOk) {
            Write-SharmoryDoctorLine "ok" "Docker" "daemon reachable"
            $ok++
        } else {
            Write-SharmoryDoctorLine "warn" "Docker" "installed, daemon not reachable"
            $warn++
        }
    } else {
        Write-SharmoryDoctorLine "miss" "Docker" "not installed"
        $miss++
    }

    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        Write-SharmoryDoctorLine "ok" "kubectl" "installed"
        $ok++
    } else {
        Write-SharmoryDoctorLine "miss" "kubectl" "not installed"
        $miss++
    }

    Write-Output ""
    Write-Output "Optional tools"
    foreach ($tool in @("fzf", "jq", "eza", "tldr", "python", "go", "node", "openssl")) {
        $check = $tool
        if ($tool -eq "python" -and -not (Get-Command python -ErrorAction SilentlyContinue)) {
            $check = "python3"
        }
        if (Get-Command $check -ErrorAction SilentlyContinue) {
            Write-SharmoryDoctorLine "ok" $tool "installed"
            $ok++
        } else {
            Write-SharmoryDoctorLine "miss" $tool (Get-SharmoryInstallHint $tool)
            $miss++
        }
    }

    Write-Output ""
    Write-Output ("  {0} ok  {1} warn  {2} miss" -f $ok, $warn, $miss)
    Write-Output ""
    if (-not $loaded) { return }
}

function Test-SharmoryInteractiveInput {
    try {
        return -not [Console]::IsInputRedirected
    } catch {
        return $false
    }
}

function sharmory {
    param(
        [Parameter(Position = 0)]
        [string]$Command,
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    if (-not $Command) {
        if (-not (Test-SharmoryInteractiveInput)) {
            Show-SharmoryUsage
            Write-Output ""
            Show-SharmoryList
            return
        }
        Start-SharmoryHud
        return
    }

    switch ($Command) {
        { $_ -in @("-h", "--help", "help") } {
            $name = if ($Rest -and $Rest.Count -gt 0) { $Rest[0] } else { $null }
            Show-SharmoryHelp $name
        }
        "list" {
            $cat = if ($Rest -and $Rest.Count -gt 0) { $Rest[0] } else { $null }
            Show-SharmoryList $cat
        }
        "run" {
            if (-not $Rest -or $Rest.Count -eq 0) {
                Write-Output "Usage: sharmory run <name> [args...]"
                return
            }
            $runName = $Rest[0]
            $runArgs = @()
            if ($Rest.Count -gt 1) { $runArgs = $Rest[1..($Rest.Count - 1)] }
            Invoke-SharmoryRun $runName $runArgs
        }
        "doctor" { sharmory-doctor }
        "setup" { sharmory-setup }
        default {
            Write-Output "Unknown subcommand: $Command"
            Show-SharmoryUsage
        }
    }
}

