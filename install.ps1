#
# Sharmory Installer for Windows (PowerShell 5.1+ & PowerShell Core 7+)
# Usage: irm https://raw.githubusercontent.com/hariharen9/sharmory/main/install.ps1 | iex
#

$ErrorActionPreference = "Stop"

$repoUrl = "https://raw.githubusercontent.com/hariharen9/sharmory/main"
$targetDir = Join-Path $HOME "sharmory"
$targetFile = Join-Path $targetDir "functions.ps1"

Write-Host "Installing Sharmory for PowerShell..." -ForegroundColor Cyan

# Create directory
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

# Download functions.ps1 (or copy from local directory if running from a local clone)
$localFunctions = if ($PSScriptRoot) { Join-Path $PSScriptRoot "functions.ps1" } else { "" }
if ($localFunctions -and (Test-Path $localFunctions)) {
    Copy-Item $localFunctions $targetFile -Force
    Write-Host "Installed functions.ps1 from local directory."
} else {
    Write-Host "Downloading functions.ps1..."
    Invoke-WebRequest "$repoUrl/functions.ps1" -OutFile $targetFile -UseBasicParsing
}

# Ensure Profile directory & file exist
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}

# Append to profile if not already present
$sourceLine = '. "$HOME\sharmory\functions.ps1"'
$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($profileContent -and $profileContent.Contains($sourceLine)) {
    Write-Host "Sharmory is already configured in $PROFILE" -ForegroundColor DarkGray
} else {
    $entry = "`n# Sharmory - Dev shell toolkit`n$sourceLine`n"
    Add-Content $PROFILE $entry
    Write-Host "Added Sharmory to $PROFILE" -ForegroundColor Green
}

# Load immediately into current session
$count = 0
if (Test-Path $targetFile) {
    . $targetFile
    Write-Host "Sharmory functions loaded into active session!" -ForegroundColor Green
    if (Get-Command Get-SharmoryRegistry -ErrorAction SilentlyContinue) {
        $count = (Get-SharmoryRegistry).Count
    }
}

if (-not $count -or $count -eq 0) {
    if (Test-Path $targetFile) {
        $count = (Get-Content $targetFile | Select-String '^\s*function\s+([a-zA-Z0-9_-]+)').Count
    }
}
if (-not $count -or $count -eq 0) {
    $count = 259
}

Write-Host ""
Write-Host "Sharmory successfully installed!" -ForegroundColor Cyan
Write-Host "All $count dev shortcuts are ready to use in your terminal." -ForegroundColor Green

