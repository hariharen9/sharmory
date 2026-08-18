#!/usr/bin/env zsh
#
# Sharmory — a collection of dev-focused zsh functions
# Source this file from your .zshrc:
#   source /path/to/functions.zsh
#
# Optional dependencies used by some functions (all fail gracefully if missing):
#   fzf, jq, eza, gh, tldr, entr/fswatch, httpie, ncdu
#
#########################################################################
# 0. INTERNAL HELPERS
#########################################################################

# Detect OS once so functions can branch cheaply
_sharmory_os() {
    case "$(uname)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

# Print a standardized "missing dependency" message and return failure
_sharmory_need() {
    if ! command -v "$1" &>/dev/null; then
        echo "⚠️  '$1' is required for this command. Install it and try again."
        return 1
    fi
}

#########################################################################
# 1. NAVIGATION & FILES
#########################################################################

# Make a directory and cd into it in one step
# Usage: mkcd <dir>
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <dir>"
        return 1
    fi
    mkdir -p "$1" && cd "$1"
}

# Go up N directory levels (default 1)
# Usage: up [n]
up() {
    local n=${1:-1}
    local target=""
    for _ in $(seq 1 "$n"); do target="../$target"; done
    cd "$target" || return 1
}

# Beautiful directory listing (Windows Explorer style) using eza
# Icons, git status, long format, sorted by most recently modified
lsd() {
    _sharmory_need eza || { ls -la "$@"; return; }
    eza \
        --icons \
        --group-directories-first \
        --long \
        --header \
        --git \
        --time-style=long-iso \
        --sort=modified \
        --reverse \
        --color=always \
        "$@"
}

# Interactively cd into a subdirectory picked via fzf
fcd() {
    _sharmory_need fzf || return 1
    local dir
    dir=$(find . -type d -not -path '*/.git*' 2>/dev/null | fzf --prompt="cd> ")
    [ -n "$dir" ] && cd "$dir"
}

# Fuzzy-search file contents and open the picked match in $EDITOR
ftext() {
    _sharmory_need fzf || return 1
    local line file
    line=$(grep -RIn --binary-files=without-match --exclude-dir={.git,node_modules,.venv,venv,dist,build} "" . 2>/dev/null | fzf)
    [ -z "$line" ] && return 0
    file=$(echo "$line" | cut -d: -f1)
    ${EDITOR:-vim} "$file"
}

# See permissions of a file, broken down by owner/group/other
# Usage: permsof <file>
permsof() {
    if [ -z "$1" ]; then
        echo "Usage: permsof <file>"
        return 1
    fi
    local p
    p=$(stat -f "%Sp" "$1" 2>/dev/null || stat -c "%A" "$1" 2>/dev/null)
    if [ -z "$p" ]; then
        echo "Could not read permissions for: $1"
        return 1
    fi
    echo "📄 $1"
    echo "   raw: $p"
    echo ""
    _sharmory_describe_seg() {
        local label=$1 seg=$2 r w x
        [ "${seg:0:1}" = "r" ] && r="read" || r="-"
        [ "${seg:1:1}" = "w" ] && w="write" || w="-"
        [ "${seg:2:1}" = "x" ] && x="execute" || x="-"
        printf "   %-6s %-8s %-8s %-8s\n" "$label" "$r" "$w" "$x"
    }
    _sharmory_describe_seg "Owner" "${p:1:3}"
    _sharmory_describe_seg "Group" "${p:4:3}"
    _sharmory_describe_seg "Other" "${p:7:3}"
}

# Auto-extract common archive formats based on file extension
# Usage: extract <archive-file>
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.tar)     tar xf "$1"  ;;
            *.tbz2)    tar xjf "$1" ;;
            *.tgz)     tar xzf "$1" ;;
            *.zip)     unzip "$1"   ;;
            *.rar)     unrar x "$1" ;;
            *.7z)      7z x "$1"    ;;
            *.gz)      gunzip "$1"  ;;
            *) echo "Unknown archive." ;;
        esac
    else
        echo "File not found: $1"
    fi
}

# Compress a file or directory into an archive
# Usage: compress <name.tar.gz|name.zip> <file-or-dir>
compress() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress <output.tar.gz|output.zip> <file-or-dir>"
        return 1
    fi
    case "$1" in
        *.tar.gz|*.tgz) tar czf "$1" "$2" ;;
        *.tar.bz2)      tar cjf "$1" "$2" ;;
        *.zip)          zip -r "$1" "$2"  ;;
        *) echo "Unsupported output extension. Use .tar.gz, .tar.bz2, or .zip" ;;
    esac
}

# Show disk usage of everything in the current directory, sorted by size
duh() {
    du -sh -- * | sort -h
}

# Show sizes of subdirectories in a path, sorted largest first
# Usage: sizeof [path]
sizeof() {
    local dir=${1:-.}
    du -sh "$dir"/*/ 2>/dev/null | sort -rh
}

# Find files above a given size (default 100M) under a directory
# Usage: findbig [size] [dir]
findbig() {
    local size=${1:-100M}
    local dir=${2:-.}
    find "$dir" -type f -size +"$size" -exec du -sh {} \; 2>/dev/null | sort -rh
}

# Find and optionally remove empty directories under a path
# Usage: emptydirs [dir]
emptydirs() {
    local dir=${1:-.}
    local found
    found=$(find "$dir" -type d -empty 2>/dev/null)
    if [ -z "$found" ]; then
        echo "No empty directories found."
        return 0
    fi
    echo "$found"
    read "confirm?Delete these empty directories? (y/N) "
    if [[ "$confirm" == "y" ]]; then
        echo "$found" | xargs -I{} rmdir "{}"
    fi
    return 0
}

# Find duplicate files (by MD5 hash) within a directory
# Usage: dupfind [dir]
dupfind() {
    local dir=${1:-.}
    local hash_cmd="md5sum"
    command -v md5 &>/dev/null && hash_cmd="md5 -r"
    find "$dir" -type f -exec $hash_cmd {} \; 2>/dev/null | \
        sort | \
        awk '{
            hash=$1; $1=""; file=$0
            if (hash in seen) {
                print seen[hash]
                print file
                print "---"
            } else {
                seen[hash]=file
            }
        }'
}

# Create a timestamped backup copy of a file
# Usage: bak <file>
bak() {
    if [ -z "$1" ]; then
        echo "Usage: bak <file>"
        return 1
    fi
    cp "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"
}

# Copy the current working directory path to the clipboard (cross-platform)
cwd() {
    local os
    os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        pwd | pbcopy
    elif command -v xclip &>/dev/null; then
        pwd | xclip -selection clipboard
    elif command -v wl-copy &>/dev/null; then
        pwd | wl-copy
    else
        echo "No clipboard tool found."
        pwd
        return 1
    fi
    pwd
    echo "Copied."
}

# Copy a file's contents to the clipboard (cross-platform)
# Usage: clipcopy <file>
clipcopy() {
    if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "Usage: clipcopy <file>"
        return 1
    fi
    local os
    os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        pbcopy < "$1"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$1"
    elif command -v wl-copy &>/dev/null; then
        wl-copy < "$1"
    else
        echo "No clipboard tool found."
        return 1
    fi
    echo "Copied contents of $1"
}

# Watch a file or directory and re-run a command whenever it changes
# Usage: watchrun <path> -- <command>
watchrun() {
    if [ -z "$1" ]; then
        echo "Usage: watchrun <path> -- <command...>"
        return 1
    fi
    local watch_target=$1
    shift
    [[ "$1" == "--" ]] && shift
    if command -v entr &>/dev/null; then
        find "$watch_target" -type f | entr -c "$@"
    elif command -v fswatch &>/dev/null; then
        fswatch -o "$watch_target" | while read -r; do clear; "$@"; done
    else
        echo "Install 'entr' or 'fswatch' to use watchrun."
        return 1
    fi
}

#########################################################################
# 2. GIT
#########################################################################

# Undo the last git commit but keep the changes staged
gitundo() {
    git reset --soft HEAD~1
    echo "Last commit undone. Changes are staged."
    git status --short
}

# Find local branches already merged into main/master and offer to delete them
branchclean() {
    local merged base
    base=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    base=${base:-main}
    merged=$(git branch --merged "$base" 2>/dev/null | grep -v -E "(^\*|$base|master)" | tr -d ' ')
    if [ -z "$merged" ]; then
        echo "Nothing to clean."
        return 0
    fi
    echo "Merged branches to delete:"
    echo "$merged"
    read "confirm?Delete these? (y/N) "
    [[ "$confirm" == "y" ]] && echo "$merged" | xargs -n 1 git branch -d
}

# List local git branches sorted by last commit date (most recent activity first)
branchage() {
    git for-each-ref --sort=-committerdate refs/heads/ \
        --format='%(committerdate:relative)%09%(refname:short)' | \
        awk -F'\t' '{printf "%-20s %s\n", $1, $2}'
}

# Show today's commits authored by you (since midnight)
gitlog-today() {
    git log --since=midnight --oneline --author="$(git config user.name)"
}

# Git add + commit + push in one step, with a confirmation prompt if on main/master
# Usage: gacp <commit message>
gacp() {
    if [ -z "$1" ]; then
        echo "Usage: gacp <commit message>"
        return 1
    fi
    local branch
    branch=$(git branch --show-current)
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        read "confirm?⚠️  You're on '$branch'. Push directly? (y/N) "
        [[ "$confirm" != "y" ]] && echo "Aborted." && return 1
    fi
    git add -A && git commit -m "$1" && git push origin "$branch"
}

# Clone a repo and cd straight into it
# Usage: gclone <repo-url> [dir]
gclone() {
    if [ -z "$1" ]; then
        echo "Usage: gclone <repo-url> [dir]"
        return 1
    fi
    git clone "$1" "$2" && cd "$(basename "${2:-${1%.git}}")" || return 1
}

# Commit "work in progress" — quick checkpoint commit for uncommitted changes
gwip() {
    git add -A && git commit -m "WIP: $(date +%Y-%m-%d\ %H:%M)"
}

# Undo the last WIP commit created by gwip (soft reset, keeps changes staged)
gunwip() {
    local msg
    msg=$(git log -1 --pretty=%B)
    if [[ "$msg" == WIP:* ]]; then
        git reset --soft HEAD~1
        echo "WIP commit undone."
    else
        echo "Last commit isn't a WIP commit, aborting."
    fi
}

# Delete local remote-tracking branches whose remote counterpart is gone
gitprune() {
    git fetch --prune
    git branch -vv | awk '/: gone]/{print $1}' | xargs -r -n 1 git branch -d
}

# Interactively pick a branch to switch to via fzf, including remotes
gswitch() {
    _sharmory_need fzf || return 1
    local branch
    branch=$(git branch -a --format='%(refname:short)' | grep -v HEAD | sort -u | fzf --prompt="branch> ")
    [ -z "$branch" ] && return 0
    git switch "${branch#origin/}" 2>/dev/null || git switch -c "${branch#origin/}" "$branch"
}

# Diff the current branch against main/master (or a given base)
# Usage: prdiff [base-branch]
prdiff() {
    local base=${1:-main}
    git diff "$base"...HEAD
}

# Show contributor commit counts for the current repo, sorted by count
gitcontributors() {
    git log --format='%aN' | sort | uniq -c | sort -rn
}

# Show total size of the .git directory
gitsize() {
    du -sh .git 2>/dev/null
}

# List files with unresolved merge conflicts
gitconflicts() {
    git diff --name-only --diff-filter=U
}

# Fetch a .gitignore template from gitignore.io and append it to .gitignore
# Usage: gitignore <lang1,lang2,...>  e.g. gitignore go,node,macos
gitignore() {
    if [ -z "$1" ]; then
        echo "Usage: gitignore <lang1,lang2,...>  e.g. gitignore go,node,macos"
        return 1
    fi
    curl -sL "https://www.toptal.com/developers/gitignore/api/$1" >> .gitignore
    echo "Appended $1 templates to .gitignore"
}

#########################################################################
# 3. DOCKER & KUBERNETES
#########################################################################

# Force stop and remove a container by name or ID
# Usage: dockernuke <container-name-or-id>
dockernuke() {
    if [ -z "$1" ]; then
        echo "Usage: dockernuke <container-name-or-id>"
        return 1
    fi
    docker stop "$1" 2>/dev/null
    docker rm -f "$1" 2>/dev/null
    echo "Removed: $1"
}

# List dangling Docker images and offer to remove them
dockerclean-images() {
    local dangling
    dangling=$(docker images -f "dangling=true" -q)
    if [ -z "$dangling" ]; then
        echo "No dangling images."
        return 0
    fi
    docker images -f "dangling=true"
    read "confirm?Remove these images? (y/N) "
    [[ "$confirm" == "y" ]] && docker rmi $dangling
}

# Remove all unused Docker data (containers, images, networks, build cache)
dclean() {
    docker system prune -af
}

# Tail logs (with timestamps) for a given container
# Usage: dockerlogs <container-name-or-id>
dockerlogs() {
    if [ -z "$1" ]; then
        echo "Usage: dockerlogs <container-name-or-id>"
        return 1
    fi
    docker logs -f --timestamps "$1"
}

# Interactively pick a running container via fzf and open a shell inside it
dsh() {
    _sharmory_need fzf || return 1
    local cid
    cid=$(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | fzf | awk '{print $1}')
    [ -z "$cid" ] && return 0
    docker exec -it "$cid" sh -c "command -v bash >/dev/null && exec bash || exec sh"
}

# Show human-readable sizes of local Docker images
dockersizes() {
    docker images --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' | sort -k2 -h
}

# Interactively pick a kubectl context and namespace via fzf, and switch to them
k8sctx() {
    _sharmory_need fzf || return 1
    _sharmory_need kubectl || return 1
    local ctx ns
    ctx=$(kubectl config get-contexts -o name | fzf --prompt="context> ")
    [ -z "$ctx" ] && return 1
    kubectl config use-context "$ctx"
    ns=$(kubectl get ns -o name | sed 's|namespace/||' | fzf --prompt="namespace> ")
    [ -z "$ns" ] && return 0
    kubectl config set-context --current --namespace="$ns"
    echo "Switched to context '$ctx', namespace '$ns'"
}

# Interactively pick a pod via fzf and stream its logs
klogs() {
    _sharmory_need fzf || return 1
    local pod
    pod=$(kubectl get pods -o name | fzf --prompt="pod> " | sed 's|pod/||')
    [ -z "$pod" ] && return 0
    kubectl logs -f "$pod" "$@"
}

# Interactively pick a pod via fzf and exec a shell into it
kexec() {
    _sharmory_need fzf || return 1
    local pod
    pod=$(kubectl get pods -o name | fzf --prompt="pod> " | sed 's|pod/||')
    [ -z "$pod" ] && return 0
    kubectl exec -it "$pod" -- sh -c "command -v bash >/dev/null && exec bash || exec sh"
}

# Show which pods are consuming the most CPU/memory (requires metrics-server)
ktop() {
    kubectl top pods --sort-by="${1:-cpu}"
}

# Describe events for the current namespace, most recent last
kevents() {
    kubectl get events --sort-by='.lastTimestamp'
}

#########################################################################
# 4. GO DEVELOPMENT
#########################################################################

# Run Go tests with coverage and open the HTML coverage report in the browser
covreport() {
    go test ./... -coverprofile=/tmp/cover.out && \
    go tool cover -html=/tmp/cover.out -o /tmp/cover.html && \
    open /tmp/cover.html 2>/dev/null || xdg-open /tmp/cover.html 2>/dev/null
}

# Explain why a given module is in the Go dependency graph
# Usage: gomodwhy <module-path>
gomodwhy() {
    if [ -z "$1" ]; then
        echo "Usage: gomodwhy <module-path>"
        return 1
    fi
    echo "Why is $1 in the dependency graph?"
    echo "---"
    go mod why -m "$1"
}

# Tidy, vet, and format a Go module in one pass
goclean() {
    gofmt -l -w .
    go vet ./...
    go mod tidy
}

# Upgrade all direct and indirect Go dependencies to their latest versions
goupdate() {
    go get -u ./...
    go mod tidy
}

# Run Go benchmarks for the current package with memory stats
# Usage: gobench [pattern]
gobench() {
    go test -bench="${1:-.}" -benchmem ./...
}

# Scaffold a minimal new Go module in the current directory
# Usage: gonew <module-path>  e.g. gonew github.com/user/project
gonew() {
    if [ -z "$1" ]; then
        echo "Usage: gonew <module-path>"
        return 1
    fi
    go mod init "$1"
    cat > main.go <<'EOF'
package main

import "fmt"

func main() {
	fmt.Println("Hello, world!")
}
EOF
    echo "Initialized Go module $1 with a starter main.go"
}

# Watch .go files and re-run tests on save (requires entr)
gowatch() {
    _sharmory_need entr || return 1
    find . -name '*.go' | entr -c go test ./...
}

#########################################################################
# 5. NODE / NPM
#########################################################################

# Delete node_modules and lockfile, then reinstall from scratch
npmclean() {
    rm -rf node_modules package-lock.json
    npm install
}

# List the scripts defined in package.json
npmscripts() {
    _sharmory_need jq || return 1
    jq -r '.scripts | to_entries[] | "\(.key): \(.value)"' package.json
}

# Show outdated dependencies in a compact form
npmoutdated() {
    npm outdated
}

# Print the size of node_modules
npmsize() {
    du -sh node_modules 2>/dev/null
}

#########################################################################
# 6. PYTHON
#########################################################################

# Create and activate a Python virtual environment in ./venv
venvcreate() {
    python3 -m venv venv && source venv/bin/activate
    echo "Virtualenv created and activated. Run 'deactivate' to exit."
}

# Remove all __pycache__ dirs and .pyc files recursively
pyclean() {
    find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null
    find . -type f -name '*.pyc' -delete
    echo "Cleaned Python cache files."
}

# Freeze current environment's packages into requirements.txt
pyfreeze() {
    pip freeze > requirements.txt
    echo "Wrote $(wc -l < requirements.txt) packages to requirements.txt"
}

#########################################################################
# 7. NETWORKING & APIs
#########################################################################

# Print your public-facing IP address
myip() {
    curl -s ifconfig.me
    echo
}

# Print your local network IP address
localip() {
    if [[ "$(_sharmory_os)" == "macos" ]]; then
        ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
    else
        hostname -I 2>/dev/null | awk '{print $1}'
    fi
}

# Find and kill whatever process is listening on the given port(s)
# Tries a normal kill first, then force-kills if it doesn't exit
# Usage: killport <port> [port ...]
killport() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: killport <port> [port ...]"
        return 1
    fi
    for PORT in "$@"; do
        local PID
        PID=$(lsof -t -i :"$PORT")
        if [[ -z "$PID" ]]; then
            echo "❌ Nothing is listening on port $PORT."
            continue
        fi
        echo "🔄 Found process (PID: $PID) using port $PORT."
        echo "⏳ Terminating..."
        kill "$PID"
        sleep 0.5
        if ps -p "$PID" >/dev/null 2>&1; then
            echo "⚠️ Process didn't exit cleanly. Force killing..."
            kill -9 "$PID"
        fi
        echo "✅ Port $PORT is now free."
        echo
    done
}

# Show which process is listening on a given TCP port
# Usage: portwho <port>
portwho() {
    if [ -z "$1" ]; then
        echo "Usage: portwho <port>"
        return 1
    fi
    lsof -i :"$1" -sTCP:LISTEN -P -n | awk 'NR==1 || NR==2 {print}'
}

# Check a domain's TLS certificate expiry date and days remaining
# Usage: certcheck <domain>
certcheck() {
    if [ -z "$1" ]; then
        echo "Usage: certcheck <domain>"
        return 1
    fi
    local expiry
    expiry=$(echo | openssl s_client -servername "$1" -connect "$1":443 2>/dev/null | \
        openssl x509 -noout -enddate | cut -d= -f2)
    echo "Expires: $expiry"
    local expiry_epoch now_epoch days_left
    expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null || date -d "$expiry" +%s)
    now_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    echo "Days remaining: $days_left"
}

# Look up A, CNAME, and MX records for a domain
# Usage: dnscheck <domain>
dnscheck() {
    if [ -z "$1" ]; then
        echo "Usage: dnscheck <domain>"
        return 1
    fi
    echo "A records:"
    dig +short A "$1"
    echo "\nCNAME:"
    dig +short CNAME "$1"
    echo "\nMX records:"
    dig +short MX "$1"
}

# Fetch just the HTTP status code for a URL and describe what it means
# Usage: httpstatus <url>
httpstatus() {
    if [ -z "$1" ]; then
        echo "Usage: httpstatus <url>"
        return 1
    fi
    local code msg
    code=$(curl -o /dev/null -s -w "%{http_code}" "$1")
    case "$code" in
        2*) msg="OK" ;;
        3*) msg="Redirect" ;;
        401|403) msg="Auth/permission issue" ;;
        404) msg="Not found" ;;
        5*) msg="Server error" ;;
        *) msg="Unknown" ;;
    esac
    echo "$code — $msg"
}

# Hit a URL with curl, pretty-print JSON response, and show timing/status
# Usage: apihit <url> [curl-args...]
apihit() {
    if [ -z "$1" ]; then
        echo "Usage: apihit <url> [curl-args...]"
        return 1
    fi
    local url=$1
    shift
    curl -s -w "\n\n⏱  %{time_total}s | status: %{http_code}\n" "$url" "$@" | \
        (command -v jq &>/dev/null && jq . 2>/dev/null || cat)
}

# Flush the local DNS cache (macOS or Linux)
flushdns() {
    if [[ "$(_sharmory_os)" == "macos" ]]; then
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
    else
        sudo systemd-resolve --flush-caches 2>/dev/null || \
        sudo /etc/init.d/nscd restart 2>/dev/null
    fi
    echo "DNS cache flushed."
}

# Show weather for a location via wttr.in (defaults to your current location if blank)
# Usage: weather [location]
weather() {
    curl -s wttr.in/"$1"
}

# Quick TCP reachability check on host:port
# Usage: tcpcheck <host> <port>
tcpcheck() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: tcpcheck <host> <port>"
        return 1
    fi
    (echo >/dev/tcp/"$1"/"$2") &>/dev/null && echo "✅ $1:$2 is reachable" || echo "❌ $1:$2 is not reachable"
}

# Shorten a URL using is.gd
# Usage: shorten <url>
shorten() {
    if [ -z "$1" ]; then
        echo "Usage: shorten <url>"
        return 1
    fi
    curl -s "https://is.gd/create.php?format=simple&url=$1"
    echo
}

#########################################################################
# 8. SECURITY & ENCODING
#########################################################################

# Generate a random base64 password (default 24 bytes)
# Usage: passgen [bytes]
passgen() {
    openssl rand -base64 "${1:-24}"
}

# Print the contents of your SSH public key(s)
pubkey() {
    cat ~/.ssh/*.pub 2>/dev/null
}

# Generate a new ed25519 SSH keypair
# Usage: genssh <key-name> [email]
genssh() {
    if [ -z "$1" ]; then
        echo "Usage: genssh <key-name> [email]"
        return 1
    fi
    ssh-keygen -t ed25519 -f ~/.ssh/"$1" -C "${2:-$1}"
}

# Base64 encode/decode text
# Usage: b64e <text>  |  b64d <base64-text>
b64e() { echo -n "$1" | base64; }
b64d() { echo -n "$1" | base64 -d; }

# URL-encode / URL-decode text
# Usage: urlencode <text>  |  urldecode <text>
urlencode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}
urldecode() {
    python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]))" "$1"
}

# Compute MD5, SHA1, and SHA256 hashes of a file
# Usage: hashfile <file>
hashfile() {
    if [ -z "$1" ] || [ ! -f "$1" ]; then
        echo "Usage: hashfile <file>"
        return 1
    fi
    echo "MD5:    $(md5sum "$1" 2>/dev/null || md5 -q "$1")"
    echo "SHA1:   $(shasum -a 1 "$1" 2>/dev/null | awk '{print $1}')"
    echo "SHA256: $(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')"
}

# Generate a random UUID v4
genuuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    else
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

#########################################################################
# 9. SYSTEM & PROCESS
#########################################################################

# Show current physical memory usage
mem() {
    if [[ "$(_sharmory_os)" == "macos" ]]; then
        top -l 1 | grep PhysMem
    else
        free -h
    fi
}

# Show a snapshot of current CPU/process activity
cpu() {
    if [[ "$(_sharmory_os)" == "macos" ]]; then
        top -l 1 | head -15
    else
        top -bn1 | head -15
    fi
}

# Show the process tree for a given PID
# Usage: pidtree <pid>
pidtree() {
    if [ -z "$1" ]; then
        echo "Usage: pidtree <pid>"
        return 1
    fi
    if command -v pstree &>/dev/null; then
        pstree -p "$1"
    else
        ps -o pid,ppid,command -A | awk -v pid="$1" '$2 == pid || $1 == pid { print }'
    fi
}

# Interactively pick a process via fzf and kill it
fkill() {
    _sharmory_need fzf || return 1
    local pid
    pid=$(ps -eo pid,comm,args | sed 1d | fzf | awk '{print $1}')
    [ -z "$pid" ] && return 0
    kill -9 "$pid" && echo "Killed PID $pid"
}

# Print the current date and time (YYYY-MM-DD HH:MM:SS)
now() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Simple countdown timer with a notification/beep when done
# Usage: timer <seconds> [label]
timer() {
    if [ -z "$1" ]; then
        echo "Usage: timer <seconds> [label]"
        return 1
    fi
    local secs=$1 label=${2:-Timer}
    while [ $secs -gt 0 ]; do
        printf "\r%s: %02d:%02d " "$label" $((secs/60)) $((secs%60))
        sleep 1
        secs=$((secs-1))
    done
    printf "\r%s: done!            \n" "$label"
    command -v afplay &>/dev/null && afplay /System/Library/Sounds/Glass.aiff 2>/dev/null
    echo -e "\a"
}

#########################################################################
# 10. PRODUCTIVITY & MISC
#########################################################################

# Append a timestamped note to today's markdown notes file (~/notes/YYYY-MM-DD.md)
# Usage: note <text>
note() {
    if [ -z "$1" ]; then
        echo "Usage: note <text>"
        return 1
    fi
    local dir="$HOME/notes"
    local file="$dir/$(date +%Y-%m-%d).md"
    mkdir -p "$dir"
    echo "- $(date +%H:%M) $*" >> "$file"
    echo "Saved to $file"
}

# Pretty-print a JSON file
# Usage: jsonpp <file>
jsonpp() {
    _sharmory_need jq || return 1
    jq . "$1"
}

# Load variables from a .env-style file into the current shell session
# Usage: envload [file]  (defaults to .env)
envload() {
    local file=${1:-.env}
    if [ ! -f "$file" ]; then
        echo "No such file: $file"
        return 1
    fi
    set -a
    source "$file"
    set +a
    echo "Loaded $(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$file") vars from $file"
}

# Find files by name (fuzzy substring match) or search file contents for text
# Usage:
#   ffind -f <filename>   # find files by name
#   ffind <text>          # search file contents for text (excludes common junk dirs/binaries)
ffind() {
    if [[ "$1" == "-f" ]]; then
        shift
        if [[ -z "$1" ]]; then
            echo "Usage: ffind -f <filename>"
            return 1
        fi
        find . -iname "*$1*" 2>/dev/null
    else
        if [[ -z "$1" ]]; then
            echo "Usage:"
            echo "  ffind -f <filename>   # Find files"
            echo "  ffind <text>          # Find text in files"
            return 1
        fi
        grep -RIn \
            --color=always \
            --binary-files=without-match \
            --exclude-dir={.git,node_modules,venv,.venv,__pycache__,dist,build} \
            --exclude='*.pyc' --exclude='*.o' --exclude='*.so' --exclude='*.class' \
            --exclude='*.zip' --exclude='*.tar' --exclude='*.gz' \
            --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.gif' --exclude='*.pdf' \
            "$1" .
    fi
}

# Look up a command's usage examples via tldr (falls back to `man`)
# Usage: cheat <command>
cheat() {
    if [ -z "$1" ]; then
        echo "Usage: cheat <command>"
        return 1
    fi
    if command -v tldr &>/dev/null; then
        tldr "$1"
    else
        man "$1"
    fi
}

# Quick command-line calculator
# Usage: calc "2 + 2 * 3"
calc() {
    if [ -z "$1" ]; then
        echo "Usage: calc <expression>"
        return 1
    fi
    python3 -c "print($*)"
}

# Generate a QR code for text/URL and display it in the terminal
# Usage: qr <text>
qr() {
    if [ -z "$1" ]; then
        echo "Usage: qr <text>"
        return 1
    fi
    curl -s "https://qrenco.de/$1"
}

#########################################################################
# 11. CI / JENKINS
# (requires JENKINS_URL, JENKINS_USER, JENKINS_TOKEN env vars to be set)
#########################################################################

# Get a CSRF crumb from Jenkins (needed for authenticated POST requests)
jenk-crumb() {
    _sharmory_need jq || return 1
    curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
        "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumb'
}

# Trigger a build for the given Jenkins job name
# Usage: jenk-build <job-name>
jenk-build() {
    if [ -z "$1" ]; then
        echo "Usage: jenk-build <job-name>"
        return 1
    fi
    local crumb
    crumb=$(jenk-crumb)
    curl -s -X POST \
        -u "$JENKINS_USER:$JENKINS_TOKEN" \
        -H "Jenkins-Crumb: $crumb" \
        "$JENKINS_URL/job/$1/build"
}

# Fetch the console log of the last build for a Jenkins job
# Usage: jenk-logs <job-name>
jenk-logs() {
    if [ -z "$1" ]; then
        echo "Usage: jenk-logs <job-name>"
        return 1
    fi
    curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
        "$JENKINS_URL/job/$1/lastBuild/consoleText"
}

# List all job names available on the configured Jenkins server
jenk-jobs() {
    _sharmory_need jq || return 1
    curl -s -u "$JENKINS_USER:$JENKINS_TOKEN" \
        "$JENKINS_URL/api/json" | jq -r '.jobs[].name'
}
