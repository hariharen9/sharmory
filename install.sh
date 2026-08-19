#!/usr/bin/env bash
#
# Sharmory Installer for macOS, Linux, and WSL (Zsh)
# Usage: curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/install.sh | bash

set -e

REPO_URL="https://raw.githubusercontent.com/hariharen9/sharmory/main"
TARGET_DIR="${HOME}/.sharmory"
TARGET_FILE="${TARGET_DIR}/functions.zsh"
RC_FILE="${HOME}/.zshrc"

echo "⚔️  Installing Sharmory..."

# Create directory
mkdir -p "$TARGET_DIR"

# Download functions.zsh
echo "📥 Downloading functions.zsh..."
curl -fsSL "${REPO_URL}/functions.zsh" -o "$TARGET_FILE"

# Create .zshrc if it doesn't exist
if [ ! -f "$RC_FILE" ]; then
    touch "$RC_FILE"
fi

# Append to .zshrc if not already present
SOURCE_LINE='[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh'
if grep -Fq "sharmory/functions.zsh" "$RC_FILE" 2>/dev/null; then
    echo "ℹ️  Sharmory is already configured in $RC_FILE"
else
    printf "\n# Sharmory — Dev shell toolkit\n%s\n" "$SOURCE_LINE" >> "$RC_FILE"
    echo "✅ Added Sharmory to $RC_FILE"
fi

echo ""
echo "✨ Sharmory successfully installed!"
echo "👉 Run: source ~/.zshrc (or open a new terminal) to activate."
