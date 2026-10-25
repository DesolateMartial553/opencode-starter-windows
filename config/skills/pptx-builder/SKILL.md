---
name: pptx-builder
description: Create or edit PowerPoint (.pptx) decks with python-pptx — school presentations, pitch decks, reports. Use when the user asks for a PowerPoint, slides as a .pptx file, or to change an existing .pptx. For browser-based HTML slides use frontend-slides instead.
---

# PowerPoint builder (python-pptx)

No system install is needed: run scripts with `uv run --with python-pptx python build_deck.py`.

## Workflow
1. **Plan first.** Write a slide-by-slide outline (title + 3-5 points each + what visual goes on it) and show it to the user before building, unless they said to just go ahead. For school work, keep the user's own wording and sources; cite sources on a final "References" slide.
2. **Write a script** (`build_deck.py` next to the output file) that builds the whole deck, so changes are a re-run, not manual edits.
3. **Design rules:**
   - 16:9 (`prs.slide_width = Inches(13.333)`, `prs.slide_height = Inches(7.5)`).
   - One idea per slide; max ~6 bullets, ~10 words each. Speaker detail goes in notes (`slide.notes_slide.notes_text_frame.text`).
   - One consistent theme: 1 background, 1 text colour, 1 accent colour, max 2 fonts. Title 36-40pt, body 18-24pt.
   - Vary layouts (title, two-column, image + text, big number/quote, timeline) — never 10 identical bullet slides.
   - Images: only files the user supplied or that are free to use; add them with `slide.shapes.add_picture`.
4. **Check it:** convert to PDF and look at it — `libreoffice --headless --convert-to pdf deck.pptx` (if LibreOffice is installed), then extract a few pages to PNG (`pdftoppm -png -r 50 deck.pdf page`) and view them. Fix text overflow, overlaps and low contrast. If LibreOffice isn't installed, say so and re-read the script for overflow risks instead of claiming it looks right.
5. Tell the user where the file is and open it with `xdg-open deck.pptx`.

## Editing an existing deck
Load with `Presentation("in.pptx")`, list slides and shapes first (`for i, s in enumerate(prs.slides): for sh in s.shapes: print(i, sh.shape_type, sh.name, sh.has_text_frame and sh.text_frame.text[:60])`), change only what was asked, keep the original fonts/colours, and save to a new filename so the original is kept.

## Minimal skeleton
```python
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

prs = Presentation()
prs.slide_width, prs.slide_height = Inches(13.333), Inches(7.5)
blank = prs.slide_layouts[6]

def text_slide(title, bullets, notes=""):
    s = prs.slides.add_slide(blank)
    tb = s.shapes.add_textbox(Inches(0.7), Inches(0.5), Inches(12), Inches(1.2))
    tb.text_frame.text = title
    tb.text_frame.paragraphs[0].font.size = Pt(38)
    tb.text_frame.paragraphs[0].font.bold = True
    body = s.shapes.add_textbox(Inches(0.9), Inches(1.9), Inches(11.5), Inches(5)).text_frame
    body.word_wrap = True
    for i, b in enumerate(bullets):
        p = body.paragraphs[0] if i == 0 else body.add_paragraph()
        p.text = "• " + b
        p.font.size = Pt(22)
    if notes:
        s.notes_slide.notes_text_frame.text = notes
    return s

text_slide("Example", ["First point", "Second point"], "What to say here")
prs.save("deck.pptx")
```
