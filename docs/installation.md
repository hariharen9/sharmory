# Installation

This guide covers every supported installation method for Sharmory on macOS, Linux, WSL, and Windows.

---

## Quick Install (Recommended)

### macOS / Linux / WSL

Detects your login shell automatically and installs the right file.

```bash
curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/install.sh | bash
```

What it does:
1. Downloads `functions.zsh` and `functions.bash` to `~/.sharmory/`
2. Detects your login shell (`$SHELL`)
3. Appends a guarded source line to `~/.zshrc` (Zsh) or `~/.bashrc` (Bash)
4. Prints the reload command to activate immediately

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/hariharen9/sharmory/main/install.ps1 | iex
```

What it does:
1. Downloads `functions.ps1` to `$HOME\sharmory\`
2. Appends a dot-source line to `$PROFILE`
3. Dot-sources the file into the active session immediately

---

## Package Managers

### Homebrew (macOS / Linux)

```bash
brew tap hariharen9/tap
brew install sharmory
```

After install, add to your shell RC file:
```bash
# Zsh
echo 'source "$(brew --prefix)/opt/sharmory/functions.zsh"' >> ~/.zshrc

# Bash
echo 'source "$(brew --prefix)/opt/sharmory/functions.bash"' >> ~/.bashrc
```

### Scoop (Windows)

```powershell
scoop bucket add hariharen9 https://github.com/hariharen9/scoop-bucket
scoop install sharmory
```

After install, add to your PowerShell profile:
```powershell
'. "$HOME\scoop\apps\sharmory\current\functions.ps1"' >> $PROFILE
```

### npm

```bash
npm install -g sharmory
sharmory-install
```

`sharmory-install` auto-detects Zsh or Bash and patches the appropriate RC file.

### pip

```bash
pip install sharmory
sharmory-install
```

Same behavior as the npm installer — detects shell and patches RC file.

---

## Manual Installation

If you prefer not to run a remote script, clone or download the repo and source manually.

### Zsh (manual)

```bash
git clone https://github.com/hariharen9/sharmory.git ~/.sharmory
echo '[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh' >> ~/.zshrc
source ~/.zshrc
```

Without git:
```bash
mkdir -p ~/.sharmory
curl -o ~/.sharmory/functions.zsh \
  https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.zsh
echo '[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Bash (manual)

> Requires **Bash 4.0+**. macOS ships Bash 3.2 by default — install a modern version first: `brew install bash`.

```bash
git clone https://github.com/hariharen9/sharmory.git ~/.sharmory
echo '[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash' >> ~/.bashrc
source ~/.bashrc
```

### PowerShell (manual)

```powershell
New-Item -ItemType Directory -Force "$HOME\sharmory"
Invoke-WebRequest `
  "https://raw.githubusercontent.com/hariharen9/sharmory/main/functions.ps1" `
  -OutFile "$HOME\sharmory\functions.ps1"

# Add to your profile
Add-Content $PROFILE '. "$HOME\sharmory\functions.ps1"'

# Reload
. $PROFILE
```

---

## Verifying the Installation

After installing and reloading your shell:

```bash
sharmory doctor
```

This checks:
- Sharmory is loaded in the current session
- The install path exists at `~/.sharmory/`
- The source line is present in your RC file
- Git identity is configured
- SSH keys are present
- Optional tools (fzf, jq, eza, etc.) are installed
- Local version matches the latest GitHub release

---

## Updating

```bash
sharmory-update
```

This downloads the latest `functions.zsh` and `functions.bash` from GitHub to `~/.sharmory/` and immediately re-sources the Zsh file in the current session.

On PowerShell, `sharmory-update` downloads the latest `functions.ps1` and dot-sources it.

---

## Uninstalling

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.sh | bash
```

Or manually:
```bash
rm -rf ~/.sharmory
# Remove the source line from your RC file
sed -i '/sharmory/d' ~/.zshrc
sed -i '/sharmory/d' ~/.bashrc
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.ps1 | iex
```

Or manually:
```powershell
Remove-Item -Recurse -Force "$HOME\sharmory"
# Remove the dot-source line from your profile
(Get-Content $PROFILE) | Where-Object { $_ -notmatch 'sharmory' } | Set-Content $PROFILE
```

---

## Install Locations

| Platform | Files installed | RC file patched |
|---|---|---|
| Zsh (macOS/Linux/WSL) | `~/.sharmory/functions.zsh` and `~/.sharmory/functions.bash` | `~/.zshrc` |
| Bash (macOS/Linux/WSL) | `~/.sharmory/functions.zsh` and `~/.sharmory/functions.bash` | `~/.bashrc` |
| PowerShell (Windows) | `$HOME\sharmory\functions.ps1` | `$PROFILE` |

Both Zsh and Bash files are always downloaded on Unix systems so switching shells does not require re-installing.

---

## Troubleshooting

**Functions not found after install**

The source line was added to your RC file, but your current session has not been reloaded yet. Run:
```bash
source ~/.zshrc   # Zsh
source ~/.bashrc  # Bash
. $PROFILE        # PowerShell
```

**`sharmory: command not found`**

The `sharmory` function is defined in `functions.zsh` / `functions.bash`. If it is missing, the source line may not have been added correctly. Check:
```bash
grep sharmory ~/.zshrc
```
If nothing appears, add it manually:
```bash
echo '[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh' >> ~/.zshrc
```

**Bash 3.2 errors on macOS**

macOS ships with Bash 3.2. `functions.bash` requires Bash 4.0+ (associative arrays). Install a modern Bash:
```bash
brew install bash
```
Then either use `/opt/homebrew/bin/bash` explicitly or change your login shell.

**PowerShell execution policy error**

If you see `cannot be loaded because running scripts is disabled`, allow script execution:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
