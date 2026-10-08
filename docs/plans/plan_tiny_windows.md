# Plan: TinyGraphics, TinyWindows and TinyPlayground: a screen, a window system and a Tetris in a window, for tiny-machine and tiny-kernel

Status: **step 1 done (2026-10-08), for review; the rest to do.**
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
- **A font.** `kernels/lib_machine/font1.bin`, 256 characters of 8 by
  8 bits, 2,048 bytes.

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
- `string`: the font's 8 by 8 characters as masks of a colour;
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
`-events`, `-window`.** Not committed: the author reviews first.

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
  tiny/TinyMachine_tests/screen.tm` (a grey screen, a blue rectangle,
  a white square where the mouse goes, red with a button down).
- Left for later steps: the machine's rate and held keys repeating
  (step 5), `./tiny-machine`'s option for the window (step 3, when a
  kernel draws).
- On macOS the tests want GNU's `stat` and `wc` first in the PATH
  (coreutils' gnubin): `TinyMachine_test.sh`'s periods and
  `TinyKernel/Makefile`'s boot.img fail otherwise, as before this
  step.
