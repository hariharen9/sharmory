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
    *) : ;;
esac
exit 0
EOF

# --- kubectl: canned responses for context/pod/namespace picking ---
cat > "$MOCKBIN/kubectl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    config\ get-contexts*) echo "mock-context" ;;
    get\ ns*)              echo "namespace/mock-ns" ;;
    get\ pods*)            echo "pod/mock-pod" ;;
    top\ pods*)            printf "NAME\tCPU\tMEMORY\nmock-pod\t1m\t2Mi\n" ;;
    get\ events*)          echo "LAST SEEN   TYPE   REASON   OBJECT" ;;
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
has_o_devnull=false
args=("$@")
for ((i=0;i<${#args[@]};i++)); do
    case "${args[i]}" in http*) url="${args[i]}" ;; esac
    if [[ "${args[i]}" == "-w" ]]; then wfmt="${args[i+1]}"; fi
    if [[ "${args[i]}" == "-o" && "${args[i+1]}" == "/dev/null" ]]; then has_o_devnull=true; fi
done

body='{"mock":"response"}'
[[ "$url" == *crumbIssuer* ]] && body='{"crumb":"mockcrumb1234"}'
[[ "$url" == *"/api/json"* && "$url" != *crumbIssuer* ]] && body='{"jobs":[{"name":"mock-job-1"},{"name":"mock-job-2"}]}'
$has_o_devnull && body=""

wout=""
if [[ -n "$wfmt" ]]; then
    wout="${wfmt//%\{http_code\}/200}"
    wout="${wout//%\{time_total\}/0.01}"
fi

printf '%s' "$body"
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

HAS_ENTR=0;    command -v entr &>/dev/null    && HAS_ENTR=1
HAS_FSWATCH=0; command -v fswatch &>/dev/null && HAS_FSWATCH=1

#########################################################################
# TEST RUNNER
#########################################################################

PASS=0
FAIL=0
SKIP=0
TOTAL=0

LOGFILE="$SANDBOX/last.log"

run() {
    local label="$1"
    local cmd="$2"
    ((TOTAL++))
    local rc
    if [[ -n "$TIMEOUT_BIN" ]]; then
        "$TIMEOUT_BIN" 10 zsh -c "source '$ENVFILE'; cd '$WORKDIR'; $cmd" >"$LOGFILE" 2>&1 </dev/null
        rc=$?
    else
        zsh -c "source '$ENVFILE'; cd '$WORKDIR'; $cmd" >"$LOGFILE" 2>&1 </dev/null
        rc=$?
    fi
    if [[ $rc -eq 0 ]]; then
        printf "  PASS  %-22s\n" "$label"
        ((PASS++))
    else
        printf "  FAIL  %-22s (exit %d)\n" "$label" "$rc"
        sed 's/^/        | /' "$LOGFILE" | head -4
        ((FAIL++))
    fi
}

skip() {
    local label="$1"
    local reason="$2"
    ((TOTAL++))
    printf "  SKIP  %-22s (%s)\n" "$label" "$reason"
    ((SKIP++))
}

#########################################################################
# 1. NAVIGATION & FILES
#########################################################################
echo "-- Navigation & Files --"
run  "mkcd"        "mkcd newdir_mkcd && [ \"\$(basename \$PWD)\" = newdir_mkcd ]"
run  "up"          "mkdir -p ud1/ud2 && cd ud1/ud2 && up 1 && [ \"\$(basename \$PWD)\" = ud1 ]"
run  "lsd"         "lsd"
run  "fcd"         "fcd"
run  "ftext"       "ftext"
run  "permsof"     "permsof file1.txt"
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
echo "-- Git --"
run  "gitundo"          "git commit --allow-empty -q -m tmp && gitundo"
run  "branchclean"      "branchclean"
run  "branchage"        "branchage"
run  "gitlog-today"     "gitlog-today"
run  "gacp"              "git checkout -q feature/test-branch && echo more >> file1.txt && gacp 'test commit via gacp'"
run  "gclone"            "cd .. && rm -rf clone-test && gclone '$REMOTE_REPO' clone-test"
run  "gwip"               "echo wipchange >> file1.txt && gwip"
run  "gunwip"             "gunwip"
run  "gitprune"           "gitprune"
run  "gswitch"            "gswitch"
run  "prdiff"             "git checkout -q main 2>/dev/null; prdiff"
run  "gitcontributors"    "gitcontributors"
run  "gitsize"            "gitsize"
run  "gitconflicts"       "gitconflicts"
run  "gitignore"          "gitignore go,macos"

#########################################################################
# 3. DOCKER & KUBERNETES (docker/kubectl fully mocked — no real daemon touched)
#########################################################################
echo "-- Docker & Kubernetes --"
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

#########################################################################
# 4. GO (go binary fully mocked — no real build/test runs)
#########################################################################
echo "-- Go --"
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
echo "-- Node/npm --"
run  "npmclean"     "npmclean"
if [[ $HAS_JQ -eq 1 ]]; then
    run "npmscripts" "npmscripts"
else
    skip "npmscripts" "jq not found"
fi
run  "npmoutdated"  "npmoutdated"
run  "npmsize"      "mkdir -p node_modules && npmsize"

#########################################################################
# 6. PYTHON
#########################################################################
echo "-- Python --"
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
echo "-- Networking --"
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

#########################################################################
# 8. SECURITY & ENCODING
#########################################################################
echo "-- Security & Encoding --"
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

#########################################################################
# 9. SYSTEM & PROCESS (kill is mocked — nothing is ever really signaled)
#########################################################################
echo "-- System & Process --"
run  "mem"      "mem"
run  "cpu"      "cpu"
run  "pidtree"  "pidtree \$\$"
run  "fkill"    "fkill"
run  "now"      "now"
run  "timer"    "timer 1 TestTimer"

#########################################################################
# 10. PRODUCTIVITY & MISC
#########################################################################
echo "-- Productivity --"
run  "note"      "note 'test note from sharmory tests'"
if [[ $HAS_JQ -eq 1 ]]; then
    run "jsonpp" "jsonpp sample.json"
else
    skip "jsonpp" "jq not found"
fi
run  "envload"       "envload .env"
run  "ffind (name)"  "ffind -f file1"
run  "ffind (text)"  "ffind hello"
run  "cheat"         "cheat ls"
if [[ $HAS_PY -eq 1 ]]; then
    run "calc" "calc '2+2'"
else
    skip "calc" "python3 not found"
fi
run  "qr"    "qr hello"

#########################################################################
# 11. CI / JENKINS (curl mocked — no real Jenkins server contacted)
#########################################################################
echo "-- CI/Jenkins --"
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
# SUMMARY
#########################################################################
echo ""
echo "================================================"
printf "  %d total   %d passed   %d failed   %d skipped\n" "$TOTAL" "$PASS" "$FAIL" "$SKIP"
echo "================================================"
echo "Sandbox will be removed: $SANDBOX"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
