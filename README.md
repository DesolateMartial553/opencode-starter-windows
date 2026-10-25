# OpenCode starter kit for Windows

A one-line installer that sets up [OpenCode](https://opencode.ai) (an AI coding assistant for the terminal)
on Windows with a ready-made setup: 50+ skills, 12 specialist agents, 20+ slash commands, a YouTube Shorts
clipping toolkit and AI image/video generation tools.

**No API keys, passwords or personal data are in this repo.** You use your own accounts.

## Install

Open **PowerShell** (press the Windows key, type `powershell`, press Enter) and paste:

```powershell
irm https://raw.githubusercontent.com/DesolateMartial553/opencode-starter-windows/main/install.ps1 | iex
```

It takes 5-15 minutes. It will ask a couple of yes/no questions and (optionally) for free API keys.
Want to see what it would do first? Download the file and run `.\install.ps1 -DryRun`.

Then open a **new** PowerShell window and:

```powershell
mkdir $env:USERPROFILE\my-first-project
cd $env:USERPROFILE\my-first-project
opencode
```

New to all this? Read **[GETTING-STARTED.md](GETTING-STARTED.md)**.

## What gets installed

| Piece | What it is | Where |
|---|---|---|
| Node.js, Git | needed by OpenCode and its plugins | via `winget` (skipped if present) |
| OpenCode | the assistant itself | `npm install -g opencode-ai` |
| Config, `AGENTS.md` | beginner-friendly instructions, safety rules (asks before deleting or `git push`) | `%USERPROFILE%\.config\opencode` |
| Skills, agents, commands | planning, TDD, code review, frontend/backend patterns, research, SEO, and more | same folder |
| YouTube toolkit (optional) | Python, ffmpeg, yt-dlp, faster-whisper plus `/youtube-helper` | tools in the config folder, workspace in `%USERPROFILE%\youtube` |
| Higgsfield CLI + 8 skills | AI image/video generation (**paid credits**, you log in with your own account) | `npm install -g @higgsfield/cli` |

Any existing OpenCode config is **backed up** (`opencode.backup-<date>`), never overwritten. To undo, run
`uninstall.ps1`.

## Models and keys

Out of the box OpenCode uses free models and needs no key. For stronger models add either or both
(both have free tiers; the installer will offer to save them as user environment variables on your PC only):

- Google Gemini: <https://aistudio.google.com/apikey> (`GOOGLE_GENERATIVE_AI_API_KEY`)
- OpenRouter: <https://openrouter.ai/keys> (`OPENROUTER_API_KEY`)

Or run `opencode auth login` and pick a provider. If a model fails or is slow, the fallback plugin tries the
next one in `opencode.json`.

## Things worth knowing

- The installer sets PowerShell's execution policy to `RemoteSigned` for **your user only** if it is still
  the default, because the default blocks `npm` and `opencode` from running.
- Higgsfield image/video generation costs credits; nothing is generated until you ask.
- The YouTube skill is guidance for clipping content you have permission to use. Respect creators' rights and
  YouTube's policies.
- The permission rules ask before recursive deletes, `git push`, and `gh` actions that publish.

## For the maintainer

`scripts/sanitize-check.sh` scans the tree for secrets and personal references; run it before every push.
