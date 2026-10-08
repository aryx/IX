# Plan: TinyGraphics, TinyWindows and TinyPlayground: a screen, a window system and a Tetris in a window, for tiny-machine and tiny-kernel

Status: **steps 1 to 6 done (2026-10-08): Tetris plays in a window of tiny-windows on tiny-machine, the plan's goal; step 7, the docs, to do.**
Written 2026-10-08. The numbers of lines of the steps to do are
estimates; the section "Status" at the end says what was built. The author, after mini-rio: "we now
have mini-9pi and mini-rio windowing system, with a kind of mini-draw.
Could we have a TinyWindows and TinyGraphics working with TinyMachine
and TinyKernel?"; then, of the answer this plan writes down: "yes,
let's write the plan document". And, the same day: "ideally we would
like also a TinyPlayground that a TinyTetris could rely on and display
a tetris game in a TinyWindow running on the TinyMachine in graphics
mode": the plan's last two programs, and its goal.

Companions: [`plan_rio.md`](plan_rio.md), mini-rio, the faithful twin;
[`plan_tiny_os.md`](plan_tiny_os.md), tiny-machine's devices and how
each was added without touching the older kernels;
[`../notes_tiny_kernel.md`](../notes_tiny_kernel.md), TinyKernel.ml's
free design, which this plan continues;
[`plan_playground.md`](plan_playground.md), the games on the draw
device.

## Context

The mini side has graphics end to end, about 5,500 lines:

| layer | where | lines |
|---|---|---:|
| the screen in a host window, the USB keyboard and mouse | `raspberry/` (`Framebuffer`, `Sdl_display`, `Usb`, `Dwc2`) | ~900 |
| images, drawing, layers; the draw, mouse and keyboard devices | `kernels/9pi/lib_graphics/`, `kernels/9pi/devices/` | ~3,000 |
| a program's side: messages to `/dev/draw` | `lib_graphics/` | ~700 |
| the window system | `windows/` (mini-rio) | ~900 |

The tiny side has none: tiny-machine's only output is the console's
byte at `-16(r0)`, and TinyKernel.ml's files are a tree, pipes and that
console.

What the tiny stack already gives, checked on 2026-10-08:

- **Speed.** tiny-machine runs a counting loop at about 57 million
  instructions a second (supervisor mode, no pages; 100 million in
  1.74 s). 640 by 480 pixels filled by a loop in assembly are a few
  milliseconds.
- **Room.** TinyKernel.ml's memory: the heap from 2 MB to 5 MB, ten
  partitions of 1 MB from 5 MB to 15 MB, the devices in the last 32
  bytes. The megabyte from `0xf00000` is free.
- **A free device word.** Of the eight words below the top, `-4(r0)`
  is unused.
- **tiny-ml -tm programs run on tiny-cpu** (`TinyML_test.sh` runs
  each test so), with arrays and mutable records. No modules, no
  `Bytes`: a program is one file.
- **A font.** `kernels/lib_machine/font1.bin`, 128 characters of 8 by
  16 bits, 2,048 bytes (as first written here: 256 of 8 by 8; step 2
  found it out). The screen is 80 by 30 characters.

Not checked: an ML program as a process of TinyKernel.ml (its user
programs are C). It is step 4's risk.

And what a Tetris stands on, on the mini side
([`plan_playground.md`](plan_playground.md)): `games/puzzle/Tetris.ml`
(511 lines) over `lib_playground/` (`Playground.ml` 781 lines, its
interface 1,210, a platform over the draw device 302, `Sub`, `Cmd`,
`Color`, `Lehmer`), compiled by mini-ml. tiny-ml compiles none of it:
the playground's numbers are floats (a shape's place, its scale, the
time of a frame: `Tick of float`), its names are modules' (`open
Playground`, `Color.Rgb`, `Sub.batch`), and tiny-ml has neither, nor
has TinyCPU a float.

## The three programs

| file | executable | its twin | the idea kept |
|---|---|---|---|
| `TinyMachine.ml`, more | tiny-machine | `raspberry/` (the framebuffer, the USB devices) | devices as memory: the screen is bytes at an address, the mouse a word |
| `TinyGraphics.ml` | in tiny-kernel | `lib_graphics/`, `kernels/9pi/lib_graphics/` (libdraw, libmemdraw) | one operation, `draw dst r src mask p`; the kernel has the images, a program says what |
| `TinyWindows.ml` | tiny-windows, a program of tiny-kernel | `windows/` (mini-rio; rio) | a window looks like a machine of its own, so the window system runs in one of its own windows |

| `TinyPlayground.ml` | with each game, a program of tiny-kernel | `lib_playground/` (the author's playground, Elm's) | a game is four values: a model, how it is drawn (a list of shapes), how a key or a frame changes it; the library has the loop |
| `TinyTetris.ml` | tetris, a program of tiny-kernel | `games/puzzle/Tetris.ml` | the game: the well, the seven pieces, lines, levels |

And TinyKernel.ml gains two kinds of open file and one system call.

The goal, what the last step shows: `./tiny-machine -window
tiny-kernel`, tiny-windows on the screen, a window swept, `tetris`
typed in it, the game played in that window while a shell runs in
another.

## Decisions (for review; each with what I recommend)

1. **The pixels are the kernel's.** TinyKernel.ml protects by a
   partition: a process reaches its megabyte and nothing else, so it
   cannot be given the screen's memory without pages. A program then
   says what to draw and the kernel draws: Plan 9's choice, here
   forced by the machine. **Decided (2026-10-08)**, the author, of
   pages in TinyKernel.ml: "let's keep it simple for now, but ideally
   we could support both and switch". So partitions here; pages are
   the section "Later", below.

2. **A byte a pixel**, an index in a fixed table of 256 colours
   (Plan 9's `m8`, its rgbv map). The other choice is a bit a pixel,
   the Blit's and Oberon's, a fifth of the memory and more historical,
   but every row then needs shifts and masks. A byte makes `draw` a
   loop of `ldb` and `stb`. Recommended: a byte.

3. **Compositing, not layers.** mini-9pi keeps what shows of each
   window and what is hidden apart (`Memlayer`, `Memshape`: about 290
   lines). Here a window is an image off the screen, whole, and the
   window system draws the windows back to front over the rectangle
   that changed, with `draw`. Nothing to learn but `draw`; paid by
   copying, which the machine's speed allows.

4. **TinyWindows is a user program, not a part of the kernel.** The
   kernel has the mechanism (images, `draw`, the mouse); the policy
   (which window is in front, the menu, a window's text) is a process.
   A window in the kernel, one more kind of open file, would be about
   150 lines shorter, and is Oberon's design. It would lose what rio
   shows: a window system is a multiplexer that gives what it takes.
   Recommended: the user program.

5. **Descriptors given, not a mount.** rio is a file server mounted
   before `/dev` in its window's process. TinyKernel.ml has no
   namespace and no 9P. A window's process gets instead, from its
   parent, descriptors: 0, 1 and 2 its text, 3 where it draws, 4 its
   mouse. The first tiny-windows gets the same five from the kernel,
   so a tiny-windows started in a window runs unchanged.

6. **Forwarding is renumbering.** A drawing program writes messages
   to its descriptor 3, each naming images by numbers. tiny-windows
   reads a window's messages, changes each number to the kernel's
   (the window's image for 0), and writes them to its own descriptor
   3. It never has a pixel: all of them are in the kernel.

7. **Waiting for several descriptors is one closure.** tiny-windows
   waits for the mouse, the keys and each window's process at once.
   rio has threads and channels for that. TinyKernel.ml's waiting is
   a closure the scheduler retries, so `ready(fds, n)`, the first
   descriptor of a list that a read would not wait on, is about ten
   lines, and tiny-windows is one loop.

8. **A session is replayed exactly.** tiny-machine's time is its
   instructions counted. With `-events file` (a line an event: the
   time, then the mouse's place and buttons, or a key) and `-screen
   out.ppm` (the screen written at the halt), a session with the
   mouse gives the same picture on every run: the test.

9. **The host's window is another program**, tiny-machine-window
   (`tiny/TinyMachineWindow.ml`), over `raspberry/Sdl_display.ml`,
   made a small library (`ix_sdl_display`) that mini-qemu links too.
   As first written, tiny-machine was to link that library itself.
   But `tiny/mkfile` builds tiny-machine by ix's tools, one file and
   nothing of C's, and it should stay so. With `-window`,
   tiny-machine runs the other program as a child: the screen to its
   standard input, a PPM each time it changed; the events from its
   standard output, the lines of `-events` without their times. So
   the window knows nothing of the machine, and something else could
   be in its place (a test's script was; mini-rio, one day).

10. **TinyPlayground is free: integers, and no platform.** The
    playground's shapes are floats under an affine transformation
    (move, scale, rotate, fade), and one program runs on four
    platforms (Cairo, software, the web, the draw device). Here the
    numbers are integers (pixels), the shapes what `draw` does at once
    (a rectangle, words, a group moved; words' size a whole number of
    times the font's), and the one platform is descriptor 3. What is
    kept is the playground's idea, Elm's: the game is a model and
    three functions, with no loop and no drawing of its own. The
    other road, floats and modules in tiny-ml so that `Tetris.ml`
    compiles as it is, is mini-ml's, and is taken already.

11. **Several files for tiny-ml, by `open`.** TinyGraphics in the
    kernel and TinyPlayground in a game are libraries, and tiny-ml
    takes one file. Recommended: `tiny-ml a.ml b.ml`, the files one
    after the other as one program, and `open A` read and ignored
    (about 5 lines). The names stay unqualified, so the same files
    are OCaml's too, modules there, and dune builds a game for the
    host, where it is tested first. Without it: `cat` in the
    Makefile, and no build by OCaml.

12. **Time is `ready`'s third argument.** A game waits for a key or
    for the next frame, whichever is first. `ready(fds, n, until)`
    returns -1 when the kernel's ticks reach `until` (decision 7's
    closure, one more test), and `ticks()` reads them. No `sleep`:
    it is `ready` with no descriptor.

13. **The machine has a speed.** A frame is a number of ticks, a
    tick a number of instructions: on a host twice as fast the pieces
    would fall twice as fast. With `-window` tiny-machine keeps a
    rate (20 million instructions a second, say: below what the host
    gives), sleeping when it is ahead. A recorded session does not
    wait, and is the same.

14. **A drawing window's keys are raw.** tiny-windows gives a line
    at a time to a window of text (decision 5's descriptor 0), which
    a game cannot use. A window whose process has drawn gets each key
    as it is typed. The arrows, which are not characters, are four
    bytes above 127, the machine's choice.

**Decided (2026-10-08), the name**: `tiny/TinyTetris.ml`, though a
game of the author's playground has it too (393 lines, on its
`Scene2d` and `Juice`), and `games/arcade/TinyCameltry.ml` and
`games/fps/TinyWolfenstein.ml` are the playground's, on mini-9pi. The
author: "TinyTetris.ml is fine". This one is t-ix's, on
TinyPlayground, nothing copied from the playground's.

## The machine (step 1)

Each behind an option, so that v0, v6, t6 and tiny-kernel as they are
run as they did (their checks after the step):

- **The screen**: 640 by 480 bytes at `0xf00000`, memory like any
  other (a kernel stores a pixel by `stb`). `-window` shows it,
  redrawn when it changed, every so many instructions; `-screen
  out.ppm` writes it at the halt, through the table of colours.
- **The mouse**: the word at `-4(r0)`, its x in the low 12 bits, its y
  in the next 12, the buttons above; an interrupt, the fourth source
  (`ip`'s bit 8), when it changed, until the word is read. The host
  window's mouse is absolute, so no grab.
- **The keys**: the console's input, `-8(r0)`, as today; with
  `-window` its bytes are the window's keys (SDL's text input: a
  character, no table of scancodes). A kernel's console code does not
  change.
- **`-events file`**: the mouse and the keys from a file, each at its
  time.
- **The arrows** as four bytes, and **the rate** kept with `-window`
  (decisions 14 and 13).

About 80 lines in `TinyMachine.ml`. Its test: a `.tm` program in
`TinyMachine_tests/` that fills rectangles and follows a recorded
mouse, its `.ppm` against the expected one.

For review: the megabyte at `0xf00000` holds the screen (300 KB) and
700 KB of images, two windows of half the screen. More room is two
partitions fewer (`nslots` 8: 2 MB more), or a screen of 320 by 240.
Recommended: eight partitions.

## TinyGraphics.ml (step 2)

In tiny-ml's ML, and OCaml's too, so that it is tested on the host
first (an image in an array, a `.ppm` written, compared):

- an image: a rectangle in the plane, its bytes at an address, whether
  it repeats (a colour is an image of one pixel that does);
- `draw dst r src mask p`, clipped to both images; the rows' loops
  (copy, fill, copy where the mask is set) are three functions in
  assembly beside `k_copy` and `k_zero`;
- `string`: the font's 8 by 16 characters as masks of a colour;
- `line`; no ellipse, no polygon (exercises);
- the messages: a letter and its arguments, decoded here (alloc,
  free, draw, string, line), with a program's numbers for its images.

About 300 lines. It names nothing of the kernel's but the functions
of bytes; TinyKernel's Makefile gives it to tiny-ml before
`TinyKernel.ml`, as one file.

## TinyKernel.ml (step 3)

- `file` gains `Draw of conn` (a connection: its images by their
  numbers; a write is messages) and `Mouse` (a read waits for a
  change, then gives x, y and the buttons); `/draw` and `/mouse` are
  nodes of the tree beside `/console`;
- `interrupts` takes the mouse's source;
- `ready`, decision 7's call, with its time (decision 12), and
  `ticks`;
- the images' bytes are outside the collected heap, in the megabytes
  decision 1's step leaves, given and freed by a list of free blocks.

About 90 lines. Its test: a C program that draws through `/draw`,
its `.ppm`; `make check` as before.

## TinyWindows.ml (step 4)

A program of TinyKernel.ml, in ML (tiny-ml -tm, its `main` and system
calls a page of C and `.tm` beside `user/sys.tm`): the first ML
process. If that costs more than it should, the fallback is C by
tiny-c -tm, the design the same.

- the windows, the front one first: an image, a rectangle, the two
  pipes of its process, its text;
- the loop: `ready` on the mouse, the keys and the windows' pipes;
- the mouse: a click gives a window the keys and brings it to the
  front; the right button's menu, rio's (New, then a rectangle swept;
  Move; Delete; Exit);
- a window's text: what its process writes, wrapped and scrolled; the
  keys typed are its input, a line at a time; no scroll bar, no
  selection, no snarf (exercises);
- a window's drawing: its messages renumbered and sent on (decision
  6), then the window composed on the screen (decision 3).

About 300 lines, and a small `draw.h` for C programs with one that
draws (a clock or a ball), about 100.

Its test: a recorded session (two windows made, `ls` typed in one,
the drawing program in the other, one moved over the other, one
deleted), the `.ppm` against the expected one; and the same with
tiny-windows started in a window.

## TinyPlayground.ml (step 5)

In tiny-ml's ML, linked with each game (decision 11):

- a shape: `Rect of color * int * int` (its width, its height),
  `Words of color * int * string` (its size), `Group of shape list`,
  `Move of int * int * shape`; the origin the window's top left
  corner, y down (the screen's, not the playground's centre and y up:
  no transformation to undo);
- a game: `{ init : int -> model; view : model -> shape list; key :
  int -> model -> model; frame : model -> model }`, the argument of
  `init` a seed (the ticks at the start; given, for a test);
- `run game`: the loop. `ready` on the keys until the next frame
  (30 a second); the model changed; if it is another (`!=`), its
  shapes drawn in an image off the window, as messages, then that
  image drawn on the window at once (nothing flickers);
- `random`: a generator on 31 bits (tiny-ml -tm's integers: Lehmer's
  by Schrage's division, or a smaller modulus).

About 150 lines. Its test on the host first: a model's shapes drawn
by `TinyGraphics.ml` in an array, the `.ppm` compared.

A frame of Tetris is about 250 rectangles, 5 KB of messages, through
two pipes of 512 bytes (the game's to tiny-windows, tiny-windows' to
the kernel): twenty turns of the scheduler a frame. To measure in
this step; a larger pipe is a constant.

## TinyTetris.ml (step 6)

`games/puzzle/Tetris.ml`'s game in integers: the well of 10 by 20, a
cell a colour, the seven pieces and their turns, the next one shown,
the lines cleared, the score, a level every ten lines; the keys the
arrows and the space (the piece dropped). Its fall is a count of
frames a row, shorter at each level, where the original adds a
fraction of a row a frame. No sound (`plan_audio.md` is the mini
side's).

About 200 lines. Its tests: on the host, a game played from a seed
and a list of keys, the well printed as text after each, against the
expected (the game's rules, no pixel); on the machine, a recorded
session in a window of tiny-windows, the `.ppm`.

## Steps

Each a commit that runs, with its test and its lines counted
(`docs/loc.md`'s t-ix):

1. tiny-machine: the screen, the mouse, `-screen`, `-events`; then
   `-window` with the shared `Sdl_display`.
2. `TinyGraphics.ml` on the host: images, `draw`, `string`, `line`.
3. TinyKernel.ml: `/draw`, `/mouse`, `ready`; a C program drawing.
4. `TinyWindows.ml`: text windows first (sh in each), then drawing
   programs, then itself in a window.
5. `TinyPlayground.ml`, with a first game of a page (a square the
   arrows move): tiny-ml's several files, `ready`'s time, the raw
   keys, the machine's rate.
6. `TinyTetris.ml`, in a window.
7. The docs: `tiny/README.md`'s rows, the README's table,
   `projects.md`, `./tiny-machine -window tiny-kernel`.

The lines, estimated: 80 (the machine) + 300 (TinyGraphics) + 90
(the kernel) + 400 (TinyWindows and a C program's `draw.h`) + 150
(TinyPlayground) + 200 (TinyTetris): about 1,200, for 5,500 and the
playground's 2,500 on the mini side.

## Later: pages in TinyKernel.ml, by a switch

Not a step of this plan; written down so that the steps above do not
close the road.

tiny-machine has pages already (Sv32, `satp`: tiny-os v6's, whose
`vm.c` is 246 lines of C). TinyKernel.ml has partitions because they
cost a few lines: `k_window` before a process runs, one `k_copy` for
fork, `base + va` to reach a user's memory. Pages in ML would be an
allocator of pages, a table a process, fork's copy page by page, and
a user's memory reached through its table: 150 to 200 lines,
estimated.

The switch: what the kernel asks of a process's memory is five
functions (made, copied for fork, freed, run in, a user's address
reached: today `free_slot`, `k_copy`, `release`, `k_window` and
`user`), so two sets of them, chosen when the kernel is built (the author:
"build time is fine"); the rest of the kernel names neither. What pages then buy:

- a process of any size, and as many as the memory holds, not ten of
  1 MB;
- copy-on-write fork (TinyKernel.ml's exercise);
- the screen in a process's own memory: a game or the window system
  drawing its pixels itself, decision 1 no longer forced. The two
  ways to draw could then be compared on one kernel, as the
  playground's two platforms are on mini-9pi (the draw device's
  shapes, and the program's own pixels).

What the steps above do for it: `TinyGraphics.ml` names nothing of
the kernel's (step 2), so it draws the same in a process's memory;
and the kernel reaches a user's memory only through `user`.

## Not in this plan

Fonts of several sizes, colours beyond the table, a cursor drawn by
the machine (the kernel draws it, or the host's is enough: to see in
step 1), sound, tiny-os v6 and t6 (they keep their console), and the
games of `games/` as they are on this draw device: they are the
playground's own files, with its floats, its modules and its filled
polygons, and mini-ml's to compile. A second game on TinyPlayground
(a Pong, a Snake) is an exercise.

## Status

**Step 1 (2026-10-08): the machine's screen, its mouse, `-screen`,
`-events`, `-window`.** Committed (`006b2e4`); the real window tried by
the author: "step 1 is working".

- `TinyMachine.ml`, 415 lines to 573 (with its comments and its
  help; about 100 of code): the screen's place and its colours (Plan 9's table by its
  formula, its 256 entries the same as principia's `cmap.c`), the
  mouse's word and its interrupt, an event's line, `-events` and
  `-screen`, the window's child and its two pipes. Not the 70
  estimated: the window's side is here, where decision 9 had it in a
  library.
- `TinyMachineWindow.ml` (68 lines): the pictures shown, the mouse
  and the keys written; a US keyboard's table, by USB usages.
- `raspberry/`: `Sdl_display` in a library of its own, with an
  `absolute` mouse (`Display.At`); mini-qemu builds as before.
- The test, `TinyMachine_tests/screen.tm` with `screen.events`: the
  screen filled, a square where the recorded mouse goes, the recorded
  keys written back; the console against `screen.expected`, the
  screen at the halt against `screen.cksum`. `TinyMachine_test.sh`: 0
  failures; v6's, t6's and tiny-kernel's checks pass as before; the
  machine's speed the same (100 million instructions in 1.8 s).
- Checked too: tiny-machine compiled by mini-ml (`TinyMachine.7`;
  it refused a labelled `Option.value`, changed); `-window` with a
  script in the window's place (its events taken, a line cut in two
  included; the same screen; the machine halted at the script's end);
  and with the real program under SDL's dummy video driver (it runs,
  and ends with the machine).
- **Not checked: a real window.** Nothing was shown on a screen and
  no key or mouse of SDL's was read: to try by hand,
  `_build/default/tiny/TinyMachine.exe -window
  tiny/tests/TinyMachine_tests/screen.tm` (a grey screen, a blue rectangle,
  a white square where the mouse goes, red with a button down).
- Left for later steps: the machine's rate and held keys repeating
  (step 5), `./tiny-machine`'s option for the window (step 3, when a
  kernel draws).
- On macOS the tests want GNU's `stat` and `wc` first in the PATH
  (coreutils' gnubin): `TinyMachine_test.sh`'s periods and
  `TinyKernel/Makefile`'s boot.img fail otherwise, as before this
  step.

**Step 2 (2026-10-08): `TinyGraphics.ml`, on the host and on
tiny-machine.**

- `tiny/TinyGraphics.ml`, 263 lines, 123 of code: images, `draw`,
  `line`, `text` (the plan's `string`: a type's name), the font made a
  mask, the images' memory (free blocks, first fit, joined when
  freed), a connection and its `messages`. The messages are a letter
  and numbers of 16 bits (`a`, `f`, `d`, `l`, `s`: the file's header
  has them); a bad one raises `Graphics`, with what is wrong.
- **The same file by OCaml and by tiny-ml**, decision 11 done here and
  not in step 5, since this step needs it: `tiny-ml a.ml b.ml`, the
  files one program, an error under its own file's name; `open M`
  read and left (19 lines of `TinyML.ml`). The author: "I like this
  TinyML change", and "keep TinyML simple, and get more compatibility
  with modern ocaml and allow split some code in multiple files (a
  bit like tiny-asm which does the linker work too)". What the
  machine gives is `TinyMemory`'s five names (`peekb`, `pokeb`,
  `row_copy`, `row_fill`, `row_mask`): `tiny/TinyMemory.ml` on the
  host, an array of 16 MB with the machine's addresses and its PPM;
  `TinyKernel/memory.ml` on the machine, five externals, the rows in
  `TinyKernel/draw.tm` (68 lines of assembly, a byte at a time).
- The test, `TinyGraphics_test.sh` (in `make test` and
  `tests/lite.sh`): `TinyGraphics_tests/Picture.ml`, a picture drawn
  by messages only (rectangles off the screen's sides, texts, lines,
  an image off the screen drawn whole, cut and from a point, a pattern
  as a source and as a mask, an image drawn on itself the four ways,
  an image freed and its memory taken again) and thirteen bad
  messages with their answers. Run twice: by OCaml on the host, and
  by tiny-ml -tm on tiny-machine with no kernel (`start.tm`,
  TinyKernel's `runtime.c`). **The two screens are the same PPM**
  (one `picture.cksum`) and the lines the same; the picture was
  looked at. `TinyGraphics_test.sh -window` shows it in the
  machine's window (run under SDL's dummy driver only: not seen).
- What it found: the font's left pixel is the low bit; tiny-ml -tm
  refuses a list of thirteen elements ("an expression too deep": 11
  registers), so the picture's writes are messages joined by `^`.
- Checked too: `TinyML_test.sh` (0 failures), tiny-kernel's `make
  check` with the new tiny-ml, `TinyMachine_test.sh`, mini-ml over
  `tiny/` (22 of 22).
- **The speed, on tiny-machine** (this host, the machine built by
  OCaml): the screen filled in 98 ms, its half copied in 82 ms, a
  cell of 20 by 20 in 0.43 ms, a point in 0.14 ms (a line is its
  points). So Tetris's 250 cells are about 110 ms a frame as it is,
  before the messages' decoding and the pipes: to measure in step 5,
  and the first thing to make faster is known (the rows a word at a
  time, a line's points without a `draw` each). The machine ran this
  code at about a fifth of step 1's 57 million instructions a second
  (a loop of 20 instructions, a million times, 1.9 s): loads and
  stores, where the counting loop had none. Not looked into.
- Not done, left to step 3: the font in the kernel's image (the test
  makes a `.tm` of `font1.bin` with `od`), `/draw`, where the
  images' megabyte is.

**Step 3 (2026-10-08): TinyKernel.ml draws: `/draw`, `/mouse`,
`ready`, `ticks`; `paint`; `./tiny-machine -window tiny-kernel`.** The
author, of step 2: "I'll wait for the tiny-machine script to be
updated with this new graphics featured kernel".

- `TinyKernel.ml`, 564 lines to 657 (about 60 of code): two nodes,
  `/draw` and `/mouse`; two kinds of open file, `Draw` (a connection
  of TinyGraphics's, counted: its images are freed at its last
  descriptor's close, a process's end included) and `Mouse` (a read
  waits for a change, then x, y and the buttons, a word each); the
  mouse's interrupt; `ready(fds, n, until)` (15), one closure over
  `readable`, and `ticks()` (16), the timer's interrupts counted. A
  write to `/draw` is messages; a bad one answers -1 and is said on
  the console (`draw: no such image`).
- Its build: `tiny-ml -tm memory.ml ../TinyGraphics.ml
  ../TinyKernel.ml`; `draw.tm`; `font.tm`, made by the Makefile of
  `kernels/lib_machine/font1.bin` (`od`, `sed`), with `k_font`.
- The memory: eight partitions, not ten (the plan's recommendation);
  the two megabytes freed, and what the screen leaves of its own, are
  the images'. `mltests` passes as it did.
- The C side: `user/draw.h` and `draw.c` (the messages gathered in a
  buffer: `d_fill`, `d_text`, `d_line`, `d_flush`...; the plan had
  them in step 4) and `user/paint.c`, a page: the mouse paints with a
  button down, a ball crosses the top by the clock, `c` clears, `q`
  quits; one loop on `ready`.
- The test, in `make check` (now in `make test` too): `paint.events`,
  a session of fifteen events (paint typed, the mouse with each
  button, a clear, a place where it must not paint, `q`), its screen
  at the halt against `paint.cksum`; the same twice. Looked at.
  `check.expected` is the new console (8 partitions, `paint`, `draw`
  and `mouse` in `ls`).
- `./tiny-machine -window tiny-kernel`: the kernel's screen in the
  window. **The console stays the terminal**: the shell's prompt and
  what it prints are there, since nothing writes text on the screen
  before step 4's windows. So tiny-machine now takes the terminal's
  keys with `-window` too (it took the window's only): `paint` is
  typed at the terminal, the mouse and `c` and `q` in the window.
  Run under SDL's dummy driver first; seen in a real window with
  step 4's tiny-windows (below).
- What it found: the kernel is at its prompt after some 20 million
  instructions (the files' bytes copied one at a time, the font's
  mask), and a mouse's places while a program is busy are lost but
  the last (the mouse is a word, not a queue): a clear of the screen
  loses one. Both are in `paint.events`'s times.
- Checked: `TinyGraphics_test.sh`, `TinyMachine_test.sh`, mini-ml
  over `tiny/` (`TinyKernel.ml` says `open TinyGraphics` for it).
- Left: a read of `/draw` (a window's size: step 4 says where it
  comes from), the machine's rate (step 5), the speed (above).

**Step 4 (2026-10-08): `TinyWindows.ml`, the window system, a program
in ML; in one of its own windows too.**

- **An ML program as a process of TinyKernel.ml**, the plan's risk:
  it ran the first time. `user/mlsys.c` (146 lines) is TinyML's
  runtime given the partition's memory (the heap from 384 KB, fixed
  addresses: nothing of it in the program's file) and the system calls
  as externals (`u_read` a string, `u_spawn` a program with five
  descriptors). No fallback to C was needed.
- `tiny/TinyWindows.ml`, 442 lines, 248 of code (300 estimated, with
  what follows not planned): windows as images off the screen,
  composed back to front in the rectangle that changed; a window's
  text (cells, a cursor, scrolling by the image drawn on itself, a
  line edited); its picture (its programs' messages read from a pipe,
  cut where a message is whole, renumbered, sent on); the menu (New,
  Move, Delete, Exit), the sweep and the drag with their outlines;
  one loop on `ready`. `tiny/TinyDraw.ml` (54 lines) is a program's
  side of the messages, which the graphics test's picture now uses.
- **What changed in the plan's design, each found by writing it**:
  - *The kernel gives the first shell the screen as its 3 and the
    mouse as its 4* (decision 5 said "from the kernel", not how): its
    programs inherit them, so `paint` no longer opens `/draw` and
    `/mouse`, and draws in a window when run there, unchanged.
  - *A window's mouse is a box*, a new kind of file and a call
    (`box(fds)`, 17): a pipe that keeps the last write only. With a
    pipe, a program that does not read its mouse (the shell) would
    have stopped the window system at the 43rd move. The kernel's own
    mouse is one too, which the interrupt writes.
  - *An image made with a number that has one replaces it* (`a`):
    the programs of a window share its connection, and one run twice
    makes its colours twice.
  - *A window is a text or a picture* (decision 14, extended to the
    mouse): a picture from a draw in it to the next print, so that the
    shell has its lines again when `paint` ends.
  - *No size told to a program*: it draws from (0, 0) and the window
    shows what fits; tiny-windows in a window takes the screen's 640
    by 480 and is clipped. An exercise.
  - 32 descriptors a process (8), for four a window.
- **The speed**, measured by a counter of instructions put for the
  time in tiny-machine (removed after: `PROFILE`, by who and where).
  An `ls` in a window was 33 million instructions, 3 seconds; a ball
  moving in a window more than the machine has. What was changed,
  each with its `old:` in the code:
  - the kernel's files of the image stay where the image has them
    (`Rom`, an address and a size) and are no longer strings: a
    megabyte of programs was copied at each collection, 3 million
    instructions;
  - when every process waits, the kernel retries their calls at a
    key, the mouse or a time asked for (`alarm`), not at each tick: a
    quarter of an idle machine's instructions; and a shell's `wait`
    is retried when a process ended;
  - the rows copied and filled a word at a time (`draw.tm`), which
    asks that an image and a window's inside start at a multiple of
    4: the images' blocks are whole words, a window is snapped;
  - a window shows the rectangle that changed, not all of itself;
    a text is one message a run of characters; a number's two bytes
    come from a table.
  After: an `ls` in a window 17 million instructions (the fork and
  exec of it 2.6), a ball's move 220,000 (147,000 the kernel's), an
  idle machine 1% in the kernel. **Still slow**: tiny-machine runs
  this code at about 10 million instructions a second, and a third of
  the kernel's are `ml_alloc`'s (tiny-ml calls C for each tuple and
  closure). The two things that would change it most are not in this
  plan: tiny-machine's own loop (an instruction decoded into a value
  of the heap at each step), and tiny-ml's allocation in line; a
  plan of its own, if wanted. Step 5's Tetris is to be measured with
  this in mind (a frame of 250 rectangles through two pipes).
- **Found**: the image had grown to 920 KB of the megabyte below the
  kernel's stack of values, and one program more was past it
  (`docs/plans/bugs/ix.md`): the stack is at 1.5 MB, the Makefile
  checks. tiny-ml -tm makes a record of nine fields at most (`window`
  is three records); `List.iteri` added to its prelude.
- The tests, in `make check` (now 44 seconds): `windows.events`,
  three windows, `ls`, `paint` and the mouse in one, a move, a
  delete, one brought to the front and typed in; `nested.events`,
  tiny-windows in a window of tiny-windows, two windows in it, a
  command in each. Each screen against its sum, the same twice, and
  with the events' gaps 1.7 times longer; looked at. `paint.events`
  and `check.expected` recorded again (the ball goes by 50 ticks; the
  sizes).
- `./tiny-machine -window tiny-kernel`, then `tiny-windows`: by
  recorded sessions first; then tried by the author in a real window
  (2026-10-08): "I tested tiny-windows. It works!".
- Left: a mouse's places while the window system is busy are lost
  but the last, so a button pressed and let go at once may not be
  seen (the sessions leave 2 million instructions between two); a
  line typed to a window whose program does not read may stop the
  window system (a pipe's write waits when it is full); a window's
  programs still running when it is deleted end at their next write.

**Step 5 (2026-10-08): `TinyPlayground.ml`, and a first game.** The
author: "let's do step 5".

- `tiny/TinyPlayground.ml` (138 lines, about 45 of code): the shapes
  (`Rect`, `Words`, `Group`, `Move`), `game` (the picture's size,
  `init`, `view`, `key`, `frame`), `random` (Lehmer's by Schrage's
  division, modulo 2^30 - 35), the picture (the shapes drawn in an
  image off the window, then that image on the window; a colour's
  image made at its first use) and `run`, the loop on `ready`.
- Its machine is four calls, `TinyCalls`'s: `tiny/TinyCalls.ml` on
  the host, where what is written to descriptor 3 is kept;
  `TinyKernel/user/calls.ml` on the machine, externals. So the same
  files are OCaml's and tiny-ml's, as decision 11 wanted, and a game
  is a last file of one line, `let () = run game`.
- **Other than the plan**: `Words` has no size (one font, 8 by 16; a
  larger text is an exercise with TinyGraphics.ml's); a game says its
  picture's size; **a picture is drawn when its shapes are others
  than those shown** (`<>`), not when the model is another (`!=`
  alone, the plan's): a model that counts its frames is another at
  each frame, and the square was drawn thirty times a second for a
  blink of two.
- The first game, `tiny/tests/TinyPlayground_tests/Square.ml` (a
  page): a square the arrows move on a field, blinking, the seconds
  counted; `square` on the machine.
- The tests: `TinyPlayground_test.sh` (in `make test` and
  `tests/lite.sh`), on the host with no machine: the game's own
  functions make a model (keys, frames; the field's top stops the
  square), its shapes are shown, TinyGraphics.ml draws the messages
  kept: the lines and the screen's sum; looked at. And in
  TinyKernel's check, `play.events`: tiny-windows, a window, `square`
  typed in it, nine arrows; the screen's sum, looked at. It ran the
  first time.
- **The machine has a speed** (decision 13): with `-window`, 8 million
  instructions a second, not the 20 planned: what the host gives of a
  kernel's and its programs' instructions is about 10. It sleeps when
  ahead and does not catch up. **A key held repeats**
  (`TinyMachineWindow.ml`: after 0.3 s, twenty times a second; the
  display says a press once). Neither can be seen by a recorded
  session: **to try by hand**, `./tiny-machine -window tiny-kernel`,
  `square`, an arrow held.
- **The kernel's clock** counted a tick at each interrupt of the
  timer, set again from then: while the kernel works the interrupt
  waits, and ticks were lost (mini-9pi's bug of 2026-10-07, here
  too). Now the ticks are the machine's time's (`k_clock`), and a
  frame is a period after the last one's time, not after its end.
- A frame's cost, measured by the seconds the square counts: alone on
  the screen about 55,000 instructions over the 260,000 of its
  period, when nothing is drawn; in a window the count was 4 where
  some 6 were due, not explained (the window's blink, drawn twice a
  second through two pipes, is part of it). To look at with Tetris.
- The image is now 1,055,000 bytes: past the megabyte that step 4's
  bug was about, under the 1.5 MB the Makefile checks.

**Step 6 (2026-10-08): `TinyTetris.ml`, in a window: the plan's
goal.** The author: "let's commit and do step 6".

- `tiny/TinyTetris.ml` (195 lines, 80 of code; 200 estimated), written
  anew on TinyPlayground: the well of 10 by 20, the seven pieces (a
  turn is four hexadecimal digits of a string), their colours, the
  next one shown, a row filled removed, the score (100, 300, 500, 800
  by the rows at once, times the level and one; 4 a piece), a level
  every ten rows (a row's fall a second, a tenth less each level);
  the arrows, the space to drop; a game over and the space for
  another. `TinyKernel/user/tetris.ml` is the program's one line.
- **The ground**, the playground's part of it (+23 lines there): the
  first of a model's shapes is kept drawn in an image of its own and
  drawn again only when it is another one; the picture is a copy of
  it, the kernel's, and the other shapes. Tetris keeps its ground in
  its model (the well's cells, the panel, the next piece: made when
  a piece lands), so a piece that moves is a copy and five shapes.
  Without it a move was every cell again, a hundred messages through
  two pipes: step 5's worry, answered before it was measured.
- The tests. `TinyTetris_test.sh` (in `make test` and
  `tests/lite.sh`), on the host with no machine: three games by the
  game's own functions, each a seed and a script of keys and frames,
  the well printed as text (a piece falling by the clock, stopped by
  the sides, turned, dropped; a well filled, the game over, where
  keys do nothing, and another game; two I and an O that fill a row,
  which is removed, the O's top half coming down, 100 points); and
  the last model's picture by TinyGraphics.ml. In TinyKernel's check,
  `tetris.events`: tiny-windows, a window, `tetris` typed, six pieces
  moved, turned and dropped; the screen's sum, looked at. **It ran
  the first time**, by OCaml and by tiny-ml.
- The check is five sessions, a minute and a quarter; `windows` and
  `nested` recorded again (their `ls` has one program more).
- Not measured: a frame's cost in the window (step 5's open
  question). The session's six pieces are where its keys put them,
  4 million instructions between two keys.
- **To try by hand**: `./tiny-machine -window tiny-kernel`,
  `tiny-windows`, a window (the right button, New, a rectangle of
  300 by 350 or more), `tetris`. How it feels at the machine's speed
  is not known: a key held, a piece dropped.
- The image is 1,197,000 bytes of the 1.5 MB.
