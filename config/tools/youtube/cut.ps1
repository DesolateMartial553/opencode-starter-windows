# Cut a clip into a 9:16 Short with a slight zoom and optional burned-in captions.
# Usage: .\cut.ps1 <input> <start> <end> <output> [subs.srt]
#   times like 00:01:23 or 83. Captions: pass the .srt made by transcribe.py (timed to the full video).
param(
    [Parameter(Mandatory)][string]$InputFile,
    [Parameter(Mandatory)][string]$Start,
    [Parameter(Mandatory)][string]$End,
    [Parameter(Mandatory)][string]$Output,
    [string]$Srt
)
$ErrorActionPreference = 'Stop'
$vf = "crop='min(iw,ih*9/16*1.0)':ih,scale=1080:1920"
$tmpDir = $null
if ($Srt) {
    # ffmpeg runs from a temp dir with a relative subtitle name, because a "C:\..." path breaks filtergraph parsing
    $tmpDir = Join-Path $env:TEMP ("cut-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    ffmpeg -loglevel error -y -ss $Start -to $End -i (Resolve-Path $Srt) (Join-Path $tmpDir 's.srt')
    $vf += ",subtitles=s.srt:force_style='FontName=Arial,Bold=1,FontSize=14,Alignment=2,MarginV=50,Outline=3,PrimaryColour=&H00FFFFFF&'"
}
$in = (Resolve-Path $InputFile).Path
$out = [System.IO.Path]::GetFullPath($Output)
$prev = Get-Location
try {
    if ($tmpDir) { Set-Location $tmpDir }
    ffmpeg -loglevel error -y -ss $Start -to $End -i $in -vf $vf -c:v libx264 -preset veryfast -crf 20 -c:a aac -b:a 160k $out
} finally {
    Set-Location $prev
    if ($tmpDir) { Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue }
}
Write-Host "wrote $out"
