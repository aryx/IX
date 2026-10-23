# Plan: a framebuffer for the playground on mini-9pi, and its platform chosen when the program runs (`kernels/9pi/devices/screen`, `lib_playground/platforms`)

The author (2026-10-22), asking for mini-doom
([`plan_doom.md`](plan_doom.md)): "Note that it maybe be too low fps
because of the way the playground and draw platform work on mini-9pi,
but we can maybe think about a /dev/framebuffer that would provide a
faster path (albeit no rio/windows support), with raw access so less
copy and intermediates. Ideally the games could be run with
-framebuffer, -software, -draw, etc. so lib_playground/ for plan 9
would allow to choose dynamically if needed"; "for plan 9 I mean for
m-ix"; "if needed, we could even make a plan_playground_framebuffer.md
or something, but first, let's do mini-doom".

[`plan_playground_speed.md`](plan_playground_speed.md) had this as K8
("the framebuffer in the program's memory"), postponed by the author
on 2026-10-07 ("use that only as a last resort"), its target then
TinyDoom's shapes. mini-doom is the other kind of game that plan
foresaw: one that makes its own pixels, every one of them at each
frame.

Where it stands (2026-10-22, the Status at the end tells it): **F2 is
done** (mini-doom 8 to 15-24 frames a second on the Pi 2, mini-quake
about 15); **F5, an integer scaled draw in the kernel, and F4 are
done** (2026-10-23: mini-doom at 960 by 600 as fast as at 320 by 200
under QEMU), for a picture larger than 320 by 200 at the same speed
(the author: "now it would be great if we could enlarge the screen
since right now the doom "window" is very small on the whole
screen"); F1 and F3 after, if their gains are measured to matter.

## What a frame of mini-doom costs now (2026-10-22, measured)

mini-9pi under QEMU (raspi1ap, the screen 1024 by 768 at 16 bits), the
up arrow held, the game's meter (`stats=on`: Plan9_loop's parts, the
draw platform's device time); a frame is 40 frames' time / 40:

| | a frame | the update (tics) | the view | the showing |
|---|---:|---:|---:|---:|
| draw platform, `scale=1`, `size=320` (mini-doom's default on Plan 9): shown as it is | 160-200 ms (5 to 6 a second) | 5 ms | 46-106 | 70-84 |
| draw platform, `scale=2` (640 by 400 scaled to 768) | no meter's line in 20 s: under 2 a second | | | |
| software platform, `scale=1` (it has no `size=`: its square is the screen's 768) | no meter's line in 60 s: under 1 a second (the whole 768 square made by the software renderer each frame, the picture scaled into it) | | | |

(Corrected the same day. The first numbers here, 15 frames a second
shown as it is and 12 scaled, were of frames that showed nothing new:
mini-doom changed its picture's bytes in place, and the draw platform
keeps the device's image of a picture it has shown, found by the value
itself; it showed the first two frames again and again, and the eye
never moved. `plan_doom.md`'s Status says it.)

And on Linux, the same frame by the two compilers' code (arm64,
300 frames walking, 320 by 200):

| | the render | the picture made RGBA |
|---|---:|---:|
| OCaml | 0.7-1.3 ms | 0.5 ms |
| mini-ml | 3.2-6.7 ms | 1.7 ms |

and by mini-5i, mini-ml's arm code: 40 million instructions a frame
(the start, the WAD read and its textures made, 648 million).

So for mini-doom today:

1. **The view (the renderer, mini-ml's code) is half of a frame**:
   46 to 106 ms under QEMU. That is mini-ml's speed (4 to 5 times
   OCaml's here: [`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md));
   no framebuffer changes it.
2. **The path to the screen is the other half, unscaled** (70 to 84 ms
   at 320 by 200: each frame a new picture, so the draw platform
   makes its pixels again, allocates an image of the device's, loads
   it, frees the oldest of the four it keeps), and **ruinous when the
   picture is scaled** (its pixels made with neighbours blended). A
   640 by 400 picture on a 768 square is under 2 frames a second.
3. **The picture is made three times before the device has it**: the
   renderer's bytes of the palette, the program's RGBA (1.7 ms by
   mini-ml at 320 by 200, four times that at 640 by 400), the
   platform's Framebuffer (x8r8g8b8, by Shape_render_software's
   blit), then the load's copies and the device's 32 to 16 bits.

## The proposal

### F1. `/dev/framebuffer`: the screen's memory, written by one program

A device of mini-9pi's (`#f`, bound on `/dev` by the boot's
namespace), two files:

- `framebufferctl`: reads `1024 768 16 r5g6b5` (the screen's size,
  depth and channel, Plan 9's chan's words); written: `open` takes the
  screen (the draw device's flushes and the software cursor stop
  drawing on it, the console too), `close` gives it back (the draw
  device redraws the whole screen from its images: rio's windows
  come back as they were, as after a window is uncovered). The
  file's last close is a `close`.
- `framebuffer`: a write at offset `o` puts its bytes at `o` of the
  screen's memory (`y * stride + x * 2`): one copy, the system call's,
  from the program's memory to the screen. No image, no message, no
  composition, no flush. A read gives the screen's bytes (a
  screenshot, what `/dev/screen` is in Plan 9).

Why writes and not the memory itself (K8: a segment of the screen's
pages in the program's address space, Plan 9's `segattach`): the
write is one copy of a frame (128 KB at 320 by 200 by 16 bits, a few
hundred microseconds), the system call exists and the kernel's code
for it is a page of OCaml; a segment wants `segattach` (in the system
call table, not implemented), the pages mapped uncached or flushed,
and a program that writes the screen while the kernel draws the
cursor on it. The write is the first step; the segment only if the
copy is measured to matter.

What it is not: a window's. Under rio the program has a window, which
is rio's image: `/dev/framebuffer` is the bare screen's only (the
author's "albeit no rio/windows support"). A program in a window
uses the draw platform as now (F3 chooses).

Plan 9 has none: its programs draw through `/dev/draw` only, and
9front's doom does too (`i_video.c`: a 320 by 200 XRGB32 image loaded
each frame, `affinewarp` to scale it, by the device). Linux has
`/dev/fb0` (`write`, or `mmap`, and `ioctl` for its geometry: the
same two-file idea, a control in place of the ioctl); Inferno's and
Plan 9's `/dev/screen` are its read half.

### F2. The picture in the screen's format, made by the platform

A frame through `/dev/framebuffer` is the screen's format, RGB565 here
(two bytes a pixel). Two ways to get there:

- **A playground shape of pixels with a palette** (`Playground.Pixels`:
  width, height, the palette, the bytes of its indices): the
  program gives the renderer's bytes as they are, no RGBA; each
  platform makes what it needs (the framebuffer one: each index's 565
  from a table of 256, written row by row, doubled if asked; the draw
  and software ones: RGBA, as now; ppm and SDL: the same). For
  mini-doom: the 1.7 ms of RGBA, and the platform's Framebuffer, gone.
  A new form in the playground's shape (the playground's file, a
  copy: said in `lib_playground/README.md`).
- Or only RGBA as now, converted to 565 by the platform: simpler, no
  new shape, and one pass more at each frame.

Proposed: the first. It is also what Doom's palette effects (the red
of pain: another palette, not other pixels) would want.

The screen's depth: at 16 bits a frame is half the bytes of 32; the
screen at 32 bits (plan_playground_speed.md's K5, accepted, not done)
would make the program's conversion a table of 32-bit words. Either
works; F1 says the format and the platform follows.

### F3. The platform chosen when the program runs

Today a program is linked with one platform (`Playground_platform`,
a module of that name in each of `platforms/draw`, `software`, `ppm`,
`sdl`), and mini-mk builds a game twice for two (`games/fps/doom` and
`doom-soft`). On Plan 9 the two share their loop already (Plan9_loop,
given a record of four functions: `make`, `at`, `show`, `free`): a
third, the framebuffer's, is one more such record. So:

- `platforms/plan9/Playground_platform.ml`: the three records, and
  `run_app` choosing one by the command line: `-draw` (the default in
  a window), `-software`, `-framebuffer` (the default on the bare
  screen when the program's picture is pixels: F2), as the author
  asked. The draw and software platforms become libraries of their
  record each, and stay as they are inside.
- What it costs: every Plan 9 program linked with all three (the
  software renderer is in most already: Redraw, the letters' masks;
  to measure: a game's size before and after).
- mkgames' `-soft` builds and the card's `*-soft` programs then go:
  `tetris -software` is what `tetris-soft` was.

### F4. The Plan 9 platforms honour `window` (the screen as it is)

`Session.window`: a program's screen follows the window, a unit a
pixel, on Linux; the Plan 9 platforms "do not look at it yet" and draw
a square of 1000 units. mini-doom's 320 by 200 (or 640 by 400) is then
scaled to the square's side (768 on QEMU's screen): the blended
scaling that is most of the second row of the table above. With
`window`, a picture of 640 by 400 is 640 by 400 pixels on any screen,
and the framebuffer platform writes it where it fits, centred. Needed
by F1 and F3, useful alone (the draw platform's slow case gone).

Measured again after F2 (2026-10-22): `size=` caps the square, so
`scale=2` (640 by 400 in a square of 640) is a whole multiple and takes
the Pixels path; `scale=3` (960 by 600) and `scale=4` (1280 by 800) do
not fit the square of the screen's shorter side (768 under QEMU),
are scaled down blended, and drew fewer than 40 frames in 20 seconds.
With F4, `scale=3` is 960 by 600 on a screen of 1024 by 768, whole,
the largest whole multiple there; `scale=4` needs a screen of 1280 by
800 at least (the author's monitor is 1280 by 800; mini-9pi's 1024 by
768 is shown on it as it is, not stretched: "I can actually see a
black column on the left and right"). The author, of this:
"yes we can't go through blending I think so we need to scale in
fixed number".

### F5. Scaling in the kernel: a draw by a whole number

The author (2026-10-22), seeing `scale=2` at 8-9 frames a second under
QEMU where `scale=1` was 13-14: "can't we get this scale kernel side
instead? so we load the same bytes, but they are scaled then? Or maybe
it's a hack". Not a hack: the step a GPU does in Chocolate Doom (a
texture shown larger), and the device's in 9front's doom (affinewarp).

Where `scale=2`'s frame goes today (Pixels at k = 2): the table pass
writes each index twice in a row and the row twice (mini-ml's code, k
times the work: most of its 53-81 ms of messages), and the load and the
device's copies carry 512 KB instead of 128 (notes_frame.md, Part II:
five copies of it). With the scaling in the kernel, the program's part
is scale 1's whatever the scale: 128 KB made, loaded into the kept
image; then one message draws that image onto a rectangle k times its
size, each pixel k by k, from the image straight to the window's back
image: the 512 KB written once, by the kernel's code (ocaml-light's),
with no image of that size in between.

Three ways it could be asked, the first proposed:

- **A scaled draw**, a message of its own beside 'd': the destination,
  its rectangle, the source image and its point, and k (a whole
  number, 1 to 8: no blending, never a fraction). Kdraw's OCaml
  pixels (lib_memdraw) do it: each destination row is a source row's
  pixels each written k times, the k - 1 rows after it copies of it
  (block copies); only when the two images are of one format and no
  mask (else an error: the program has the slow way). Principia's C
  pixels (`PIXEL=c`) answer it with an error, not a second
  implementation.
- A scaled load ('y' into an image k times larger): the program sends
  128 KB, but the 512 KB image is still made, then copied by 'd': one
  copy of 512 KB more than the scaled draw.
- An image flagged scaled (its draws replicate): no new message, but a
  state on an image that every drawing must know about.

What it is not: Plan 9's draw protocol has no scaling at all (a
picture is drawn at its size, or through a mask); this is an
extension of ix's, said as such in Devdraw and lib_graphics's Draw.
F4 is needed with it, for k = 3.

### F6. The Pi's own scaler (an experiment, if F5 is not enough)

The Pi's display hardware (the VideoCore's HVS) can scale a picture
to the monitor for nothing, as a graphics card shows DOS's 320 by 200
on any screen: a game on the bare screen would ask the firmware for a
framebuffer of 320 by 200 (or 640 by 400; 8 bits a pixel and its
palette, perhaps) and give it the screen back after. Not on rio, not
under QEMU, a board's only. And not known to work: the author's Pi 2
shows mini-9pi's 1024 by 768 on its 1280 by 800 monitor as it is,
black around it, so the firmware may show a 320 by 200 the same, small
in the middle (2026-10-23). To try on the board before planning more.

Expected: a frame at k = 2 or 3 near k = 1's 13-14 under QEMU (the
program's part the same, the kernel's loop simple); to be measured.

## The stages

In the order of 2026-10-22's evening (the first order was F4, F1, F2,
F3, F5):

1. **F2** (done): `Playground.Pixels`, drawn by every platform,
   mini-doom and mini-quake giving their bytes and palette; the
   frames' tests the same pictures.
2. **F5**: the scaled draw in the kernel (Devdraw, lib_memdraw;
   lib_graphics's Draw), the draw platform using it for Pixels at a
   whole multiple; a test of the kernel's (a picture drawn at k = 2
   and 3, read back, compared with the program's own doubling).
3. **F4**: the Plan 9 platforms honour `window` (the picture's own
   size, not a square), so that `scale=3` fits a screen of 1024 by
   768. Measured: mini-doom and mini-quake at scales 1, 2, 3 under
   QEMU, the screens looked at; then the author's Pi 2.
4. **F1**, if the show at scale 1 (15-20 ms) is then worth it: a
   window of rio's costs about what the bare screen does (the author:
   "running under rio gives similar number"), and F1 is the bare
   screen's only.
5. **F3**: the platform chosen at run time, if F1 is made.

## Open questions, for the author

- The device's name and files (`#f`, `framebuffer` and
  `framebufferctl`), or Plan 9's `/dev/screen` made writable?
- The screen taken from rio's windows while a program has it: rio
  itself running under it (its windows redrawn after), or only from
  the console?
- ~~`Playground.Pixels` (a new shape, the playground's file changed), or
  RGBA only?~~ Pixels (F2).
- The screen at 32 bits (K5) first, since every path is simpler with
  one format?
- F5: a message of ix's own in the draw protocol (proposed), and its
  letter; or the scaled load, which needs no new drawing in memdraw?
- `scale=4`: mini-9pi's screen on the Pi at 1280 by 800 (the author's
  monitor), or 1024 by 768 and `scale=3` the largest?

## Status

2026-10-22: proposed, nothing begun. The numbers above were taken on
a card of the scratchpad's (the main tree's `build/card.img` not
remade).

2026-10-22, **F2 done** (the author: "Should we also do the playground
speedup work at the same time? Can we get doom and quake at high fps
under mini-9pi and qemu and also the real Pi2?", then "yes let's
start"; and "ideally what we do can also benefit every playground
games, like cameltry, and also some apps"). Taken first: the measures
said the device was 3 ms of the showing, the program's making of the
picture the rest (the game's RGBA, the opacity scan, Shape_render_
software's draw into a Framebuffer through a transform, a new image
of the device's loaded with 4 bytes a pixel).
- `Playground.Pixels` (the open question's answer: a new shape, said
  in the playground's file as an ix addition): palette indices and
  their palette. The draw platform (`pixels_image`) writes them in the
  screen's own format (r5g6b5 or x8r8g8b8: a table of 256), each pixel
  k by k when the box is a whole multiple, into one image kept and
  loaded again each frame; drawn to the window's back image (of the
  screen's format: no conversion in the device). Else, and on the
  other platforms (Shape_render_software, the PDF writer), RGBA at the
  same whole multiple (`Shape_render_software.pixels_rgba`): the
  pictures of before, byte for byte. Juice, Physics and Redraw know it
  as a Bitmap.
- mini-doom and mini-quake give their 320 by 200 bytes (two buffers in
  turn: each frame's picture a new value) and their palette (mini-
  quake's with its gamma); their `to_rgba` gone.
- Under QEMU (`kernels/9pi/tests/perf/frames.sh`, now with `CARD=`,
  the up arrow held 12 s, the meter's two 40-frame lines):

  | | before | after |
  |---|---|---|
  | mini-doom | 4.7 to 6.7 a second: view 58-99 ms, show 76-92 (the device 3) | **13 to 14**: view 37-46, show 17-22 (the device 1-4) |
  | mini-quake | 5.3 to 5.9: view 30-86, show 64-76 (the device 3-4) | **11 to 15**: view 18-37, show 33-36 (the device 3) |

  The view is faster too: the game's RGBA was in it. The screens
  looked at: they move, their colours right.
- For the other programs (the author's ask): Pixels helps a program
  that makes its own pixels. TinyCameltry, of shapes, measured the
  same day: 25 to 30 a second, its showing 27-32 ms of which the
  device 16-23 and the messages 9-10, its view under 1: there the
  device (the kernel's drawing, compiled by ocaml-light: kernel.mk's
  COMPILER=light; COMPILER=ix would be mini-ml's code) and mini-ml's
  code for the messages are what is left, not the path of a picture.
  A Bitmap (an app's RGBA pictures: a page, a browser's images) still
  takes the slow path when it is new each frame (a video's).
- On the author's Pi 2 (the main tree's card, made the same evening,
  mini-9pi 0.2 at 7f15c58f+), mini-doom outside rio: "around 15 fps on
  big area, and more like 24 on smaller area; quite smooth. could be
  better but not bad" (8 a second before, plan_doom.md); TinyCameltry,
  of shapes: "around 44, 50 fps depending on the area", as before;
  mini-quake: "around 15 fps too, depend on the zone, not bad either".
- Checked: games, examples, office and drscheme's frames' tests (130
  sessions) the same; mini-mk O=5 OS=plan9 of lib_playground, its
  platforms and apis, mini-doom, mini-quake.

2026-10-22, later, **a larger picture** (the author: "now it would be
great if we could enlarge the screen since right now the doom
"window" is very small on the whole screen; not sure how to remain
fast; maybe by doublimg/scaling", "maybe we can scale=4 to get the
whole screen?"). Under QEMU, the main tree's card, the up arrow held
20 s (an argument with `=` is quoted for rc: `doom 'scale=2'`):

| mini-doom | frames a second | the view | the show (the messages) |
|---|---|---|---|
| `scale=1` | 13 to 14 | 37-46 ms | 17-22 (13-17) |
| `scale=2`, 640 by 400 | 8 to 9 | 29-43 | 56-83 (53-81) |
| `scale=3`, 960 by 600 | under 2: no meter's line in 20 s | | |
| `scale=4`, 1280 by 800 | under 2 | | |

`scale=2` is a whole multiple and takes the Pixels path, but pays it
k times (F5); 3 and 4 do not fit the square (F4). Hence F5 and F4, the
plan's next stages.

2026-10-23, **F5 and F4 done, the Pi's screen the monitor's** (the
author: "we can do the largest; and it's ok to have a new message in
the draw protocol", then, of the three steps proposed, "let's start").
- The kernel: 'z' dstid[4] srcid[4] R[4*4] P[2*4] k[1], src drawn into
  R k times larger, each pixel k by k (Devdraw, Kdraw.scale,
  Memlayer.scale, Memdraw.scale: clipped as a draw, then shown as a
  draw on a window is). Its loop is C, runtime.c's imag_scale beside
  imag_copy: a source row's pixels each written k times, the k - 1 rows
  after it copies of it, counters and no division (the Pi 1), the
  kernel's lock given back as a copy's. Only between images of one
  chan of whole bytes a pixel; else an error. PIXEL=c: an error.
- The program: Draw.scale; Draw.can_scale asks the device once (a
  pixel drawn, Display.accepted: whether the write was taken). The
  draw platform's Pixels: the image at the picture's own size, loaded,
  then 'z'; at the largest whole multiple that fits its box, centred
  (old: only a box a whole multiple; else a Bitmap, blended). The
  flag kscale=off: the program's own k by k, as before.
- F4: window=WxH, when it fits, is the program's screen, a unit a
  pixel, centred; the size it starts at (a window made again follows
  the window, as the flag window alone).
- The Pi's screen (Swconsole): the monitor's own size from the
  firmware, up to 1920 by 1200 (1280 by 800 on the author's Pi 2); an
  emulator's 640 by 480 keeps 1024 by 768.
- Tests: tests/memdraw/run.sh compiles runtime.c's imag_scale on the
  host, and Scale.ml checks it against a pixel by pixel reference
  (2, 3 and 4 bytes a pixel, k 1 to 5, clipped starts): 0 pixels of
  900 draws differ; with the clipped start's column left out of the
  loop, thousands.
- Under QEMU (a card of a private worktree, faf1c544 and this; the
  up arrow held 20 s; 1024 by 768):

  | mini-doom | before (2026-10-22) | after |
  |---|---|---|
  | `scale=1` | 13 to 14 | 13 to 14: view 35-45, show 20-23 (the device 2-3) |
  | `scale=2`, 640 by 400 | 8 to 9 | 13 to 14: show 21-26 (the device 5-6) |
  | `scale=3`, 960 by 600 | under 2 | 12.5 to 13: show 27-28 (the device 8-9) |
  | `scale=4` (1280 by 800 does not fit: the screen, 960 by 600 in it) | under 2 | 13 to 13.5: show 27-30 |

  mini-quake: the show 28-37 ms at scales 1 and 2, 42-46 at 3; its
  view (27 to 118 ms, by where the eye is) the most of a frame. The
  screens looked at: 960 by 600 centred, each 3 by 3 block one colour
  (0 pixels of 538,560 differ). The recorded sessions draw-tetris,
  draw-wolf, tetris-win, colors-win, win-new and menu the same.
- Not checked: a game at k > 1 in a window of rio's (Memlayer.scale's
  show) on the screen; the Pi 2 (the author's card to try).
