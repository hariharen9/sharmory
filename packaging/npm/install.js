#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const PKG_ROOT = path.resolve(__dirname, "..", "..");
const VERSION = require(path.join(PKG_ROOT, "package.json")).version;

function copyAsset(name, destDir) {
  const src = path.join(PKG_ROOT, name);
  if (!fs.existsSync(src)) {
    throw new Error(`Missing ${name} in the sharmory npm package`);
  }
  fs.mkdirSync(destDir, { recursive: true });
  const dest = path.join(destDir, name);
  fs.copyFileSync(src, dest);
  return dest;
}

function appendOnce(filePath, needle, block) {
  const dir = path.dirname(filePath);
  fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, "", "utf8");
  }
  const current = fs.readFileSync(filePath, "utf8");
  if (current.includes(needle)) {
    console.log(`Already configured in ${filePath}`);
    return;
  }
  const prefix = current.endsWith("\n") || current.length === 0 ? "" : "\n";
  fs.appendFileSync(filePath, prefix + block, "utf8");
  console.log(`Added Sharmory to ${filePath}`);
}

// Mirror the detection logic from install.sh: prefer the login shell ($SHELL),
// fall back to checking availability, default to zsh.
function detectUnixShell() {
  const loginShell = path.basename(process.env.SHELL || "");
  if (loginShell === "zsh") return "zsh";
  if (loginShell === "bash") return "bash";
  // Exotic login shell (fish, etc.) — prefer zsh if available, else bash.
  const { execSync } = require("child_process");
  try { execSync("command -v zsh", { stdio: "ignore" }); return "zsh"; } catch (_) {}
  return "bash";
}

function installUnix() {
  const destDir = path.join(os.homedir(), ".sharmory");

  // Always install all Unix function files so the user can switch shells
  // without reinstalling.
  copyAsset("functions.zsh",  destDir);
  copyAsset("functions.bash", destDir);
  copyAsset("functions.ps1",  destDir);

  const shell = detectUnixShell();
  if (shell === "zsh") {
    const rc   = path.join(os.homedir(), ".zshrc");
    const line = "[[ -f ~/.sharmory/functions.zsh ]] && source ~/.sharmory/functions.zsh";
    appendOnce(rc, "sharmory/functions.zsh", `\n# Sharmory — Dev shell toolkit\n${line}\n`);
    console.log(`Detected shell: zsh — installed to ~/.sharmory. Run: source ~/.zshrc`);
  } else {
    const rc   = path.join(os.homedir(), ".bashrc");
    const line = "[[ -f ~/.sharmory/functions.bash ]] && source ~/.sharmory/functions.bash";
    appendOnce(rc, "sharmory/functions.bash", `\n# Sharmory — Dev shell toolkit\n${line}\n`);
    console.log(`Detected shell: bash — installed to ~/.sharmory. Run: source ~/.bashrc`);
  }
}

function installWindows() {
  const destDir = path.join(os.homedir(), "sharmory");
  copyAsset("functions.ps1",  destDir);
  copyAsset("functions.zsh",  destDir);
  copyAsset("functions.bash", destDir);
  const documents = path.join(os.homedir(), "Documents");
  const candidates = [
    process.env.PROFILE,
    path.join(documents, "PowerShell", "Microsoft.PowerShell_profile.ps1"),
    path.join(documents, "WindowsPowerShell", "Microsoft.PowerShell_profile.ps1"),
  ].filter(Boolean);
  const profilePath = candidates[0];
  const line = '. "$HOME\\sharmory\\functions.ps1"';
  appendOnce(
    profilePath,
    "sharmory\\functions.ps1",
    `\n# Sharmory - Dev shell toolkit\n${line}\n`
  );
  console.log(`Installed to ${destDir}. Restart PowerShell or run: . $PROFILE`);
}

function main() {
  console.log(`Sharmory installer v${VERSION}`);
  if (process.platform === "win32") {
    installWindows();
  } else {
    installUnix();
  }
}

main();
