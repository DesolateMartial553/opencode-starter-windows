<#
  Update the OpenCode starter kit on Windows without losing your own setup.

  Use it (PowerShell):
    irm https://raw.githubusercontent.com/DesolateMartial553/opencode-starter-windows/main/update.ps1 | iex

  What it does (nothing is changed with -DryRun):
    1. Downloads the newest version of the kit from GitHub (3 tries if your Wi-Fi wobbles)
    2. Backs up your current OpenCode config first
    3. Replaces skills, agents, commands and tools with the newest versions
    4. Leaves your own opencode.json and AGENTS.md alone if you edited them; the new
       versions are saved next to them as opencode.json.new / AGENTS.md.new

  Switches:  -DryRun  -Source <path to a local copy of the repo>  -Force (overwrite opencode.json too)
#>
param(
    [switch]$DryRun,
    [switch]$Force,
    [string]$Source
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo      = 'DesolateMartial553/opencode-starter-windows'
$Branch    = 'main'
$HomeDir   = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ConfigDir = Join-Path $HomeDir '.config\opencode'
$work      = $null

function Say($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Note($msg) { Write-Host "  ... $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

function Update-SessionPath {
    $parts = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        (Join-Path $env:ProgramFiles 'nodejs'),
        (Join-Path $env:APPDATA 'npm')
    ) | Where-Object { $_ }
    $env:Path = $parts -join ';'
}

function Invoke-WithRetry([int]$Attempts, [int]$WaitSeconds, [scriptblock]$Action) {
    for ($i = 1; $i -le $Attempts; $i++) {
        try { return (& $Action) }
        catch {
            if ($i -ge $Attempts) { throw }
            Warn "attempt $i of $Attempts failed: $($_.Exception.Message)"
            Note "waiting $WaitSeconds second(s), then trying again"
            Start-Sleep -Seconds $WaitSeconds
        }
    }
}

# Copy the kit's version of $name over the user's, but keep their edits.
function Install-File([string]$name, [string]$kitRoot) {
    $src  = Join-Path $kitRoot "config\$name"
    $dest = Join-Path $ConfigDir $name
    if (-not (Test-Path $src)) { return }
    if (-not (Test-Path $dest)) {
        if (-not $DryRun) { Copy-Item $src $dest -Force }
        Ok "added $name"
        return
    }
    $same = $false
    try {
        $same = (Get-FileHash $src).Hash -eq (Get-FileHash $dest).Hash
    } catch { }
    if ($same) { Note "$name already up to date"; return }
    if ($Force) {
        if (-not $DryRun) { Copy-Item $src $dest -Force }
        Ok "updated $name (your old one is in the backup)"
        return
    }
    if (-not $DryRun) { Copy-Item $src "$dest.new" -Force }
    Warn "$name differs from the new version, so yours was kept"
    Note "the new one is saved as $name.new - compare them if you want the latest settings"
}

try {

    Say "Updating the OpenCode starter kit"
    if ($DryRun) { Warn "DRY RUN: nothing will be changed" }
    if ($env:OS -ne 'Windows_NT') { throw "This updater is for Windows." }

    if (-not (Test-Path $ConfigDir)) {
        Warn "This kit is not installed on this PC yet (no $ConfigDir)."
        Note "Run install.ps1 first, then use update.ps1 after that."
        if ($PSCommandPath) { exit 1 } else { return }
    }

    # --- 1. fetch the newest kit -----------------------------------------------------------
    Say "`n[1/3] Downloading the newest kit"
    $kitRoot = $null
    if ($Source) {
        $kitRoot = (Resolve-Path $Source).Path
        Note "using local copy: $kitRoot"
    } elseif ($DryRun) {
        Note "[dry-run] would: download https://github.com/$Repo/archive/refs/heads/$Branch.zip"
    } else {
        $work = Join-Path $env:TEMP ("opencode-kit-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        $zip = Join-Path $work 'kit.zip'
        Note "downloading"
        try {
            Invoke-WithRetry 3 5 {
                Invoke-WebRequest -Uri "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
            }
            Expand-Archive -Path $zip -DestinationPath $work -Force
            $kitRoot = (Get-ChildItem $work -Directory | Select-Object -First 1).FullName
            Ok "downloaded"
        } catch {
            throw "could not download the kit after 3 tries. Check your internet connection and try again. Details: $($_.Exception.Message)"
        }
    }

    # --- 2. back up, then replace ----------------------------------------------------------
    Say "`n[2/3] Updating your config"
    if (-not $DryRun) {
        $backup = "$ConfigDir.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -Path $ConfigDir -Destination $backup -Recurse -Force
        Ok "backed up your current setup to $backup"
    } else {
        Note "[dry-run] would: back up $ConfigDir"
    }

    if ($kitRoot) {
        foreach ($part in 'skills', 'agents', 'commands', 'tools') {
            if (-not (Test-Path (Join-Path $kitRoot "config\$part"))) { continue }
            if ($DryRun) { Note "[dry-run] would: refresh $part"; continue }
            Copy-Item -Path (Join-Path $kitRoot "config\$part") -Destination $ConfigDir -Recurse -Force
            Ok "refreshed $part"
        }
        Install-File 'opencode.json' $kitRoot
        Install-File 'AGENTS.md'     $kitRoot
        Install-File 'package.json'  $kitRoot
    }

    if (-not $DryRun) {
        Update-SessionPath
        if (Test-Cmd 'npm.cmd') {
            Push-Location $ConfigDir
            try { & npm.cmd install --silent --no-audit --no-fund } catch { } finally { Pop-Location }
        }
        $skills = (Get-ChildItem (Join-Path $ConfigDir 'skills') -Directory).Count
        $cmds   = (Get-ChildItem (Join-Path $ConfigDir 'commands') -Filter *.md).Count
        $agents = (Get-ChildItem (Join-Path $ConfigDir 'agents') -Filter *.md).Count
        Ok "now $skills skills, $agents agents, $cmds slash commands"
    }

    # --- 3. done ---------------------------------------------------------------------------
    Say "`n[3/3] Finished"
    Write-Host @"

  Start a NEW PowerShell window and run  opencode  to use it.
  Anything that went wrong: https://github.com/$Repo/blob/$Branch/TROUBLESHOOTING.md
  To undo this update, copy the newest opencode.backup-* folder back over your config.
"@
}
catch {
    Write-Host ''
    Warn "The update stopped: $($_.Exception.Message)"
    Write-Host ''
    Write-Host '  Your existing setup was not removed. Run the updater again once the cause is fixed.' -ForegroundColor White
    if ($PSCommandPath) { exit 1 } else { return }
}
finally {
    if ($work -and (Test-Path $work)) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
}
