#!/usr/bin/env zsh
#
# test-sharmory.zsh — sandboxed smoke test for every function in functions.zsh
#
# Runs each function in an isolated subprocess with mocked external commands
# (docker, kubectl, git remotes, curl, dns, ssh-keygen, fzf, etc.) so nothing
# touches the real network, real docker/k8s, real processes, or your real
# $HOME. Everything happens inside a throwaway temp directory that is deleted
# at the end, whether tests pass or fail.
#
# Usage:
#   ./test-sharmory.zsh [path/to/functions.zsh]
#
# Exit code: 0 if all tests passed/skipped, 1 if any test failed.

emulate -L zsh
setopt pipefail

SCRIPT_DIR="${0:A:h}"
FUNCTIONS_FILE="${1:-$SCRIPT_DIR/functions.zsh}"

if [[ ! -f "$FUNCTIONS_FILE" ]]; then
    echo "Cannot find functions.zsh at: $FUNCTIONS_FILE"
    echo "Usage: $0 [path/to/functions.zsh]"
    exit 1
fi

# Locate a real timeout binary (GNU coreutils on Linux, gtimeout via brew on macOS).
# If neither exists, we still run tests but skip the two functions that loop forever
# by design (watchrun, gowatch), since we can't guarantee we can kill them.
TIMEOUT_BIN=""
if command -v timeout &>/dev/null; then
    TIMEOUT_BIN="timeout"
elif command -v gtimeout &>/dev/null; then
    TIMEOUT_BIN="gtimeout"
fi

# Resolve real binaries we may need to delegate to from inside mocks, BEFORE
# we prepend the mock bin directory to PATH.
REAL_OPENSSL="$(command -v openssl 2>/dev/null)"
HAS_JQ=0;      command -v jq &>/dev/null      && HAS_JQ=1
HAS_PY=0;      command -v python3 &>/dev/null && HAS_PY=1
HAS_PIP=0;     command -v pip3 &>/dev/null    && HAS_PIP=1
HAS_TAR=0;     command -v tar &>/dev/null     && HAS_TAR=1

#########################################################################
# SANDBOX SETUP
#########################################################################

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/sharmory-test.XXXXXX")"
WORKDIR="$SANDBOX/work"
FAKEHOME="$SANDBOX/fakehome"
REMOTE_REPO="$SANDBOX/remote.git"
MOCKBIN="$SANDBOX/mockbin"
ENVFILE="$SANDBOX/env.zsh"

mkdir -p "$WORKDIR" "$FAKEHOME/.ssh" "$MOCKBIN"

cleanup() {
    cd /
    rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

echo "Sandbox: $SANDBOX"
echo "Testing: $FUNCTIONS_FILE"
echo ""

#########################################################################
# MOCK EXTERNAL COMMANDS
# (all live only inside $MOCKBIN, which is deleted with the sandbox)
#########################################################################

# --- fzf: auto-select the first non-empty line from stdin, no interactivity ---
cat > "$MOCKBIN/fzf" <<'EOF'
#!/usr/bin/env bash
line=""
while IFS= read -r l; do
    if [[ -n "$l" ]]; then line="$l"; break; fi
done
[[ -n "$line" ]] && printf '%s\n' "$line"
exit 0
EOF

# --- docker: canned responses for the few subcommands functions.zsh uses ---
cat > "$MOCKBIN/docker" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    ps\ --format*)          printf "mockid123\tmockcontainer\tmockimage\n" ;;
    images\ -f\ dangling*)  : ;;  # empty = "no dangling images"
    images\ --format*)      printf "mockrepo:latest\t123MB\n" ;;
    inspect\ --format*)     printf "MOCK_VAR=hello\nOTHER_VAR=world\n" ;;
    build*)                 echo "Successfully built mockimage123" ;;
    info*)                  echo "Client: Docker Engine - Community (mock)" ;;
    *) : ;;
esac
exit 0
EOF

# --- kubectl: canned responses for context/pod/namespace picking ---
cat > "$MOCKBIN/kubectl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    config\ get-contexts*)          echo "mock-context" ;;
    config\ set-context*)           echo "Context updated." ;;
    get\ ns*)                       echo "namespace/mock-ns" ;;
    get\ pods*)                     echo "pod/mock-pod" ;;
    top\ pods*)                     printf "NAME\tCPU\tMEMORY\nmock-pod\t1m\t2Mi\n" ;;
    get\ events*)                   echo "LAST SEEN   TYPE   REASON   OBJECT" ;;
    describe\ pod*)                 printf "Name: mock-pod\nNamespace: default\n" ;;
    port-forward*)                  echo "Forwarding from 127.0.0.1:8080 -> 80" ;;
    *) : ;;
esac
exit 0
EOF

# --- go / npm: no-op, always succeed ---
for cmd in go npm; do
cat > "$MOCKBIN/$cmd" <<EOF
#!/usr/bin/env bash
exit 0
EOF
done

# --- ssh-keygen: write fake key files instead of prompting for a passphrase ---
cat > "$MOCKBIN/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
outfile=""
for ((i=1;i<=$#;i++)); do
    if [[ "${!i}" == "-f" ]]; then
        j=$((i+1))
        outfile="${!j}"
    fi
done
if [[ -n "$outfile" ]]; then
    mkdir -p "$(dirname "$outfile")"
    echo "mock-private-key" > "$outfile"
    echo "ssh-ed25519 AAAAmockkey mock@sharmory" > "$outfile.pub"
fi
exit 0
EOF

# --- curl: never touches the real network; returns canned bodies/headers ---
cat > "$MOCKBIN/curl" <<'EOF'
#!/usr/bin/env bash
url=""
wfmt=""
outfile=""
has_o_devnull=false
head_only=false
args=("$@")
for ((i=0;i<${#args[@]};i++)); do
    case "${args[i]}" in http*|https*) url="${args[i]}" ;; esac
    if [[ "${args[i]}" == "-w" ]]; then wfmt="${args[i+1]}"; fi
    if [[ "${args[i]}" == "-o" ]]; then
        outfile="${args[i+1]}"
        if [[ "$outfile" == "/dev/null" ]]; then has_o_devnull=true; fi
    fi
    if [[ "${args[i]}" == "-I" || "${args[i]}" == "-sI" ]]; then head_only=true; fi
done

body='{"mock":"response"}'
[[ "$url" == *crumbIssuer* ]] && body='{"crumb":"mockcrumb1234"}'
[[ "$url" == *"/api/json"* && "$url" != *crumbIssuer* ]] && body='{"jobs":[{"name":"mock-job-1"},{"name":"mock-job-2"}]}'
[[ "$url" == *functions.zsh* ]] && body='# mock updated functions.zsh'
$has_o_devnull && body=""
$head_only && body="HTTP/2 200
content-type: text/html; charset=UTF-8
server: mock-server
x-powered-by: sharmory-test"

if [[ -n "$outfile" && "$outfile" != "/dev/null" ]]; then
    mkdir -p "$(dirname "$outfile")"
    printf '%s' "$body" > "$outfile"
fi

wout=""
if [[ -n "$wfmt" ]]; then
    wout="${wfmt//%\{http_code\}/200}"
    wout="${wout//%\{time_total\}/0.01}"
fi

if [[ -z "$outfile" || "$outfile" == "/dev/null" ]]; then
    printf '%s' "$body"
fi
printf '%b' "$wout"
exit 0
EOF

# --- openssl: delegate to the real binary except for the network-touching
#     s_client/x509 pair used by certcheck ---
cat > "$MOCKBIN/openssl" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "s_client" ]]; then
    echo "mock-cert-placeholder"
    exit 0
elif [[ "\$1" == "x509" ]]; then
    echo "notAfter=Jan  1 00:00:00 2030 GMT"
    exit 0
else
    exec "$REAL_OPENSSL" "\$@"
fi
EOF

# --- dig: canned DNS records, no real lookup ---
cat > "$MOCKBIN/dig" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *\ A|*\ A\ *)     echo "93.184.216.34" ;;
    *\ MX|*\ MX\ *)   echo "10 mock-mx.example.com." ;;
esac
exit 0
EOF

# --- ping: canned output so pingcheck has something to parse ---
cat > "$MOCKBIN/ping" <<'EOF'
#!/usr/bin/env bash
echo "PING $@ (93.184.216.34): 56 data bytes"
echo "64 bytes from 93.184.216.34: icmp_seq=0 ttl=55 time=12.345 ms"
echo "64 bytes from 93.184.216.34: icmp_seq=1 ttl=55 time=11.234 ms"
echo "64 bytes from 93.184.216.34: icmp_seq=2 ttl=55 time=13.456 ms"
echo "64 bytes from 93.184.216.34: icmp_seq=3 ttl=55 time=10.123 ms"
echo "64 bytes from 93.184.216.34: icmp_seq=4 ttl=55 time=12.000 ms"
echo ""
echo "--- $@ ping statistics ---"
echo "5 packets transmitted, 5 packets received, 0.0% packet loss"
echo "round-trip min/avg/max/stddev = 10.123/11.832/13.456/1.145 ms"
exit 0
EOF

# --- tree: canned output so treelist has a deterministic result ---
cat > "$MOCKBIN/tree" <<'EOF'
#!/usr/bin/env bash
echo "."
echo "├── file1.txt"
echo "├── main.go"
echo "└── sample.json"
echo ""
echo "0 directories, 3 files"
exit 0
EOF

# --- ncdu: no-op (non-interactive in test context) ---
cat > "$MOCKBIN/ncdu" <<'EOF'
#!/usr/bin/env bash
echo "[mock] ncdu $*"
exit 0
EOF

# --- generic silent no-ops: clipboard tools, media/app launchers, system tools ---
for cmd in afplay xdg-open open killall dscacheutil systemd-resolve pbcopy xclip wl-copy 7z unrar tldr; do
cat > "$MOCKBIN/$cmd" <<EOF
#!/usr/bin/env bash
cat >/dev/null 2>&1
exit 0
EOF
done

chmod +x "$MOCKBIN"/*

#########################################################################
# PER-TEST ENVIRONMENT
# Every test runs as its own `zsh -c` subprocess that sources this file
# first, so mocks/env are always fresh and nothing leaks between tests.
#########################################################################

cat > "$ENVFILE" <<EOF
export PATH="$MOCKBIN:\$PATH"
export HOME="$FAKEHOME"
export PAGER=cat GIT_PAGER=cat MANPAGER=cat EDITOR=cat VISUAL=cat
export JENKINS_URL="http://mock-jenkins.local"
export JENKINS_USER="mockuser"
export JENKINS_TOKEN="mocktoken"
# Never actually terminate a real process, no matter what fkill/killport pick.
kill() { echo "[mock] kill \$*"; return 0 }
sudo() { echo "[mock] sudo \$*"; "\$@" }
# Prevent mkproject's 'git commit' from needing a real identity in subshells
export GIT_AUTHOR_NAME="Sharmory Test"
export GIT_AUTHOR_EMAIL="test@sharmory.local"
export GIT_COMMITTER_NAME="Sharmory Test"
export GIT_COMMITTER_EMAIL="test@sharmory.local"
source "$FUNCTIONS_FILE"
EOF

#########################################################################
# SEED SANDBOX DATA
#########################################################################

git init -q --bare "$REMOTE_REPO"

cd "$WORKDIR"
git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main 2>/dev/null; }
# Local (not --global) config so identity resolves regardless of each
# subprocess's sandboxed $HOME (which has no ~/.gitconfig of its own).
git config user.email "test@sharmory.local"
git config user.name "Sharmory Test"
git config core.pager cat
git remote add origin "$REMOTE_REPO"

echo "hello" > file1.txt
echo "main.go dummy" > main.go
git add -A && git commit -q -m "initial commit"
git push -q -u origin main

git checkout -q -b feature/test-branch
echo "feature work" >> file1.txt
git add -A && git commit -q -m "feature commit"
git checkout -q main

echo '{"a":1,"b":{"c":2},"list":[1,2,3]}' > sample.json
printf 'FOO=bar\nBAZ=qux\n' > .env
echo '{"name":"mock","version":"1.0.0","scripts":{"test":"echo test","build":"echo build"}}' > package.json
mkdir -p node_modules && touch node_modules/.keep
mkdir -p updir/sub
echo "ssh-ed25519 AAAAmockkey mock@sharmory" > "$FAKEHOME/.ssh/id_ed25519.pub"

# Create a fake ~/.ssh/config for sshconfig tests
cat > "$FAKEHOME/.ssh/config" <<'SSHEOF'
Host devserver
    HostName dev.example.com
    User deploy
    Port 2222

Host staging
    HostName staging.example.com
    User ubuntu
SSHEOF

# Create a second .env file for envdiff tests
printf 'FOO=bar\nNEW_KEY=added\n' > "$WORKDIR/.env2"

# Create two JSON files that differ for diffjson tests
echo '{"a":1,"b":2}' > "$WORKDIR/a.json"
echo '{"a":1,"b":3,"c":4}' > "$WORKDIR/b.json"

# Create a sample JWT token (header.payload.sig — all base64url encoded, no real sig needed)
# Header: {"alg":"HS256","typ":"JWT"}  Payload: {"sub":"1234567890","name":"Test","iat":1516239022}
MOCK_JWT="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlRlc3QiLCJpYXQiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

# Create a clean .env and a bad .env for dotenv-check tests
printf 'APP_ENV=development\nLOG_LEVEL=info\n' > "$WORKDIR/.env.clean"
printf 'EMPTY_KEY=\nBAD KEY=oops\nFOO=has spaces here\nSECRET_TOKEN=plaintext\nFOO=duplicate\n' > "$WORKDIR/.env.bad"

HAS_ENTR=0;    command -v entr &>/dev/null    && HAS_ENTR=1
HAS_FSWATCH=0; command -v fswatch &>/dev/null && HAS_FSWATCH=1

#########################################################################
# TEST RUNNER
#########################################################################

# Each result is written to $RESULTSDIR/<seq> as a one-line record:
#   PASS|FAIL|SKIP <label> [exit-code] [log-snippet]
# The seq counter keeps insertion order so output matches source order.
RESULTSDIR="$SANDBOX/results"
mkdir -p "$RESULTSDIR"
_seq=0          # global insertion-order counter (incremented before fork)
_pids=()        # all background PIDs, waited on before printing

# _run_one: shared implementation — writes result file, returns rc
_run_one() {
    local label="$1" cmd="$2" seq="$3"
    local logfile="$RESULTSDIR/${seq}.log"
    local resfile="$RESULTSDIR/${seq}.res"
    local rc
    if [[ -n "$TIMEOUT_BIN" ]]; then
        "$TIMEOUT_BIN" 10 zsh -c "source '$ENVFILE'; cd '$WORKDIR'; $cmd" \
            >"$logfile" 2>&1 </dev/null
        rc=$?
    else
        zsh -c "source '$ENVFILE'; cd '$WORKDIR'; $cmd" \
            >"$logfile" 2>&1 </dev/null
        rc=$?
    fi
    if [[ $rc -eq 0 ]]; then
        printf 'PASS %s\n' "$label" > "$resfile"
    else
        local snippet
        snippet=$(sed 's/^/        | /' "$logfile" | head -4)
        printf 'FAIL %s\x00%d\x00%s\n' "$label" "$rc" "$snippet" > "$resfile"
    fi
}

# run: fire test in background (parallel)
run() {
    local label="$1" cmd="$2"
    (( _seq++ ))
    local seq=$_seq
    ( _run_one "$label" "$cmd" "$seq" ) &
    _pids+=($!)
}

# runs: run test sequentially — use for tests with shared mutable state (git)
runs() {
    local label="$1" cmd="$2"
    (( _seq++ ))
    _run_one "$label" "$cmd" "$_seq"
}

skip() {
    local label="$1" reason="$2"
    (( _seq++ ))
    local seq=$_seq
    printf 'SKIP %s\x00%s\n' "$label" "$reason" > "$RESULTSDIR/${seq}.res"
    printf '%s' "$label" > "$RESULTSDIR/${seq}.label"
}

# Wait for all background jobs, then print results in insertion order
print_results() {
    local section=""
    # Wait for every background job to finish
    for pid in "${_pids[@]}"; do
        wait "$pid" 2>/dev/null
    done

    local pass=0 fail=0 skip=0 total=0
    local i kind rest
    for (( i = 1; i <= _seq; i++ )); do
        local resfile="$RESULTSDIR/${i}.res"
        [[ ! -f "$resfile" ]] && continue
        IFS= read -r kind rest < "$resfile"
        rest="${kind#* }"
        kind="${kind%% *}"
        case "$kind" in
            SECTION)
                printf "\n-- %s --\n" "$rest"
                ;;
            PASS)
                (( total++ ))
                printf "  PASS  %-28s\n" "$rest"
                (( pass++ ))
                ;;
            FAIL)
                (( total++ ))
                local lbl rc snippet
                lbl="${rest%%$'\x00'*}"
                rest="${rest#*$'\x00'}"
                rc="${rest%%$'\x00'*}"
                snippet="${rest#*$'\x00'}"
                printf "  FAIL  %-28s (exit %s)\n" "$lbl" "$rc"
                [[ -n "$snippet" ]] && printf '%s\n' "$snippet"
                (( fail++ ))
                ;;
            SKIP)
                (( total++ ))
                local _lbl="${rest%%$'\x00'*}"
                local _reason="${rest#*$'\x00'}"
                printf "  SKIP  %-28s (%s)\n" "$_lbl" "$_reason"
                (( skip++ ))
                ;;
        esac
    done

    echo ""
    echo "================================================"
    printf "  %d total   %d passed   %d failed   %d skipped\n" \
        "$total" "$pass" "$fail" "$skip"
    echo "================================================"
    echo "Sandbox will be removed: $SANDBOX"
    [[ $fail -eq 0 ]]
}

# Write a section header into the results stream so it prints in order
section() {
    (( _seq++ ))
    printf 'SECTION %s\n' "$1" > "$RESULTSDIR/${_seq}.res"
}

#########################################################################
# 1. NAVIGATION & FILES
#########################################################################
section "Navigation & Files"
run  "mkcd"        "mkcd newdir_mkcd && [ \"\$(basename \$PWD)\" = newdir_mkcd ]"
run  "up"          "mkdir -p ud1/ud2 && cd ud1/ud2 && up 1 && [ \"\$(basename \$PWD)\" = ud1 ]"
run  "lsd"         "lsd"
run  "fcd"         "fcd"
run  "ftext"       "ftext"
run  "permsof"     "permsof file1.txt"
run  "treelist"    "treelist ."
run  "treelist(depth)" "treelist . 2"
run  "recent"      "recent 5"
run  "swap"        "echo a > swapA && echo b > swapB && swap swapA swapB && grep -q b swapA && grep -q a swapB"
run  "trash"       "echo trashme > trashtest.txt && trash trashtest.txt && [ ! -e trashtest.txt ]"
if [[ $HAS_TAR -eq 1 ]]; then
    run "extract"    "tar czf t.tar.gz file1.txt && mkdir xd && cd xd && extract ../t.tar.gz"
    run "compress"   "compress out.tar.gz file1.txt"
else
    skip "extract"   "tar not found"
    skip "compress"  "tar not found"
fi
run  "duh"         "duh"
run  "sizeof"      "sizeof"
run  "findbig"     "findbig"
run  "emptydirs"   "mkdir -p emptytest && emptydirs emptytest"
run  "dupfind"     "cp file1.txt file1_dup.txt && dupfind ."
run  "bak"         "bak file1.txt && ls file1.txt.*.bak >/dev/null"
run  "cwd"         "cwd"
run  "clipcopy"    "clipcopy file1.txt"
if [[ -z "$TIMEOUT_BIN" ]]; then
    skip "watchrun" "no timeout binary available to safely bound this test"
elif [[ $HAS_ENTR -eq 0 && $HAS_FSWATCH -eq 0 ]]; then
    skip "watchrun" "neither entr nor fswatch installed"
else
    run "watchrun" "watchrun . true"
fi

#########################################################################
# 2. GIT
#########################################################################
section "Git"
runs  "gitundo"          "git commit --allow-empty -q -m tmp && gitundo"
runs  "branchclean"      "branchclean"
runs  "branchage"        "branchage"
runs  "gitlog-today"     "gitlog-today"
runs  "gacp"              "git checkout -q feature/test-branch && echo more >> file1.txt && gacp 'test commit via gacp'"
runs  "gclone"            "cd .. && rm -rf clone-test && gclone '$REMOTE_REPO' clone-test"
runs  "gwip"               "echo wipchange >> file1.txt && gwip"
runs  "gunwip"             "gunwip"
runs  "gitprune"           "gitprune"
runs  "gswitch"            "gswitch"
runs  "prdiff"             "git checkout -q main 2>/dev/null; prdiff"
runs  "gitcontributors"    "gitcontributors"
runs  "gitsize"            "gitsize"
runs  "gitconflicts"       "gitconflicts"
runs  "gitignore"          "gitignore go,macos"
runs  "gstash"             "echo wipstash >> file1.txt && git add -A && git stash && gstash"
runs  "grebase"            "grebase 1"
runs  "gopen"              "gopen"
runs  "gitbranch-rename"   "git checkout -q main && git checkout -q -b rename-old && gitbranch-rename rename-old rename-new && git checkout -q main"
runs  "gitlog-graph"       "gitlog-graph"
runs  "gcleanup"           "gcleanup"

#########################################################################
# 3. DOCKER & KUBERNETES (docker/kubectl fully mocked — no real daemon touched)
#########################################################################
section "Docker & Kubernetes"
run  "dockernuke"          "dockernuke mockcontainer"
run  "dockerclean-images"  "dockerclean-images"
run  "dclean"              "dclean"
run  "dockerlogs"          "dockerlogs mockcontainer"
run  "dsh"                 "dsh"
run  "dockersizes"         "dockersizes"
run  "k8sctx"              "k8sctx"
run  "klogs"                "klogs"
run  "kexec"                "kexec"
run  "ktop"                 "ktop"
run  "kevents"              "kevents"
run  "denv"                 "denv mockcontainer"
run  "dbuild"               "dbuild mytestimage"
run  "dbuild(auto-tag)"     "dbuild"
run  "kns"                  "kns mock-ns"
run  "kdesc"                "kdesc"
run  "kport"                "kport 8080 mock-pod 80"

#########################################################################
# 4. GO (go binary fully mocked — no real build/test runs)
#########################################################################
section "Go"
run  "covreport"   "covreport"
run  "gomodwhy"    "gomodwhy example.com/mockmod"
run  "goclean"     "goclean"
run  "goupdate"    "goupdate"
run  "gobench"     "gobench"
run  "gonew"       "mkdir -p gonew_test && cd gonew_test && gonew example.com/mocktest"
if [[ -z "$TIMEOUT_BIN" ]]; then
    skip "gowatch" "no timeout binary available to safely bound this test"
elif [[ $HAS_ENTR -eq 0 ]]; then
    skip "gowatch" "entr not installed"
else
    run "gowatch"  "gowatch"
fi

#########################################################################
# 5. NODE / NPM (npm binary fully mocked)
#########################################################################
section "Node/npm"
run  "npmclean"     "npmclean"
if [[ $HAS_JQ -eq 1 ]]; then
    run "npmscripts" "echo '{\"name\":\"m\",\"scripts\":{\"test\":\"echo t\"}}' > package.json && npmscripts"
else
    skip "npmscripts" "jq not found"
fi
run  "npmoutdated"  "npmoutdated"
run  "npmsize"      "mkdir -p node_modules && npmsize"

#########################################################################
# 6. PYTHON
#########################################################################
section "Python"
if [[ $HAS_PY -eq 1 ]]; then
    run "venvcreate" "rm -rf venv && venvcreate"
else
    skip "venvcreate" "python3 not found"
fi
run  "pyclean"   "mkdir -p __pycache__ && touch __pycache__/x.pyc dummy.pyc && pyclean"
if [[ $HAS_PIP -eq 1 ]]; then
    run "pyfreeze" "pyfreeze"
else
    skip "pyfreeze" "pip3 not found"
fi

#########################################################################
# 7. NETWORKING & APIs (curl/dns/openssl s_client all mocked — no real network)
#########################################################################
section "Networking"
run  "myip"         "myip"
run  "localip"      "localip"
run  "killport"     "killport 65533"
run  "portwho"      "portwho 65533"
run  "certcheck"    "certcheck example.com"
run  "dnscheck"     "dnscheck example.com"
run  "httpstatus"   "httpstatus https://example.com"
run  "apihit"       "apihit https://example.com/api"
run  "flushdns"     "flushdns"
run  "weather"      "weather london"
run  "tcpcheck"     "tcpcheck 127.0.0.1 65533"
run  "shorten"      "shorten https://example.com"
run  "pingcheck"    "pingcheck example.com"
run  "sshconfig"    "sshconfig"
run  "headers"      "headers https://example.com"
run  "proxy(on)"    "proxy on http://proxy.local:3128"
run  "proxy(off)"   "proxy on http://p:1 && proxy off"
run  "proxy(status)" "proxy status"

#########################################################################
# 8. SECURITY & ENCODING
#########################################################################
section "Security & Encoding"
run  "passgen"    "passgen"
run  "pubkey"     "pubkey"
run  "genssh"     "genssh testkey mock@sharmory"
run  "b64e"       "b64e hello"
run  "b64d"       "b64d aGVsbG8="
if [[ $HAS_PY -eq 1 ]]; then
    run "urlencode" "urlencode 'a b&c'"
    run "urldecode" "urldecode 'a%20b'"
else
    skip "urlencode" "python3 not found"
    skip "urldecode" "python3 not found"
fi
run  "hashfile"   "hashfile file1.txt"
run  "genuuid"    "genuuid"
run  "jwtdecode"  "jwtdecode '$MOCK_JWT'"
run  "dotenv-check(clean)" "printf 'APP_ENV=dev\nLOG_LEVEL=info\n' > /tmp/sharmory-env-clean && dotenv-check /tmp/sharmory-env-clean; rm -f /tmp/sharmory-env-clean"
run  "dotenv-check(bad)"   "printf 'EMPTY=\nSECRET_TOKEN=plain\nFOO=has spaces\n' > /tmp/sharmory-env-bad && dotenv-check /tmp/sharmory-env-bad; ret=\$?; rm -f /tmp/sharmory-env-bad; [ \$ret -ne 0 ]"

#########################################################################
# 9. SYSTEM & PROCESS (kill is mocked — nothing is ever really signaled)
#########################################################################
section "System & Process"
run  "mem"      "mem"
run  "cpu"      "cpu"
run  "pidtree"  "pidtree \$\$"
run  "fkill"    "fkill"
run  "now"      "now"
run  "timer"    "timer 1 TestTimer"
run  "diskusage"   "diskusage ."
run  "envdiff"       "printf 'A=1\n' > /tmp/ea && printf 'A=2\nB=3\n' > /tmp/eb && envdiff /tmp/ea /tmp/eb; rm -f /tmp/ea /tmp/eb"
run  "envdiff(same)" "printf 'A=1\n' > /tmp/ec && envdiff /tmp/ec /tmp/ec; rm -f /tmp/ec"
run  "ports"       "ports"
run  "sysinfo"     "sysinfo"

#########################################################################
# 10. PRODUCTIVITY & MISC
#########################################################################
section "Productivity"
run  "note"      "note 'test note from sharmory tests'"
if [[ $HAS_JQ -eq 1 ]]; then
    run "jsonpp" "echo '{\"k\":1}' > /tmp/sharmory-test.json && jsonpp /tmp/sharmory-test.json; rm -f /tmp/sharmory-test.json"
else
    skip "jsonpp" "jq not found"
fi
run  "envload"       "printf 'FOO=bar\nBAZ=qux\n' > /tmp/sharmory-test.env && envload /tmp/sharmory-test.env; rm -f /tmp/sharmory-test.env"
run  "ffind (name)"  "ffind -f file1"
run  "ffind (text)"  "ffind hello"
run  "cheat"         "cheat ls"
if [[ $HAS_PY -eq 1 ]]; then
    run "calc" "calc '2+2'"
else
    skip "calc" "python3 not found"
fi
run  "qr"    "qr hello"
run  "todo(add)"   "todo 'buy groceries'"
run  "todo(list)"  "todo"
run  "mkproject(bare)"   "cd /tmp && rm -rf sharmory-bare-test && mkproject sharmory-bare-test bare && [ -f /tmp/sharmory-bare-test/README.md ]; ret=\$?; rm -rf /tmp/sharmory-bare-test; exit \$ret"
run  "mkproject(node)"   "cd /tmp && rm -rf sharmory-node-test && mkproject sharmory-node-test node && [ -f /tmp/sharmory-node-test/package.json ]; ret=\$?; rm -rf /tmp/sharmory-node-test; exit \$ret"
run  "mkproject(python)" "cd /tmp && rm -rf sharmory-py-test && mkproject sharmory-py-test python && [ -f /tmp/sharmory-py-test/main.py ]; ret=\$?; rm -rf /tmp/sharmory-py-test; exit \$ret"
run  "epoch(now)"    "epoch"
run  "epoch(from-ts)" "epoch 0"
if [[ $HAS_JQ -eq 1 ]]; then
    run  "diffjson"       "echo '{\"a\":1}' > /tmp/ja && echo '{\"a\":2}' > /tmp/jb && diffjson /tmp/ja /tmp/jb; ret=\$?; rm -f /tmp/ja /tmp/jb; [ \$ret -ne 0 ]"
    run  "diffjson(same)" "echo '{\"a\":1}' > /tmp/jc && diffjson /tmp/jc /tmp/jc; rm -f /tmp/jc"
else
    skip "diffjson"       "jq not found"
    skip "diffjson(same)" "jq not found"
fi
run  "retry(pass)"   "retry 3 true"
run  "retry(fail)"   "retry 2 false; [ \$? -ne 0 ]"

#########################################################################
# 11. CI / JENKINS (curl mocked — no real Jenkins server contacted)
#########################################################################
section "CI/Jenkins"
if [[ $HAS_JQ -eq 1 ]]; then
    run "jenk-crumb" "jenk-crumb"
    run "jenk-jobs"  "jenk-jobs"
else
    skip "jenk-crumb" "jq not found"
    skip "jenk-jobs"  "jq not found"
fi
run  "jenk-build"  "jenk-build mock-job"
run  "jenk-logs"   "jenk-logs mock-job"

#########################################################################
# 12. SHARMORY MANAGEMENT
#########################################################################
section "Sharmory Management"
run  "sharmory-update" "sharmory-update"

#########################################################################
# 13. ORCHESTRATOR
#########################################################################
section "Orchestrator"
run  "sharmory unknown"   "sharmory nosuch; [[ \$? -ne 0 ]]"
run  "sharmory list"      "sharmory list | grep -q mkcd"
run  "sharmory list git"  "sharmory list git | grep -q gitundo"
run  "sharmory help mkcd" "sharmory help mkcd | grep -q Usage"
run  "sharmory run now"   "sharmory run now"
run  "sharmory doctor"    "sharmory doctor | grep -q 'Sharmory doctor'"
run  "sharmory-setup"     "sharmory-setup | grep -q 'Sharmory setup'"
run  "registry"          "_sharmory_registry_check"

#########################################################################
# SUMMARY — wait for all parallel jobs, then print in order
#########################################################################
print_results
