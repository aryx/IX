#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A sheet of fonts as t-IX would draw them, to choose one by looking
# (docs/notes/notes_font.md, section 7): the same line, a bold one and a large
# one in each, in cells of 8 by 16 (16 by 32 the large), shown twice
# as large with no smoothing, as tiny-machine's window shows its
# screen. Rows:
# - font1.bin and what the kernel makes of it (bold smeared, italic
#   slanted, large doubled);
# - each font file in tiny.font's format given (tiny.font, a
#   Mkfont.exe's; grey.font, its pixels' levels as greys), its four
#   faces as the kernel draws them;
# - Terminus Font, the four faces copied beside this script;
# - TrueType fonts drawn by FreeType (Ubuntu Mono, the author's Emacs
#   font, from the copies beside this script; this machine's Ubuntu
#   Sans Mono, the terminal's, and DejaVu Sans Mono, fc-match's
#   monospace), each twice: 1 bit a pixel (what TinyKernelGraphics
#   draws with tiny.font) and with grey edges (grey.font's 4 levels are
#   between the two). A font
#   not installed is said and skipped.
# A tool to look with, not the build's (the .font files are Mkfont.ml's);
# needs Pillow.
# usage: preview.py [out.png [file.font...]]   (default: preview.png, in
# the current directory)
import gzip, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT1 = os.path.join(HERE, "../../../kernels/lib_machine/font1.bin")
TTF = "/usr/share/fonts/truetype"
W = 640
LINE = "The quick brown fox jumps: {mail@ix} 0O1lI | let x = f y"
BOLD = "Bold: Hello world, menu"
LARGE = "Tiny office"

def blank(h):
    return Image.new("L", (W, h), 255)

def label(s):
    im = blank(16)
    ImageDraw.Draw(im).text((4, 2), s, fill=0)
    return im

# [bitmap glyph s w h]: s in cells of w by h, glyph c (row, col) a
# pixel's part of ink, 0 or 1 (a grey font's thirds between); bold
# smeared and slanted as TinyKernelGraphics' make
def bitmap(glyph, s, w, h, scale=1, bold=False, slant=0):
    im = blank(h * scale)
    ch = h * scale
    for i, c in enumerate(s):
        for row in range(ch):
            shift = slant * (ch - 1 - row) // ch
            for col in range(w * scale):
                k = col // scale
                def ink(k):
                    return glyph(ord(c), row // scale, k) if 0 <= k < w else 0
                v = ink(k) or (ink(k - 1) if bold and not ink(k + 1) else 0)
                x = 4 + (i * w * scale) + col + shift
                if v and x < W: im.putpixel((x, row), round(255 * (1 - v)))
    return im

# font1.bin: 16 bytes a character, a row's left pixel its low bit
def font1():
    d = open(FONT1, "rb").read()
    return lambda c, r, x: (d[(c * 16) + r] >> x) & 1

# a face of a font in tiny.font's format, its bytes from off: a row
# (w + 7) / 8 bytes, the left pixel the low bit of the first; or in
# grey.font's, depth 2: a pixel two bits, its level, 0 to 3
def tiny(d, off, w, h, depth=1):
    b = ((w * depth) + 7) // 8
    top = (1 << depth) - 1
    def glyph(c, r, x):
        byte = d[off + (((c * h) + r) * b) + (x * depth // 8)]
        return ((byte >> (x * depth % 8)) & top) / top
    return glyph

# the first 128 characters of a .psf.gz (header 4 bytes in PSF 1, 32 in
# PSF 2; there a character's place is its code), the left pixel the
# high bit
def psf(name, header, w, h):
    d = gzip.open(os.path.join(HERE, name)).read()
    b = (w + 7) // 8
    def glyph(c, r, x):
        return (d[header + (((c * h) + r) * b) + (x // 8)] >> (7 - (x % 8))) & 1
    return glyph

# a TrueType font drawn by FreeType (Pillow's) at size pixels, each
# character at its cell; grey, or each pixel black or white
def ttf(path, size, s, cw, ch, grey, variation=None):
    f = ImageFont.truetype(path, size)
    if variation:
        f.set_variation_by_name(variation)
    im = blank(ch)
    d = ImageDraw.Draw(im)
    ascent, descent = f.getmetrics()
    for i, c in enumerate(s):
        d.text((4 + (cw * i), (ch - (ascent + descent)) // 2), c, font=f, fill=0)
    return im if grey else im.point(lambda v: 0 if v < 128 else 255)

rows = []
rows += [label("font1.bin, and the kernel's bold, italic and large of it"),
         bitmap(font1(), LINE, 8, 16), bitmap(font1(), BOLD, 8, 16, bold=True),
         bitmap(font1(), "italic: Hello world", 8, 16, slant=3),
         bitmap(font1(), LARGE, 8, 16, scale=2)]
for f in sys.argv[2:]:
    d = open(f, "rb").read()
    name = os.path.basename(f)
    rows += [label(name + ": 8x16, bold, italic slanted, 16x32, bold")]
    if len(d) == 2048:
        rows.append(label("(one face: font1.bin's format)"))
        continue
    k = 2 if len(d) == 40960 else 1     # grey.font's depth, as the kernel's
    rows += [bitmap(tiny(d, 0, 8, 16, k), LINE, 8, 16),
             bitmap(tiny(d, 2048 * k, 8, 16, k), BOLD, 8, 16),
             bitmap(tiny(d, 0, 8, 16, k), "italic: Hello world", 8, 16, slant=3),
             bitmap(tiny(d, 4096 * k, 16, 32, k), LARGE, 16, 32),
             bitmap(tiny(d, 12288 * k, 16, 32, k), "Bold large", 16, 32)]
rows += [label("Terminus Font (mkfont.sh): 8x16, bold, 16x32, italic slanted"),
         bitmap(psf("Uni2-Terminus16.psf.gz", 4, 8, 16), LINE, 8, 16),
         bitmap(psf("Uni2-TerminusBold16.psf.gz", 4, 8, 16), BOLD, 8, 16),
         bitmap(psf("Uni2-Terminus16.psf.gz", 4, 8, 16), "italic: Hello world",
                8, 16, slant=3),
         bitmap(psf("Uni2-Terminus32x16.psf.gz", 32, 16, 32), LARGE, 16, 32)]
# (name, regular, bold, the size whose characters are 8 wide)
for name, regular, bold, size in [
        ("Ubuntu Mono (the author's Emacs; tiny.font's)",
         os.path.join(HERE, "UbuntuMono-Regular.ttf"),
         os.path.join(HERE, "UbuntuMono-Bold.ttf"), 16),
        ("Ubuntu Sans Mono (the terminal's)",
         TTF + "/ubuntu/UbuntuSansMono[wght].ttf", None, 13),
        ("DejaVu Sans Mono (fc-match monospace)",
         TTF + "/dejavu/DejaVuSansMono.ttf",
         TTF + "/dejavu/DejaVuSansMono-Bold.ttf", 13)]:
    if not os.path.exists(regular):
        rows.append(label(name + ": not installed (" + regular + ")"))
        continue
    # a variable font's bold is a variation of its one file (Ubuntu's
    # package's: its UbuntuMono-R.ttf and -B.ttf are links to
    # UbuntuMono[wght].ttf; the static ones are beside this script)
    b, v = (bold, None) if bold else (regular, "Bold")
    for grey in (False, True):
        rows += [label(name + (": grey edges" if grey else ": 1 bit a pixel")),
                 ttf(regular, size, LINE, 8, 16, grey),
                 ttf(b, size, BOLD, 8, 16, grey, v),
                 ttf(regular, 2 * size, LARGE, 16, 32, grey)]

out = sys.argv[1] if len(sys.argv) > 1 else "preview.png"
h = sum(r.size[1] + 2 for r in rows)
sheet = blank(h)
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.size[1] + 2
sheet.resize((2 * W, 2 * h), Image.NEAREST).save(out)
print(out)
