"""Copy Sharmory function files and hook the user shell profile."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import __version__

ASSET_NAMES = ("functions.zsh", "functions.bash", "functions.ps1")


def _find_asset(name: str) -> Path:
    here = Path(__file__).resolve().parent
    candidates = [
        here / name,
        here.parents[3] / name,  # repo root from packaging/python/sharmory_install
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise SystemExit(
        f"Missing {name}. Reinstall the sharmory package from the repo or PyPI."
    )


def _append_once(file_path: Path, needle: str, block: str) -> None:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    if not file_path.exists():
        file_path.write_text("", encoding="utf-8")
    current = file_path.read_text(encoding="utf-8")
    if needle in current:
        print(f"Already configured in {file_path}")
        return
    prefix = "" if current.endswith("\n") or not current else "\n"
    file_path.write_text(current + prefix + block, encoding="utf-8")
    print(f"Added Sharmory to {file_path}")


def _copy_assets(dest_dir: Path) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    for name in ASSET_NAMES:
        shutil.copy2(_find_asset(name), dest_dir / name)


def _detect_unix_shell() -> str:
    """Mirror the detection logic from install.sh.

    Prefer the user's login shell ($SHELL); fall back to availability;
    default to zsh.
    """
    login_shell = Path(os.environ.get("SHELL", "")).name
    if login_shell == "zsh":
        return "zsh"
    if login_shell == "bash":
        return "bash"
    # Exotic login shell (fish, etc.) — prefer zsh if available, else bash.
    try:
        subprocess.run(["zsh", "--version"], capture_output=True, check=True)
        return "zsh"
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass
    return "bash"


def install_unix() -> None:
    dest = Path.home() / ".sharmory"
    # Always install all Unix function files so the user can switch shells
    # without reinstalling.
    _copy_assets(dest)

    shell = _detect_unix_shell()
    if shell == "zsh":
        rc = Path.home() / ".zshrc"
        line = "[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh"
        _append_once(
            rc,
            "sharmory/functions.zsh",
            f"\n# Sharmory — Dev shell toolkit\n{line}\n",
        )
        print("Detected shell: zsh — installed to ~/.sharmory. Run: source ~/.zshrc")
    else:
        rc = Path.home() / ".bashrc"
        line = "[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash"
        _append_once(
            rc,
            "sharmory/functions.bash",
            f"\n# Sharmory — Dev shell toolkit\n{line}\n",
        )
        print("Detected shell: bash — installed to ~/.sharmory. Run: source ~/.bashrc")


def install_windows() -> None:
    dest = Path.home() / "sharmory"
    _copy_assets(dest)
    documents = Path.home() / "Documents"
    profile = Path(
        os.environ.get(
            "PROFILE",
            str(documents / "WindowsPowerShell" / "Microsoft.PowerShell_profile.ps1"),
        )
    )
    line = '. "$HOME\\sharmory\\functions.ps1"'
    _append_once(
        profile,
        "sharmory\\functions.ps1",
        f"\n# Sharmory - Dev shell toolkit\n{line}\n",
    )
    print(f"Installed to {dest}. Restart PowerShell or run: . $PROFILE")


def main() -> None:
    print(f"Sharmory installer v{__version__}")
    if os.name == "nt":
        install_windows()
    else:
        install_unix()
    return None


if __name__ == "__main__":
    sys.exit(main() or 0)
