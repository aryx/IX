# Notes on fonts: what a letter is, who draws it, where it is kept

The author, 2026-10-20, mini-netscape's frames slow on mini-9pi and the
letters' cache agreed again: "maybe we could have a notes_font.md
document, like we have notes_keyboard.md where we discuss all those
issues related to font, and speed, and cache, and where to do it, and
how it's done in Linux and freetype and fontconfig and so on, so maybe
the current design of how it's done in ix does not look too different
than the other systems (including plan 9)".

What a letter is in ix, the paths from a string to pixels, what they
cost, and how other systems answer the same three questions: what a
font is, who turns a letter into pixels, and where the pixels are kept
so that the second "e" costs less than the first.

## 1. Three kinds of font in ix

| | a letter is | made for | where |
|---|---|---|---|
| bitmap | a picture, a bit a pixel, at one size | the windows' text: mini-rio, its menus, a terminal, mini-drscheme | `Font` and `Font_default` (Plan 9's default subfont, lucm/latin1.9), the kernel's `Memfont` |
| strokes | a pen's lines through points, any size | everything that draws its own pixels: a game's words, the word processor's and the browser's text, a PDF's font it does not carry | `Hershey` (Roman simplex, 1967), `Glyph_unicode` (the letters beyond ASCII: marks, quotes, dashes, built from Hershey's), `Stroke_text` (bold a wider pen, italic a slant) |
| outlines | closed curves, filled | a PDF file's own fonts | `Truetype`, `Cff`, `Type1`, `Outline` (lib_graphics/fonts) |

The headers of `Font.mli` and `Hershey.mli` tell each in full. The
small systems have their own: the kernels' consoles a bitmap
(`font1.bin`), tiny-kernel's a bitmap of its own (`font.tm`, made
of `tiny.font`: section 7).

A real system has the third kind for everything, and keeps the first
for terminals and boot screens. ix uses strokes where others use
outlines: no curve to fill, no hinting, no rasterizer to write. A
letter is drawn by drawing lines, which every platform can.

## 2. The path of a letter, today

    a game's words                 Playground.words colour "Score"
      -> Linux (software, SDL, ppm)   the renderer draws Hershey's strokes, a line each
      -> mini-9pi (draw platform)     upright and 11 to 16 pixels: Plan 9's default font,
                                      a message a letter (Font.string); else a polyline
                                      of the device's a stroke

    a page's text (office, browser)  Stroke_text.glyph: a letter's strokes,
                                     each a thin rectangle turned to its angle
      -> every platform               a rectangle each, as any other shape:
                                      no platform knows it was a letter

    a PDF file's text (mini-page,   Pdf_render: the file's own font (outlines),
    office's export read back)       each glyph filled once into a mask (its font,
                                     code, size, quarter pixel: Pdf_render's cache),
                                     laid into the page's picture with the rest
      -> every platform               one Bitmap, the whole page; on mini-9pi
                                      loaded into the kernel once, a frame one copy

The second path is the one that costs. A letter of a page is about six
shapes. The platform transforms each, in floats, at every frame drawn,
and on mini-9pi sends each to the device, which fills it. (Since
2026-10-20 the platforms keep a letter's mask instead: section 5.)

The third is drawn once a page, not each frame, and its letters cost
the page's first drawing only: a page of principia's Kernel book,
21 pages by mini-ml's code on Linux, 19.65 s with each glyph filled
each time, 6.42 with Pdf_render's cache (2026-10-22). The two caches,
the playground's and Pdf_render's, are the same idea (Cairo's, Skia's
quarters) in two places: the playground's masks are of its stroke
font, a `float array` each, laid into a Framebuffer or kept by the
kernel; Pdf_render's are of a PDF's outlines, `Bytes`, laid into the
page's canvas through the PDF's clip and opacity. What they could
share is a table and a key, not worth a module. Which way suits which
program: the shapes (mini-office, mini-netscape) for a text that
changes, a picture (mini-page) for a page that does not, and whose
text the reader draws with all PDF's means.

## 3. What it costs (measured)

- mini-office, a page (2026-10-09, plan_playground_speed.md): 7,941
  shapes for 40 lines of text. On mini-9pi under QEMU a changed frame
  was 255 ms of messages and 144 ms of the device.
- mini-netscape, about:home (2026-10-20): 185 ms of messages and 115
  ms of the device at each frame drawn. The cursor stood still for the
  whole of it, since the kernel does not move it while a frame is
  copied over its rows (`Swcursor.clock`, `Kdraw.busy`).

Two things about the design make it so, which no optimisation round
them removes (plan_playground_speed.md, "The redesign"): text is
nothing a platform knows, and the draw platform draws a frame whole
when anything changed. The first is this note's subject.

## 4. How other systems do it

The same three questions everywhere. What is a font (a file of
pictures, of strokes, of outlines)? Who turns a letter into pixels
(the program, a library, a server, the kernel)? Where are the pixels
kept (nowhere, the program's memory, the server's, the graphics
card's)?

**Plan 9 (libdraw and the draw device).** A font is a text file
listing ranges of characters and, for each, a subfont: pictures, a bit
a pixel, side by side (`Font.mli`'s figure). The kernel's draw device
knows nothing of letters. A program's libdraw keeps a *cache image* in
the device ('i': allocate it), loads into it each character the first
time it is drawn ('l': these columns of a subfont's image), and draws
a string as one message, 's', the characters' places in the cache.
The device then copies, the colour through the cache's columns as a
mask. Rasterized never (a subfont is already pixels), kept in the
kernel, chosen by the program. ix's `Font` is the simplest of it: one
subfont and a message a letter, no cache messages.

**X11, its core fonts (1987).** The server has the fonts (BDF, PCF:
bitmaps, later scaled outlines), the program names one
(`-adobe-helvetica-bold-r-normal--12-...`) and sends strings
(`XDrawString`). Rasterized by the server, kept by the server. Fast on
a network, since a string is its bytes, but the program cannot know
or change the letters: no antialiasing, no font of its own.

**X11, XRender with FreeType and fontconfig (2000 on: Keith Packard's
Render extension, Xft).** The other way round: the *program* reads the
font file (TrueType, OpenType) with FreeType, rasterizes each letter
at its size (hinted, antialiased: an alpha mask), uploads it once to a
*glyph set* in the server (`XRenderAddGlyphs`), and then draws text as
a list of glyph numbers and positions (`XRenderCompositeGlyphs`). The
server composites the masks it keeps. Rasterized by the program, kept
by the server. This is what the X desktops did until GL.
- *FreeType* (1996) is the rasterizer: a font file's outlines and
  hints to a letter's pixels at a size. It has a cache module, but the
  cache that counts is the server's or the card's.
- *fontconfig* (2002) answers which file: "sans, bold, 12" to
  `/usr/share/fonts/.../DejaVuSans-Bold.ttf`, and for a character the
  font lacks, which other font has it (fallback). ix has one font and
  needs neither: `Glyph_unicode`'s "?" is its fallback.
- *HarfBuzz* (2006 on) and *Pango* lay out: which glyphs a string is
  (ligatures, Arabic's joined forms, Indic reordering: shaping) and
  where each goes. ix's layout is Hershey's widths added up, a letter
  a glyph; nothing is shaped.

**Cairo, browsers, terminals, today.** The same as XRender, with the
graphics card as the server. (Cairo drawing in memory, its image
backend, keeps the same cache in the program: a *scaled font*, the
font at a size and a transform, holds each glyph's mask once
rasterized, and text is those masks composited at their places.) Letters are rasterized by FreeType
(or the system's: Core Text, DirectWrite) into a *glyph atlas*, one
large texture of the letters in use. A text run is then a rectangle
per letter, each sampling its place in the atlas: Skia's in Chrome,
WebRender's in Firefox, a terminal's (kitty, Alacritty). Positions
are not whole pixels. A letter is kept at a few sub-pixel offsets
(Skia: quarters), so that "illegal" is not laid out on a coarser grid
than the layout asked.

**Vector letters, before.** Hershey's letters were drawn for pen
plotters and vector displays (the Tektronix storage tubes, 1970s), a
letter a few moves of the beam. Nothing was kept: a letter was drawn
again each time, which is what ix's page text does now on a raster
screen, where it costs.

| | the font | rasterized by | kept by | a letter drawn is |
|---|---|---|---|---|
| Plan 9 | subfonts (pictures) | nobody: already pixels | the kernel (cache image) | a copy, one message a string |
| X11 core | server's bitmaps | the server | the server | a copy, the string sent |
| X11 Render, Xft | the program's files (FreeType) | the program | the server (glyph set) | a composite of a mask |
| Chrome, Firefox, terminals | the system's (fontconfig, Core Text...) | FreeType or the system | the card (atlas) | a textured rectangle |
| ix's page text, now | Hershey (strokes) | the platform, each frame | nothing | its strokes filled, every time |

## 5. ix's design, among them

The redesign agreed on 2026-10-09 and taken up on 2026-10-20
(plan_playground_speed.md, "The redesign", A) puts ix in the table's
common line.

- **Text a shape.** A run of letters in one look (size, bold, italic),
  a colour, each letter's place from the layout, is one shape of the
  playground's (`Letters`). The platform knows it is text, as a
  string message tells the device, and as `XRenderCompositeGlyphs`
  tells the server.
- **On Linux**, the software renderer keeps a *mask* for each letter
  at a size, a look and a scale: its strokes (`Letter_strokes`, the
  rectangles `Stroke_text.glyph` made) drawn once, white over black,
  how much of each pixel they cover; a letter drawn is then the colour
  put through it, at the nearest quarter of a pixel (a mask for each
  quarter: Skia's way, where whole pixels put the office's PDF export
  too far from its screen). Cairo's image backend's way. Done 2026-10-20 (the author: "scrolling on linux still feels
  slow though on HN for instance, but also wikipedia"; the plan of
  2026-10-09 had kept the strokes there, "the machine is fast
  enough": it was not). Measured, Hacker News, a frame scrolled:

  | | strokes | masks |
  |---|---|---|
  | OCaml's code, at 100% | 12 ms | 1.7 ms |
  | OCaml's code, at 250% | 29 ms | 4.3 ms |
  | mini-ml's code, at 100% | 107 ms | 9 ms |

  (With quarters, 2.1 ms and 13 ms for the first and third.) The
  letters' shapes are the same, their edges smoothed otherwise: the
  recorded frames were recorded again, and the playground's golden
  pictures are compared with a tolerance (games/tests/frames.sh).
- **On mini-9pi**, the draw platform keeps an image in the kernel for
  each letter at a size, a look and a scale, and puts the letter there
  the first time it is used. A letter drawn is then one copy in the
  kernel, the colour through that image as a mask: Plan 9's 's', one
  message a letter. Done 2026-10-20 the second way below (the author:
  "I would experiment first with reusing the software renderer also
  for mini-9pi and send the letter via bitmap once to the kernel"):
  Linux's mask, a pixel the letter's where its strokes cover a third
  of it, an image of a bit a pixel (k1), whose copy is the device's
  fast case for a character. The flag `letters=strokes` draws the
  strokes again. Measured under QEMU, about:home with the mouse over
  its links (`stats=on`), a frame shown:

  | | strokes | letters kept |
  |---|---|---|
  | the messages (the program) | 220 ms | 20 ms |
  | the device (the kernel) | 113 ms | 90 ms |

  What is left is the device's, not yet looked into: at each change
  the frame is made white and copied whole to the window, which the
  letters' copies may not be the most of (plan_playground_speed.md's
  other stages: a frame drawn only where it changed).

  Smoothed 2026-10-21 (the author: "mini-netscape fonts are not super
  readable under mini-9pi"; "let's do c, with the memdraw fast path
  too"): the mask given is Linux's whole, a byte a pixel (k8), how
  much of it the strokes cover, so a letter's edges are as on Linux.
  The device had no fast case for such a mask, and its general loop
  is about 1,400 instructions a pixel: `Memdraw` has one now
  (`fast_grey`), the general loop's arithmetic with its terms known
  (mul m s + mul (255 - m) d), the blend of a coverage over a pixel
  kept for the next letter of the colour, since a letter's edges are
  over the page's background (`tests/memdraw/run.sh` compares it with
  the general loop: the same bytes). The flag `letters=bits` is the
  bit a pixel of before. Measured under QEMU, the same session (the
  mouse on and off a link of about:home, 40 frames, two runs each):

  | the device, a frame | run 1 | run 2 |
  |---|---|---|
  | a bit a pixel (k1) | 78 ms | 75 ms |
  | a byte a pixel (k8) | 82 ms | 82 ms |

  (Without the blends kept, 22 to 30 ms more a frame; QEMU's runs
  vary by 10 ms or more when two run at once.)
- **Who rasterizes, two ways** (the author: "An alternative would be
  to do this caching font work user-side and not send draw commands
  (strokes) but instead a bitmap of the 'rendered' image user side";
  "maybe we can do both"):
  - *the device draws the letter's strokes into the font image* with
    its own lines: Plan 9's and X core's way, no pixel crossing from
    the program;
  - *the program renders the letter* with the software renderer, the
    very pixels Linux shows, and loads them into the font image once:
    XRender's way, FreeType's place taken by the software renderer.
  Both end in the same font image and the same copies. Which is
  faster to fill, and whether a letter looks better either way, is to
  be measured; a switch keeps both while it is.
- **Whole pixels on mini-9pi.** A letter is copied to a whole pixel,
  half a pixel off at most from where the layout put it, as Plan 9's
  and X core's text are. Linux's masks keep quarters (16 a letter);
  the device's font image could too, at the same cost.

What ix leaves out, and the reason, so that it is a choice and not a
gap: hinting (strokes have no outline to hint),
kerning and shaping (Hershey's widths, a letter a glyph: Latin and its
marks), font selection and fallback (one font, its "?").

## 6. To measure

The same sessions before and after, with `stats=on`: about:home at
rest and with the mouse over its links, a page scrolled, mini-office's
page with a character typed and a sheet dragged. The plan's stages
say the order: the shape and the software renderer first, the golden
frames unchanged; then the draw platform's font images, mini-9pi's
recorded screens looked at, since letters on whole pixels will move.

## 7. t-IX's font: a bitmap, four faces

The author, 2026-10-28: "the font displayed in tiny-emacs,
tiny-office, and tiny-www is not great and very pixelized; on both
Linux and under the tiny-machine. Anything we can improve?"

**One path for both.** On tiny-machine, tiny-kernel draws a program's
text with `TinyKernelGraphics`; on the host, the tiny programs in an
SDL window (`tiny/sdl/TinyCalls.ml`) call the same module on an array.
So a font changed there changes both. A face is made a mask, a byte a
pixel, the characters side by side, and a character is a draw of the
ink through it (draw.tm's `glyphs` for a whole text of the regular
face).

**Why it looked pixelized.** Three things, the first two the font's:

- one face, 1 bit a pixel: `font1.bin`, xv6's Raspberry Pi ports'
  8 by 16, 128 characters;
- the other styles made from it when first asked for: bold each
  stroke a pixel wider (smeared), large each pixel 2 by 2 (blocks:
  tiny-office's headings, tiny-www's titles), italic the rows slanted;
- the screen, 640 by 480, shown by `TinyMachineSDL` at the largest
  whole number of times that fits (2 or 3 on today's screens), each
  pixel a block.

**What could be done**, from the cheapest:

1. Real faces in place of the made ones: a bold and a 16 by 32 drawn
   by hand, the same cells, so no program and no message changes.
   Terminus Font has exactly those sizes (and an 8 by 16 regular,
   thinner and more even than font1.bin), under the SIL OFL. The
   chosen one.
2. Grey edges: a mask of levels, 0 to 255, TinyKernelGraphics.mli's
   exercise. But a pixel is an index into Plan 9's table of 256
   colours, so each mix of ink and background is a colour looked up,
   and draw.tm's `glyphs`, a word of 4 pixels at a time, would mix a
   pixel at a time: smoother, slower on tiny-machine, with fonts made
   from outlines at the build.
3. A larger screen (1280 by 960, 16 by 32 the regular face): the one
   cure for the blocks, but 640 by 480 is in tiny-machine's memory map
   (the screen at 0xf00000, 300 KB; four times that passes 16 MB), in
   the PPM frames the window reads, in what the CPU fills, and in every
   program's layout. Not for fonts alone.
4. SDL's linear filtering when scaled: one line, the host only; blur
   for blocks.

**What was done (1).** `tiny/TinyKernel/fonts/`: Terminus Font's four
console fonts copied (regular and bold, 8 by 16 and 16 by 32), its
licence, and `tiny.font`, their first 128 characters in font1.bin's
format, the faces one after the other (its README.md: the format, the
origin, the licence; `mkfont.sh` makes it). The kernel's
`font_mask` is given the font's size: with 2,048 bytes (font1.bin)
the bold and the large are made as before; with more, they are the
font's own. Italic stays a slant of the upright face, real or made.

font1.bin is kept as the simpler one to read, a face and what is
made of it: `make FONT=../../kernels/lib_machine/font1.bin` in
tiny/TinyKernel, `TINY_FONT=kernels/lib_machine/font1.bin` on the
host. Checked: tiny-kernel's 26 recorded sessions with font1.bin, the
same screens as before (the derivation unchanged); with tiny.font,
the same text, every screen another (recorded again); the host tests
of TinyKernelGraphics, TinyLibGUI, TinyAppTetris and TinyLibPlayground
still with font1.bin, unchanged.


**Then Ubuntu Mono, from its outlines.** The author, the same day:
"The text looks less pixelated, especially biggest text in www and
office, but I still don't like that much the font. Is it possible to
use the font used in this terminal or in the emacs I'm currently
running on this machine?" The terminal's is Ubuntu Sans Mono 13
(GNOME's monospace), the Emacs's Ubuntu Mono Bold at 43 pixels; both
outline fonts. `fonts/preview.py` drew them in t-IX's cells: Ubuntu
Sans Mono, wider, must be 13 pixels tall to be 8 wide, small and thin
in a cell of 16; Ubuntu Mono, narrow, is 8 wide at 16, the cell, and
looks right even 1 bit a pixel. Neither can look as the Emacs does:
there 43 pixels with grey edges on a dense screen, here 16 pixels on
640 by 480 magnified.

So tiny.font is Ubuntu Mono's (fonts/README.md), drawn once by
`fonts/Mkfont.ml` with ix's own TrueType reader and filler, the same
that draw a PDF's fonts (section 2's third path): no FreeType. What
FreeType does and ix does not is hinting, the font's programs that
move its points onto the pixels: unhinted, a stem a pixel and a little
wide is one pixel or two by where it falls. Two cheap stand-ins:

- one shift of a whole face, by eighths of a pixel, chosen for the
  least sum of c (1 - c) over its pixels (c each one's part covered):
  in a monospaced font most stems are at the same places of their
  cells, so the shift that puts the most pixels all in or all out puts
  most stems on whole pixels;
- a pixel set where 0.6 of it is covered, not a half: at a half, the
  stems that straddled two pixels were two wide (E, F, L, T heavy); at
  0.7 strokes broke; at 0.6 nearly all stems are one pixel, close to
  FreeType's hinted letters.

A dropout control (TrueType's: a thin stroke's best pixel set even
under the threshold) was tried for the m, whose middle stem looked
lost: it is short by design, FreeType draws it so too, and the control
changed six bytes, so it went. The Ubuntu font package has only a
variable font (one file, its weights by variation tables), which ix's
reader does not read: the static regular and bold were copied from
Google Fonts. Terminus Font stays beside it, `terminus.font`
(`make FONT=fonts/terminus.font`), and font1.bin.

The author on tiny-emacs: "the font looks worse with tiny-emacs (at
least on this host), the top of e is missing. Bad." The e's top was a
third of one row and half of the next, set in neither. What FreeType's
autohinter does, done in Mkfont: the heights every letter shares (the
baseline, the x's top, the H's) made whole rows, the heights between
stretched; then each character's own shift, an eighth of a pixel at a
time, across up to 3/8 from the face's, and down for what is no letter
(the +'s bar, between two rows), what it loses outside its cell counted
against it (else the m moved its stem out); and a bar a pixel thick on
two rows kept on its upper one (the A's crossbar). tiny-emacs in bold,
as the author's Emacs, was tried and taken back ("it does not read as
good"); bold and underlined text kept the fast path, the plain text's
(draw.tm's glyphs: 8 by 16 cells either way), where it was a draw a
character.

**Then grey edges (2).** The author: "What's next to get a font that
looks more like what I currently see in my terminal and emacs on this
host?", then "let's make the code configurable so one can easily switch
to the bitmap font vs grey fonts". `grey.font`: Mkfont -grey, the
same letters (tiny.font's pixels, its fitting kept: the stems on whole
pixels), each pixel one of four levels, two bits, the pixels tiny.font
leaves out grey by the part covered, a third or two; 40,960 bytes, the
same four faces. The kernel knows it by its size: a mask byte 0, 85,
170 or 255. A colour through such a mask is mixed by a table made for
the colour when first drawn with (1 KB: for each level and each
colour under it, the colour of Plan 9's table nearest to the mix),
draw.tm's mix_table: the nearest among the 16 a mix can be near, one
for each (den, v) of the table's formula, the same as a search of the
256 but for ties. In tiny-ml's ML it was 3.5 million instructions a
colour, half a second of the machine's: tiny-windows' first menu drew
so late that the recorded click on it was taken for its item exit;
in assembly some 230,000. Texts by draw.tm's glyphs_mixed (a byte at a
time where a row is not blank), the others by row_mix. A whole session
costs 0.3% (www) to 5% (emacs) more instructions than with tiny.font.

grey.font is the default (tiny-kernel's Makefile, tiny/sdl's dune);
the bitmap one switch away: `make FONT=fonts/tiny.font`,
`TINY_FONT=tiny/TinyKernel/fonts/tiny.font` on the host. A source of
more than a colour through a font of levels, and a program's own mask,
are still set or not (a level not 0 is set).

The author then: "I can see some pixels on the e above isolated a
bit". The e's, o's, a's tops go past the x's height by a fifth of a
pixel (a round letter's overshoot, so that it looks as tall as an x),
a fifth of the row above covered: in grey.font a lone light pixel over
each, and over the digits, the C, the O. Mkfont now puts what is within
the overshoot of the baseline, the x's height and the H's on them (the
o's and the O's, measured), as FreeType's autohinter's blue zones do at
small sizes; what is above the H's (brackets, accents) moved down by
the same fifth. tiny.font changed little (its 0.6 threshold had left
those slivers out).

Left: the characters beyond ASCII (both fonts have them, the kernel's
font 128); a larger screen (3), the one way to the Emacs's 43 pixels.

**Then 1024 by 768.** The author: "mini-pi -g -q mini-9pi shows a
console with still a better looking font", then "maybe let's use the
higher resolution with the current font". mini-9pi's screen is 1024 by
768, its font (Plan 9's, Lucida Sans Typewriter's 9 by 15) magnified
twice in the host's window; t-IX's 640 by 480 three times, each pixel
a block of 9. So tiny-machine's screen is now 1024 by 768 too, the font
unchanged: the window two times on the same display, the letters a
third smaller, 128 columns by 48 rows of text where there were 80 by
30. It still fits (3)'s megabyte: 768 KB at 0xf00000, up to 0xfc0000,
the images after it 252 KB to the last page (old: 720 KB). The places
that knew 640 by 480: TinyMachineDevices (the machine), TinyKernelDevices
(the kernel), tiny/sdl's TinyCalls (the host's stand-in), TinyLibDraw's
screen_w and screen_h (tiny-windows' whole screen, TinyLibGUI's window
when no tiny-windows answers), paint.c, and the tests' pictures. The
windows are swept by the mouse, so the recorded sessions click the
same places: every screen larger, the same windows in it.

The author then: "it looks better!", and for the cheap fix of thin
strokes, darker greys: Mkfont's level raises the part covered to 0.6
before rounding it to thirds (a gamma), so that more of the edge is a
level and more of it two thirds (a third from 8% covered, old 17%; two
thirds from 37%, old 50%). Only grey.font changes; 0.75 was barely
darker, 0.5 heavy.

Then Plan 9's own font, tried by TINY_FONT, and the author: "let's
make the plan9 font the default one for now, and keep the other fonts
as well". plan9.font is Mkfont -plan9's, from the subfont copied beside
it (fonts/README.md: lucm.latin1.9, B&H's Lucida, mini-9pi's console's
and Memdata.ml's): 9 by 15 put in 8 by 16, the bold and the large made
of it as the kernel makes font1.bin's (so smeared and in blocks again;
Plan 9 has its own bold and larger sizes of Lucida, a next step if
those look poor), but by Mkfont: one face alone, the kernel made them
in the middle of the recorded office session, and its click at (300,
300) was missed, the sheet put at (100, 100). grey.font, tiny.font and terminus.font stay, by
FONT= and TINY_FONT=.
