#!/usr/bin/env zsh
#
# Sharmory — a collection of dev-focused zsh functions
# Source this file from your .zshrc:
#   [[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh
#
# The guard above ensures that if this file has any load-time error,
# it never aborts .zshrc mid-execution (protecting your PATH and plugins).
#
# Optional dependencies used by some functions (all fail gracefully if missing):
#   fzf, jq, eza, gh, tldr, entr/fswatch, httpie, ncdu
#
#########################################################################
# 0. INTERNAL HELPERS
#########################################################################

# Silently unalias any name Sharmory defines as a function.
# Single unalias -- call with all names: one fork instead of 40+.
# This prevents "defining function based on alias" parse errors when a plugin
# manager (oh-my-zsh, Prezto, etc.) has already claimed one of our names.
unalias -- \
    mkcd up lsd fcd ftext permsof extract compress duh sizeof findbig \
    emptydirs dupfind bak cwd clipcopy watchrun \
    treelist recent swap trash \
    gitundo branchclean branchage gitlog-today gacp gclone gwip gunwip \
    gitprune gswitch prdiff gitcontributors gitsize gitconflicts gitignore \
    gstash grebase gopen gitbranch-rename gitlog-graph gcleanup \
    dockernuke dockerclean-images dclean dockerlogs dsh dockersizes \
    k8sctx klogs kexec ktop kevents \
    denv dbuild kns kdesc kport \
    covreport gomodwhy goclean goupdate gobench gonew gowatch \
    npmclean npmscripts npmoutdated npmsize \
    venvcreate pyclean pyfreeze \
    myip localip killport portwho certcheck dnscheck httpstatus apihit \
    flushdns weather tcpcheck shorten \
    pingcheck sshconfig headers proxy \
    passgen pubkey genssh b64e b64d urlencode urldecode hashfile genuuid \
    jwtdecode dotenv-check \
    mem cpu pidtree fkill now timer \
    diskusage envdiff ports sysinfo \
    note jsonpp envload ffind cheat calc qr \
    todo mkproject epoch diffjson retry \
    jenk-crumb jenk-build jenk-logs jenk-jobs \
    sharmory-update \
    2>/dev/null; true

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

# Recursive tree listing; uses `tree` if installed, else pretty-prints via find
# Usage: treelist [dir] [depth]
treelist() {
    local dir=${1:-.}
    local depth=${2:-}
    if command -v tree &>/dev/null; then
        if [[ -n "$depth" ]]; then
            tree -L "$depth" --dirsfirst -C "$dir"
        else
            tree --dirsfirst -C "$dir"
        fi
    else
        # Pure Zsh fallback — no external tools needed
        local base_depth=$(( ${#${dir%%/}//[^\/]} ))
        find "$dir" -not -path '*/.git*' 2>/dev/null | sort | while IFS= read -r p; do
            local depth=$(( ${#${p//[^\/]/}} - base_depth ))
            local pad=${(l:$(( depth * 4 )):: :)}
            print "${pad}${p:t}"
        done
    fi
}

# Show the N most recently modified files in the current directory tree
# Usage: recent [n]
recent() {
    local n=${1:-10}
    find . -type f -not -path '*/.git*' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn \
        | head -n "$n" \
        | awk '{print $2}' \
    || find . -type f -not -path '*/.git*' 2>/dev/null \
        | xargs stat -f '%m %N' 2>/dev/null \
        | sort -rn | head -n "$n" | awk '{print $2}'
}

# Atomically swap two filenames using a temp file
# Usage: swap <file-a> <file-b>
swap() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: swap <file-a> <file-b>"
        return 1
    fi
    if [[ ! -e "$1" ]]; then echo "Not found: $1"; return 1; fi
    if [[ ! -e "$2" ]]; then echo "Not found: $2"; return 1; fi
    local tmp
    tmp=$(mktemp "${1}.XXXXXXXX.swaptmp")
    mv -- "$1" "$tmp"
    mv -- "$2" "$1"
    mv -- "$tmp" "$2"
    echo "Swapped: $1 ↔ $2"
}

# Move a file to the system trash instead of deleting it permanently
# Usage: trash <file-or-dir>
trash() {
    if [[ -z "$1" ]]; then
        echo "Usage: trash <file-or-dir>"
        return 1
    fi
    if [[ ! -e "$1" ]]; then
        echo "Not found: $1"
        return 1
    fi
    local os
    os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        local trash_dir="$HOME/.Trash"
        mkdir -p "$trash_dir"
        local dest="$trash_dir/$(basename "$1")"
        # Avoid collisions in the Trash by appending a timestamp if needed
        [[ -e "$dest" ]] && dest="${dest}.$(date +%s)"
        mv -- "$1" "$dest"
    else
        local trash_dir="${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files"
        mkdir -p "$trash_dir"
        local dest="$trash_dir/$(basename "$1")"
        [[ -e "$dest" ]] && dest="${dest}.$(date +%s)"
        mv -- "$1" "$dest"
    fi
    echo "Trashed: $1"
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

# Interactive git stash picker — pop, apply, or drop a stash entry via fzf
gstash() {
    _sharmory_need fzf || return 1
    local entry action
    entry=$(git stash list | fzf --prompt="stash> " --preview='git stash show -p {1}')
    [[ -z "$entry" ]] && return 0
    local stash_ref
    stash_ref=$(echo "$entry" | cut -d: -f1)
    echo "Action for $stash_ref — (p)op  (a)pply  (d)rop  [p/a/d]:"
    read -r action
    case "$action" in
        p) git stash pop "$stash_ref"   ;;
        a) git stash apply "$stash_ref" ;;
        d) git stash drop "$stash_ref"  ;;
        *) echo "Aborted." ;;
    esac
}

# Interactive rebase — pick how many commits to rebase interactively
# Usage: grebase [n]   (omit n to pick via prompt)
grebase() {
    local n=$1
    if [[ -z "$n" ]]; then
        echo "How many commits back do you want to rebase?"
        read -r n
    fi
    if ! [[ "$n" =~ ^[0-9]+$ ]]; then
        echo "Expected a positive integer, got: $n"
        return 1
    fi
    git rebase -i "HEAD~$n"
}

# Open the current repo's GitHub/GitLab/Bitbucket URL in the browser
gopen() {
    local remote
    remote=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote" ]]; then
        echo "No 'origin' remote found."
        return 1
    fi
    # Normalise SSH → HTTPS: git@github.com:user/repo.git → https://github.com/user/repo
    local url
    if [[ "$remote" == git@* ]]; then
        url=$(echo "$remote" | sed -E 's|git@([^:]+):(.+)(\.git)?$|https://\1/\2|')
    else
        url="${remote%.git}"
    fi
    echo "Opening: $url"
    if command -v open &>/dev/null; then
        open "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url"
    else
        echo "$url"
    fi
}

# Rename a git branch locally and on the remote, updating tracking refs
# Usage: gitbranch-rename <old-name> <new-name>
gitbranch-rename() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: gitbranch-rename <old-name> <new-name>"
        return 1
    fi
    local old=$1 new=$2
    git branch -m "$old" "$new"
    git push origin --delete "$old" 2>/dev/null && echo "Deleted remote '$old'"
    git push origin -u "$new"
    echo "Renamed '$old' → '$new' locally and on remote."
}

# Pretty one-line graph log for the whole repo
gitlog-graph() {
    git log --graph --oneline --decorate --all --color "$@"
}

# Combined cleanup: prune remote-tracking refs, delete merged branches, tidy Go module
gcleanup() {
    echo "==> gitprune"
    gitprune
    echo "==> branchclean"
    branchclean
    if [[ -f go.mod ]]; then
        echo "==> goclean"
        goclean
    fi
    echo "Done."
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

# Print all environment variables of a running container
# Usage: denv <container-name-or-id>
denv() {
    if [[ -z "$1" ]]; then
        echo "Usage: denv <container-name-or-id>"
        return 1
    fi
    docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$1"
}

# Build a Docker image; auto-derives the tag from the current directory name
# Usage: dbuild [tag]
dbuild() {
    local tag=${1:-$(basename "$PWD")}
    echo "Building image: $tag"
    docker build -t "$tag" .
}

# Quickly switch the current kubectl namespace without changing context
# Usage: kns <namespace>
kns() {
    if [[ -z "$1" ]]; then
        echo "Usage: kns <namespace>"
        return 1
    fi
    kubectl config set-context --current --namespace="$1"
    echo "Namespace set to: $1"
}

# Interactively pick a pod via fzf and run kubectl describe on it
kdesc() {
    _sharmory_need fzf || return 1
    local pod
    pod=$(kubectl get pods -o name | fzf --prompt="describe pod> " | sed 's|pod/||')
    [[ -z "$pod" ]] && return 0
    kubectl describe pod "$pod"
}

# Forward a local port to a port on a pod
# Usage: kport <local-port> <pod-name> <remote-port>
kport() {
    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
        echo "Usage: kport <local-port> <pod-name> <remote-port>"
        return 1
    fi
    echo "Forwarding localhost:$1 → pod/$2:$3 (Ctrl-C to stop)"
    kubectl port-forward "pod/$2" "$1:$3"
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

# Send 5 pings to a host and print a clean summary of RTT and packet loss
# Usage: pingcheck <host>
pingcheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: pingcheck <host>"
        return 1
    fi
    local host=$1
    echo "Pinging $host (5 packets)..."
    local os
    os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        ping -c 5 "$host"
    else
        ping -c 5 -W 2 "$host"
    fi
}

# List all Host entries from ~/.ssh/config
sshconfig() {
    local cfg="$HOME/.ssh/config"
    if [[ ! -f "$cfg" ]]; then
        echo "No ~/.ssh/config found."
        return 1
    fi
    awk '/^[Hh]ost /{
        host=$2
        alias=""
        hostname=""
        user=""
        port=""
    }
    /^[[:space:]]+HostName /{hostname=$2}
    /^[[:space:]]+User /{user=$2}
    /^[[:space:]]+Port /{port=$2}
    /^[[:space:]]+IdentityFile /{alias=$2}
    /^[Hh]ost /{
        if (host && hostname)
            printf "  %-20s → %s%s%s\n", host, (user?user"@":""), hostname, (port?":"port:"")
    }
    END {
        if (host && hostname)
            printf "  %-20s → %s%s%s\n", host, (user?user"@":""), hostname, (port?":"port:"")
    }' "$cfg"
}

# Show full HTTP response headers for a URL
# Usage: headers <url>
headers() {
    if [[ -z "$1" ]]; then
        echo "Usage: headers <url>"
        return 1
    fi
    curl -sI "$1"
}

# Toggle http_proxy / https_proxy / no_proxy env vars on/off
# Usage: proxy on [host:port]  |  proxy off  |  proxy status
proxy() {
    local action=${1:-status}
    case "$action" in
        on)
            local addr=${2:-"http://127.0.0.1:8080"}
            export http_proxy="$addr"
            export https_proxy="$addr"
            export HTTP_PROXY="$addr"
            export HTTPS_PROXY="$addr"
            export no_proxy="localhost,127.0.0.1,::1"
            export NO_PROXY="$no_proxy"
            echo "Proxy ON → $addr"
            ;;
        off)
            unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
            echo "Proxy OFF."
            ;;
        status)
            echo "http_proxy  = ${http_proxy:-<not set>}"
            echo "https_proxy = ${https_proxy:-<not set>}"
            ;;
        *)
            echo "Usage: proxy <on [host:port]|off|status>"
            return 1
            ;;
    esac
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

# Decode a JWT token's header and payload and pretty-print as JSON (no signature verification)
# Usage: jwtdecode <token>
jwtdecode() {
    if [[ -z "$1" ]]; then
        echo "Usage: jwtdecode <token>"
        return 1
    fi
    local token=$1
    local header payload
    header=$(echo "$token"  | cut -d. -f1)
    payload=$(echo "$token" | cut -d. -f2)

    # JWT uses base64url (- and _ instead of + and /); pad to a multiple of 4
    _jwt_decode_part() {
        local part=$1
        # base64url → base64
        part=$(echo "$part" | tr '_-' '/+')
        # add padding
        local pad=$(( 4 - ${#part} % 4 ))
        [[ $pad -ne 4 ]] && part="${part}$(printf '%0.s=' $(seq 1 $pad))"
        echo "$part" | base64 -d 2>/dev/null
    }

    echo "=== Header ==="
    if command -v jq &>/dev/null; then
        _jwt_decode_part "$header"  | jq .
        echo "=== Payload ==="
        _jwt_decode_part "$payload" | jq .
    else
        _jwt_decode_part "$header"
        echo "=== Payload ==="
        _jwt_decode_part "$payload"
    fi
}

# Lint a .env file: flag empty values, missing quotes on values with spaces,
# duplicate keys, and keys whose names suggest they might be secrets but are unquoted
# Usage: dotenv-check [file]
dotenv-check() {
    local file=${1:-.env}
    if [[ ! -f "$file" ]]; then
        echo "No such file: $file"
        return 1
    fi
    local issues=0
    local -A seen_keys
    local lineno=0
    while IFS= read -r line; do
        (( lineno++ ))
        # skip blanks and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        # must match KEY=value pattern
        if ! [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            printf "  [WARN] line %d: not a valid KEY=value pair: %s\n" "$lineno" "$line"
            (( issues++ ))
            continue
        fi
        local key value
        key=${line%%=*}
        value=${line#*=}

        # duplicate key
        if [[ -n "${seen_keys[$key]+_}" ]]; then
            printf "  [DUPE] line %d: duplicate key '%s'\n" "$lineno" "$key"
            (( issues++ ))
        fi
        seen_keys[$key]=1

        # empty value
        if [[ -z "$value" ]]; then
            printf "  [EMPTY] line %d: '%s' has no value\n" "$lineno" "$key"
            (( issues++ ))
            continue
        fi

        # value has unquoted whitespace
        if [[ "$value" != \"*\" && "$value" != \'*\' && "$value" == *[[:space:]]* ]]; then
            printf "  [QUOTE] line %d: '%s' value contains spaces but is not quoted\n" "$lineno" "$key"
            (( issues++ ))
        fi

        # secret-ish key with plaintext value (not redacted/placeholder)
        if [[ "$key" =~ (SECRET|PASSWORD|PASSWD|TOKEN|API_KEY|APIKEY|PRIVATE_KEY|AUTH) ]]; then
            if [[ "$value" != \"*\" && "$value" != \'*\' && "$value" != \$\{*\} ]]; then
                printf "  [SECRET] line %d: '%s' looks like a secret — consider quoting or using a vault\n" "$lineno" "$key"
                (( issues++ ))
            fi
        fi
    done < "$file"

    if [[ $issues -eq 0 ]]; then
        echo "  ✅ $file looks clean (no issues found)."
    else
        printf "  ⚠️  %d issue(s) found in %s\n" "$issues" "$file"
        return 1
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

# Show disk usage interactively via ncdu, fallback to a df + du summary
diskusage() {
    if command -v ncdu &>/dev/null; then
        ncdu "${1:-.}"
    else
        echo "=== Filesystem usage ==="
        df -h
        echo ""
        echo "=== Largest directories under ${1:-.} ==="
        du -sh "${1:-.}"/*/ 2>/dev/null | sort -rh | head -20
    fi
}

# Diff two .env files: show added, removed, and changed key=value pairs
# Usage: envdiff <file1> <file2>
envdiff() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: envdiff <file1> <file2>"
        return 1
    fi
    if [[ ! -f "$1" ]]; then echo "Not found: $1"; return 1; fi
    if [[ ! -f "$2" ]]; then echo "Not found: $2"; return 1; fi

    # Parse KEY=value into associative arrays
    local -A a b
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        a[${line%%=*}]="${line#*=}"
    done < "$1"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        b[${line%%=*}]="${line#*=}"
    done < "$2"

    local changed=0
    # Keys removed in file2
    for k in "${(@k)a}"; do
        if [[ -z "${b[$k]+_}" ]]; then
            printf "  \033[31m- %s=%s\033[0m\n" "$k" "${a[$k]}"
            (( changed++ ))
        elif [[ "${a[$k]}" != "${b[$k]}" ]]; then
            printf "  \033[33m~ %s: %s → %s\033[0m\n" "$k" "${a[$k]}" "${b[$k]}"
            (( changed++ ))
        fi
    done
    # Keys added in file2
    for k in "${(@k)b}"; do
        if [[ -z "${a[$k]+_}" ]]; then
            printf "  \033[32m+ %s=%s\033[0m\n" "$k" "${b[$k]}"
            (( changed++ ))
        fi
    done

    if [[ $changed -eq 0 ]]; then
        echo "  No differences found."
    else
        printf "  %d difference(s) between %s and %s\n" "$changed" "$1" "$2"
    fi
}

# List all listening TCP/UDP ports with the owning process name and PID
ports() {
    local os
    os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        printf "%-8s %-10s %-25s %s\n" "Proto" "Port" "Process" "PID"
        printf "%-8s %-10s %-25s %s\n" "-----" "----" "-------" "---"
        lsof -iTCP -iUDP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1 {
            split($9,a,":")
            printf "%-8s %-10s %-25s %s\n", $8, a[length(a)], $1, $2
        }'
    else
        ss -tulnp 2>/dev/null | awk 'NR>1 {
            split($5,a,":")
            split($7,p,"\"")
            printf "%-8s %-10s %-25s\n", $1, a[length(a)], (p[2]?p[2]:$7)
        }' | sort -k2 -n
    fi
}

# Print a single-screen system summary: OS, CPU, RAM, disk, uptime, load
sysinfo() {
    local os
    os=$(_sharmory_os)
    echo "╔═══════════════════════════════════════╗"
    echo "║           System Information          ║"
    echo "╚═══════════════════════════════════════╝"

    if [[ "$os" == "macos" ]]; then
        printf "  OS       : %s\n" "$(sw_vers -productName) $(sw_vers -productVersion)"
        printf "  Kernel   : %s\n" "$(uname -r)"
        printf "  CPU      : %s\n" "$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
        printf "  Cores    : %s physical / %s logical\n" \
            "$(sysctl -n hw.physicalcpu 2>/dev/null)" \
            "$(sysctl -n hw.logicalcpu 2>/dev/null)"
        local mem_bytes
        mem_bytes=$(sysctl -n hw.memsize 2>/dev/null)
        printf "  RAM      : %.1f GB total\n" "$(echo "scale=1; $mem_bytes/1073741824" | bc 2>/dev/null || echo '?')"
        printf "  Uptime   : %s\n" "$(uptime | sed 's/.*up /up /' | cut -d, -f1-2)"
        printf "  Load     : %s\n" "$(uptime | awk -F'load averages:' '{print $2}')"
    else
        printf "  OS       : %s\n" "$(uname -o 2>/dev/null || uname -s) $(uname -r)"
        printf "  Distro   : %s\n" "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
        printf "  CPU      : %s\n" "$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)"
        printf "  Cores    : %s\n" "$(nproc 2>/dev/null)"
        local mem_total mem_avail
        mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
        mem_avail=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
        printf "  RAM      : %s MB total / %s MB available\n" \
            "$(( mem_total / 1024 ))" "$(( mem_avail / 1024 ))"
        printf "  Uptime   : %s\n" "$(uptime -p 2>/dev/null || uptime)"
        printf "  Load     : %s\n" "$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
    fi

    echo ""
    printf "  Disk usage:\n"
    df -h 2>/dev/null | awk 'NR==1 || /\/$/ || /home/ {printf "    %s\n", $0}'
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

# Append a timestamped entry to ~/todo.md; run with no args to list all todos
# Usage: todo [text]
todo() {
    local file="$HOME/todo.md"
    if [[ -z "$1" ]]; then
        if [[ -f "$file" ]]; then
            cat "$file"
        else
            echo "No todo file yet. Run: todo <text>"
        fi
        return 0
    fi
    local dir
    dir=$(dirname "$file")
    mkdir -p "$dir"
    [[ ! -f "$file" ]] && echo "# Todos\n" > "$file"
    echo "- [ ] $(date +%Y-%m-%d\ %H:%M) $*" >> "$file"
    echo "Added: $*"
}

# Scaffold a new project directory with README.md, .gitignore, and .env.example
# Templates: go, node, python (default: bare)
# Usage: mkproject <name> [template]
mkproject() {
    if [[ -z "$1" ]]; then
        echo "Usage: mkproject <name> [go|node|python]"
        return 1
    fi
    local name=$1
    local template=${2:-bare}
    if [[ -d "$name" ]]; then
        echo "Directory '$name' already exists."
        return 1
    fi
    mkdir -p "$name"
    cd "$name" || return 1

    # README
    printf "# %s\n\n> Add project description here.\n\n## Getting Started\n\n## License\n\nMIT\n" "$name" > README.md

    # .env.example
    printf "# Copy this file to .env and fill in your values\n\nAPP_ENV=development\nLOG_LEVEL=info\n" > .env.example

    # template-specific setup
    case "$template" in
        go)
            printf "*.out\n*.test\nvendor/\n" > .gitignore
            printf "*.log\n.env\n" >> .gitignore
            go mod init "$name" 2>/dev/null
            cat > main.go <<'GOEOF'
package main

import "fmt"

func main() {
	fmt.Println("Hello from ${name}!")
}
GOEOF
            ;;
        node)
            printf "node_modules/\ndist/\n.env\n*.log\n" > .gitignore
            cat > package.json <<PKGEOF
{
  "name": "${name}",
  "version": "0.1.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  }
}
PKGEOF
            printf "console.log('Hello from ${name}!');\n" > index.js
            ;;
        python)
            printf "venv/\n__pycache__/\n*.pyc\n.env\n*.egg-info/\ndist/\nbuild/\n" > .gitignore
            printf "# %s\n\nrequirements:\n" "$name" > requirements.txt
            cat > main.py <<'PYEOF'
def main():
    print("Hello!")

if __name__ == "__main__":
    main()
PYEOF
            ;;
        bare)
            printf ".env\n*.log\n" > .gitignore
            ;;
        *)
            echo "Unknown template '$template'. Using bare."
            printf ".env\n*.log\n" > .gitignore
            ;;
    esac

    git init -q
    git add -A
    git commit -q -m "Initial commit ($template)"
    echo "✅ Project '$name' created with template '$template'"
    echo "   $(pwd)"
}

# Convert between Unix epoch and human-readable datetime (both directions)
# Usage: epoch          → prints current epoch and datetime
#        epoch <epoch>  → epoch to human
#        epoch <date>   → human to epoch  (e.g. "2024-01-15 12:00:00")
epoch() {
    if [[ -z "$1" ]]; then
        local now
        now=$(date +%s)
        printf "Epoch   : %s\nHuman   : %s\n" "$now" "$(date -r "$now" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || date -d "@$now" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)"
        return 0
    fi
    # Detect if arg is all digits → epoch to human, else human to epoch
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        date -r "$1" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || \
        date -d "@$1" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null
    else
        date -j -f "%Y-%m-%d %H:%M:%S" "$1" "+%s" 2>/dev/null || \
        date -d "$1" "+%s" 2>/dev/null
    fi
}

# Semantically diff two JSON files by normalising with jq before diffing
# Usage: diffjson <file-a> <file-b>
diffjson() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: diffjson <file-a> <file-b>"
        return 1
    fi
    _sharmory_need jq || return 1
    if [[ ! -f "$1" ]]; then echo "Not found: $1"; return 1; fi
    if [[ ! -f "$2" ]]; then echo "Not found: $2"; return 1; fi
    diff <(jq -S . "$1") <(jq -S . "$2")
}

# Run a command up to N times, retrying on failure with exponential backoff
# Usage: retry <max-attempts> <command> [args...]
retry() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: retry <max-attempts> <command> [args...]"
        return 1
    fi
    local max=$1
    shift
    local attempt=1
    local wait=1
    while true; do
        if "$@"; then
            [[ $attempt -gt 1 ]] && echo "✅ Succeeded on attempt $attempt."
            return 0
        fi
        if (( attempt >= max )); then
            printf "❌ Command failed after %d attempt(s): %s\n" "$max" "$*"
            return 1
        fi
        printf "⚠️  Attempt %d/%d failed. Retrying in %ds...\n" "$attempt" "$max" "$wait"
        sleep "$wait"
        wait=$(( wait * 2 ))
        (( attempt++ ))
    done
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

#########################################################################
# 12. SHARMORY MANAGEMENT
#########################################################################

# Update Sharmory to the latest version from GitHub
sharmory-update() {
    local target="${HOME}/.sharmory/functions.zsh"
    echo "Updating Sharmory from GitHub..."
    mkdir -p "$(dirname "$target")"
    if curl -fsSL "https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.zsh" -o "$target"; then
        source "$target"
        echo "Sharmory successfully updated and reloaded!"
    else
        echo "Failed to update Sharmory."
        return 1
    fi
}

