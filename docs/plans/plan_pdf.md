# Plan: PDF in ix: a file read and drawn (mini-page, mini-netscape) and a file written (mini-office's Export) (`lib_graphics/fonts/`, `lib_graphics/pdf/`, `apps/page/`)

The author (2026-10-09): "how difficult it would be to add a pdf
exported to mini-office? I saw a pdf viewer in ~/github/mini-chrome
which I guess rely on some playground tiny libs, but I'm not sure how
much code it would be. also how difficult would it be to have a "page"
like program (see plan 9) to visualize a pdf?"; then: "maybe we can
write a plan_pdf.md document", "with its use in the mini-netscape, in
mini-office, and in a new page mini application".

The short answer: **reading is a copy, 15 files and 2,621 lines of .ml
(930 of .mli), and it already draws the author's books; writing is
new and small, about 400 lines (an estimate); the viewer is about 300
(an estimate).** The two directions share nothing but the format: the
office's Export needs none of the reader, so it can come first.

- **Read**: mini-chrome's `libs/pdf` (9 files, 1,429 lines) over its
  `libs/fonts` (6 files, 1,192 lines: TrueType, CFF and Type 1
  outlines). Under them, of the playground's libraries, ix has
  everything but `Curve` (94 lines) and `Jpeg` with its three files
  (712 lines), and those four are already `plan_office.md`'s stage 7
  and `plan_browser.md`'s stage 5. 3 of the 15 compile by mini-ml as
  they are; the others are refused for what the office's and the
  browser's files were (optional arguments, `for _`, `a.{i}`, a
  polymorphic variant).
- **Write**: nothing to copy. A PDF's writer and a Playground shape
  turned into its operators; every part of mini-office already draws
  itself as Playground shapes, and `Zlib.deflate` is here.
- **mini-page**: a Playground program over the reader. Plan 9's
  `page` is 3,919 lines and draws no PDF itself: it is a viewer round
  Ghostscript. mini-page does the drawing in the program.
- **mini-netscape**: mini-chrome's `Pdf_viewer` (61 lines) and 24
  lines of its tab, when the browser shows pictures.

Its numbers are `scripts/stats/pdf_survey.sh`'s (run 2026-10-09,
against mini-chrome at `8af888e`, 2026-10-07, and the playground at
`028d8abf`, 2026-10-06), which gives mini-ml's **first** refusal of a
file: a file has others behind it, found when the first is gone.

**Status: stages A, B, C1 and D done on Linux** (mini-office's File >
Export writes a PDF; the reader is here, by dune and by mini-ml,
arm64 and arm; `mini-page` shows a file's pages; what is exported is
read back in the tests). **C2, mini-page on mini-9pi: seen
working on the author's Pi 1 (2026-10-10), not measured.** Not begun: Hershey as a font (E),
mini-netscape (F) (see Status at the end).

## What there is

mini-chrome's reader is one commit (`27319fd`, "libs/pdf, libs/fonts:
a PDF file read and its pages drawn"), pure OCaml, bytes in and a
picture out:

```
  bytes ──Pdf──▶ objects, pages ──Pdf_render──▶ Pdf_canvas ──▶ Rgba_image
            │                        │    │
       Pdf_object               Pdf_font  Pdf_color, Pdf_shading, Pdf_image
       Pdf_filter                    │
       (Zlib, Jpeg)             Truetype, Cff, Type1 ──▶ Outline ──Curve──▶ polygons
                                                                   (Fill, Stroke)
```

- `Pdf`: the file's objects found by the table at its end (the old
  table and PDF 1.5's stream of numbers, objects packed in streams;
  a file whose table is wrong, by looking for every `n g obj`), the
  pages listed. `Pdf_object` is the syntax, `Pdf_filter` a stream's
  encodings undone (Flate, ASCII85, ASCIIHex, LZW, RunLength, the
  PNG predictors; DCT is `Jpeg`'s).
- `Pdf_render`: a page's operators run over a graphics state, onto
  `Pdf_canvas` (polygons filled inside a clip, pictures, gradients,
  transparency). A record of options turns each refinement off:
  `plain` is paths, colours and Hershey's letters at the file's
  widths. `Pdf_render.text` is the same run with nothing painted: a
  page's words.
- `Pdf_font`: a code's glyph, width and characters; the outlines are
  `libs/fonts`' (`Truetype`, `Cff`, `Type1`, each to an `Outline`),
  `Standard_widths` for Helvetica and Times named and not embedded,
  `Glyph_names` for the old encodings (262 of those two files' 406
  lines are tables). A Type 3 font's glyphs are operators, run by
  `Pdf_render` itself.
- Not read: an encrypted file, the outline, links, form fields,
  tiling patterns, dashed lines, blend modes, layers, annotations.

What it draws today, by mini-chrome's own build (OCaml native, this
machine, 2 pixels a point as its viewer):

| file | made by | fonts | pages | first page | seconds, all pages |
|---|---|---|---|---|---|
| `shapes.pdf` | cairo | TrueType | 1 | 800 x 600 | 0.11 |
| `tex.pdf` | pdfTeX | Type 1 | 2 | 567 x 284 | 0.07 |
| `bitmap.pdf` | pdfTeX | Type 3 | 2 | 567 x 284 | 0.05 |
| `cff.pdf` | cairo | CFF | 1 | 640 x 220 | 0.03 |
| `browser.pdf` | Chrome | TrueType by glyph number | 1 | 576 x 432 | 0.04 |
| `office.pdf` | LibreOffice | TrueType | 1 | 576 x 432 | 0.04 |
| `standard.pdf` | by hand | Helvetica, Times, not embedded | 1 | 600 x 240 | 0.03 |

And one file that is not a test's: `principia-softwarica/windows/Windows-9.pdf`
(1.3 MB, 362 pages, 15 Type 1 fonts, 2 Type 3, 1 TrueType) opens, and
its pages 1, 20 and 60 are drawn at 1224 by 1584 in 0.25, 0.61 and
0.37 s; page 20 looked at: the text, the section titles, the
footnotes, the coloured links and the small capitals are right. The
other 359 pages were not drawn.

## What to copy

The file, its lines (.ml, .mli), where it goes here, and what mini-ml
refuses first (none: it compiles as it is; "its X.mli": refused in an
interface it reads).

| file | .ml | .mli | goes to | mini-ml's first refusal |
|---|---|---|---|---|
| playground `Curve` | 94 | 165 | `lib_graphics/software/` | `?(tolerance = 0.1)` |
| playground `Huffman` | 88 | 80 | `lib_compression/` | none |
| playground `Dct` | 101 | 60 | `lib_graphics/images/` | none |
| playground `Jpeg_progressive` | 89 | 95 | `lib_graphics/images/` | none |
| playground `Jpeg` | 434 | 120 | `lib_graphics/images/` | `for _` |
| `Outline` | 82 | 63 | `lib_graphics/fonts/` | `?(tolerance : float option)` |
| `Glyph_names` | 258 | 39 | `lib_graphics/fonts/` | none |
| `Standard_widths` | 148 | 29 | `lib_graphics/fonts/` | none |
| `Truetype` | 187 | 74 | `lib_graphics/fonts/` | `?(depth : int = 0)` |
| `Cff` | 278 | 70 | `lib_graphics/fonts/` | `Option.value ~default:` |
| `Type1` | 239 | 67 | `lib_graphics/fonts/` | `?(clear : int option)` |
| `Pdf_object` | 167 | 67 | `lib_graphics/pdf/` | `?(length : ...)` |
| `Pdf_filter` | 151 | 42 | `lib_graphics/pdf/` | `for _` |
| `Pdf` | 208 | 100 | `lib_graphics/pdf/` | `for _` |
| `Pdf_color` | 54 | 40 | `lib_graphics/pdf/` | its `Pdf_object.mli` |
| `Pdf_canvas` | 131 | 75 | `lib_graphics/pdf/` | `img.rgba.{4 * i}` |
| `Pdf_font` | 193 | 68 | `lib_graphics/pdf/` | a polymorphic variant (`` `None ``, 20 lines) |
| `Pdf_shading` | 87 | 53 | `lib_graphics/pdf/` | its `Pdf_object.mli` |
| `Pdf_image` | 64 | 35 | `lib_graphics/pdf/` | `img.rgba.{...}` |
| `Pdf_render` | 374 | 108 | `lib_graphics/pdf/` | `?(options : options = full)` |
| `Pdf_viewer` (the browser's) | 61 | 49 | `browsers/`, with mini-netscape | its `Pdf_object.mli` |

The fonts and the reader: 15 files, 2,621 and 930. The first five
rows, 806 and 520, are not this plan's alone: `Huffman`, `Dct`,
`Jpeg_progressive` and `Jpeg` are the office's stage 7 (a picture
from a file) and `Curve` is the browser's stage 5; whichever comes
first does them. `Png` is not needed: a PDF's pictures are Flate's
bytes or a JPEG.

Already here: `Zlib` (`Pdf_filter`'s one line that names the
playground's `Zlib.decompress` and `Inflate.inflate` is said with
ix's `Zlib.inflate` and `inflate_at`), `Rgba_image`, `Framebuffer`, `Fill`
(`polygons_aa`), `Stroke` (`contours`), `Affine` (`invert` too),
`Hershey`.

mini-chrome's tests go with them: `Unit_pdf`, `Unit_pdf_render`,
`Unit_fonts` (332 lines, Testo), `Dump` (64 lines: a file's pages, a
page as a PPM, a page's words, a font's glyph), the seven files above
(148 KB) and poppler's picture of each page, which ours must be near.

## What it requires, beyond the copy

1. **The files made what mini-ml takes.** Counted in the 15: 8
   definitions with optional arguments (7 in the interfaces), 5 lines
   of `a.{i}` (`Rgba_image` is a `Bytes` here), `for _` in 2 files,
   the polymorphic variant of `Pdf_font`, one `~default:`; 53 lines
   of `Hashtbl` and 53 of `Buffer`, which lib_core has. No functor,
   no `let open`, no `Printf`. What is behind each first refusal is
   not known until it is gone.
2. **`Pdf_canvas`'s paper**: a `float array`, three numbers a pixel.
   mini-ml boxes a float in an array (`plan_ml.md`, decision 4): a
   page at 1224 by 1584 is 5.8 million of them. To measure first; the
   likely change is a `Bytes` and the blending in integers, which is
   also what would make it fast on arm.
3. **A page shown on mini-9pi**: a page is a `Playground.Bitmap`, and
   the draw platform draws that form as a grey rectangle today. That
   is the office's stage 7 ("Bitmap drawn by the draw platform,
   loaded once into an image of the kernel's"); not done twice.
4. **The builds**: `lib_graphics/fonts/` and `lib_graphics/pdf/` in
   dune and in the mkfiles, as `lib_graphics/software/`.

## The writer, and mini-office's Export

Export today writes the same bytes as Save (`File_menu`: `Store.export`
of `Saved.to_string`). Nothing of the playground's or mini-chrome's
writes a PDF, so this part is written here. Three pieces (the lines
are estimates, nothing is written):

- **`Pdf_write`** (`lib_graphics/pdf/`, about 200 lines): the other
  half of `Pdf_object`. Objects numbered as they are added, a stream
  deflated by `Zlib.deflate`, the pages' tree, the table of where each
  object starts, the trailer; and a small set of content operators
  behind functions (a path filled or stroked, a transform, a colour,
  an opacity by an `ExtGState`, a picture as an image object). Names
  nothing of Playground: the browser could print with it one day.
- **`Shape_render_pdf`** (`lib_playground/platforms/`, about 150
  lines, beside `Shape_render_software`): a `Playground.shape list`
  as a content stream. `Rectangle`, `Ngon` and `Polygon` are a path
  filled; `Circle` and `Oval` four curves; a shape's place, angle and
  scale a `cm`; its alpha an `ExtGState`; `Bitmap` an image; `Group`
  a `q ... Q`; `Words` Hershey's strokes. Vectors, not a picture of
  the screen: the file stays sharp at any zoom and prints.
- **The office's side** (about 50 lines): `Office_view.page_shapes
  ~chrome:false` is already the document without the caret and the
  selection (the slide show uses it). It is one column of all the
  pages; written once as a form object, and each PDF page is that
  form moved up by a page's pitch, its own box cutting the rest.
  `File_menu`'s Export then writes `name.pdf`.

**The text.** Today `Stroke_text` gives a letter as about six thin
rectangles, a page of 40 lines as 8,000 shapes; exported as they are
that is 8,000 small filled paths, a few hundred kilobytes before
Flate, and words nobody can select or search. Right the first day,
and the same pixels as the screen. The better form waits for
`plan_playground_speed.md`'s A (text a shape of Playground's, a run
with its look): a run then exports as real text in **Hershey as a
Type 3 font**, each glyph its strokes written once in the file, the
widths Hershey's own, so the layout is the screen's and the words are
words. The reader already runs Type 3 glyphs.

**Its test** needs no eye: a document exported, read back by the
reader, and the picture compared with `Shape_render_software`'s of
the same shapes; and on Linux poppler's `pdftoppm` of the same file,
as an outsider's reading (a test's tool, not the build's).

## mini-page

Plan 9's `page` (principia's `typesetting/page/`, 3,919 lines of C)
is a viewer and no more: `view.c` (1,075) is the window, the menu of
pages and the mouse; `gs.c`, `ps.c`, `pdf.c` and `pdfprolog.c` (965)
start Ghostscript and talk to it over pipes; `rotate.c` and
`nrotate.c` (777) turn a picture; `gfx.c` and `filter.c` (441) hand
the other formats to `jpg`, `png`, `gif`. There is no PostScript
interpreter here and none is planned, so **mini-page shows PDF and
pictures, not PostScript**.

A Playground program, about 300 lines (an estimate), as mini-office
is, so it runs on Linux and on mini-9pi and its sessions are
recorded as theirs:

- `mini-page file.pdf`: the first page at the window's width.
- Keys and mouse as `page`'s where it has them: space, Page Down and
  the arrows a page forward or back, a number and Enter that page;
  `+` and `-` the zoom, `r` a quarter turn; button 1 held drags the
  page; button 3 the menu of pages.
- A page is drawn when it is first shown and kept; a few are kept,
  the oldest let go (`cache.c`'s job).
- A file that is a PNG or a JPEG by its first bytes is shown too, by
  the office's `Image_file`, when that is here.
- `mini-page -t file.pdf`: the words of each page printed
  (`Pdf_render.text`), no window; `-ppm n out` a page's picture.
  These two are what the tests run, and they replace `Dump`.

## mini-netscape

`plan_browser.md` leaves PDF out, and its base, mini-chrome's first
version, has none. Added back as its table adds the rest, when a
site asks: `Pdf_viewer` (61 and 49 lines: the document made a page of
HTML, an `<img>` a page) and the 24 lines of `Browser_tab` that draw
the pages in view as the tab is scrolled and let the others go. It
stands on the browser's own pictures and scrolling, so it comes
after that plan's stage 5.

## Decisions (proposed, to confirm)

1. **Where**: the fonts in `lib_graphics/fonts/`, the reader and the
   writer in `lib_graphics/pdf/`, beside `software/` and the planned
   `images/`; the viewer in `apps/page/`, the program `mini-page`.
   (Principia's is `typesetting/page/`; ix has no `typesetting/`.)
2. **The reader is copied whole, then cut by what the files ask**, as
   the browser's is: the seven test files and the author's books are
   the sites. Each of the three font formats is asked for by one of
   them (the books alone want Type 1, Type 3 and TrueType), so none
   is a candidate; the gradients (`Pdf_shading`, 87 lines) and the
   transparency are, if no file of the author's has them.
3. **mini-page is a Playground program**, not one written on
   `lib_graphics`' `Draw` as Plan 9's is: one program for Linux and
   mini-9pi, and the recorded sessions for its tests.
4. **Export writes shapes, text as strokes first**, the Type 3 font
   after the playground's text is a shape.
5. **Export is PDF and only PDF**: the menu's entry writes
   `name.pdf`; the document's own bytes are Save's.
6. **No PostScript, no encrypted file, no file changed in place**
   (a PDF opened is not edited; the office does not import one).

## The stages (each checked before the next)

The writer (A) and the reader (B) do not depend on each other; C
needs B, D needs both.

- **A1. `Pdf_write` and `Shape_render_pdf`** on Linux: a list of
  shapes of each form written, opened by poppler, looked at.
- **A2. mini-office's Export**: a document of each kind exported; a
  page of text, a sheet, a drawing, a chart, a picture.
- **B1. The reader on Linux, by dune**: `Curve`, the JPEG's files if
  the office has not brought them, the fonts, the reader, made what
  mini-ml takes; mini-chrome's unit tests and its seven files.
- **B2. By mini-ml**, arm64 then arm: the paper's memory and a
  page's time measured (items 2 above), and changed if they must be.
- **C1. mini-page on Linux**: the tests' files and a book of the
  author's read through; `-t` and `-ppm`.
- **C2. mini-page on mini-9pi**, after the office's stage 7 has the
  draw platform draw a `Bitmap`.
- **D. The round trip as a test**: what A2 exports read by B1 and
  compared with the screen's picture.
- **E. Hershey as a Type 3 font** in the export, after
  `plan_playground_speed.md`'s A.
- **F. mini-netscape**, after `plan_browser.md`'s stage 5.

## Open questions

- **A page's time on arm.** 0.25 to 0.61 s for a page of a book by
  OCaml native here. The only ratio known is mini-emacs's (a line
  down: 2.0 ms by dune, 7.0 by mini-ml on arm64, 1,900 on arm under
  mini-5i), and that code has no float; this one is floats in every
  line of its inner loops, and mini-ml's are boxed. Not known for a
  Pi; measured in B2. If it is tens of seconds: 1 pixel a point (a
  quarter of the pixels), `plain` first and the outlines after, the
  integer paper of item 2.
- **Memory on mini-9pi**: the file whole in a string (a book is 1.3
  MB; mini-ml's string on arm holds 16 MB), the paper, the picture,
  the kept pages. `plan_self_hosting.md`'s open question too.
- **A JPEG in a PDF on arm**: the office's stage 7 question, the
  same code.
- **What the author's files ask beyond the seven**: one book opened,
  three of its pages drawn. The figures (pictures, the lineage
  diagrams by Graphviz) were not looked at.
- **Fonts not embedded**: drawn in Hershey's letters at
  `Standard_widths`' widths. Good enough for a file by hand; a file
  that names Times and embeds nothing reads, and does not look like
  itself.
- **Does the Linux window's `Bitmap` scale and turn** as mini-page
  wants (zoom, a quarter turn), or is a page drawn again at each
  zoom? Drawn again is simpler and sharper; it costs a page's time.

## Status

Stages B, C1 and D, and `lib_graphics/`'s folders (2026-10-09, the
night; the author: "I'll review tomorrow morning; move as much
possible forward on the plan as you can"). Nothing is committed.

**`lib_graphics/`'s folders** (the author: "should
lib_graphics/software/xpm.ml be moved to lib_graphics/images/ ?",
"and rgba_image.mli and maybe Framebuffer.ml moved out of software/ in
lib_graphics/core/ like we did in the ~/playground ?", "and also have
a geometry subfolder"): `core/` (`Framebuffer`, `Rgba_image`, `Opti`,
and `Blit`, new), `geometry/` (`Vec2`, `Affine`, and `Curve`, new),
`images/` (`Xpm`, and `Png`, `Jpeg`, `Dct`, `Jpeg_progressive`, new),
`software/` (`Fill`, `Line`, `Circle`, `Stroke`, `Hershey`), each a
library of dune's; `fonts/` and `pdf/` beside. `games/mkgames`
compiles a unit from the folder that has it; the scripts' paths
follow. `Hershey` was left in `software/`: `fonts/` is the outline
fonts of a PDF, and nobody asked.

**B1, the reader**: the 15 files in `lib_graphics/fonts/` and
`lib_graphics/pdf/` (2,650 lines of .ml here for 2,621 there:
`pdf_survey.sh`'s table, file by file), with `Curve`, `Huffman`,
`Dct`, `Jpeg_progressive`, `Jpeg` and `Png` of the playground's (the
office's stage 7a, less its `Image_file` and the playground's unit
tests of them, which are not copied). What changed is
`lib_graphics/pdf/README.md`'s list; `Zlib.inflate_blocks` is new.
mini-chrome's tests are `lib_graphics/pdf/tests/` (24 of them, its
seven files and poppler's pictures).

**B2, by mini-ml (arm64)**: every file compiles (`compile_ix.sh`: 115
of 115 in the directories touched). The paper was the plan's worry
(item 2) and it was right: `Pdf_canvas`'s pixels are **bytes now**,
where they were floats in an array. `Windows-9.pdf` in mini-page's
window (a pixel and a half a point, page 1 then page 2), the run
whole:

| | floats | bytes |
|---|---|---|
| OCaml (dune) | 0.82 s, 107 MB | 0.45 s, 58 MB |
| mini-ml, arm64 | 4.01 s, 264 MB | 1.78 s, 133 MB |

A page at a pixel a point, by mini-ml: 1.1 to 2.7 s (pages 1, 60,
20), where OCaml's is 0.3 to 0.5. What the bytes cost: a colour is
rounded each time something is laid on it; the tests against
poppler's pictures pass as before; and mini-ml's picture, which was
OCaml's to the pixel, is a level apart on a few (20 bytes of a
frame of `shapes.pdf` enlarged; the book's pages are the same).

**arm (mini-ml's 32-bit code, an int of 31 bits), under mini-5i**:
mini-page built by `mini-mk O=5`; page 1 of each of the seven test
files by `-ppm` is OCaml's picture to the byte (7 to 81 s each under
the emulator, which says nothing of a Pi), `-t` gives the words, and
a PNG in a window of 300 is OCaml's frame. Three things it took:
- **`Zlib.crc32` is wrong on arm** (`bugs/ix.md`): a PNG was refused,
  "bad CRC in chunk IHDR". `Zlib.crc32_halves` is new, and `Png`
  reads and writes by it; `crc32_sub`, which mini-git's pack index is
  written with, is as it was.
- **mini-ml's arm code takes 7 parameters at most**:
  `Jpeg_progressive.block`'s readers are a record (`source`),
  `Jpeg.decode_scan`'s tables another (`decoding`),
  `Pdf_image.paint`'s and `Pdf_shading.paint`'s canvas and clip a
  pair (and the first's fill, alpha and shown a triple).
- No JPEG was decoded on arm (none of the seven files has one); the
  book was not tried there.

**C2, mini-page on mini-9pi: runs on the Pi 1** (2026-10-10, the
author, of the card of `make card` written to an SD card: "it works on
the pi1!"; which file, a page's time and the memory were not said, and
nothing was run under mini-qemu or QEMU). The draw platform
(`lib_playground/platforms/draw`) draws a `Bitmap` whose box it fills
and that has no transparent pixel: its pixels made in the program at
the size shown, given to the device once, an image of the kernel's
kept (the last four), a frame then one copy. Another picture (turned
other than by quarters, or with transparency: a game's sprite) is
its grey box as before: the device would need a mask. mini-page is
on the card as `page`, with three of the tests' files in `/lib/pdf`
(`kernels/9pi/Makefile`). Checked: `pageview` and `office` built and
linked by `mini-mk O=5 OS=plan9` in a copy of the tree. **Not done:
the card built, anything run under mini-9pi or QEMU**; the device's
code for a copy from an `x8r8g8b8` image is the software platform's
way, which runs there; whether a destination larger than the window
is cut as Plan 9's is not known.

**C1, mini-page on Linux** (`apps/page/Pageview.ml`, 266 lines;
`bin/mini-page` is SDL's): a file's pages, a number and Enter, the
zoom, a quarter turn, the page moved by the arrows, the wheel and the
mouse; a PNG or a JPEG shown too; `-t` (a file's words) and `-ppm`.
For it the software renderer **draws a `Bitmap`** (`Blit`: the
office's stage 7b, less its test and its example): it was a grey
box. Its tests: `apps/page/tests/frames.sh`, ten sessions and the
two ways without a window. Looked at: the book's first page and its
contents enlarged and scrolled; four of the sessions; mini-office's
exported document opened in it.

**D, the round trip**: `Unit_pdf_write` (every form and a picture
written, read back by `Pdf_render`, held to
`Shape_render_software`'s picture, and further with a shape less) and
`Unit_export` (five documents exported, each page read back and held
to the screen's).

Checked, the last state: `lib_graphics/pdf/tests/Test.exe` 29 of 29,
`apps/office/tests/Test.exe` 63 of 63, `apps/page/tests/frames.sh` 12
of 12 by dune's build and by mini-ml's (five sessions a level apart
on a few pixels, their second sum recorded), the office's and the
games' and the examples' sessions by both builds (mini-mk in a copy of
the tree, from clean for the libraries), `export.sh`, `write.sh`,
`compile_ix.sh` on the directories touched (136 of 136). `dune build`
of the whole tree stops in `languages/datalog/dune`, another
session's; everything else builds.
The two new tests are in `make test`'s list; `make test` itself was
not run.

Not done, not known:
- **Nobody has looked at mini-page's window**: its sessions are the
  platform without one. The keys' names and the wheel's direction
  under SDL are as the office's, not tried.
- **mini-9pi**: C2 above, seen on the Pi 1 only. A page's time on a Pi is not
  known: by the table, mini-ml's arm64 code is 4 to 6 times OCaml's
  here. And mini-page's view makes its shape anew at each frame, so
  the draw platform's "is this frame the last one?" compares the
  page's bytes (megabytes) where `==` would do: to see there.
- **Memory**: 133 MB for a page of the book by mini-ml, in steps (10,
  18, 67, 133: its heap's sizes), not looked into; a Pi1 has 512.
- **page's menu of the pages** is not there (a number and Enter); no
  text found or selected.
- **A picture larger than the window** is drawn again whole at each
  frame it moves (the software renderer's `Bitmap`, blended when
  scaled): not timed.
- `Image_file`, the office's `Part_image` and the playground's
  `Unit_png` and `Unit_jpeg` are the office's stage 7 still.
- `docs/loc.md` and `make loc`'s rows do not know the new folders
  (`loc.py`'s "software platform" row counts `core/`, `geometry/` and
  `images/` as it counted `software/`).
- E and F wait for `plan_playground_speed.md`'s A and for the
  browser.

To confirm (decided here, to go on): `Pageview` as the unit's name
(`Page` is the office's); mini-page's keys; the paper as bytes;
`Png` copied now; `parse_with`, `outline_at`, `glyph_at`,
`decode_with` as the names where an optional argument made two
functions; the records and pairs that arm's 7 parameters asked for;
`page` and `/lib/pdf` on the card.

Stage A (2026-10-09): **File > Export in mini-office writes
`name.pdf`.** `Pdf_write` (218 lines, 114 of .mli), `Shape_render_pdf`
(86 and 27), `Office_export` (44 and 11): 348 lines of .ml where 400
were guessed. `File_menu.export` is new; `Office_update.update` is
given the exporter by `Office.ml` (the view's shapes are what is
written, and the view comes after the update). In `games/mkgames`
the three units and `Zlib` are linked for `WITH=office` only.
Checked:
- `lib_graphics/pdf/tests`: 4 unit tests; `write.sh`: a page of every
  form read by poppler, 67 pixels of 120,000 far from
  `Shape_render_software`'s, the two pictures looked at; a picture
  turned, with its transparency, looked at.
- `apps/office/tests`: 2 unit tests (62 of 62 with the others);
  `export.sh`: a document of each kind and one of four pages, ten
  pages read by poppler and each near the screen's (a page of text:
  1.2% of its pixels far apart, the strokes being a pixel and a third
  wide; the same letters, seen side by side); `frames.sh`, the
  sixteen sessions as before.
- The menu's way: the program run without a window, File then Export
  clicked; by dune's build and by mini-ml's (arm64, built by mini-mk
  in a copy of the tree) `untitled.pdf` is the same 181,060 bytes,
  and the ones `Export_sample` writes.
Not done, not known:
- **The size**: a page of text is 181 KB (8,000 small paths), four
  pages 700 KB. Stage E is what makes it small.
- **The time**: the export of one page is about 1.6 s by mini-ml's
  code on arm64 (the run is 2.0 s, 0.3 by OCaml's); most of it is
  thought to be `Zlib.deflate`, not measured apart. Nothing on arm or
  mini-9pi, where the file goes to the directory the program was
  started in.
- **The paper**: a page is the document's own size, a unit a point:
  620 by 820 points, which is neither Letter nor A4.
- `export.sh` and `write.sh` are not in `make test` (they need
  poppler).

Before: 2026-10-09: this plan and `scripts/stats/pdf_survey.sh`. Run for it:
the survey; mini-chrome's `Dump.exe` (its own dune build) on its
seven test files and on `Windows-9.pdf`, pages 1, 20 and 60, page 20
looked at. Not done: anything copied, written or built here; no file
of the reader tried past mini-ml's first refusal; nothing on arm64,
arm or mini-9pi; the writer's and the viewer's lines are estimates.
