#!/usr/bin/env python3
"""Build a Short: 9:16 layout, word-by-word captions, hook text, punch-in zooms, whoosh SFX.

Usage: python clip.py INPUT START END OUTPUT [--words X.words.json] [--hook "TEXT"]
         [--layout auto|blur|crop] [--zoom-period 6] [--no-zoom] [--no-sfx] [--draft]
         [--zoom-at T1,T2,...] [--loudnorm] [--tag "TEXT"] [--watermark "TEXT"]
         [--namecard "TIME:TEXT"] [--cta "TEXT"] [--emphasize T0,T1]
         [--image-watermark PATH] [--image-watermark-pos "x,y"] [--image-watermark-scale 0.55]
START/END/TIME/Tn are seconds in the source. --words comes from transcribe.py.

Checklist flags (see the youtube-helper skill, "Clip quality bar"):
  --zoom-at     sync the punch-in zoom + whoosh to real hype beat(s) instead of a fixed timer
  --loudnorm    normalize audio toward -14 LUFS instead of shipping raw stream levels
  --tag         small creator/context identifier, top-left, shown for the first couple seconds
  --watermark   persistent low-opacity channel handle, bottom-right, whole clip (burned-in TEXT)
  --namecard    on-screen name/subject card at a specific reveal beat (e.g. "858.5:SOUTH LAKE TAHOE, USA")
  --cta         lightweight end-card text shown over the last couple seconds
  --emphasize   source time window (e.g. "858,861") whose caption word renders bigger/bolder
  --image-watermark  a supplied transparent PNG/AVIF, overlaid untouched for the whole clip —
                      use this (not --watermark/drawtext) when a campaign requires its exact
                      watermark file rather than a recreated one. Default position: horizontally
                      centered, vertically mid-frame (clear of the Hook/NameCard/Cap/CTA bands
                      this script already reserves) at ~55% of canvas width.

--draft renders at quarter area (540x960) with the ultrafast preset, for fast timing/overlay
checks on a slow CPU. Not for posting — always do the final render
without --draft once the cut is approved.
"""
import argparse, json, subprocess, sys, tempfile, textwrap
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("input"); ap.add_argument("start", type=float); ap.add_argument("end", type=float); ap.add_argument("output")
ap.add_argument("--words"); ap.add_argument("--hook")
ap.add_argument("--layout", default="auto", choices=["auto", "blur", "crop"])
ap.add_argument("--zoom-period", type=float, default=6.0)
ap.add_argument("--no-zoom", action="store_true"); ap.add_argument("--no-sfx", action="store_true")
ap.add_argument("--draft", action="store_true", help="quarter-resolution ultrafast preview render — timing/overlay check only")
ap.add_argument("--zoom-at", help="comma-separated absolute source seconds to punch-zoom on, overrides --zoom-period")
ap.add_argument("--loudnorm", action="store_true", help="loudnorm pass toward -14 LUFS")
ap.add_argument("--tag", help="small creator/context tag, top-left, first ~2.5s")
ap.add_argument("--watermark", help="persistent low-opacity channel handle, bottom-right")
ap.add_argument("--namecard", help='"TIME:TEXT" — name/subject card at an absolute source time')
ap.add_argument("--cta", help="end-card text over the last ~2.5s")
ap.add_argument("--emphasize", help="absolute source time window T0,T1 — caption word in it renders bigger")
ap.add_argument("--image-watermark", help="PATH to a transparent PNG/AVIF overlaid untouched for the whole clip")
ap.add_argument("--image-watermark-pos", help='"x,y" top-left in canvas px; default centers horizontally, mid-frame vertically')
ap.add_argument("--image-watermark-scale", type=float, default=0.55, help="watermark width as a fraction of canvas width")
a = ap.parse_args()
# ffmpeg runs with cwd=<temp dir> (see below), so anything we hand it must be absolute
a.input = str(Path(a.input).resolve()); a.output = str(Path(a.output).resolve())
if a.image_watermark:
    a.image_watermark = str(Path(a.image_watermark).resolve())
FONT = "Arial" if sys.platform == "win32" else "DejaVu Sans"
dur = a.end - a.start

def ff(*args, cwd=None):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-filter_threads", "2",
                    "-filter_complex_threads", "2", *map(str, args)], check=True, cwd=cwd)

w, h = map(int, subprocess.check_output(
    ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=p=0", a.input], text=True).strip().split(","))
layout = a.layout if a.layout != "auto" else ("blur" if w / h > 0.7 else "crop")

# canvas: 1080x1920 is the real posting size; --draft works at quarter area (half each dim) for
# fast local iteration. All pixel-based style/position numbers below are designed for 1080x1920
# and scaled by SF for draft mode.
CW, CH = (540, 960) if a.draft else (1080, 1920)
SF = CW / 1080

def sc(x):
    return max(1, round(x * SF))

def t(x):
    x = max(x, 0); return f"{int(x // 3600)}:{int(x % 3600 // 60):02}:{x % 60:05.2f}"

emph_lo, emph_hi = (None, None)
if a.emphasize:
    emph_lo, emph_hi = map(float, a.emphasize.split(","))

# ---- captions (ASS; canvas is CWxCH so sizes below need to scale with --draft) ----
ass = ["[Script Info]", "ScriptType: v4.00+", f"PlayResX: {CW}", f"PlayResY: {CH}", "WrapStyle: 2", "",
       "[V4+ Styles]",
       "Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding",
       f"Style: Cap,{FONT},{sc(86)},&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,1,0,0,0,100,100,0,0,1,{sc(7)},{sc(2)},5,{sc(40)},{sc(40)},0,1",
       f"Style: Hook,{FONT},{sc(72)},&H00FFFFFF,&H00FFFFFF,&H90000000,&H00000000,1,0,0,0,100,100,0,0,3,{sc(18)},0,8,{sc(60)},{sc(60)},{sc(230)},1",
       f"Style: Tag,{FONT},{sc(38)},&H00FFFFFF,&H00FFFFFF,&H00000000,&H90000000,1,0,0,0,100,100,0,0,3,{sc(10)},0,7,{sc(40)},{sc(40)},{sc(40)},1",
       f"Style: Watermark,{FONT},{sc(34)},&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,1,0,0,0,100,100,0,0,1,{sc(4)},0,3,{sc(30)},{sc(40)},{sc(40)},1",
       f"Style: NameCard,{FONT},{sc(66)},&H00FFFFFF,&H00FFFFFF,&H90000000,&H00000000,1,0,0,0,100,100,0,0,3,{sc(16)},0,5,{sc(60)},{sc(60)},0,1",
       f"Style: CTA,{FONT},{sc(56)},&H00FFFFFF,&H00FFFFFF,&H90000000,&H00000000,1,0,0,0,100,100,0,0,3,{sc(14)},0,8,{sc(60)},{sc(60)},{sc(260)},1",
       "", "[Events]", "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text"]
if a.hook:
    hook = "\\N".join(textwrap.wrap(a.hook.upper(), 16))
    ass.append(f"Dialogue: 1,{t(0)},{t(2.2)},Hook,,0,0,0,,{{\\fad(120,200)}}{hook}")
if a.tag:
    ass.append(f"Dialogue: 1,{t(0)},{t(2.5)},Tag,,0,0,0,,{{\\fad(100,250)}}{a.tag}")
if a.watermark:
    ass.append(f"Dialogue: 0,{t(0)},{t(dur)},Watermark,,0,0,0,,{{\\alpha&H60&}}{a.watermark}")
if a.namecard:
    nc_time, nc_text = a.namecard.split(":", 1)
    nc_rel = float(nc_time) - a.start
    ass.append(f"Dialogue: 1,{t(nc_rel)},{t(nc_rel + 2.5)},NameCard,,0,0,0,,{{\\an5\\pos({CW // 2},{sc(700)})\\fad(150,250)}}{nc_text.upper()}")
if a.cta:
    ass.append(f"Dialogue: 1,{t(dur - 2.5)},{t(dur)},CTA,,0,0,0,,{{\\fad(150,150)}}{a.cta.upper()}")
if a.words:
    ws = [x for x in json.load(open(a.words)) if x["s"] >= a.start - 0.05 and x["e"] <= a.end + 0.3]
    for i in range(0, len(ws), 3):
        chunk = ws[i:i + 3]
        for j, cur in enumerate(chunk):
            s0 = cur["s"] - a.start
            e0 = (chunk[j + 1]["s"] if j + 1 < len(chunk) else cur["e"]) - a.start
            emphasized = emph_lo is not None and emph_lo <= cur["s"] <= emph_hi
            def wrap(k, x):
                word = x["w"].upper().strip(".,!?")
                if k != j:
                    return word
                if emphasized:
                    # reset colour/scale explicitly instead of \r, so a per-line \fs
                    # shrink (below) survives to the rest of the chunk
                    return f"{{\\c&H00D7FF&\\fscx150\\fscy150}}{word}{{\\c&HFFFFFF&\\fscx100\\fscy100}}"
                return f"{{\\c&H00D7FF&}}{word}{{\\c&HFFFFFF&}}"
            line = " ".join(wrap(k, x) for k, x in enumerate(chunk))
            # fit long words to the canvas: 3-word chunks of long words (e.g. "INTERNET
            # RUINS EVERYTHING") overflowed the frame edge and got clipped, so shrink the
            # whole line — emphasis included — until its estimated width fits the margins
            plain_w = sum(len(x["w"].upper().strip(".,!?")) + 1 for x in chunk)
            emph_w = sum(len(x["w"].upper().strip(".,!?")) + 1
                         for x in chunk if emph_lo is not None and emph_lo <= x["s"] <= emph_hi)
            est = plain_w * 0.62 * sc(86) + emph_w * 0.62 * sc(86) * 0.5
            max_w = CW - 2 * sc(40)
            line_fs = ""
            if est > max_w:
                line_fs = f"{{\\fs{max(1, int(sc(86) * max_w / est))}}}"
            ass.append(f"Dialogue: 0,{t(s0)},{t(max(e0, s0 + 0.12))},Cap,,0,0,0,,{{\\an5\\pos({CW // 2},{sc(1180)})}}{line_fs}{line}")
tmp = Path(tempfile.mkdtemp())
(tmp / "c.ass").write_text("\n".join(ass))

# ---- video graph ----
if layout == "blur":
    g = (f"[0:v]split=2[a][b];[a]scale={CW}:{CH}:force_original_aspect_ratio=increase,crop={CW}:{CH},boxblur=40:2[bg];"
         f"[b]scale={CW}:-2[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2[base]")
else:
    g = f"[0:v]scale={CW}:{CH}:force_original_aspect_ratio=increase,crop={CW}:{CH}[base]"
last = "base"
zoom_rels = [float(x) - a.start for x in a.zoom_at.split(",")] if a.zoom_at else None
if not a.no_zoom:
    if zoom_rels:
        # one Gaussian punch-in per beat instead of a fixed-period square wave
        bumps = "+".join(f"exp(-pow(t-{r:.3f}\\,2)/0.18)" for r in zoom_rels)
        expr = f"1+0.12*({bumps})"
    else:
        P = a.zoom_period
        expr = f"1+0.07*lt(mod(t,{P}),{P / 2})"
    g += f";[base]scale=w='trunc({CW}*({expr})/2)*2':h=-2:eval=frame,crop={CW}:{CH}[z]"
    last = "z"
# relative name + cwd=tmp: a Windows drive-letter path ("C:\\...") breaks ffmpeg's filtergraph parser
g += f";[{last}]ass=c.ass[capped]"
last = "capped"

# ---- inputs ----
cmd = ["-ss", a.start, "-t", dur, "-i", a.input]
next_idx = 1

if a.image_watermark:
    # movie= loads the PNG as a filter source (one static frame, held for the whole
    # main stream) — fast, and avoids a separate "-loop 1 -i watermark.png" input,
    # which pathologically stalls ffmpeg here (measured: a 3s draft clip never
    # finished in 2+ min with that approach). These supplied watermark files are
    # rendered on a solid black canvas with no real alpha (checked: alphaextract on
    # the campaign's PNG was 100% opaque) — they're meant for a "screen" blend, where
    # black contributes nothing and the glow/text show through, not a straight
    # alpha overlay (which would paint an opaque black box over the clip).
    wm_w = sc(int(1080 * a.image_watermark_scale))
    wm_path = str(a.image_watermark).replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")
    if a.image_watermark_pos:
        wx_expr, wy = a.image_watermark_pos.split(",")
    else:
        wx_expr, wy = "(ow-iw)/2", sc(900)
    # "screen" blend math (1-(1-a)(1-b)) is an RGB/linear-light formula; running it
    # directly on YUV planes corrupts chroma (measured: tinted the whole frame
    # magenta, since U/V are offset-128 "no color" at neutral, not 0). Convert both
    # sides to an RGB pix_fmt for the blend, then back to yuv420p for encoding.
    g += f";movie='{wm_path}',format=rgba,scale={wm_w}:-1,pad={CW}:{CH}:{wx_expr}:{wy}:color=black,format=gbrp[wmpad]"
    g += f";[{last}]format=gbrp[basefmt]"
    g += f";[basefmt][wmpad]blend=all_mode=screen:enable='between(t,0,{dur})',format=yuv420p[v]"
    last = "v"
else:
    g += f";[{last}]null[v]"

# ---- audio: whoosh at each punch-in, optional loudnorm ----
if a.no_zoom or a.no_sfx:
    times = []
elif zoom_rels:
    times = zoom_rels
else:
    times = [k * a.zoom_period for k in range(1, int(dur // a.zoom_period) + 1)]
if times:
    ff("-f", "lavfi", "-i", "anoisesrc=d=0.5:c=pink:a=0.6", "-af",
       "highpass=f=500,lowpass=f=6000,afade=t=in:d=0.25,afade=t=out:st=0.25:d=0.25,volume=0.5", tmp / "whoosh.wav")
    cmd += ["-i", tmp / "whoosh.wav"]
    whoosh_idx = next_idx
    next_idx += 1
    n = len(times)
    g += f";[{whoosh_idx}:a]asplit={n}" + "".join(f"[w{i}]" for i in range(n))
    for i, tt in enumerate(times):
        ms = max(int(tt * 1000) - 80, 0)
        g += f";[w{i}]adelay={ms}|{ms}[d{i}]"
    g += ";[0:a]" + "".join(f"[d{i}]" for i in range(n)) + f"amix=inputs={n + 1}:duration=first:normalize=0[amix]"
    alast = "amix"
else:
    g += ";[0:a]anull[amix]"
    alast = "amix"
if a.loudnorm:
    g += f";[{alast}]loudnorm=I=-14:TP=-1.5:LRA=11[aout]"
    alast = "aout"
amap = f"[{alast}]"
preset = "ultrafast" if a.draft else "veryfast"
crf = "28" if a.draft else "20"
ff(*cmd, "-filter_complex", g, "-map", "[v]", "-map", amap, "-c:v", "libx264", "-preset", preset, "-crf", crf,
   "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-r", "30", a.output, cwd=tmp)
print(f"wrote {a.output} ({CW}x{CH}, layout={layout}, whooshes={len(times)}, loudnorm={a.loudnorm}, draft={a.draft})")
