#
# Sharmory Uninstaller for Windows (PowerShell)
# Usage: irm https://raw.githubusercontent.com/hariharen9/sharmory/main/uninstall.ps1 | iex
#

$ErrorActionPreference = "SilentlyContinue"

$targetDir = Join-Path $HOME "sharmory"

Write-Host "Uninstalling Sharmory for PowerShell..." -ForegroundColor Yellow

# Remove directory
if (Test-Path $targetDir) {
    Remove-Item -Recurse -Force $targetDir
    Write-Host "Removed $targetDir" -ForegroundColor Green
}

# Clean $PROFILE
if (Test-Path $PROFILE) {
    $lines = Get-Content $PROFILE | Where-Object { $_ -notmatch 'sharmory' -and $_ -notmatch 'Sharmory' }
    $lines | Set-Content $PROFILE
    Write-Host "Removed Sharmory entries from $PROFILE" -ForegroundColor Green
}

Write-Host "Sharmory successfully uninstalled." -ForegroundColor Yellow
