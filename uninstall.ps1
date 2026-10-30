<#
  Undo the OpenCode starter kit config: removes the kit's config folder and restores the newest backup
  made by install.ps1 (if there is one). It does NOT uninstall Node, Git, Python, ffmpeg or OpenCode itself.

  Usage:  .\uninstall.ps1 [-DryRun]
  Remove the tools yourself if you want:  npm uninstall -g opencode-ai @higgsfield/cli
#>
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ConfigDir = Join-Path $HomeDir '.config\opencode'
$parent = Split-Path $ConfigDir -Parent
$backup = Get-ChildItem $parent -Directory -Filter 'opencode.backup-*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

if (-not (Test-Path $ConfigDir)) { Write-Host "Nothing to remove: $ConfigDir does not exist."; if (-not $backup) { return } }

Write-Host "This will delete: $ConfigDir"
if ($backup) { Write-Host "and restore your earlier config from: $($backup.FullName)" } else { Write-Host "(no backup found, so nothing will be restored)" }
if ($DryRun) { Write-Host "[dry-run] no changes made."; return }
$a = Read-Host "Continue? [y/N]"
if (-not $a.Trim().ToLower().StartsWith('y')) { Write-Host "Cancelled."; return }

if (Test-Path $ConfigDir) { Remove-Item -Recurse -Force $ConfigDir }
if ($backup) { Move-Item -Path $backup.FullName -Destination $ConfigDir; Write-Host "Restored your previous config." }
Write-Host "Done. Your API-key environment variables and %USERPROFILE%\youtube folder were left alone."
