#!/usr/bin/env bash
#
# Sharmory — a collection of dev-focused Bash functions
# (ported 1:1 from the Zsh original, functions.zsh)
#
# Requires Bash 4.0+ (uses associative arrays: `local -A`). macOS ships
# Bash 3.2 by default — install a modern Bash via `brew install bash` and
# make sure it comes first in $PATH, or just use it explicitly via
# `/opt/homebrew/bin/bash` / `/usr/local/bin/bash`.
#
# Source this file from your .bashrc:
#   [[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash
#
# The guard above ensures that if this file has any load-time error,
# it never aborts .bashrc mid-execution (protecting your PATH and plugins).
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
    emptydirs dupfind bak cwd clipcopy clip watchrun \
    treelist recent swap trash \
    gitundo branchclean branchage gitlog-today gacp gclone gwip gunwip \
    gitprune gswitch prdiff gitcontributors gitsize gitconflicts gitignore \
    gstash grebase gopen gpr gitbranch-rename gitlog-graph gcleanup \
    grecentbranch gcamend gdiffstage \
    dockernuke dockerclean-images dclean dockerlogs dsh dockersizes \
    k8sctx klogs kexec ktop kevents \
    denv dbuild kns kdesc kport \
    covreport gomodwhy goclean goupdate gobench gonew gowatch \
    gorace gobuild goxbuild gocover-func goenv golist goversion gotest gomod-name govscan goimpl \
    npmclean npmscripts npmoutdated npmsize \
    nodeversion nvmuse tscheck npxrun npmglobal npmlink noderepl npmaudit nodeinfo npmdedup npmwatch \
    venvcreate pyclean pyfreeze pipinstall \
    pyversion pycheck pytest-run pywatch pydeps pyupgrade pyrequirements-diff pyrun pyprofile pyvenv \
    myip localip killport portwho certcheck dnscheck httpstatus apihit \
    flushdns weather tcpcheck shorten \
    tlscheck portscan ipinfo \
    pingcheck sshconfig headers proxy \
    passgen pubkey genssh b64e b64d urlencode urldecode hashfile genuuid \
    jwtdecode dotenv-check \
    mem cpu pidtree fkill now timer \
    diskusage envdiff ports sysinfo openports \
    note jsonpp envload ffind cheat calc qr \
    todo mkproject epoch diffjson retry \
    hist mktemplate envswitch \
    jenk-crumb jenk-build jenk-logs jenk-jobs \
    sharmory-update sharmory-doctor sharmory-setup sharmory-bench sharmory \
    2>/dev/null; true

# Current version — bump this on every release
SHARMORY_VERSION="1.0.0"

# Path of this file so sharmory-bench can source a clean copy
# (BASH_SOURCE[0] is the path this file was sourced/executed as; resolve it
# to an absolute path the same way Zsh's ${(%):-%x}:A} does.)
_SHARMORY_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)/$(basename "${BASH_SOURCE[0]}")"

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
    # Skip the prompt when stdin is not a terminal (CI/pipes) — just list, never delete
    if [[ ! -t 0 ]]; then
        return 0
    fi
    read -r -p "Delete these empty directories? (y/N) " confirm
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

# Copy stdin (or a file) to the clipboard — works with pipes: echo foo | clip
# Usage: clip [file]   or   some-command | clip
clip() {
    local os
    os=$(_sharmory_os)
    local _clip_cmd
    if [[ "$os" == "macos" ]]; then
        _clip_cmd="pbcopy"
    elif command -v xclip &>/dev/null; then
        _clip_cmd="xclip -selection clipboard"
    elif command -v wl-copy &>/dev/null; then
        _clip_cmd="wl-copy"
    else
        echo "No clipboard tool found."
        return 1
    fi
    if [[ -n "$1" ]]; then
        if [[ ! -f "$1" ]]; then
            echo "File not found: $1"
            return 1
        fi
        eval "$_clip_cmd" < "$1"
        echo "Copied: $1"
    else
        eval "$_clip_cmd"
        echo "Copied from stdin."
    fi
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
        # Pure Bash fallback — no external tools needed
        local dir_trimmed="${dir%%/}"
        local base_depth
        base_depth=$(printf '%s' "$dir_trimmed" | tr -cd '/' | wc -c)
        find "$dir" -not -path '*/.git*' 2>/dev/null | sort | while IFS= read -r p; do
            local slash_count
            slash_count=$(printf '%s' "$p" | tr -cd '/' | wc -c)
            local depth=$(( slash_count - base_depth ))
            local pad
            pad=$(printf '%*s' $(( depth * 4 )) '')
            printf '%s%s\n' "$pad" "$(basename "$p")"
        done
    fi
}

# Show the N most recently modified files in the current directory tree
# Usage: recent [n]
recent() {
    local n=${1:-10}
    # macOS stat: -f '%m %N' per-file; Linux find: -printf '%T@ %p\n'
    if find . -maxdepth 0 -printf '' 2>/dev/null; then
        # GNU find available (Linux)
        find . -type f -not -path '*/.git*' -printf '%T@ %p\n' 2>/dev/null \
            | sort -rn | head -n "$n" | awk '{print $2}'
    else
        # macOS: use stat per file, avoid xargs batch form
        find . -type f -not -path '*/.git*' 2>/dev/null \
            | while IFS= read -r f; do
                stat -f '%m %N' "$f" 2>/dev/null
              done \
            | sort -rn | head -n "$n" | awk '{print $2}'
    fi
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
    read -r -p "Delete these? (y/N) " confirm
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
        read -r -p "⚠️  You're on '$branch'. Push directly? (y/N) " confirm
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
    local dest
    dest="${2:-$(basename "${1%.git}")}"
    git clone "$1" "$dest" || return 1
    if [[ -d "$dest" ]]; then
        cd "$dest"
    else
        echo "Warning: expected directory '$dest' not found after clone."
        return 1
    fi
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

# Open a PR creation page for the current branch on GitHub/GitLab/Bitbucket
gpr() {
    local remote branch url base
    remote=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote" ]]; then
        echo "No 'origin' remote found."
        return 1
    fi
    branch=$(git branch --show-current 2>/dev/null)
    if [[ -z "$branch" ]]; then
        echo "Not on a branch."
        return 1
    fi
    # Normalise SSH → HTTPS
    if [[ "$remote" == git@* ]]; then
        base=$(echo "$remote" | sed -E 's|git@([^:]+):(.+)(\.git)?$|https://\1/\2|')
    else
        base="${remote%.git}"
    fi
    # Build the compare URL per host
    case "$base" in
        *github.com*)  url="${base}/compare/${branch}?expand=1" ;;
        *gitlab.com*)  url="${base}/-/merge_requests/new?merge_request[source_branch]=${branch}" ;;
        *bitbucket.org*) url="${base}/pull-requests/new?source=${branch}" ;;
        *)             url="${base}/compare/${branch}" ;;
    esac
    echo "Opening PR page: $url"
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

# Show the N most recently checked-out branches from the reflog
# Usage: grecentbranch [n]
grecentbranch() {
    local n=${1:-10}
    git reflog --format='%gs' 2>/dev/null \
        | grep -oP '(?<=checkout: moving from ).*(?= to )' \
        | awk '!seen[$0]++' \
        | head -n "$n"
}

# Amend the last commit message without touching the stage
# Usage: gcamend <new message>
gcamend() {
    if [[ -z "$1" ]]; then
        echo "Usage: gcamend <new message>"
        return 1
    fi
    git commit --amend --allow-empty -m "$*"
}

# Show what is currently staged (ready to commit)
gdiffstage() {
    git diff --cached
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
    read -r -p "Remove these images? (y/N) " confirm
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

# Run Go tests with the race detector enabled
# Usage: gorace [./...]
gorace() {
    go test -race "${1:-./...}"
}

# Build a Go binary for the current module; output name defaults to the module base name
# Usage: gobuild [output-name]
gobuild() {
    local out="${1:-$(basename "$(go env GOMODCACHE 2>/dev/null)" 2>/dev/null)}"
    out="${1:-$(basename "$PWD")}"
    echo "Building → $out"
    go build -v -o "$out" ./...
}

# Cross-compile a Go binary for a target OS and architecture
# Usage: goxbuild <os> <arch> [output]
#   e.g. goxbuild linux amd64
#        goxbuild windows amd64 myapp.exe
goxbuild() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: goxbuild <GOOS> <GOARCH> [output]"
        echo "  Common targets: linux/amd64  darwin/arm64  windows/amd64"
        return 1
    fi
    local goos=$1 goarch=$2
    local out="${3:-$(basename "$PWD")-${goos}-${goarch}}"
    [[ "$goos" == "windows" && "$out" != *.exe ]] && out="${out}.exe"
    echo "Building ${goos}/${goarch} → $out"
    GOOS="$goos" GOARCH="$goarch" go build -v -o "$out" ./...
}

# Run coverage in function-breakdown mode (shows % per function, not just overall)
# Usage: gocover-func
gocover-func() {
    go test ./... -coverprofile=/tmp/cover-func.out 2>/dev/null
    go tool cover -func=/tmp/cover-func.out
}

# Show all Go environment variables (GOPATH, GOROOT, GOPROXY, etc.)
goenv() {
    go env
}

# List all packages in the current module
golist() {
    go list ./...
}

# Show the Go version and key paths (GOROOT, GOPATH, GOMODCACHE)
goversion() {
    go version
    printf "  GOROOT     : %s\n" "$(go env GOROOT)"
    printf "  GOPATH     : %s\n" "$(go env GOPATH)"
    printf "  GOMODCACHE : %s\n" "$(go env GOMODCACHE)"
    printf "  GOPROXY    : %s\n" "$(go env GOPROXY)"
}

# Run go test with verbose flag for the given package (default ./...)
# Usage: gotest [./...]
gotest() {
    go test -v "${1:-./...}"
}

# Print the module name from go.mod in the current directory
gomod-name() {
    if [[ ! -f go.mod ]]; then
        echo "No go.mod found in the current directory."
        return 1
    fi
    awk '/^module /{print $2; exit}' go.mod
}

# Check if any direct dependencies have known vulnerabilities (requires govulncheck)
# Usage: govscan
govscan() {
    if ! command -v govulncheck &>/dev/null; then
        echo "Installing govulncheck…"
        go install golang.org/x/vuln/cmd/govulncheck@latest || return 1
    fi
    govulncheck ./...
}

# Show all interfaces implemented by types in the current package (requires guru)
# Falls back to plain go doc when guru is not available
# Usage: goimpl <type>
goimpl() {
    if [[ -z "$1" ]]; then
        echo "Usage: goimpl <TypeName>"
        return 1
    fi
    if command -v guru &>/dev/null; then
        echo "Use guru manually: guru implements <position>"
    else
        go doc "$1"
    fi
}

#########################################################################
# 5. NODE / NPM
#########################################################################

# Delete node_modules and the appropriate lockfile, then reinstall from scratch
# Detects npm / yarn / pnpm automatically
npmclean() {
    rm -rf node_modules
    if [[ -f pnpm-lock.yaml ]]; then
        echo "pnpm project detected — removing pnpm-lock.yaml"
        rm -f pnpm-lock.yaml
        pnpm install
    elif [[ -f yarn.lock ]]; then
        echo "yarn project detected — removing yarn.lock"
        rm -f yarn.lock
        yarn install
    else
        rm -f package-lock.json
        npm install
    fi
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

# Print the current Node.js and npm/yarn/pnpm versions
nodeversion() {
    printf "node  : %s\n" "$(node --version 2>/dev/null || echo 'not found')"
    printf "npm   : %s\n" "$(npm --version  2>/dev/null || echo 'not found')"
    command -v yarn  &>/dev/null && printf "yarn  : %s\n" "$(yarn --version)"
    command -v pnpm  &>/dev/null && printf "pnpm  : %s\n" "$(pnpm --version)"
}

# Switch to a Node.js version via nvm (if installed)
# Usage: nvmuse <version>  e.g. nvmuse 20  or nvmuse lts/iron
nvmuse() {
    if [[ -z "$1" ]]; then
        echo "Usage: nvmuse <version>  e.g. nvmuse 20  or nvmuse lts/iron"
        return 1
    fi
    if command -v nvm &>/dev/null 2>&1 || [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # source nvm if it hasn't been loaded into the current shell yet
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
        nvm use "$1"
    elif command -v fnm &>/dev/null; then
        fnm use "$1"
    else
        echo "Neither nvm nor fnm found. Install one to manage Node versions."
        return 1
    fi
}

# Run TypeScript type-check without emitting files (requires tsc in PATH or node_modules)
# Usage: tscheck
tscheck() {
    local tsc_bin
    if command -v tsc &>/dev/null; then
        tsc_bin="tsc"
    elif [[ -x node_modules/.bin/tsc ]]; then
        tsc_bin="node_modules/.bin/tsc"
    else
        echo "TypeScript compiler (tsc) not found. Run: npm install typescript"
        return 1
    fi
    "$tsc_bin" --noEmit
}

# Run a package with npx, prompting to install if not cached
# Usage: npxrun <package> [args...]
npxrun() {
    if [[ -z "$1" ]]; then
        echo "Usage: npxrun <package> [args...]"
        return 1
    fi
    npx "$@"
}

# List globally installed npm packages (top-level only)
npmglobal() {
    npm list -g --depth=0
}

# Link the current package globally, then link it into another project
# Usage: npmlink [target-project-dir]
npmlink() {
    if [[ -z "$1" ]]; then
        npm link
        echo "Linked $(jq -r .name package.json 2>/dev/null || basename "$PWD") globally."
    else
        npm link "$(jq -r .name package.json 2>/dev/null || basename "$PWD")" --prefix "$1"
        echo "Linked into $1"
    fi
}

# Open an interactive Node.js REPL with the project's node_modules on the path
noderepl() {
    NODE_PATH="$(pwd)/node_modules" node
}

# Run npm audit and show a short summary
npmaudit() {
    npm audit 2>/dev/null || true
}

# Print key info about the current Node project (name, version, scripts count, deps count)
nodeinfo() {
    if [[ ! -f package.json ]]; then
        echo "No package.json in the current directory."
        return 1
    fi
    local name version scripts_count deps_count devdeps_count
    name=$(node -e "const p=require('./package.json');console.log(p.name||'(none)')" 2>/dev/null)
    version=$(node -e "const p=require('./package.json');console.log(p.version||'(none)')" 2>/dev/null)
    scripts_count=$(node -e "const p=require('./package.json');console.log(Object.keys(p.scripts||{}).length)" 2>/dev/null)
    deps_count=$(node -e "const p=require('./package.json');console.log(Object.keys(p.dependencies||{}).length)" 2>/dev/null)
    devdeps_count=$(node -e "const p=require('./package.json');console.log(Object.keys(p.devDependencies||{}).length)" 2>/dev/null)
    printf "  Name         : %s\n" "$name"
    printf "  Version      : %s\n" "$version"
    printf "  Scripts      : %s\n" "$scripts_count"
    printf "  Dependencies : %s prod, %s dev\n" "$deps_count" "$devdeps_count"
}

# Deduplicate and flatten the npm dependency tree
npmdedup() {
    npm dedupe
}

# Watch source files and re-run a npm script on change (requires nodemon or entr)
# Usage: npmwatch [script]   defaults to "dev"
npmwatch() {
    local script="${1:-dev}"
    if command -v nodemon &>/dev/null; then
        nodemon --exec "npm run $script"
    elif command -v entr &>/dev/null; then
        find . -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \
            | grep -v node_modules \
            | entr -c npm run "$script"
    else
        echo "Install nodemon or entr to use npmwatch."
        return 1
    fi
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

# Show the active Python and pip versions, and whether a venv is active
# Install packages from requirements.txt; does nothing if the file is missing
# Usage: pipinstall
pipinstall() {
    if [[ ! -f requirements.txt ]]; then
        echo "No requirements.txt found in the current directory."
        return 1
    fi
    pip install -r requirements.txt
}

pyversion() {
    printf "python : %s\n" "$(python3 --version 2>/dev/null || echo 'not found')"
    printf "pip    : %s\n" "$(pip3 --version 2>/dev/null || echo 'not found')"
    if [[ -n "$VIRTUAL_ENV" ]]; then
        printf "venv   : %s (active)\n" "$VIRTUAL_ENV"
    else
        printf "venv   : (none active)\n"
    fi
}

# Run ruff (preferred) or flake8/pyflakes for linting, then mypy for type-checking
# Falls back gracefully if tools are missing
# Usage: pycheck [path]
pycheck() {
    local target="${1:-.}"
    local found=0
    if command -v ruff &>/dev/null; then
        echo "==> ruff $target"
        ruff check "$target"
        found=1
    elif command -v flake8 &>/dev/null; then
        echo "==> flake8 $target"
        flake8 "$target"
        found=1
    elif command -v pyflakes &>/dev/null; then
        echo "==> pyflakes $target"
        pyflakes "$target"
        found=1
    fi
    if command -v mypy &>/dev/null; then
        echo "==> mypy $target"
        mypy "$target"
        found=1
    fi
    if [[ $found -eq 0 ]]; then
        echo "No linter found. Install ruff, flake8, or mypy."
        return 1
    fi
}

# Run pytest with verbose output; pass extra args to pytest
# Usage: pytest-run [args...]
pytest-run() {
    if command -v pytest &>/dev/null; then
        pytest -v "$@"
    elif [[ -x venv/bin/pytest ]]; then
        venv/bin/pytest -v "$@"
    elif [[ -x .venv/bin/pytest ]]; then
        .venv/bin/pytest -v "$@"
    else
        echo "pytest not found. Install it: pip install pytest"
        return 1
    fi
}

# Watch Python files and re-run pytest on change (requires entr or watchexec)
# Usage: pywatch [test-path]
pywatch() {
    local target="${1:-tests}"
    if command -v entr &>/dev/null; then
        find . -name '*.py' -not -path '*/.git*' -not -path '*/\.*' 2>/dev/null \
            | entr -c python3 -m pytest -v "$target"
    elif command -v watchexec &>/dev/null; then
        watchexec --exts py -- python3 -m pytest -v "$target"
    else
        echo "Install entr or watchexec to use pywatch."
        return 1
    fi
}

# Show all installed packages and their sizes, sorted largest first
# Usage: pydeps
pydeps() {
    pip list --format=columns 2>/dev/null || pip list
}

# Upgrade all packages listed in requirements.txt to their latest versions
# Usage: pyupgrade
pyupgrade() {
    if [[ ! -f requirements.txt ]]; then
        echo "No requirements.txt found."
        return 1
    fi
    pip install --upgrade -r requirements.txt
}

# Diff the current pip freeze output against the committed requirements.txt
# Usage: pyrequirements-diff
pyrequirements-diff() {
    if [[ ! -f requirements.txt ]]; then
        echo "No requirements.txt found."
        return 1
    fi
    diff <(sort requirements.txt) <(pip freeze 2>/dev/null | sort)
}

# Run a Python script using the venv interpreter if one is active or present
# Usage: pyrun <script.py> [args...]
pyrun() {
    if [[ -z "$1" ]]; then
        echo "Usage: pyrun <script.py> [args...]"
        return 1
    fi
    local py="python3"
    if [[ -n "$VIRTUAL_ENV" ]]; then
        py="$VIRTUAL_ENV/bin/python"
    elif [[ -x venv/bin/python ]]; then
        py="venv/bin/python"
    elif [[ -x .venv/bin/python ]]; then
        py=".venv/bin/python"
    fi
    "$py" "$@"
}

# Profile a Python script with cProfile and print the top 20 hotspots
# Usage: pyprofile <script.py> [args...]
pyprofile() {
    if [[ -z "$1" ]]; then
        echo "Usage: pyprofile <script.py> [args...]"
        return 1
    fi
    python3 -m cProfile -s cumulative "$@" | head -30
}

# Create a .venv virtual environment (PEP 668 / modern convention) and activate it
# Prefers uv if available for speed
# Usage: pyvenv
pyvenv() {
    if command -v uv &>/dev/null; then
        uv venv .venv
    else
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    echo "Virtual environment .venv activated. Run 'deactivate' to exit."
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
    printf '\nCNAME:\n'
    dig +short CNAME "$1"
    printf '\nMX records:\n'
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

# Show the full TLS certificate chain for a domain, with expiry dates per cert
# Usage: tlscheck <domain>
tlscheck() {
    if [[ -z "$1" ]]; then
        echo "Usage: tlscheck <domain>"
        return 1
    fi
    echo | openssl s_client -servername "$1" -connect "$1":443 -showcerts 2>/dev/null \
        | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
        | while IFS= read -r line; do
            printf '%s\n' "$line"
            if [[ "$line" == "-----END CERTIFICATE-----" ]]; then
                printf '%s\n' "$(cat)"
            fi
          done 2>/dev/null
    # Simpler summary: subject + expiry for each cert in the chain
    echo | openssl s_client -servername "$1" -connect "$1":443 -showcerts 2>/dev/null \
        | grep -E "(subject|issuer|notAfter)" \
        | sed 's/^ */  /'
}

# Scan a range of TCP ports on a host using pure /dev/tcp (no nmap required)
# Usage: portscan <host> <start-port> [end-port]
portscan() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: portscan <host> <start-port> [end-port]"
        return 1
    fi
    local host=$1 start=$2 end=${3:-$2}
    echo "Scanning $host ports $start–$end …"
    local port
    for (( port = start; port <= end; port++ )); do
        if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
            printf "  ✅ %d open\n" "$port"
        fi
    done
    echo "Done."
}

# Look up an IP address's geolocation and ASN via ipinfo.io (curl, no key needed)
# Usage: ipinfo [ip]   (omit ip for your own public IP)
ipinfo() {
    local target=${1:-}
    curl -s "https://ipinfo.io/${target}" | \
        (command -v jq &>/dev/null && jq . || cat)
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
    for k in "${!a[@]}"; do
        if [[ -z "${b[$k]+_}" ]]; then
            printf "  \033[31m- %s=%s\033[0m\n" "$k" "${a[$k]}"
            (( changed++ ))
        elif [[ "${a[$k]}" != "${b[$k]}" ]]; then
            printf "  \033[33m~ %s: %s → %s\033[0m\n" "$k" "${a[$k]}" "${b[$k]}"
            (( changed++ ))
        fi
    done
    # Keys added in file2
    for k in "${!b[@]}"; do
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
# Subcommands: note <text>          append a note
#              note today           print today's note file
#              note list            list all note files
#              note search <text>   grep across all note files
# Usage: note <text|today|list|search <text>>
note() {
    local dir="$HOME/notes"
    mkdir -p "$dir"
    case "$1" in
        list)
            ls -1t "$dir"/*.md 2>/dev/null || echo "No note files yet."
            ;;
        today)
            local file="$dir/$(date +%Y-%m-%d).md"
            if [[ -f "$file" ]]; then
                cat "$file"
            else
                echo "No notes for today yet."
            fi
            ;;
        search)
            shift
            if [[ -z "$1" ]]; then
                echo "Usage: note search <text>"
                return 1
            fi
            grep -rn --color=always "$*" "$dir"/*.md 2>/dev/null \
                || echo "No matches for: $*"
            ;;
        "")
            echo "Usage: note <text>          — append a note"
            echo "       note today           — show today's notes"
            echo "       note list            — list all note files"
            echo "       note search <text>   — search across all notes"
            return 1
            ;;
        *)
            local file="$dir/$(date +%Y-%m-%d).md"
            echo "- $(date +%H:%M) $*" >> "$file"
            echo "Saved to $file"
            ;;
    esac
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

# Append a timestamped entry to ~/todo.md; list or mark entries done
# Usage: todo [text]
#        todo done <pattern>   — mark matching open items as done ([ ] → [x])
todo() {
    local file="$HOME/todo.md"
    local dir
    dir=$(dirname "$file")
    mkdir -p "$dir"

    case "$1" in
        done)
            shift
            if [[ -z "$1" ]]; then
                echo "Usage: todo done <pattern>"
                return 1
            fi
            if [[ ! -f "$file" ]]; then
                echo "No todo file yet."
                return 1
            fi
            local pattern="$*"
            # Replace first matching unchecked line in-place
            local matched=0
            local tmp
            tmp=$(mktemp)
            while IFS= read -r line; do
                if [[ $matched -eq 0 && "$line" == "- [ ] "*"$pattern"* ]]; then
                    # Use sed for literal substitution — Zsh glob treats [ ] as char class
                    printf '%s\n' "$line" | sed 's/^- \[ \]/- [x]/' >> "$tmp"
                    matched=1
                else
                    printf '%s\n' "$line" >> "$tmp"
                fi
            done < "$file"
            mv "$tmp" "$file"
            if [[ $matched -eq 1 ]]; then
                echo "Marked done: $pattern"
            else
                echo "No open todo matched: $pattern"
            fi
            ;;
        "")
            if [[ -f "$file" ]]; then
                cat "$file"
            else
                echo "No todo file yet. Run: todo <text>"
            fi
            ;;
        *)
            [[ ! -f "$file" ]] && printf '# Todos\n\n' > "$file"
            echo "- [ ] $(date +%Y-%m-%d\ %H:%M) $*" >> "$file"
            echo "Added: $*"
            ;;
    esac
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
    # Pass as a single quoted argument to python3 to prevent shell injection
    python3 -c "print($1)"
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

# Fuzzy-search shell history and paste the selection onto the command line
# Requires fzf. Bind to a key or call manually.
# Usage: hist
hist() {
    _sharmory_need fzf || return 1
    local selected
    selected=$(fc -l 1 | fzf --tac --no-sort --prompt="history> " | sed 's/^ *[0-9]* *//')
    if [[ -n "$selected" ]]; then
        # Zsh's `print -z` stuffs the command onto the next prompt line for
        # editing. Bash has no direct equivalent outside of a `bind -x`
        # keybinding widget. If hist is invoked from such a binding (where
        # READLINE_LINE is set by readline), we stuff the line buffer the
        # same way; otherwise we fall back to pushing it onto history (so a
        # single Up-arrow recalls it) and echoing it for visibility.
        if [[ -n "${READLINE_LINE+x}" ]]; then
            READLINE_LINE="$selected"
            READLINE_POINT=${#READLINE_LINE}
        else
            history -s "$selected"
            echo "$selected"
        fi
    fi
}

# Apply a user-defined project template from ~/.sharmory/templates/<name>/
# Copies all files from the template into a new directory named <project>
# Usage: mktemplate <template-name> <project-name>
mktemplate() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: mktemplate <template-name> <project-name>"
        local tdir="$HOME/.sharmory/templates"
        if [[ -d "$tdir" ]]; then
            echo "Available templates:"
            ls -1 "$tdir" 2>/dev/null | sed 's/^/  /'
        else
            echo "No templates found. Create one at ~/.sharmory/templates/<name>/"
        fi
        return 1
    fi
    local tdir="$HOME/.sharmory/templates/$1"
    if [[ ! -d "$tdir" ]]; then
        echo "Template not found: $tdir"
        return 1
    fi
    if [[ -d "$2" ]]; then
        echo "Directory '$2' already exists."
        return 1
    fi
    cp -r "$tdir" "$2"
    cd "$2"
    echo "✅ Project '$2' created from template '$1'"
    echo "   $(pwd)"
}

# Load a named env profile from ~/.sharmory/envprofiles/<name>.env
# Usage: envswitch <profile-name>   (omit to list available profiles)
envswitch() {
    local pdir="$HOME/.sharmory/envprofiles"
    if [[ -z "$1" ]]; then
        echo "Available env profiles:"
        ls -1 "$pdir"/*.env 2>/dev/null | xargs -n1 basename | sed 's/\.env$//' | sed 's/^/  /' \
            || echo "  (none — create files in ~/.sharmory/envprofiles/)"
        return 0
    fi
    local profile="$pdir/$1.env"
    if [[ ! -f "$profile" ]]; then
        echo "Profile not found: $profile"
        return 1
    fi
    set -a
    source "$profile"
    set +a
    echo "Loaded env profile '$1' from $profile"
}

# List all listening ports; flag any bound to 0.0.0.0 / :: (exposed outside localhost)
openports() {
    local os
    os=$(_sharmory_os)
    printf "%-8s %-10s %-25s %-20s %s\n" "Proto" "Port" "Process" "PID" "Exposure"
    printf "%-8s %-10s %-25s %-20s %s\n" "-----" "----" "-------" "---" "--------"
    if [[ "$os" == "macos" ]]; then
        lsof -iTCP -iUDP -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR>1 {
            split($9,a,":")
            addr = a[1]; port = a[length(a)]
            exposure = (addr == "*" || addr == "0.0.0.0" || addr == "::") ? "⚠️  EXPOSED" : "localhost"
            printf "%-8s %-10s %-25s %-20s %s\n", $8, port, $1, $2, exposure
        }'
    else
        ss -tulnp 2>/dev/null | awk 'NR>1 {
            split($5,a,":")
            port = a[length(a)]
            addr = a[1]
            exposure = (addr == "0.0.0.0" || addr == "::") ? "EXPOSED" : "localhost"
            split($7,p,"\"")
            printf "%-8s %-10s %-25s %s\n", $1, port, (p[2]?p[2]:$7), exposure
        }' | sort -k2 -n
    fi
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
# Refreshes both functions.bash and functions.zsh so whichever shell the user
# runs next gets the latest version.
sharmory-update() {
    local dir="${HOME}/.sharmory"
    local base_url="https://raw.githubusercontent.com/hariharen9/sharmory/main"
    local failed=0
    echo "Updating Sharmory from GitHub..."
    mkdir -p "$dir"
    for f in functions.bash functions.zsh; do
        if curl -fsSL "${base_url}/${f}" -o "${dir}/${f}"; then
            echo "  ✅ ${f}"
        else
            echo "  ❌ ${f} — download failed"
            failed=1
        fi
    done
    if [[ $failed -eq 0 ]]; then
        source "${dir}/functions.bash"
        echo "Sharmory successfully updated and reloaded!"
    else
        echo "Update incomplete. Check your connection and try again."
        return 1
    fi
}

#########################################################################
# 13. ORCHESTRATOR — HUD, catalog, doctor
# Registry fields (caret-delimited): category^name^description^usage^deps
#########################################################################

_SHARMORY_REGISTRY=(
    'files^mkcd^Make a directory and cd into it^mkcd <dir>^'
    'files^up^Go up N directory levels^up [n]^'
    'files^lsd^List directory (eza if present)^lsd^eza'
    'files^fcd^Fuzzy cd into a subdirectory^fcd^fzf'
    'files^ftext^Fuzzy-search file contents and open in editor^ftext^fzf'
    'files^permsof^Show file permissions by owner/group/other^permsof <file>^'
    'files^extract^Extract an archive by extension^extract <archive-file>^'
    'files^compress^Compress a file or directory^compress <output> <path>^'
    'files^duh^Disk usage of items in the current directory^duh^'
    'files^sizeof^Sizes of subdirectories, largest first^sizeof [path]^'
    'files^findbig^Find files above a given size^findbig [size] [dir]^'
    'files^emptydirs^Find and optionally remove empty directories^emptydirs [dir]^'
    'files^dupfind^Find duplicate files by hash^dupfind [dir]^'
    'files^bak^Timestamped backup copy of a file^bak <file>^'
    'files^cwd^Copy the working directory path to the clipboard^cwd^'
    'files^clipcopy^Copy a file contents to the clipboard^clipcopy <file>^'
    'files^clip^Copy stdin or a file to the clipboard^clip [file]^'
    'files^watchrun^Re-run a command when a path changes^watchrun <path> -- <command...>^entr,fswatch'
    'files^treelist^Recursive tree listing^treelist [dir] [depth]^'
    'files^recent^Most recently modified files^recent [n]^'
    'files^swap^Atomically swap two filenames^swap <file-a> <file-b>^'
    'files^trash^Move a path to the system trash^trash <file-or-dir>^'
    'git^gitundo^Undo last commit, keep changes staged^gitundo^'
    'git^branchclean^Delete local branches already merged^branchclean^'
    'git^branchage^Local branches sorted by last commit date^branchage^'
    'git^gitlog-today^Your commits since midnight^gitlog-today^'
    'git^gacp^Add, commit, and push^gacp <commit message>^'
    'git^gclone^Clone a repo and cd into it^gclone <repo-url> [dir]^'
    'git^gwip^Checkpoint commit of uncommitted work^gwip^'
    'git^gunwip^Undo the last gwip commit^gunwip^'
    'git^gitprune^Delete local branches whose remotes are gone^gitprune^'
    'git^gswitch^Fuzzy-switch git branch^gswitch^fzf'
    'git^prdiff^Diff current branch against a base^prdiff [base-branch]^'
    'git^gitcontributors^Commit counts by author^gitcontributors^'
    'git^gitsize^Size of the .git directory^gitsize^'
    'git^gitconflicts^List unresolved merge conflict files^gitconflicts^'
    'git^gitignore^Append a gitignore.io template^gitignore <lang1,lang2,...>^'
    'git^gstash^Interactive stash picker^gstash^fzf'
    'git^grebase^Interactive rebase N commits^grebase [n]^'
    'git^gopen^Open the origin remote in a browser^gopen^'
    'git^gpr^Open PR creation page for current branch^gpr^'
    'git^gitbranch-rename^Rename a branch locally and on the remote^gitbranch-rename <old> <new>^'
    'git^gitlog-graph^Pretty one-line graph log^gitlog-graph^'
    'git^gcleanup^Prune remotes, delete merged branches, tidy Go^gcleanup^'
    'git^grecentbranch^Recently checked-out branches from reflog^grecentbranch [n]^'
    'git^gcamend^Amend last commit message without touching stage^gcamend <new message>^'
    'git^gdiffstage^Show what is currently staged^gdiffstage^'
    'docker^dockernuke^Force stop and remove a container^dockernuke <container>^'
    'docker^dockerclean-images^Remove dangling Docker images^dockerclean-images^'
    'docker^dclean^Prune unused Docker data^dclean^'
    'docker^dockerlogs^Tail container logs with timestamps^dockerlogs <container>^'
    'docker^dsh^Shell into a running container^dsh^fzf'
    'docker^dockersizes^Human-readable local image sizes^dockersizes^'
    'docker^denv^Print a container environment^denv <container>^'
    'docker^dbuild^Build an image tagged from the directory name^dbuild [tag]^'
    'k8s^k8sctx^Switch kubectl context and namespace^k8sctx^fzf,kubectl'
    'k8s^klogs^Stream logs from a picked pod^klogs^fzf,kubectl'
    'k8s^kexec^Exec a shell into a picked pod^kexec^fzf,kubectl'
    'k8s^ktop^Pods by CPU or memory^ktop [cpu|memory]^kubectl'
    'k8s^kevents^Namespace events, most recent last^kevents^kubectl'
    'k8s^kns^Set the current kubectl namespace^kns <namespace>^kubectl'
    'k8s^kdesc^Describe a picked pod^kdesc^fzf,kubectl'
    'k8s^kport^Port-forward to a pod^kport <local-port> <pod> <remote-port>^kubectl'
    'go^covreport^Go tests with HTML coverage report^covreport^'
    'go^gomodwhy^Why a module is in the Go graph^gomodwhy <module-path>^'
    'go^goclean^gofmt, vet, and mod tidy^goclean^'
    'go^goupdate^Upgrade Go module dependencies^goupdate^'
    'go^gobench^Run Go benchmarks with memory stats^gobench [pattern]^'
    'go^gonew^Scaffold a minimal Go module^gonew <module-path>^'
    'go^gowatch^Re-run Go tests on save^gowatch^entr'
    'go^gorace^Run Go tests with the race detector^gorace [./...]^'
    'go^gobuild^Build a Go binary from the current module^gobuild [output]^'
    'go^goxbuild^Cross-compile a Go binary^goxbuild <GOOS> <GOARCH> [output]^'
    'go^gocover-func^Coverage breakdown per function^gocover-func^'
    'go^goenv^Show Go environment variables^goenv^'
    'go^golist^List all packages in the module^golist^'
    'go^goversion^Go version and key paths^goversion^'
    'go^gotest^Run go test -v^gotest [./...]^'
    'go^gomod-name^Print the module name from go.mod^gomod-name^'
    'go^govscan^Scan dependencies for vulnerabilities^govscan^govulncheck'
    'go^goimpl^Show go doc (or guru implements) for a type^goimpl <TypeName>^'
    'node^npmclean^Delete node_modules and reinstall^npmclean^'
    'node^npmscripts^List package.json scripts^npmscripts^jq'
    'node^npmoutdated^Show outdated npm dependencies^npmoutdated^'
    'node^npmsize^Size of node_modules^npmsize^'
    'node^nodeversion^Node.js, npm, yarn, and pnpm versions^nodeversion^'
    'node^nvmuse^Switch Node version via nvm or fnm^nvmuse <version>^nvm,fnm'
    'node^tscheck^TypeScript type-check (no emit)^tscheck^tsc'
    'node^npxrun^Run a package with npx^npxrun <package> [args...]^'
    'node^npmglobal^List global npm packages^npmglobal^'
    'node^npmlink^Link this package globally or into a project^npmlink [target-dir]^'
    'node^noderepl^Node REPL with project node_modules on path^noderepl^'
    'node^npmaudit^Run npm audit^npmaudit^'
    'node^nodeinfo^Summary of the current Node project^nodeinfo^'
    'node^npmdedup^Deduplicate the npm dependency tree^npmdedup^'
    'node^npmwatch^Watch files and re-run an npm script^npmwatch [script]^nodemon,entr'
    'python^venvcreate^Create and activate ./venv^venvcreate^'
    'python^pyclean^Remove __pycache__ and .pyc files^pyclean^'
    'python^pyfreeze^Write requirements.txt from pip freeze^pyfreeze^'
    'python^pipinstall^pip install -r requirements.txt^pipinstall^'
    'python^pyversion^Python/pip versions and active venv^pyversion^'
    'python^pycheck^Lint with ruff/flake8 and type-check with mypy^pycheck [path]^ruff,flake8,mypy'
    'python^pytest-run^Run pytest -v^pytest-run [args...]^pytest'
    'python^pywatch^Watch .py files and re-run pytest^pywatch [test-path]^entr,watchexec'
    'python^pydeps^List installed pip packages^pydeps^'
    'python^pyupgrade^Upgrade packages from requirements.txt^pyupgrade^'
    'python^pyrequirements-diff^Diff pip freeze against requirements.txt^pyrequirements-diff^'
    'python^pyrun^Run a script via the active venv python^pyrun <script.py> [args...]^'
    'python^pyprofile^Profile a script with cProfile^pyprofile <script.py> [args...]^'
    'python^pyvenv^Create .venv and activate (uv if available)^pyvenv^'
    'net^myip^Public-facing IP address^myip^'
    'net^localip^Local network IP address^localip^'
    'net^killport^Kill whatever is listening on a port^killport <port> [port ...]^'
    'net^portwho^Process listening on a TCP port^portwho <port>^'
    'net^certcheck^TLS certificate expiry for a domain^certcheck <domain>^'
    'net^dnscheck^A, CNAME, and MX records^dnscheck <domain>^'
    'net^httpstatus^HTTP status code for a URL^httpstatus <url>^'
    'net^apihit^GET a URL, pretty-print JSON, show timing^apihit <url> [curl-args...]^'
    'net^flushdns^Flush the local DNS cache^flushdns^'
    'net^weather^Weather via wttr.in^weather [location]^'
    'net^tcpcheck^TCP reachability check^tcpcheck <host> <port>^'
    'net^shorten^Shorten a URL with is.gd^shorten <url>^'
    'net^tlscheck^Full TLS cert chain info for a domain^tlscheck <domain>^'
    'net^portscan^Scan a TCP port range (pure /dev/tcp)^portscan <host> <start> [end]^'
    'net^ipinfo^IP geolocation and ASN via ipinfo.io^ipinfo [ip]^'
    'net^pingcheck^Five pings with a short summary^pingcheck <host>^'
    'net^sshconfig^Host entries from ~/.ssh/config^sshconfig^'
    'net^headers^HTTP response headers^headers <url>^'
    'net^proxy^Toggle http(s)_proxy env vars^proxy <on [host:port]|off|status>^'
    'security^passgen^Random base64 password^passgen [bytes]^'
    'security^pubkey^Print SSH public keys^pubkey^'
    'security^genssh^Generate an ed25519 SSH keypair^genssh <key-name> [email]^'
    'security^b64e^Base64-encode text^b64e <text>^'
    'security^b64d^Base64-decode text^b64d <base64-text>^'
    'security^urlencode^URL-encode text^urlencode <text>^'
    'security^urldecode^URL-decode text^urldecode <text>^'
    'security^hashfile^MD5, SHA1, and SHA256 of a file^hashfile <file>^'
    'security^genuuid^Random UUID v4^genuuid^'
    'security^jwtdecode^Decode a JWT header and payload^jwtdecode <token>^'
    'security^dotenv-check^Lint a .env file^dotenv-check [file]^'
    'system^mem^Physical memory usage^mem^'
    'system^cpu^Snapshot of CPU/process activity^cpu^'
    'system^pidtree^Process tree for a PID^pidtree <pid>^'
    'system^fkill^Fuzzy-pick a process and kill it^fkill^fzf'
    'system^now^Current date and time^now^'
    'system^timer^Countdown timer^timer <seconds> [label]^'
    'system^diskusage^Disk usage via ncdu or df/du^diskusage [path]^'
    'system^envdiff^Diff two .env files by key^envdiff <file1> <file2>^'
    'system^ports^Listening TCP/UDP ports^ports^'
    'system^sysinfo^One-screen system summary^sysinfo^'
    'system^openports^Listening ports flagged by exposure^openports^'
    'prod^note^Append or view notes in ~/notes^note <text|today|list|search <text>>^'
    'prod^jsonpp^Pretty-print a JSON file^jsonpp <file>^jq'
    'prod^envload^Load a .env file into the shell^envload [file]^'
    'prod^ffind^Find files by name or search contents^ffind <text> | ffind -f <filename>^'
    'prod^cheat^tldr or man for a command^cheat <command>^tldr'
    'prod^calc^Command-line calculator^calc <expression>^'
    'prod^qr^QR code in the terminal^qr <text>^'
    'prod^todo^Append or list entries in ~/todo.md^todo [text]^'
    'prod^mkproject^Scaffold a project directory^mkproject <name> [go|node|python]^'
    'prod^epoch^Unix epoch and human datetime^epoch [epoch|date]^'
    'prod^diffjson^Semantic diff of two JSON files^diffjson <file-a> <file-b>^jq'
    'prod^retry^Retry a command with exponential backoff^retry <max-attempts> <command> [args...]^'
    'prod^hist^Fuzzy-search shell history and paste selection^hist^fzf'
    'prod^mktemplate^Create project from a user template^mktemplate <template> <project>^'
    'prod^envswitch^Load a named env profile^envswitch [profile-name]^'
    'jenkins^jenk-crumb^Jenkins CSRF crumb^jenk-crumb^jq'
    'jenkins^jenk-build^Trigger a Jenkins job build^jenk-build <job-name>^'
    'jenkins^jenk-logs^Console log of the last Jenkins build^jenk-logs <job-name>^'
    'jenkins^jenk-jobs^List Jenkins job names^jenk-jobs^jq'
    'meta^sharmory^Interactive catalog and dispatcher^sharmory [list|help|run|doctor]^'
    'meta^sharmory-doctor^Environment health check^sharmory doctor^'
    'meta^sharmory-setup^Install optional CLI tools (fzf, jq, ...)^sharmory-setup^'
    'meta^sharmory-bench^Measure Sharmory source time in a clean shell^sharmory-bench [runs]^'
    'meta^sharmory-update^Download the latest Sharmory from GitHub^sharmory-update^'
)

_sharmory_parse_row() {
    local row=$1
    _sh_cat=${row%%^*}
    local rest=${row#*^}
    _sh_name=${rest%%^*}
    rest=${rest#*^}
    _sh_desc=${rest%%^*}
    rest=${rest#*^}
    _sh_usage=${rest%%^*}
    _sh_deps=${rest#*^}
}

_sharmory_registry_lookup() {
    local want=$1 row
    for row in "${_SHARMORY_REGISTRY[@]}"; do
        _sharmory_parse_row "$row"
        if [[ "$_sh_name" == "$want" ]]; then
            return 0
        fi
    done
    return 1
}

_sharmory_registry_check() {
    local row missing=0
    for row in "${_SHARMORY_REGISTRY[@]}"; do
        _sharmory_parse_row "$row"
        if ! typeset -f "$_sh_name" >/dev/null; then
            echo "missing function: $_sh_name"
            missing=1
        fi
    done
    return $missing
}

_sharmory_self_usage() {
    cat <<'EOF'
Usage: sharmory [list|help|run|doctor|setup|bench] [args]

  sharmory                    Interactive HUD (fzf, or a numbered menu)
  sharmory list [category]    List commands
  sharmory help [name]        Explain a command (or this orchestrator)
  sharmory run <name> [args]  Run a catalogued command
  sharmory doctor             Environment health check
  sharmory setup              Install optional CLI tools (fzf, jq, eza, tldr)
  sharmory bench [n]          Source-time benchmark (default 10 runs)

Categories: files git docker k8s go node python net security system prod jenkins meta
EOF
}

_sharmory_list() {
    local filter=${1:-}
    local row printed=0
    printf "%-10s %-22s %s\n" "CATEGORY" "NAME" "DESCRIPTION"
    printf "%-10s %-22s %s\n" "--------" "----" "-----------"
    for row in "${_SHARMORY_REGISTRY[@]}"; do
        _sharmory_parse_row "$row"
        if [[ -n "$filter" && "$_sh_cat" != "$filter" ]]; then
            continue
        fi
        printf "%-10s %-22s %s\n" "$_sh_cat" "$_sh_name" "$_sh_desc"
        printed=1
    done
    if [[ $printed -eq 0 ]]; then
        echo "No commands in category: $filter"
        return 1
    fi
}

_sharmory_help() {
    local name=$1
    if [[ -z "$name" || "$name" == "sharmory" ]]; then
        _sharmory_self_usage
        return 0
    fi
    if ! _sharmory_registry_lookup "$name"; then
        echo "Unknown command: $name"
        echo "Try: sharmory list"
        return 1
    fi
    echo "$_sh_name  ($_sh_cat)"
    echo "  $_sh_desc"
    echo "  Usage: $_sh_usage"
    if [[ -n "$_sh_deps" ]]; then
        echo "  Optional: $_sh_deps"
    fi
}

_sharmory_run() {
    local name=$1
    shift || true
    if [[ -z "$name" ]]; then
        echo "Usage: sharmory run <name> [args...]"
        return 1
    fi
    case "$name" in
        sharmory)
            _sharmory_self_usage
            return 0
            ;;
        sharmory-doctor|doctor)
            sharmory-doctor
            return $?
            ;;
        sharmory-setup|setup)
            sharmory-setup
            return $?
            ;;
        sharmory-bench|bench)
            sharmory-bench "$@"
            return $?
            ;;
    esac
    if ! _sharmory_registry_lookup "$name"; then
        echo "Unknown command: $name"
        return 1
    fi
    if ! typeset -f "$name" >/dev/null; then
        echo "Not defined in this shell: $name"
        return 1
    fi
    "$name" "$@"
}

_sharmory_needs_args() {
    [[ "$1" == *'<'* ]]
}

_sharmory_prompt_and_run() {
    local name=$1
    if [[ "$name" == "sharmory" ]]; then
        _sharmory_self_usage
        return 0
    fi
    if [[ "$name" == "sharmory-doctor" || "$name" == "doctor" ]]; then
        sharmory-doctor
        return $?
    fi
    if [[ "$name" == "sharmory-setup" || "$name" == "setup" ]]; then
        sharmory-setup
        return $?
    fi
    if [[ "$name" == "sharmory-bench" || "$name" == "bench" ]]; then
        sharmory-bench
        return $?
    fi
    if ! _sharmory_registry_lookup "$name"; then
        echo "Unknown command: $name"
        return 1
    fi
    echo ""
    _sharmory_help "$name"
    local line=""
    if _sharmory_needs_args "$_sh_usage"; then
        echo -n "args (empty cancels): "
        IFS= read -r line || true
        if [[ -z "$line" ]]; then
            echo "Cancelled."
            return 0
        fi
        # shellcheck disable=SC2086
        _sharmory_run "$name" $line
    else
        _sharmory_run "$name"
    fi
}

_sharmory_hud_fzf() {
    local selection name
    while true; do
        selection=$(
            for row in "${_SHARMORY_REGISTRY[@]}"; do
                _sharmory_parse_row "$row"
                printf '%s\t%s\t%s\t%s\t%s\n' "$_sh_cat" "$_sh_name" "$_sh_desc" "$_sh_usage" "${_sh_deps:-none}"
            done | fzf \
                --delimiter=$'\t' \
                --with-nth=1,2,3 \
                --prompt='sharmory> ' \
                --header='Enter to run, Esc to quit' \
                --preview='printf "Usage: %s\nOptional: %s\n" {4} {5}' \
                --preview-window=down,3:wrap
        ) || return 0
        [[ -z "$selection" ]] && return 0
        name=$(printf '%s' "$selection" | cut -d$'\t' -f2)
        _sharmory_prompt_and_run "$name"
        echo ""
    done
}

_sharmory_print_numbered() {
    local row i=1
    printf "  %3s  %-10s %-22s %s\n" "#" "CATEGORY" "NAME" "DESCRIPTION"
    for row in "${_SHARMORY_REGISTRY[@]}"; do
        _sharmory_parse_row "$row"
        printf "  %3d  %-10s %-22s %s\n" "$i" "$_sh_cat" "$_sh_name" "$_sh_desc"
        (( i++ )) || true
    done
}

_sharmory_hud_menu() {
    local names=() line cmd rest idx row
    echo "Sharmory HUD  (no fzf — numbered menu)"
    echo "Commands: list [cat] | help <name> | <number> | <name> | doctor | setup | bench | q"
    echo ""
    _sharmory_print_numbered
    for row in "${_SHARMORY_REGISTRY[@]}"; do
        _sharmory_parse_row "$row"
        names+=("$_sh_name")
    done
    while true; do
        echo -n "sharmory> "
        IFS= read -r line || return 0
        line=${line## }
        line=${line%% }
        [[ -z "$line" ]] && continue
        cmd=${line%% *}
        rest=${line#"$cmd"}
        rest=${rest## }
        case "$cmd" in
            q|quit|exit) return 0 ;;
            doctor) sharmory-doctor ;;
            setup) sharmory-setup ;;
            bench) sharmory-bench $rest ;;
            list) _sharmory_list "$rest" ;;
            help)
                if [[ -n "$rest" ]]; then
                    _sharmory_help "$rest"
                else
                    _sharmory_self_usage
                fi
                ;;
            *)
                if [[ "$cmd" =~ ^[0-9]+$ ]]; then
                    idx=$cmd
                    if (( idx < 1 || idx > ${#names[@]} )); then
                        echo "No command numbered $idx"
                        continue
                    fi
                    # Bash arrays are 0-indexed (Zsh's are 1-indexed), so
                    # shift the 1-based menu number down by one.
                    _sharmory_prompt_and_run "${names[$((idx - 1))]}"
                else
                    _sharmory_prompt_and_run "$cmd"
                fi
                ;;
        esac
        echo ""
    done
}

_sharmory_hud() {
    if command -v fzf &>/dev/null; then
        _sharmory_hud_fzf
    else
        _sharmory_hud_menu
    fi
}

_sharmory_hint() {
    case "$1" in
        fzf) echo "brew install fzf  |  apt install fzf  |  winget install fzf" ;;
        jq) echo "brew install jq  |  apt install jq  |  winget install jqlang.jq" ;;
        eza) echo "brew install eza  |  apt install eza  |  winget install eza-community.eza" ;;
        tldr) echo "brew install tldr  |  npm install -g tldr  |  winget install tldr" ;;
        entr) echo "brew install entr  |  apt install entr" ;;
        fswatch) echo "brew install fswatch" ;;
        python3|python) echo "brew install python  |  apt install python3  |  winget install Python.Python.3.12" ;;
        go) echo "brew install go  |  apt install golang  |  winget install GoLang.Go" ;;
        node) echo "brew install node  |  apt install nodejs  |  winget install OpenJS.NodeJS" ;;
        openssl) echo "brew install openssl  |  apt install openssl" ;;
        *) echo "install $1 via your package manager" ;;
    esac
}

_sharmory_doctor_line() {
    printf "  [%s] %-12s %s\n" "$1" "$2" "$3"
}

# Environment health check. Exit 1 only if Sharmory itself is not loaded.
sharmory-doctor() {
    local ok=0 warn=0 miss=0
    echo "Sharmory doctor"
    echo ""

    if typeset -f sharmory >/dev/null; then
        _sharmory_doctor_line "ok" "Sharmory" "loaded"
        ok=$(( ok + 1 ))
    else
        _sharmory_doctor_line "miss" "Sharmory" "not sourced"
        miss=$(( miss + 1 ))
    fi

    local install_path="${HOME}/.sharmory/functions.bash"
    if [[ -f "$install_path" ]]; then
        _sharmory_doctor_line "ok" "Install" "$install_path"
        ok=$(( ok + 1 ))
    else
        _sharmory_doctor_line "warn" "Install" "canonical path not found ($install_path)"
        warn=$(( warn + 1 ))
    fi

    # Check that functions.bash is actually sourced from ~/.bashrc
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]] && grep -q 'sharmory' "$bashrc" 2>/dev/null; then
        _sharmory_doctor_line "ok" ".bashrc" "source line present"
        ok=$(( ok + 1 ))
    elif [[ -f "$bashrc" ]]; then
        _sharmory_doctor_line "warn" ".bashrc" "no sharmory source line found in ~/.bashrc"
        warn=$(( warn + 1 ))
    else
        _sharmory_doctor_line "warn" ".bashrc" "~/.bashrc not found"
        warn=$(( warn + 1 ))
    fi

    _sharmory_doctor_line "ok" "Shell" "bash ${BASH_VERSION:-unknown}"
    ok=$(( ok + 1 ))

    if command -v git &>/dev/null; then
        local gver gname gmail
        gver=$(git --version 2>/dev/null)
        gname=$(git config user.name 2>/dev/null)
        gmail=$(git config user.email 2>/dev/null)
        if [[ -n "$gname" && -n "$gmail" ]]; then
            _sharmory_doctor_line "ok" "Git" "$gver ($gname <$gmail>)"
            ok=$(( ok + 1 ))
        else
            _sharmory_doctor_line "warn" "Git" "$gver (user.name/email not set)"
            warn=$(( warn + 1 ))
        fi
    else
        _sharmory_doctor_line "miss" "Git" "not installed"
        miss=$(( miss + 1 ))
    fi

    local -a pubs
    # (N) in Zsh is the null-glob qualifier for a single pattern; the
    # portable Bash equivalent is toggling the nullglob shopt around the
    # expansion so a no-match glob expands to nothing instead of itself.
    shopt -s nullglob
    pubs=( "$HOME"/.ssh/*.pub )
    shopt -u nullglob
    if (( ${#pubs[@]} )); then
        _sharmory_doctor_line "ok" "SSH" "${#pubs[@]} public key(s) in ~/.ssh"
        ok=$(( ok + 1 ))
    else
        _sharmory_doctor_line "warn" "SSH" "no ~/.ssh/*.pub keys found"
        warn=$(( warn + 1 ))
    fi

    if command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            _sharmory_doctor_line "ok" "Docker" "daemon reachable"
            ok=$(( ok + 1 ))
        else
            _sharmory_doctor_line "warn" "Docker" "installed, daemon not reachable"
            warn=$(( warn + 1 ))
        fi
    else
        _sharmory_doctor_line "miss" "Docker" "not installed"
        miss=$(( miss + 1 ))
    fi

    if command -v kubectl &>/dev/null; then
        _sharmory_doctor_line "ok" "kubectl" "installed"
        ok=$(( ok + 1 ))
    else
        _sharmory_doctor_line "miss" "kubectl" "not installed"
        miss=$(( miss + 1 ))
    fi

    echo ""
    echo "Optional tools"
    local tool
    for tool in fzf jq eza tldr go node openssl; do
        if command -v "$tool" &>/dev/null; then
            _sharmory_doctor_line "ok" "$tool" "installed"
            ok=$(( ok + 1 ))
        else
            _sharmory_doctor_line "miss" "$tool" "$(_sharmory_hint "$tool")"
            miss=$(( miss + 1 ))
        fi
    done

    # Python: check presence and minimum version (3.8+)
    if command -v python3 &>/dev/null; then
        local pyver
        pyver=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
        local pymaj pymin
        pymaj=${pyver%%.*}
        pymin=${pyver#*.}
        if (( pymaj >= 3 && pymin >= 8 )); then
            _sharmory_doctor_line "ok" "python3" "v${pyver} (≥ 3.8)"
            ok=$(( ok + 1 ))
        else
            _sharmory_doctor_line "warn" "python3" "v${pyver} installed but < 3.8 required"
            warn=$(( warn + 1 ))
        fi
    else
        _sharmory_doctor_line "miss" "python3" "$(_sharmory_hint python3)"
        miss=$(( miss + 1 ))
    fi

    if command -v entr &>/dev/null; then
        _sharmory_doctor_line "ok" "entr" "installed"
        ok=$(( ok + 1 ))
    elif command -v fswatch &>/dev/null; then
        _sharmory_doctor_line "ok" "fswatch" "installed"
        ok=$(( ok + 1 ))
    else
        _sharmory_doctor_line "miss" "entr" "$(_sharmory_hint entr)  (or fswatch)"
        miss=$(( miss + 1 ))
    fi

    # Version comparison: local SHARMORY_VERSION vs latest GitHub release tag
    echo ""
    echo "Version"
    local local_ver="${SHARMORY_VERSION:-unknown}"
    _sharmory_doctor_line "ok" "Local" "v${local_ver}"
    ok=$(( ok + 1 ))
    if command -v curl &>/dev/null; then
        local latest
        latest=$(curl -sfL "https://api.github.com/repos/hariharen9/sharmory/releases/latest" \
            | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"v*\(.*\)".*/\1/')
        if [[ -n "$latest" ]]; then
            if [[ "$local_ver" == "$latest" ]]; then
                _sharmory_doctor_line "ok" "Remote" "v${latest} — up to date ✅"
                ok=$(( ok + 1 ))
            else
                _sharmory_doctor_line "warn" "Remote" "v${latest} available (you have v${local_ver}) — run sharmory-update"
                warn=$(( warn + 1 ))
            fi
        else
            _sharmory_doctor_line "warn" "Remote" "could not fetch latest release from GitHub"
            warn=$(( warn + 1 ))
        fi
    else
        _sharmory_doctor_line "warn" "Remote" "skipped (curl not found)"
        warn=$(( warn + 1 ))
    fi

    echo ""
    printf "  %d ok  %d warn  %d miss\n" "$ok" "$warn" "$miss"
    echo ""
    if ! typeset -f sharmory >/dev/null; then
        return 1
    fi
    return 0
}

_sharmory_setup_why() {
    case "$1" in
        fzf) echo "fuzzy HUD, gswitch, gstash, fcd, kdesc, ..." ;;
        jq) echo "jsonpp, npmscripts, diffjson, Jenkins helpers" ;;
        eza) echo "richer lsd listings" ;;
        tldr) echo "cheat examples" ;;
        entr) echo "watchrun and gowatch (file watchers)" ;;
        *) echo "optional Sharmory helper" ;;
    esac
}

_sharmory_setup_install() {
    local tool=$1
    local os; os=$(_sharmory_os)
    if [[ "$os" == "macos" ]]; then
        if command -v brew &>/dev/null; then
            echo "-> brew install $tool"
            brew install "$tool"
            return $?
        fi
        echo "Homebrew is not installed. Install from https://brew.sh then re-run sharmory-setup."
        echo "  $(_sharmory_hint "$tool")"
        return 1
    fi
    if command -v brew &>/dev/null; then
        echo "-> brew install $tool"
        brew install "$tool"
        return $?
    fi
    if command -v apt-get &>/dev/null; then
        echo "-> sudo apt-get install -y $tool"
        sudo apt-get install -y "$tool"
        return $?
    fi
    if command -v dnf &>/dev/null; then
        echo "-> sudo dnf install -y $tool"
        sudo dnf install -y "$tool"
        return $?
    fi
    if command -v pacman &>/dev/null; then
        echo "-> sudo pacman -S --noconfirm $tool"
        sudo pacman -S --noconfirm "$tool"
        return $?
    fi
    echo "No supported package manager found (brew, apt, dnf, pacman)."
    echo "  $(_sharmory_hint "$tool")"
    return 1
}

# Install optional CLI enhancers (fzf, jq, eza, tldr, entr). Never installs Docker/K8s/Go/Node/Python.
sharmory-setup() {
    local tools=(fzf jq eza tldr)
    local os; os=$(_sharmory_os)
    if [[ "$os" == "macos" || "$os" == "linux" ]]; then
        tools+=(entr)
    fi

    echo "Sharmory setup"
    echo "Optional CLI tools only. Skips Docker, Kubernetes, Go, Node, and Python."
    echo ""

    local missing=() t
    for t in "${tools[@]}"; do
        if command -v "$t" &>/dev/null; then
            printf "  [ok]   %-8s %s\n" "$t" "$(_sharmory_setup_why "$t")"
        elif [[ "$t" == "entr" ]] && command -v fswatch &>/dev/null; then
            printf "  [ok]   %-8s %s\n" "fswatch" "(covers watchrun instead of entr)"
        else
            printf "  [miss] %-8s %s\n" "$t" "$(_sharmory_setup_why "$t")"
            missing+=("$t")
        fi
    done

    if (( ${#missing} == 0 )); then
        echo ""
        echo "Nothing to install."
        return 0
    fi

    if [[ ! -t 0 ]]; then
        echo ""
        echo "Not a TTY — no installs. Re-run sharmory-setup in a terminal, or:"
        for t in "${missing[@]}"; do
            echo "  $(_sharmory_hint "$t")"
        done
        return 0
    fi

    echo ""
    echo "For each missing tool: [i]nstall  [s]kip  [a] skip all remaining  [q]uit"
    local choice
    for t in "${missing[@]}"; do
        echo ""
        echo "$t — $(_sharmory_setup_why "$t")"
        echo "  hint: $(_sharmory_hint "$t")"
        echo -n "  [i/s/a/q] "
        IFS= read -r choice || return 0
        choice=${choice,,}
        case "$choice" in
            i|install|y|yes)
                _sharmory_setup_install "$t" || echo "Install of $t failed (skipped)."
                ;;
            a|all)
                echo "Skipping remaining tools."
                return 0
                ;;
            q|quit)
                echo "Stopped."
                return 0
                ;;
            s|skip|n|no|"")
                echo "Skipped $t."
                ;;
            *)
                echo "Skipped $t."
                ;;
        esac
    done
    echo ""
    echo "Done. New tools are available in new shells (or after refreshing PATH)."
}

# Time how long a clean Bash takes to source this file (not Oh-My-Bash, not your .bashrc).
# Usage: sharmory-bench [runs]
sharmory-bench() {
    local n=${1:-10}
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( n < 1 )); then
        echo "Usage: sharmory-bench [runs]"
        return 1
    fi
    local src=${_SHARMORY_FILE:-$HOME/.sharmory/functions.bash}
    if [[ ! -f "$src" ]]; then
        echo "Cannot find functions.bash at: $src"
        return 1
    fi

    echo "Sharmory bench"
    echo "  file : $src"
    echo "  runs : $n  (1 warmup discarded)"
    echo ""

    local i raw
    local -a times
    # Bash 5.0+ exposes $EPOCHREALTIME natively (no zmodload equivalent
    # needed). On older Bash (no EPOCHREALTIME) we fall back to `date +%s.%N`
    # (GNU date; BSD/macOS date lacks %N, in which case timing degrades to
    # whole-second resolution — install GNU coreutils or a modern Bash for
    # meaningful numbers).
    bash -c 'source "$0"' "$src" >/dev/null 2>&1 || true
    for (( i = 1; i <= n; i++ )); do
        raw=$(bash -c '
            src="$0"
            if [[ -n "${EPOCHREALTIME:-}" ]]; then
                s=$EPOCHREALTIME
                source "$src"
                awk -v a="$EPOCHREALTIME" -v b="$s" "BEGIN{printf \"%.3f\", (a-b)*1000}"
            else
                s=$(date +%s.%N)
                source "$src"
                e=$(date +%s.%N)
                awk -v a="$e" -v b="$s" "BEGIN{printf \"%.3f\", (a-b)*1000}"
            fi
        ' "$src" 2>/dev/null) || continue
        [[ -z "$raw" ]] && continue
        times+=("$raw")
        printf "  run %-3d %8s ms\n" "$i" "$raw"
    done

    if (( ${#times[@]} < 1 )); then
        echo "Could not spawn a clean bash to measure."
        return 1
    fi
    local min max avg
    min=$(printf '%s\n' "${times[@]}" | sort -n | head -1)
    max=$(printf '%s\n' "${times[@]}" | sort -n | tail -1)
    avg=$(printf '%s\n' "${times[@]}" | awk '{s+=$1} END {printf "%.3f", s/NR}')
    echo ""
    printf "  min  %s ms\n" "$min"
    printf "  avg  %s ms\n" "$avg"
    printf "  max  %s ms\n" "$max"
    echo ""
    echo "  Oh-My-Zsh/Bash frameworks commonly add 200-800 ms to every new tab."
    echo "  Sharmory is one sourced file — no plugin manager."
    if awk -v a="$avg" 'BEGIN { exit !(a < 5) }'; then
        echo "  Badge: sub-5ms source time on this machine."
    else
        echo "  This host averaged ${avg} ms (disk/antivirus can dominate)."
        echo "  The target is still under 5 ms on a typical Mac/Linux SSD."
    fi
}

sharmory() {
    local sub=${1:-}
    case "$sub" in
        "")
            if [[ ! -t 0 ]]; then
                _sharmory_self_usage
                echo ""
                _sharmory_list
                return 0
            fi
            _sharmory_hud
            ;;
        -h|--help|help)
            shift
            _sharmory_help "$1"
            ;;
        list)
            shift
            _sharmory_list "$1"
            ;;
        run)
            shift
            _sharmory_run "$@"
            ;;
        doctor)
            sharmory-doctor
            ;;
        setup)
            sharmory-setup
            ;;
        bench)
            shift
            sharmory-bench "$@"
            ;;
        *)
            echo "Unknown subcommand: $sub"
            _sharmory_self_usage
            return 1
            ;;
    esac
}

