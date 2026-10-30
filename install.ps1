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
  Undo it:   uninstall.ps1
  Update it: update.ps1   (keeps your own opencode.json settings)
#>
param(
    [switch]$DryRun,
    [switch]$SkipYouTube,
    [switch]$SkipHiggsfield,
    [switch]$NoPrompt,
    [string]$Source
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # progress bars make downloads crawl in Windows PowerShell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo      = 'DesolateMartial553/opencode-starter-windows'
$Branch    = 'main'
$HomeDir   = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$ConfigDir = Join-Path $HomeDir '.config\opencode'
$YtDir     = Join-Path $HomeDir 'youtube'
$work      = $null

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

# Pick up anything a winget/npm install just added, without needing a new window.
function Update-SessionPath {
    $parts = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        (Join-Path $env:ProgramFiles 'nodejs'),
        (Join-Path $env:APPDATA 'npm'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links')
    ) | Where-Object { $_ }
    $env:Path = $parts -join ';'
}

function Ask-YesNo([string]$q, [bool]$default = $true) {
    if ($NoPrompt -or $DryRun) { return $default }
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    $a = Read-Host "$q [$hint]"
    if ([string]::IsNullOrWhiteSpace($a)) { return $default }
    return $a.Trim().ToLower().StartsWith('y')
}

# Try something a few times before giving up (flaky Wi-Fi is the usual reason an install fails).
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

function Get-OpenCodeVersion {
    Update-SessionPath
    if (-not (Test-Cmd 'opencode')) { return $null }
    try {
        $out = & opencode --version 2>&1
        if ($LASTEXITCODE -eq 0) { return (($out | Where-Object { $_ }) -join ' ').Trim() }
    } catch { }
    return $null
}

function Ensure-Winget-Package([string]$cmd, [string]$id, [string]$label) {
    if (Test-Cmd $cmd) { Ok "$label already installed"; return }
    if (-not (Test-Cmd 'winget')) {
        Warn "$label is missing and winget is not available. Install it by hand, then run this again."
        return
    }
    Do-Step "installing $label with winget" {
        try {
            winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements --source winget
        } catch {
            # Fallback without explicit source if winget source fails
            try {
                winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
            } catch { }
        }
        Update-SessionPath
    }
    if (-not $DryRun) {
        if (Test-Cmd $cmd) { Ok "$label installed" }
        else { Warn "$label did not appear yet (often it only shows up in a new PowerShell window)" }
    }
}

try {

    Say "OpenCode starter kit for Windows"
    if ($DryRun) { Warn "DRY RUN: nothing will be changed" }
    if ($env:OS -ne 'Windows_NT') { throw "This installer is for Windows. If you are on Linux or a Mac, tell the person who shared this kit." }

    # --- 0. let PowerShell run npm/opencode shims (default policy blocks them) ---------------
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -in 'Undefined', 'Restricted') {
        Do-Step "setting PowerShell execution policy to RemoteSigned for your user (needed so npm/opencode can run)" {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        }
    } elseif ($policy -eq 'AllSigned') {
        Warn "PowerShell on this PC is set to 'AllSigned', which can block npm and opencode."
        Note "If they refuse to start later: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }

    # --- 1. prerequisites ------------------------------------------------------------------
    Say "`n[1/5] Checking tools"
    if (-not (Test-Cmd 'winget') -and -not $DryRun) {
        Warn "winget (the Windows package installer) is not available on this PC."
        Note "It normally comes with Windows 11 and up-to-date Windows 10. To add it: open the"
        Note "Microsoft Store, install 'App Installer', then run this installer again."
        Note "Carrying on: anything already installed on this PC will be used as-is."
    }
    Ensure-Winget-Package 'node'   'OpenJS.NodeJS.LTS' 'Node.js'
    Ensure-Winget-Package 'git'    'Git.Git'           'Git'
    $wantYouTube = (-not $SkipYouTube) -and (Ask-YesNo 'Set up the YouTube clipping tools (Python, ffmpeg, yt-dlp, transcription; about 1 GB)?')
    if ($wantYouTube) {
        if (Test-Python) { Ok 'Python already installed' }
        else { Ensure-Winget-Package 'py' 'Python.Python.3.12' 'Python 3.12' }
        Ensure-Winget-Package 'ffmpeg'  'Gyan.FFmpeg'      'ffmpeg'
        Ensure-Winget-Package 'yt-dlp'  'yt-dlp.yt-dlp'    'yt-dlp'
    }

    # --- 2. OpenCode + Higgsfield CLI ------------------------------------------------------
    Say "`n[2/5] Installing OpenCode"
    if (Test-Cmd 'opencode') { Ok "OpenCode already installed" }
    elseif ($DryRun -or (Test-Cmd 'npm.cmd')) {
        Do-Step "npm install -g opencode-ai" { & npm.cmd install -g opencode-ai; Update-SessionPath }
    } else {
        Warn "npm (which comes with Node.js) was not found, so OpenCode cannot be installed yet."
        Note "Open a NEW PowerShell window and run this installer again; Node.js is installed by then."
    }

    if (-not $SkipHiggsfield) {
        if (Test-Cmd 'higgsfield') { Ok "Higgsfield CLI already installed" }
        elseif ($DryRun -or (Test-Cmd 'npm.cmd')) {
            Do-Step "npm install -g @higgsfield/cli (image/video generation tool)" { & npm.cmd install -g '@higgsfield/cli'; Update-SessionPath }
        }
    }

    # Prove OpenCode actually starts, rather than trusting that the install "worked".
    if (-not $DryRun) {
        $ocVersion = Get-OpenCodeVersion
        if ($ocVersion) { Ok "OpenCode starts: $ocVersion" }
        elseif (Test-Cmd 'opencode') {
            Warn "OpenCode is installed but did not start from here yet."
            Note "Usually a new PowerShell window fixes it. If it still fails, see TROUBLESHOOTING.md."
        }
    }

    # --- 3. config -------------------------------------------------------------------------
    Say "`n[3/5] Installing the kit's config, skills, agents and commands"
    $kitRoot = $null
    if ($Source) {
        $kitRoot = (Resolve-Path $Source).Path
        Note "using local copy: $kitRoot"
    } else {
        $url = "https://github.com/$Repo/archive/refs/heads/$Branch.zip"
        if ($DryRun) {
            Note "[dry-run] would: download $url"
        } else {
            $work = Join-Path $env:TEMP ("opencode-kit-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $work -Force | Out-Null
            $zip = Join-Path $work 'kit.zip'
            Note "downloading $url"
            try {
                Invoke-WithRetry 3 5 { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }
                Expand-Archive -Path $zip -DestinationPath $work -Force
                $kitRoot = (Get-ChildItem $work -Directory | Select-Object -First 1).FullName
            } catch {
                throw "could not download the kit from GitHub after 3 tries. Check your internet connection (and any work/school network filter), then run the installer again. Details: $($_.Exception.Message)"
            }
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
            try { & npm.cmd install --silent --no-audit --no-fund } catch { } finally { Pop-Location }
        }
        $skills = (Get-ChildItem (Join-Path $ConfigDir 'skills') -Directory).Count
        $cmds   = (Get-ChildItem (Join-Path $ConfigDir 'commands') -Filter *.md).Count
        $agents = (Get-ChildItem (Join-Path $ConfigDir 'agents') -Filter *.md).Count
        Ok "installed $skills skills, $agents agents, $cmds slash commands"
    }

    # --- 4. YouTube tools ------------------------------------------------------------------
    Say "`n[4/5] YouTube clipping tools"
    if (-not $wantYouTube) { Note "skipped" }
    else {
        Do-Step "creating $YtDir (raw, clips, notes)" {
            foreach ($d in 'raw', 'clips', 'notes') { New-Item -ItemType Directory -Path (Join-Path $YtDir $d) -Force | Out-Null }
        }
        $venv = Join-Path $YtDir '.venv'
        Do-Step "creating a Python environment and installing faster-whisper (the transcription engine)" {
            if (Test-Cmd 'py') { & py -3 -m venv $venv } else { & python -m venv $venv }
            $py = Join-Path $venv 'Scripts\python.exe'
            & $py -m pip install --quiet --upgrade pip
            & $py -m pip install --quiet faster-whisper numpy
        }
        if (-not $DryRun) {
            if (Test-Path (Join-Path $venv 'Scripts\python.exe')) { Ok "transcription ready" }
            else { Warn "this does not matter for anything except YouTube clipping; you can re-run the installer later to retry it" }
        }
    }

    # --- 5. API keys (optional) ------------------------------------------------------------
    Say "`n[5/5] Optional API keys"
    Note "OpenCode works with no keys using its free models. Keys add stronger models."
    Note "Keys are saved only as Windows user environment variables on THIS PC."
    function Save-Key([string]$label, [string]$varName, [string]$link) {
        if ([Environment]::GetEnvironmentVariable($varName, 'User')) { Ok "${label}: key already set"; return }
        if ($NoPrompt -or $DryRun) {
            Note "${label}: get a free key at $link, then run:  setx $varName `"<your key>`""
            return
        }
        Write-Host "`n  ${label} key: get one free at $link" -ForegroundColor White
        $sec = Read-Host "  Paste it here (or press Enter to skip)" -AsSecureString
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        if ([string]::IsNullOrWhiteSpace($plain)) { Note "skipped $label"; return }
        [Environment]::SetEnvironmentVariable($varName, $plain.Trim(), 'User')
        Set-Item -Path "Env:$varName" -Value $plain.Trim()
        Ok "$label key saved for your user account"
    }
    Save-Key 'Google Gemini' 'GOOGLE_GENERATIVE_AI_API_KEY' 'https://aistudio.google.com/apikey'
    Save-Key 'OpenRouter'    'OPENROUTER_API_KEY'           'https://openrouter.ai/keys'

    Say "`nAll done."
    Write-Host @"

Next steps:
  1. Close this window and open a NEW PowerShell window (so the new tools are found).
  2. Go to a project folder:   mkdir `$env:USERPROFILE\my-first-project ; cd `$env:USERPROFILE\my-first-project
  3. Start it:                 opencode
  4. Try typing:               /plan  or  /youtube-helper
  Image/video generation (paid credits): run  higgsfield auth login  once with your own account.
  Beginners' guide: https://github.com/$Repo/blob/$Branch/GETTING-STARTED.md
  Stuck?           https://github.com/$Repo/blob/$Branch/TROUBLESHOOTING.md
  Newer kit later: re-run install.ps1, or run update.ps1 (keeps your own settings).
"@
}
catch {
    Write-Host ''
    Warn "The installer stopped: $($_.Exception.Message)"
    if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) {
        Note "at line $($_.InvocationInfo.ScriptLineNumber) of the installer"
    }
    Write-Host ''
    Write-Host '  Your files were not touched. If an old OpenCode config existed it was moved aside, not deleted.' -ForegroundColor White
    Write-Host '  Fix the cause and run the installer again - it is safe to run more than once.' -ForegroundColor White
    Write-Host "  If the message makes no sense, send the text above to whoever shared this kit." -ForegroundColor White
    Write-Host "  https://github.com/$Repo/blob/$Branch/TROUBLESHOOTING.md" -ForegroundColor DarkGray
    # Never `exit` when this was run with `irm ... | iex`: that closes the window and the
    # message vanishes before anyone can read it.
    if ($PSCommandPath) { exit 1 } else { return }
}
finally {
    if ($work -and (Test-Path $work)) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
}
