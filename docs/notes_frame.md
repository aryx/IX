# Notes on a frame: from a program's picture to the screen

The author, 2026-10-22, after mini-doom and mini-quake went from 5 to
13 frames a second under QEMU: "can you better explain what we were
doing before, and what do we now, so I better [understand] this opti;
maybe with concrete example and ASCII diagrams", then "maybe we should
store the different design choices and alternatives in notes_frame.md
or something, with those ASCII diagrams and discussions", and "there
are currently also many ways, just under mini-9pi to display things,
and different opti; you can use the playground, or directly
lib_graphics, you can use the draw device shapes, or instead load
images, you can then use the Redraw opti, the letter font cache, etc.
Would be good to write down all those possible paths, and take
concrete example like what cameltry is doing (shapes? redraw working?
bitmaps loaded?), doom, quake, office, page, etc."

Part I is the map: the layers between a program and mini-9pi's screen,
the paths a program can take through them, the optimizations on each,
and which path each program of the card takes. Part II is one path
told in full, a game's own pixels (the Bitmap's way, then the Pixels'),
with the choices behind it, the roads not taken, and how other systems
do it. The plans: [`plan_playground_framebuffer.md`](plans/plan_playground_framebuffer.md)
(F2: the Pixels path), [`plan_playground_speed.md`](plans/plan_playground_speed.md)
(the measures of the playground's other paths); the letters have their
own note, [`notes_font.md`](notes_font.md).

# Part I: the map

## 1. The layers, and whose code runs where

```
  a program (mini-ml's code, in its process)
  |
  |  the playground (lib_playground)        |  lib_terminal           |  nothing more
  |  the view: a list of shapes             |  a screen of cells      |  (rio, mini-stats,
  |    draw platform | software platform    |  (Cells: a Tui's,       |   mini-colors,
  |                  |                      |   Curses' grid)         |   squeak's host)
  v                  v                      v                         v
  lib_graphics: Display, Draw, Font -- the draw protocol's messages, batched
  |   'b' allocate an image   'y' load pixels into one   'd' draw one on another
  |   'P' a filled polygon  'E' a filled ellipse  'L' a line  's' a string of a font
  |   'v' flush
  |
  |  write(/dev/draw/n/data)   -- a system call; its bytes copied in
  v
  the kernel (ocaml-light's code: kernel.mk's COMPILER=light)
  |   Devdraw: the messages read, the images kept by number
  |   Kdraw, over lib_memdraw and lib_memlayer (principia's memdraw and
  |   memlayer in OCaml; PIXEL=c their C): the drawing itself, and
  |   rio's windows as layers that cover each other
  |   Swcursor: the mouse's arrow drawn on the screen, avoided by draws
  v
  the screen image (r5g6b5 under QEMU), its pixels kept in memory,
  each change written to the framebuffer (Machine.Phys.write_sub)
```

Two compilers in one frame: what the program computes is mini-ml's
code, 4 to 5 times slower than OCaml's (plan_doom.md); what the device
computes is ocaml-light's, in the kernel. And a cost between them: a
system call per batch of messages, and a copy of what they carry.

In a window of mini-rio's the same files are the window's: rio gives
the program the name of its window's image, and the program draws in
it through the same device, as on Plan 9. Rio draws only its borders
and menus; it is not on a program's path to the screen. A window is a
layer (memlayer): a draw on a window seen whole goes to the screen's
pixels directly, a covered part to the layer's own memory; the cost is
the clipping by the windows above it. On the author's Pi 2, mini-doom
and mini-quake in a window: "similar number; maybe slightly lower, but
I'm not even sure" (2026-10-22).

## 2. The paths

| path | what the program gives | what crosses to the kernel at each frame | who makes the pixels | programs |
|---|---|---|---|---|
| A. the draw platform, shapes | a list of shapes | a message a shape (a fill, a polygon, an ellipse, a line, a string), then a copy to the window | the kernel | the playground's games and apps |
| B. the draw platform, a still picture | a Bitmap that stays the same | after its first frame, one 'd' (a copy of an image the kernel has) | the program once, then the kernel's copy | mini-page, a photo in mini-office |
| C. the draw platform, a moving picture | a Bitmap new at each frame | 'b', 'y' with 4 bytes a pixel, 'd', a free | the program, through a transform, then the kernel converting | a video (none on the card) |
| D. the draw platform, a program's pixels | Pixels: palette indices | 'y' with the screen's 2 bytes a pixel into a kept image, 'd' | the program, a table look-up a pixel | mini-doom, mini-quake |
| E. the software platform | a list of shapes | 'y' of the parts that changed, 4 bytes a pixel, 'd' | the program (Shape_render_software) | the card's `*-soft` programs |
| F. cells | a screen of characters (Tui) | for the cells that changed: a fill and an 's' of the default font | the kernel (the font is its image) | mini-emacs, turbopascal |
| G. lib_graphics directly | whatever it calls | its own messages | either | mini-rio, mini-stats, mini-colors, squeak |

A, D and E are chosen when the program is built (the draw platform is
`games/x`, the software one `games/x-soft`); inside the draw platform,
B, C and D are chosen by the shape the program gives.

## 3. The optimizations, and where each is

| | where | what it saves | who gains | off by |
|---|---|---|---|---|
| messages batched | lib_graphics (Display) | a system call a message: they are kept and written when they pile up, and at the flush | every path | |
| a frame equal to the last not drawn | draw platform (`show`: `==` before `=`) | the whole frame when nothing changed; a group kept from a frame to the next (mini-office's page of 8,000 letters) compared by its pointer | A, B, D | |
| Redraw: what changed only | lib_playground (Redraw), draw and software platforms | the shapes outside the boxes that changed are not sent, nor their pixels copied | A, B, E: little when everything moves | `redraw=all`, `redraw=top` |
| the colours kept | draw platform (`colors`, `inks`; `fast`: their common cases' short way) | a colour is an image of one pixel, repeated; made once, its number reused | A | |
| an upright rectangle a copy | draw platform (`rectangle`) | an upright rectangle is one 'd' of a colour, not a polygon; a thin turned one a line | A | |
| Plan 9's letters | draw platform (`font_of`) | a word upright at 11 to 16 pixels is one 's' message of the kernel's bitmap font, not its Hershey strokes as lines | A, F | `font=hershey` |
| the letters kept | draw platform (`letter_image`) | a Letters' letter (mini-office's, mini-netscape's text) is a mask made once (k8, smoothed), then a 'd' through it | A | `letters=strokes`, `letters=bits` |
| a word's points kept | draw platform (`written`) | a word at the place it was (a score) is not laid out again | A | |
| the pictures kept | draw platform (`picture`: the last four) | a Bitmap shown again is a 'd' of the kernel's image | B | |
| Pixels | draw platform (`pixels_image`) | a program's own pixels made once, in the screen's format, into an image kept | D | (a Bitmap instead) |
| the cells' difference | lib_terminal (Cells.show) | only the cells that changed painted, as Curses for a terminal | F | |
| a frame's rows kept | mini-emacs (Frame) | its rows made again only when the text or the first line changed | F | `-nocache` |
| the device's fast cases | the kernel (memdraw) | a polygon's runs written directly, a fill's rows by adding, a colour read once (plan_playground_speed.md) | A, F, G | (`PIXEL=c`: principia's C instead) |

## 4. The programs, one by one

**Tetris** (A). Squares, upright: each one 'd' of its colour; the score
in words. Redraw works: the piece falling is four squares' boxes of
the 230,000 pixels, the rest of the board not sent. The kind of
program path A was made for.

**TinyCameltry** (A). The maze is a group of tiles (rectangles) and
balls (circles), the whole group turned as the player tilts it. Turned,
a rectangle is no longer upright: each tile is a filled polygon ('P'),
each ball a filled ellipse ('E'). While it turns every shape moves, so Redraw's
box is the whole picture and nothing is saved there; standing still,
only the ball's boxes. No Bitmap is loaded. Measured (2026-10-22,
turning): 25 to 30 frames a second; its view under 1 ms, the messages
9 to 10 ms, the kernel drawing them 16 to 23 ms. On the author's Pi 2
the same evening: "around 44, 50 fps depending on the area" (50 before
too, bugs/ix.md's force_turbo: Pixels changed nothing here, as it
should not). Its cost is the device's polygons, and mini-ml's code
making the messages.

**TinyWolfenstein** (A). A column of the view a ray, drawn as an upright
rectangle: hundreds of 'd' a frame, each of a colour (no textures).
Everything changes as the player turns.

**mini-doom, mini-quake** (D). Their renderers make 320 by 200 palette
indices; the platform makes them the screen's two bytes a pixel and
loads them into an image it keeps: Part II. 13 to 14 and 11 to 15
frames a second under QEMU; mini-doom on the author's Pi 2 "around 15
fps on big area, and more like 24 on smaller area" (8 before),
mini-quake "around 15 fps too, depend on the zone". The
renderer, in mini-ml's code, is now the larger part of a frame, and
the one that varies with the view.

**mini-page** (B). A PDF page is a Bitmap, made at the size it is shown
(the author: "also it shows low fps"; commit 48ff2664), kept by the
kernel: a frame that does not move the page is nothing (the frame equal
to the last), one that moves it is one 'd'. 60 frames a second.

**mini-office** (A, B). lib_gui over the playground. The page's text is
Letters, each letter a mask kept in the kernel; the page is one group
of 8,000 letters kept from a frame to the next while the document is
the same, so the frame-equal test is one comparison of pointers. A
picture in a document is a Bitmap (B).

**mini-netscape** (A, B). The page's text in Letters (the letters kept),
its pictures Bitmaps (B), its rules and boxes rectangles. Redraw makes a
link lit under the mouse a few letters' boxes, where it was the page's
450.

**mini-drscheme** (A). Its editor's text in words at the font's size:
Plan 9's letters, one 's' a word; its pictures (the teachpack's
circles, rectangles, polygons) shapes.

**mini-emacs, turbopascal** (F). Not the playground: lib_terminal's
cells, Plan 9's font. A key changes a few cells: a fill and an 's'
each. mini-emacs also keeps its frame's rows while the text is the
same.

**squeak** (G). Its Display is a picture in its own memory (Smalltalk's
BitBlt draws there), loaded into an image of the device, 4 bytes a
pixel ("x8b8g8r8"), by bands of rows, then a 'd': path C's cost, by
lib_graphics directly.

**mini-rio** (G). Its borders, its menus, the screen's background: fills
and strings. Its windows' programs draw in their images themselves.

**mini-stats, mini-colors** (G). Fills and strings of the font, a few a
frame.

**The `*-soft` programs** (E). The same games, their pixels made by the
program (Shape_render_software) where they changed, loaded 4 bytes a
pixel: a whole frame of 480 by 480 is a second under QEMU.

## 5. Choosing a path

- Shapes that stay where they are, or few that move (a board, a page,
  a menu): A, and Redraw does the rest.
- Many shapes that all move (a turning maze, a scrolling world): A,
  but the cost is the device's drawing and the messages, a shape each.
- A picture that stays (a page, a photo): a Bitmap, B: made once.
- A program that makes every pixel itself, at every frame (a renderer):
  Pixels, D, if it has a palette; a moving Bitmap, C, if it has RGBA
  (slow: Part II, the "RGBA only" road).
- Text: Letters (kept masks) for a document's; words at the font's
  size for an editor's; cells for a terminal's program.

# Part II: a program's own pixels

## 6. Before: a game's frame as a Bitmap

mini-doom renders 320 by 200 **palette indices**, a byte a pixel: not
colours. Index 112 is "the palette's 112th colour", in Freedoom's
palette a green, r 119, g 255, b 111. The screen under QEMU wants two
bytes a pixel, r5g6b5: that green is `0x77ED`, the bytes `ED 77`.
Something must turn each of the 64,000 indices into those two bytes.
Until 2026-10-22:

```
   game (mini-doom, mini-ml)              platform (draw, mini-ml)                  kernel
   ------------------------               ------------------------                  ------

  Render.screen          to_rgba          Bitmap shape: 320x200 RGBA
  64,000 B indices  ------------> 256,000 B -----------------+
  [112][112][96]     per pixel:   [77 FF 6F FF]...           |
                     the palette,                            v
                     4 bytes      1. the opacity scan: is every
                     (1st pass)      alpha byte 255?          (2nd pass)
                                  2. a new Framebuffer 320x200,
                                     x8r8g8b8, 256,000 B
                                  3. Shape_render_software.draw_pixels:
                                     for each pixel the transform
                                     to its source pixel, 4 bytes  (3rd pass)
                                  4. Display.alloc: a NEW image  -------->  256 KB allocated
                                  5. Display.load: 256,000 B in a message ->  copied into it
                                  6. Draw.draw: image -> window  -------->  32 -> 16 bits,
                                                                             each pixel (4th)
                                  7. the oldest of 4 kept freed  -------->  freed
```

One pixel's way:

```
   112  --to_rgba-->  77 FF 6F FF  --draw_pixels-->  6F FF 77 FF  --device-->  ED 77
  index               RGBA (game)                   x8r8g8b8 (platform)        r5g6b5 (screen)
```

Three passes over the picture in mini-ml's code, 768 KB written by the
program, a megabyte allocated and freed by the kernel each second or
so, and a conversion in the device. Under QEMU, the up arrow held
(`kernels/9pi/tests/perf/frames.sh`):

```
  a frame: 150 to 200 ms (5 to 6 a second)
    the view  58-99 ms   (the renderer, and the game's to_rgba)
    the show  76-92 ms   (steps 1 to 7; the device itself: 3 ms of them)
```

The kernel was not the cost: the program was, moving the same picture
from one format to another three times.

### Why the Bitmap path is what it is

It was made for path B of section 2: **a picture that
stays**. A page of mini-page, a photo: any size, turned by quarters,
scaled smoothly, so a general transform (`draw_pixels`); made once at
the size it is shown, given to the device once, and kept (the four
last pictures, found by the value itself). A frame of mini-page is
then a copy in the kernel; it reaches 60 frames a second. For a
picture that stays, every step above is paid once.

A game's picture is the opposite: new at each frame, never turned,
shown at a whole multiple of its size. It paid the general path at
every frame, and its cache only freed what it had just allocated.

## 7. Now: Pixels, made once in the screen's format

`Playground.Pixels` is a shape for the fourth kind: the indices and
their palette, as the game has them. The platform makes of them what
its device wants, once:

```
   game                                   platform (draw)                          kernel
   ----                                   ---------------                          ------

  Render.screen        snapshot           Pixels shape: the indices, the palette
  64,000 B indices  ------------> 64,000 B ------------------+
  [112][112][96]     Bytes.blit           (no conversion)    |
                     (one memcpy, C)                         v
                                  a. a table of the 256 colours in the
                                     screen's format:  table[112] = ED 77
                                  b. one pass: each index its 2 bytes, into
                                     a kept buffer of 128,000 B   (the only pass)
                                  c. Display.load into the SAME image  ----->  128 KB copied in
                                     (allocated once, of the screen's            (no alloc, no free)
                                     format)
                                  d. Draw.draw: image -> window  ----------->  r5g6b5 to r5g6b5:
                                                                                rows copied
```

One pixel's way:

```
   112  --table[112]-->  ED 77
  index                 r5g6b5: the screen's already, the device copies it
```

"The same image" is the device's image, the object: allocated at the
first frame, kept after. **The bytes are still sent at every frame**
(the author, of the diagram above: "for each frame, mini-doom needs to
load the image bytes in the kernel no?", "so that's a draw message to
the device, and some copies there too?"). A frame is two messages, a
load and a draw, and the 128 KB are copied five times on their way
(`Display.load_sub`, `Devdraw`'s write and its `'y'`):

```
  program                                            kernel (devdraw)
  -------                                            ----------------
  the indices, 64 KB
     | b. the table pass (mini-ml's code: the one pass a pixel)
     v
  the buffer, 128 KB (kept)
     | load_sub: Bytes.blit into the message
     v
  'y' id rect + 128 KB  ------- write() ------->  1. the system call: into a
                                                     kernel string
                                                  2. 'y': String.sub of its pixels
                                                  3. Kdraw.memload: into the
                                                     image's memory (the kept image)
  'd': the image to the window  ------------->    4. memdraw: its rows to the
                                                     window's back image
  the show (Plan9_loop)  -------------------->    5. the back image to the screen
```

What keeping the image saved is the rest: an allocation message and a
free one each frame, the kernel's 256 KB allocated and cleared, and
every copy twice as large, with a conversion in the draw. The copies
left are block copies (C's, the kernel's), not a pass of mini-ml's
code with work at each pixel: cheap, not free, and most of what is
left of the show. `/dev/framebuffer` (section 8) would make the five
one; inside this path, Devdraw's String.sub could be an offset, and
load_sub's blit two writes if the device took a message in two.

| a frame, under QEMU | before | now |
|---|---|---|
| passes over the picture in mini-ml's code | 3 | 1 |
| bytes made by the program | 3 x 256 KB | 128 KB |
| the device's image | allocated and freed each frame | one, kept, loaded again |
| conversion in the device | 32 to 16 bits, each pixel | none |
| the view | 58-99 ms | 37-46 ms |
| the show | 76-92 ms | 17-22 ms |
| frames a second | 4.7 to 6.7 | **13 to 14** |

mini-quake the same way: 5.3 to 5.9 a second, now 11 to 15.

### The contract that makes the shortcut safe

The platform takes the short way only when:

- the shape is upright (no turn), and its box on the screen is a
  whole multiple k of the picture's size (each pixel k by k: a table
  look-up written k times, rows copied k - 1 times);
- the screen's format is one the table knows (r5g6b5 or x8r8g8b8);
- nothing is transparent (a palette has no opacity).

Otherwise the Pixels are made RGBA and shown as a Bitmap: slower, never
wrong. On the other platforms (ppm, SDL, software, the PDF writer) they
are made RGBA at the same whole multiple, so the pictures are the same,
byte for byte, as the game's own RGBA was (the frames' tests did not
change).

Two rules the program keeps, as with a Bitmap: a **new value** at each
frame (the platform compares a frame's shapes with the last's,
Redraw: the same bytes changed in place would look unchanged), so
mini-doom and mini-quake copy their picture into one of two buffers in
turn; and the palette given with the picture, so a change of palette
(mini-quake's gamma, Doom's red of pain) is the table's 256 entries,
not the picture's 64,000.

## 8. The choices, and the roads not taken

**RGBA only, converted by the platform** (no new shape). The game
keeps giving a Bitmap; the platform recognises the case (upright, a
whole multiple, new each frame) and converts RGBA to the screen's
format in one pass. One pass less than before, one more than now (the
game's to_rgba stays, 30% of mini-doom's frame on the Pi 2 by
mini-prof), and four bytes read a pixel instead of one. Kept as the
next step for the programs whose pictures are RGBA by nature (a video,
a browser's images).

**The game writes the screen's format itself.** One pass fewer still
(no table in the platform): the game's renderer writes `ED 77` where
it wrote 112. But the game then knows the device's format (16 bits
under QEMU, maybe 32 on a board), its renderer's inner loops write two
or four bytes where they wrote one, and its colormaps (the light's 64
rows in Quake, 34 in Doom) become tables of the device's words. The
platform is where the format is known; a table pass is cheap.

**Plan 9's 8-bit images** (`m8`, CMAP8). The draw device has images of
a byte a pixel, and would convert them while drawing. But their
palette is Plan 9's own (rgbv: a fixed cube of colours), not a game's:
Doom's indices are not rgbv's. The device would need an image with a
palette of its own, which Plan 9's draw never had.

**The device scales** (9front's `affinewarp`). For `scale=2`, the
kernel could double the picture while drawing it, the program loading
a quarter of the bytes. Not needed at a whole multiple (the table
pass writes each pixel k times cheaply); stage F5 of the plan, if the
copy ever matters.

**`/dev/framebuffer`** (the plan's F1). The program writes the screen's
memory directly: no image, no load, no draw, one copy by the write's
system call. It removes steps c and d (17 to 22 ms of the show, some of
which is the table pass, which stays). The price: the bare screen
only, no window of rio's. Now a smaller gain than when proposed: the
show was half of a frame, it is a quarter.

**The screen's memory mapped in the program** (`segattach`, the speed
plan's K8). No copy at all; but a segment mapped uncached or flushed,
and a program writing the screen while the kernel draws the cursor on
it. Only if the write's copy is measured to matter.

**The screen at 32 bits** (the speed plan's K5). One format
everywhere: the table of words, the device's copies, the Bitmap's
format the screen's own. Twice the bytes per frame; simpler code.

**Dirty rectangles** (Redraw). For shapes, only what changed is drawn
again; a game's picture changes everywhere at each frame, so Redraw
can only tell it changed. Pixels are compared by their place and size
(hashed like a Bitmap), not by their 64 KB.

## 9. How others do it

**DOS, 1993-1996.** Doom and Quake wrote their indices straight into
the VGA's memory (the 256-colour modes; Doom an unchained variant,
"mode Y", for page flipping), and the VGA's DAC turned each index into
a colour on its way to the monitor: the table look-up of section 7,
done by the hardware, at no cost to the program. A palette change
(the red of pain) was 768 bytes to the DAC. Pixels is that design
again, the platform playing the DAC.

**9front's doom** (`sys/src/games/doom`, i_video.c). Its palette made
32-bit words, the picture made XRGB32 in the program, `loadimage`
each frame, `affinewarp` to scale it in the device, `flushimage`:
section 6's path with one pass fewer (no transform, no opacity scan),
and the device scaling.

**Chocolate Doom, SDL 2.** The 8-bit picture blitted to a 32-bit
surface (SDL converts through the palette), uploaded to a texture, the
GPU scaling and showing it: the conversion is a pass of the CPU, the
rest the GPU's.

**Linux's framebuffer** (`/dev/fb0`). `write`, or `mmap` and the
pixels written in place, its format by `ioctl`: what F1 proposes,
without windows, as on mini-9pi.

**X11, Wayland.** `XPutImage` copies a picture to the server, in its
format; MIT-SHM shares the picture's memory with the server (no copy:
K8's idea); Wayland's shm buffers are that by design, the compositor
reading the client's pixels where they are.

## 10. What is left, by kind

```
  mini-doom now, under QEMU (about 70 ms a frame):

  |------- view 37-46 ms -------|--- show 17-22 ms ---|update 4-12|
    the renderer itself:          b. the table pass
    mini-ml's code                c. the load (128 KB)
                                  d. the device's copy (1-4 ms)
```

- **Pixels** (mini-doom, mini-quake): the view, the renderer in
  mini-ml's code, is now the larger part: what better code generation
  gives. Then F1 for the show.
- **Shapes** (TinyCameltry, about 25 to 30 a second): its view is under
  1 ms; its show is the messages (9-10 ms, mini-ml's code) and the
  device drawing them (16-23 ms, the kernel's, ocaml-light's code).
  Neither picture path changes it.
- **A moving Bitmap** (a video): still section 6's path; the "RGBA
  only" road of section 8 is for it.
- **A still Bitmap** (mini-page): already a copy a frame.
