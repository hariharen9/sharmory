#!/usr/bin/env bash
#
# Sharmory Uninstaller for macOS, Linux, and WSL (Zsh)
# Usage: curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.sh | bash

set -e

TARGET_DIR="${HOME}/.sharmory"
RC_FILE="${HOME}/.zshrc"

echo "🗑️  Uninstalling Sharmory..."

# Remove directory
if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "✅ Removed $TARGET_DIR"
fi

# Clean .zshrc
if [ -f "$RC_FILE" ]; then
    sed -i.bak '/sharmory/d' "$RC_FILE" 2>/dev/null || sed -i '' '/sharmory/d' "$RC_FILE" 2>/dev/null
    rm -f "${RC_FILE}.bak"
    echo "✅ Removed Sharmory entries from $RC_FILE"
fi

echo "✨ Sharmory successfully uninstalled."
