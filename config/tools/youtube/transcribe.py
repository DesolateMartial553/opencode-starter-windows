"""Transcribe a video/audio file to timestamped segments.
Usage: python transcribe.py raw/video.mp4 [model=base.en]
Writes <file>.segments.txt (readable), <file>.words.json (word timings) and <file>.srt next to the input.
"""
import json, subprocess, sys
import numpy as np
from pathlib import Path
from faster_whisper import WhisperModel

src = Path(sys.argv[1])
model = WhisperModel(sys.argv[2] if len(sys.argv) > 2 else "base.en", device="cpu", compute_type="int8")
# decode with ffmpeg ourselves (the bundled PyAV call is incompatible with this PyAV version)
raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(src), "-f", "s16le", "-ac", "1", "-ar", "16000", "-"],
                     capture_output=True, check=True).stdout
audio = np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0
segments, _ = model.transcribe(audio, vad_filter=True, word_timestamps=True)

def ts(t, comma=False):
    h, r = divmod(t, 3600); m, s = divmod(r, 60)
    return f"{int(h):02}:{int(m):02}:{s:06.3f}".replace(".", "," if comma else ".")

txt, srt, words = [], [], []
for i, s in enumerate(segments, 1):
    words += [{"w": w.word.strip(), "s": round(w.start, 2), "e": round(w.end, 2)} for w in (s.words or [])]
    txt.append(f"[{ts(s.start)} -> {ts(s.end)}] {s.text.strip()}")
    srt.append(f"{i}\n{ts(s.start, True)} --> {ts(s.end, True)}\n{s.text.strip()}\n")
src.with_suffix(".segments.txt").write_text("\n".join(txt))
src.with_suffix(".srt").write_text("\n".join(srt))
src.with_suffix(".words.json").write_text(json.dumps(words))
print(f"{len(txt)} segments -> {src.with_suffix('.segments.txt')}")
