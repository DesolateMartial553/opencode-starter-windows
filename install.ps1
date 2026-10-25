<#
  OpenCode starter kit installer for Windows.

  One-line install (PowerShell):
    irm https://raw.githubusercontent.com/DesolateMartial553/opencode-starter-windows/main/install.ps1 | iex

  What it does (nothing is changed with -DryRun):
    1. Installs missing tools with winget: Node.js, Git, Python, ffmpeg, yt-dlp
    2. Installs OpenCode and the Higgsfield CLI (npm)
    3. Backs up any existing OpenCode config, then installs this kit's config, skills, agents, commands
    4. Sets up the YouTube clipping tools (optional)
    5. Optionally saves your own API keys as user environment variables (never written to any file)

  Switches:  -DryRun  -SkipYouTube  -SkipHiggsfield  -NoPrompt  -Source <path to a local copy of the repo>
#>
param(
    [switch]$DryRun,
    [switch]$SkipYouTube,
    [switch]$SkipHiggsfield,
    [switch]$NoPrompt,
    [string]$Source
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Repo      = 'DesolateMartial553/opencode-starter-windows'
$Branch    = 'main'
$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$YtDir     = Join-Path $env:USERPROFILE 'youtube'

function Say($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Note($msg) { Write-Host "  ... $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }

# Run an action, or just describe it in dry-run mode.
function Do-Step([string]$what, [scriptblock]$action) {
    if ($DryRun) { Note "[dry-run] would: $what"; return }
    Note $what
    & $action
}

function Test-Cmd([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# The Windows Store "python" alias is a stub that opens the Store, so check it really runs.
function Test-Python {
    if (Test-Cmd 'py') { return $true }
    if (Test-Cmd 'python') {
        try { return ((& python --version 2>&1) -match 'Python 3') } catch { return $false }
    }
    return $false
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Ask-YesNo([string]$q, [bool]$default = $true) {
    if ($NoPrompt -or $DryRun) { return $default }
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    $a = Read-Host "$q [$hint]"
    if ([string]::IsNullOrWhiteSpace($a)) { return $default }
    return $a.Trim().ToLower().StartsWith('y')
}

function Ensure-Winget-Package([string]$cmd, [string]$id, [string]$label) {
    if (Test-Cmd $cmd) { Ok "$label already installed"; return }
    if (-not (Test-Cmd 'winget')) {
        Warn "$label is missing and winget is not available. Install it by hand, then run this again."
        return
    }
    Do-Step "installing $label with winget" {
        winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        Update-SessionPath
    }
    if (-not $DryRun) {
        if (Test-Cmd $cmd) { Ok "$label installed" } else { Warn "$label installed but not on PATH yet (open a new terminal later)" }
    }
}

Say "OpenCode starter kit for Windows"
if ($DryRun) { Warn "DRY RUN: nothing will be changed" }
if ($env:OS -ne 'Windows_NT') { throw "This installer is for Windows." }

# --- 0. let PowerShell run npm/opencode shims (default policy blocks them) -----------------
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in 'Undefined', 'Restricted') {
    Do-Step "setting PowerShell execution policy to RemoteSigned for your user (needed so npm/opencode can run)" {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    }
}

# --- 1. prerequisites ----------------------------------------------------------------------
Say "`n[1/5] Checking tools"
Ensure-Winget-Package 'node'   'OpenJS.NodeJS.LTS' 'Node.js'
Ensure-Winget-Package 'git'    'Git.Git'           'Git'
$wantYouTube = (-not $SkipYouTube) -and (Ask-YesNo 'Set up the YouTube clipping tools (Python, ffmpeg, yt-dlp, transcription; about 1 GB)?')
if ($wantYouTube) {
    if (Test-Python) { Ok 'Python already installed' }
    else { Ensure-Winget-Package 'py' 'Python.Python.3.12' 'Python 3.12' }
    Ensure-Winget-Package 'ffmpeg'  'Gyan.FFmpeg'      'ffmpeg'
    Ensure-Winget-Package 'yt-dlp'  'yt-dlp.yt-dlp'    'yt-dlp'
}

# --- 2. OpenCode + Higgsfield CLI ----------------------------------------------------------
Say "`n[2/5] Installing OpenCode"
if (Test-Cmd 'opencode') { Ok "OpenCode already installed" }
elseif ($DryRun -or (Test-Cmd 'npm.cmd')) {
    Do-Step "npm install -g opencode-ai" { & npm.cmd install -g opencode-ai; Update-SessionPath }
    if (-not $DryRun) { if (Test-Cmd 'opencode') { Ok "OpenCode installed" } else { Warn "OpenCode installed but not on PATH yet; open a new terminal" } }
} else { Warn "npm not found (Node.js did not install). Open a new terminal and run this again." }

if (-not $SkipHiggsfield) {
    if (Test-Cmd 'higgsfield') { Ok "Higgsfield CLI already installed" }
    elseif ($DryRun -or (Test-Cmd 'npm.cmd')) {
        Do-Step "npm install -g @higgsfield/cli (image/video generation tool)" { & npm.cmd install -g '@higgsfield/cli' }
    }
}

# --- 3. config -----------------------------------------------------------------------------
Say "`n[3/5] Installing the kit's config, skills, agents and commands"
$work = Join-Path $env:TEMP ("opencode-kit-" + [guid]::NewGuid().ToString('N'))
$kitRoot = $null
if ($Source) {
    $kitRoot = (Resolve-Path $Source).Path
    Note "using local copy: $kitRoot"
} else {
    $url = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
    if ($DryRun) { Note "[dry-run] would: download $url" }
    else {
        New-Item -ItemType Directory -Path $work | Out-Null
        $zip = Join-Path $work 'kit.zip'
        Note "downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $work -Force
        $kitRoot = (Get-ChildItem $work -Directory | Select-Object -First 1).FullName
    }
}

if (Test-Path $ConfigDir) {
    $backup = "$ConfigDir.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
    Do-Step "backing up your existing OpenCode config to $backup" { Move-Item -Path $ConfigDir -Destination $backup }
}
Do-Step "copying config to $ConfigDir" {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    Copy-Item -Path (Join-Path $kitRoot 'config\*') -Destination $ConfigDir -Recurse -Force
}
if (-not $DryRun) {
    if (Test-Cmd 'npm.cmd') {
        Push-Location $ConfigDir
        try { & npm.cmd install --silent --no-audit --no-fund } finally { Pop-Location }
    }
    $skills = (Get-ChildItem (Join-Path $ConfigDir 'skills') -Directory).Count
    $cmds   = (Get-ChildItem (Join-Path $ConfigDir 'commands') -Filter *.md).Count
    Ok "installed $skills skills, $cmds slash commands"
}

# --- 4. YouTube tools ----------------------------------------------------------------------
Say "`n[4/5] YouTube clipping tools"
if (-not $wantYouTube) { Note "skipped" }
else {
    Do-Step "creating $YtDir (raw, clips, notes)" {
        foreach ($d in 'raw', 'clips', 'notes') { New-Item -ItemType Directory -Path (Join-Path $YtDir $d) -Force | Out-Null }
    }
    $venv = Join-Path $YtDir '.venv'
    Do-Step "creating a Python environment and installing faster-whisper (the transcription engine)" {
        if (Test-Cmd 'py') { & py -3 -m venv $venv } else { & python -m venv $venv }
        & (Join-Path $venv 'Scripts\python.exe') -m pip install --quiet --upgrade pip
        & (Join-Path $venv 'Scripts\python.exe') -m pip install --quiet faster-whisper numpy
    }
}

# --- 5. API keys (optional) ----------------------------------------------------------------
Say "`n[5/5] Optional API keys"
Note "OpenCode works with no keys using its free models. Keys add stronger models."
Note "Keys are saved only as Windows user environment variables on THIS PC."
function Save-Key([string]$label, [string]$varName, [string]$link) {
    if ([Environment]::GetEnvironmentVariable($varName, 'User')) { Ok "$label key already set"; return }
    if ($NoPrompt -or $DryRun) { Note "$label: get a free key at $link, then run:  setx $varName `"<your key>`""; return }
    Write-Host "`n  $label key: get one free at $link" -ForegroundColor White
    $sec = Read-Host "  Paste it here (or press Enter to skip)" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    if ([string]::IsNullOrWhiteSpace($plain)) { Note "skipped $label"; return }
    [Environment]::SetEnvironmentVariable($varName, $plain.Trim(), 'User')
    Set-Item -Path "Env:$varName" -Value $plain.Trim()
    Ok "$label key saved for your user account"
}
Save-Key 'Google Gemini' 'GOOGLE_GENERATIVE_AI_API_KEY' 'https://aistudio.google.com/apikey'
Save-Key 'OpenRouter'    'OPENROUTER_API_KEY'           'https://openrouter.ai/keys'

if (-not $DryRun -and (Test-Path $work)) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }

Say "`nAll done."
Write-Host @"

Next steps:
  1. Close this window and open a NEW PowerShell window (so the new tools are found).
  2. Go to a project folder:   mkdir `$env:USERPROFILE\my-first-project ; cd `$env:USERPROFILE\my-first-project
  3. Start it:                 opencode
  4. Try typing:               /plan  or  /youtube-helper
  Image/video generation (paid credits): run  higgsfield auth login  once with your own account.
  Full guide: https://github.com/$Repo/blob/$Branch/GETTING-STARTED.md
"@
