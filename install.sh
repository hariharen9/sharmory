#!/usr/bin/env bash
#
# Sharmory Installer for macOS, Linux, and WSL
# Auto-detects Zsh or Bash and installs the right file.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/install.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/hariharen9/sharmory/main"
TARGET_DIR="${HOME}/.sharmory"

echo "⚔️  Installing Sharmory..."

# Create the install directory
mkdir -p "$TARGET_DIR"

# Download both function files so whichever shell the user switches to later
# is already in place.
echo "📥 Downloading functions.zsh..."
curl -fsSL "${REPO_URL}/functions.zsh"   -o "${TARGET_DIR}/functions.zsh"
echo "📥 Downloading functions.bash..."
curl -fsSL "${REPO_URL}/functions.bash"  -o "${TARGET_DIR}/functions.bash"

# Detect which shell to configure.
# Prefer Zsh if it is the user's login shell; fall back to Bash.
_detect_shell() {
    local shell_bin
    # $SHELL is the login shell; prefer it when it points to zsh or bash.
    shell_bin="$(basename "${SHELL:-}")"
    case "$shell_bin" in
        zsh)  echo "zsh"  ; return ;;
        bash) echo "bash" ; return ;;
    esac
    # Login shell is something else (fish, sh, …) — fall back by availability.
    if command -v zsh &>/dev/null; then
        echo "zsh"
    else
        echo "bash"
    fi
}

DETECTED_SHELL="$(_detect_shell)"

if [[ "$DETECTED_SHELL" == "zsh" ]]; then
    FUNC_FILE="${TARGET_DIR}/functions.zsh"
    RC_FILE="${HOME}/.zshrc"
    SOURCE_LINE='[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh'
    NEEDLE="sharmory/functions.zsh"
    RELOAD_CMD="source ~/.zshrc"
else
    FUNC_FILE="${TARGET_DIR}/functions.bash"
    RC_FILE="${HOME}/.bashrc"
    SOURCE_LINE='[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash'
    NEEDLE="sharmory/functions.bash"
    RELOAD_CMD="source ~/.bashrc"
fi

echo "🐚 Detected shell: $DETECTED_SHELL → configuring $RC_FILE"

# Create the RC file if it doesn't exist yet
if [ ! -f "$RC_FILE" ]; then
    touch "$RC_FILE"
fi

# Append the source line only if it isn't already there
if grep -Fq "$NEEDLE" "$RC_FILE" 2>/dev/null; then
    echo "ℹ️  Sharmory is already configured in $RC_FILE"
else
    printf "\n# Sharmory — Dev shell toolkit\n%s\n" "$SOURCE_LINE" >> "$RC_FILE"
    echo "✅ Added Sharmory to $RC_FILE"
fi

echo ""
echo "✨ Sharmory successfully installed!"
echo "👉 Run: $RELOAD_CMD (or open a new terminal) to activate."
