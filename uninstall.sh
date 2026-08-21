#!/usr/bin/env bash
#
# Sharmory Uninstaller for macOS, Linux, and WSL
# Removes ~/.sharmory and cleans both ~/.zshrc and ~/.bashrc.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.sh | bash

set -e

TARGET_DIR="${HOME}/.sharmory"

echo "🗑️  Uninstalling Sharmory..."

# Remove the install directory
if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "✅ Removed $TARGET_DIR"
else
    echo "ℹ️  $TARGET_DIR not found — skipping"
fi

# Remove the source line from whichever RC files contain it.
# Handles Zsh, Bash, or both if the user has configured multiple shells.
_clean_rc() {
    local rc="$1"
    if [ -f "$rc" ] && grep -qF "sharmory" "$rc" 2>/dev/null; then
        # Try GNU sed (-i with no suffix), fall back to BSD sed (-i '')
        sed -i '/sharmory/d' "$rc" 2>/dev/null || sed -i '' '/sharmory/d' "$rc"
        echo "✅ Removed Sharmory entries from $rc"
    fi
}

_clean_rc "${HOME}/.zshrc"
_clean_rc "${HOME}/.bashrc"

echo ""
echo "✨ Sharmory successfully uninstalled."
