# Getting started with OpenCode (for complete beginners)

## 1. Your first session
1. Open PowerShell and go into a folder for your project: `cd $env:USERPROFILE\my-first-project`.
2. Type `opencode` and press Enter. A chat screen appears.
3. Type what you want in normal English, e.g. *"Make me a simple one-page website for a dog-walking business"*.
4. OpenCode proposes changes and may ask permission to run things. Read, then approve or decline.

## 2. The two modes (press `Tab` to switch)
- **Plan**: it only reads and thinks. Safe for "how should we build this?"
- **Build**: it edits files and runs commands.

Tip: for anything big, plan first, then switch to Build.

## 3. Handy slash commands
Type `/` to see them all. The useful ones:

| Command | What it does |
|---|---|
| `/plan` | make a step-by-step plan before coding |
| `/feature-dev` | build a feature end to end |
| `/tdd` | build with tests first |
| `/code-review` | review your changes for bugs |
| `/security-scan` | look for security problems |
| `/build-fix` | fix build errors |
| `/verify` and `/quality-gate` | check everything still works |
| `/pr` | prepare a pull request |
| `/youtube-helper` | YouTube Shorts clip workflow (clip, caption, package, upload) |
| `/aside` | ask a quick side question without losing your place |

## 4. Skills
Skills are expert checklists OpenCode loads when your task matches (frontend design, accessibility, SEO,
Postgres, Docker, research, writing, and more). You do not need to remember them; just describe the task.
You can also say, e.g., *"use the deep-research skill to compare these tools"*.

## 5. Making images and video (Higgsfield)
1. Run `higgsfield auth login` once and sign in with your own Higgsfield account (generation uses paid credits).
2. In OpenCode, ask: *"Generate a 5-second video of a neon city at night"* or *"make a YouTube thumbnail for ..."*.
   The `higgsfield-*` skills pick the right model for you.

## 6. YouTube clipping
Run `/youtube-helper`. It will ask for your channel handle, set up a notes file in
`%USERPROFILE%\youtube\notes\`, and guide you through: finding a moment worth clipping, transcribing it,
cutting a 9:16 Short with word-by-word captions, writing a hook-first title, and uploading.
Only clip content you have permission to use.

## 7. Models and keys
- Check the current model at the bottom of the screen, switch with `/models`.
- Free models work with no key. Add a Gemini or OpenRouter key (see the [README](README.md)) for stronger ones.
- Never paste keys into chats or files in a project; use environment variables.

## 8. If something goes wrong
- **Red error text while installing**: run the one-line installer again; an early copy had a bug that
  stopped it dead. Nothing gets half-installed.
- **"running scripts is disabled"**: run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, then try again.
- **`opencode` not found**: close and reopen PowerShell (the PATH updates only in new windows).
- **Mistake in your project**: ask OpenCode to undo it, or use Git (`git status`, `git restore <file>`).
- **Start over with the kit config**: run `uninstall.ps1` (restores your old config), or re-run the installer.

There is a full **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** with the exact messages Windows gives and what
to do about each one.
