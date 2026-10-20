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
(`font1.bin`), tiny-kernel's a bitmap of its own (`font.tm`).

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

The second path is the one that costs. A letter of a page is about six
shapes. The platform transforms each, in floats, at every frame drawn,
and on mini-9pi sends each to the device, which fills it.

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
graphics card as the server. Letters are rasterized by FreeType
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
- **On Linux**, the software renderer draws a run by the strokes it
  is made of (the same rectangles as `Stroke_text.glyph` made), so the
  pictures do not change: nothing is kept, the machine is fast enough.
- **On mini-9pi**, the draw platform keeps a *font image* in the
  kernel for each look at a size in pixels, Plan 9's cache image, and
  puts each letter there the first time it is used. A letter drawn is
  then one copy in the kernel, the colour through the font image as a
  mask: Plan 9's 's', one message a letter.
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
- **Whole pixels.** A letter is copied to a whole pixel, half a pixel
  off at most from where the layout put it, as Plan 9's and X core's
  text are. The atlases' sub-pixel copies are what a finer grid would
  cost: four letters kept for one.

What ix leaves out, and the reason, so that it is a choice and not a
gap: hinting (strokes have no outline to hint), antialiasing on
mini-9pi (a pixel is in the letter or not, as Plan 9's subfonts),
kerning and shaping (Hershey's widths, a letter a glyph: Latin and its
marks), font selection and fallback (one font, its "?").

## 6. To measure

The same sessions before and after, with `stats=on`: about:home at
rest and with the mouse over its links, a page scrolled, mini-office's
page with a character typed and a sheet dragged. The plan's stages
say the order: the shape and the software renderer first, the golden
frames unchanged; then the draw platform's font images, mini-9pi's
recorded screens looked at, since letters on whole pixels will move.
