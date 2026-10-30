# If something goes wrong

Most problems are one of the ones below. Work down the list, and if none of it helps, see
[Still stuck](#still-stuck) at the bottom.

## Check the basics first

Open a **new** PowerShell window and paste this. It tells you what is installed and whether the kit's
config arrived:

```powershell
node -v; git --version; opencode --version
Test-Path "$env:USERPROFILE\.config\opencode"
```

You want a version number from each, and `True` on the last line.

---

## "Variable reference is not valid" or other red errors while installing

Example:

```
install.ps1: Variable reference is not valid.
':' was not followed by a valid variable name character. Consider using ${} to delimit the name.
```

That is a **fault in an old copy of the installer**, not something you did. Nothing was installed.

1. Run the one-line installer again — the fixed version is live now.
2. If it still happens, download the file first, then run it (this bypasses any caching):

```powershell
cd $env:USERPROFILE\Downloads
irm https://raw.githubusercontent.com/DesolateMartial553/opencode-starter-windows/main/install.ps1 -OutFile install.ps1
Unblock-File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## "Running scripts is disabled on this system"

Windows blocks scripts by default. Fix it for your user only (no administrator needed):

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then run the installer again.

## Windows shows "Windows protected your PC" / SmartScreen, or antivirus complains

Windows flags any script downloaded from the internet. Right-click the downloaded `.ps1` file →
**Properties** → tick **Unblock** → **OK**. Or unblock it from PowerShell:

```powershell
Unblock-File .\install.ps1
```

Nothing in this kit is a program that runs in the background; it installs tools and copies config files.

## The download fails ("Could not resolve host", "Unable to connect to the remote server")

- Check you are online and not on a school/work network that blocks GitHub.
- The installer already retries three times; a flaky connection is the usual cause.
- Or download the kit by hand: open <https://github.com/DesolateMartial553/opencode-starter-windows>,
  **Code → Download ZIP**, unzip it, then run:

```powershell
cd <the unzipped folder>
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

## "winget is not recognised"

`winget` comes with **App Installer** on Windows 10/11. Open **Microsoft Store**, search for
**App Installer**, install/update it, then run the installer again. On very old Windows 10 builds it
is missing entirely; install Node.js and Git by hand from nodejs.org and git-scm.com.

## `opencode` is "not recognised as a command"

The PATH only updates in **new** windows. Close PowerShell completely, open a new one, try again.

If it is still missing, npm may have installed it somewhere unusual. Check:

```powershell
npm config get prefix
npm ls -g --depth=0
```

If `opencode-ai` is listed but not found, add the prefix folder (usually `%APPDATA%\npm`) to PATH, or
reinstall it: `npm install -g opencode-ai`.

## OpenCode opens but it cannot find the kit's skills, agents or commands

1. Make sure the config folder exists: `Test-Path "$env:USERPROFILE\.config\opencode"` → should be `True`.
2. **If that prints `False`, check for `XDG_CONFIG_HOME`.** When that variable is set, OpenCode reads its
   config from there instead. Run `$env:XDG_CONFIG_HOME`. If it prints a path, copy the kit's `config`
   folder into `$env:XDG_CONFIG_HOME\opencode` instead, or remove the variable.
3. OpenCode must be version 2 or newer (`opencode --version`). Skills, agents and the `mcp.servers`
   config shape are for v2.

You can also ask inside OpenCode: *"list the skills you have available"*.

## The model is slow, rate-limited or fails

Free models have busy periods.

- Type `/models` and pick another one.
- Add a free Gemini or OpenRouter key (see the [README](README.md)); stronger models make a big difference.
- If a model fails, the fallback plugin in `opencode.json` should move to the next one automatically.

## The Chrome / browser tools do not work

The `chrome-devtools` helper needs Google Chrome and `npx` (which comes with Node.js). If it fails, tell
OpenCode *"start Chrome with remote debugging enabled and tell me how"*. Nothing else in the kit depends
on it. Context7 (documentation lookup) needs an internet connection only.

## Why did it install things I did not ask for?

Each step is listed in the installer output. It adds: Node.js, Git, and (if you said yes) Python, ffmpeg,
yt-dlp, the OpenCode CLI, the Higgsfield CLI, and a Python environment inside `%USERPROFILE%\youtube`.
Anything already installed is skipped. Nothing is installed silently in the background.

## I want my old setup back

The installer never deletes your old OpenCode config; it renames it. Look in:

```
%USERPROFILE%\.config\opencode.backup-<date>
```

`uninstall.ps1` removes the kit's config and puts the newest backup back:

```powershell
.\uninstall.ps1
```

Your API keys (environment variables) and `%USERPROFILE%\youtube` are left alone.

## Keeping the kit up to date

```powershell
irm https://raw.githubusercontent.com/DesolateMartial553/opencode-starter-windows/main/update.ps1 | iex
```

It refreshes skills, agents and commands, backs up first, and **keeps your own `opencode.json` and
`AGENTS.md`** (the new versions are saved next to them as `.new` files). Or just re-run `install.ps1`.

---

## Still stuck

Copy the **full red text** (and the lines above it) plus the output of this:

```powershell
winver
node -v; npm -v; git --version; opencode --version
$PSVersionTable.PSVersion.ToString()
```

Send that to whoever shared the kit. Do not send API keys — if a key appears in an error, blur it out first.
