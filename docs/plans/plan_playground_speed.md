# Plan: the playground fast on mini-9pi: what a frame costs, from the program's shapes to the screen's pixels, and what would let a game that redraws everything (Doom) run on the Pi1 and the Pi4 (`lib_playground/`, `lib_graphics/`, `kernel/9pi/`, `languages/ml/`)

The author (2026-10-07), having played Tetris on mini-9pi
([`plan_playground.md`](plan_playground.md), stage 2): "it is very
slow and not super responsive to the keys"; "this is a simple game so
this should be fast"; "so what prevents to reach 60fps? like I have on
Linux"; "so sending an image each time to the draw device is fast
enough? and can reach 60fps? How does doom9 work under 9front?"; "let's
profile the load in the kernel"; then: "let's make a plan document to
optimize the playground speed. There are lots of places (kernel side,
user side, C memmove, fast path, mini-ml, 32 vs 16 bits, removing some
copy, mini-ml extension (Bigarray can help?), etc."; "let's consider
everything that could make it possible to run fast pace games like
Doom on the Pi1 and Pi4"; and: "can we configure the raspberry pi to
use 32-bit pixels?"

Where it stands: Tetris is 51 to 52 frames a second under QEMU,
because a frame draws only what changed (`Redraw`). **A frame drawn
whole is 2 a second.** A game whose every pixel changes at every frame
is that second case, and this plan is about it.

Its numbers: `games/speed.sh` (instructions, by mini-5i: no host
changes them), and seconds under QEMU on the author's machine
(a Neoverse N1), each said with how it was taken. **No number here is a
real board's.**

## The survey (2026-10-07, measured)

### A whole frame, 480 by 480, under QEMU

    the program (mini-ml's code, arm)                    the kernel (ocaml-light's ocamlopt)
    +-----------------------------------+                +------------------------------------------+
    | the view's shapes                 |                |                                          |
    |   | Shape_render_software  0.57 s |                |                                          |
    |   v                               |                |                                          |
    | Framebuffer (32 bits a pixel)     |   16 writes    | copied in from the process       0.015 s |
    |   | Display.load: 4 copies,       | -------------> | the pixels cut out of the message 0.013 s |
    |   v  then write          ~0.10 s  |  of 60 KB      | into the image, a byte at a time  0.091 s |
    |                                   |                | drawn on the window, 32 bits to 16 0.02 s |
    |                                   |                |   (2.1 s before Memdraw's path for it)   |
    +-----------------------------------+                | the screen's memory to the framebuffer   |
                                                         +------------------------------------------+

- The program's three figures are its own clock's around each step
  (taken out since). The load is 0.22 s for the program: 0.12 of it in
  the kernel, by a count of the timer's microseconds around
  `syspwrite`'s copy in, `Devdraw`'s `String.sub` and `Kdraw.memload`
  (64 loads, four frames: 58, 53 and 365 ms; taken out too). The 0.10
  left is the program's side, **not measured by itself**.
- **A pixel is copied nine times** between the program's Framebuffer
  and the screen: `Bytes.sub_string` (the band), `Buffer.add_string`
  (the message), `Buffer.add_buffer` (the display's buffer),
  `Buffer.contents`, the write's copy in, `String.sub`,
  `Memimage.load` (a byte at a time, each through two functions that
  check its index), `Memdraw` (to the window's 16 bits), and the
  screen's memory to the framebuffer. Plan 9's C does about four (the
  program's buffer, the kernel's, the image, the screen: from memory).

### The instructions (`games/speed.sh`: mini-5i, a game built for arm)

| | instructions |
|---|---:|
| a whole frame of Tetris: its shapes drawn, 230,400 pixels | 143,921,679 |
| a frame's change (`Redraw`: the falling piece) | 353,371 |
| the program's start, one frame, the picture written | 764,570,668 |

625 instructions a pixel for a frame that is mostly white: the cost is
the shapes' (250 squares, each a polygon filled with smooth edges: lists
of edges, floats, a closure a span), not the pixels'. A Pi1's ARM1176
runs at 700 MHz and less than an instruction a cycle: **4 whole frames
a second at the very most**, before the load.

### mini-ml against OCaml, the same source (Linux, arm64, one frame of 1,000 by 1,000)

| | mini-ml | OCaml 4.14 | times |
|---|---:|---:|---:|
| the shapes drawn | 0.22 s | 0.019 s | 12 |
| a million pixels set one by one (four `Bytes.unsafe_set` each) | 0.56 s | 0.010 s | 55 |
| the picture written (three `Buffer.add_char` a pixel) | 0.57 s | 0.024 s | 24 |

What is known of why:

- **A byte read or written is a call of C, and so is every float's
  operation** (`languages/ml/simple/Lower.ml`'s `prim`):
  `%string_unsafe_set` is `CallC "ml_string_set"`, which checks the
  index all the same; `%addfloat` is `CallC "caml_addfloat"`. Only an
  array's element is code in place. A loop of a million
  `String.unsafe_set` is 73 instructions a byte on arm (mini-5i),
  about 25 of them the loop's own (each value through the frame's
  slots) and the rest the call; ocamlopt's is a handful.
- **And `Bytes.unsafe_set` was a call around that call**: lib_core's
  `Bytes.ml` said `let unsafe_set = String.unsafe_set`, a function: 99
  instructions a byte, 327 a pixel of four (M1, done: below).
- **A float is boxed, always** (plan_ml.md): each `+.` allocates, and
  an allocation is a call of C
  ([`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md):
  `ml_alloc` 21% of its benchmark, the curried calls 19%, a call's
  entry and exit the rest). The renderer is floats and closures.
- That plan's target is the kernel and ix built by ix, its ratio 4.6;
  this one's programs are at 12 to 55: floats and bytes, which its
  benchmarks do not have.

### What a Doom asks

- **id's Doom** draws 320 by 200 pixels of 8 bits, 35 times a second,
  by columns and spans in integers (fixed point): no float, no list in
  its inner loops. 9front's port (from memory, not read here) draws it
  in the program, makes 32-bit pixels of it through the palette,
  scaled, and gives them to the draw device: `loadimage`, `draw`,
  `flushimage`: this plan's path. At twice its size: 640 by 400, a
  megabyte a frame at 32 bits, **36 MB a second** through the load;
  mini-9pi's is 4 under QEMU (921 KB in 0.22 s).
- **The playground's own** (`games/fps/TinyDoom.ml`, 499 lines;
  `TinyWolfenstein.ml`, 306) draw with shapes: a rectangle a screen
  column, polygons: floats (`Float.` 33 times). Every column changes
  when the player turns: `Redraw` finds the whole picture changed. For
  them the cost is the first box of the figure, 0.57 s.
- So two different games: one that makes its own pixels and wants the
  path from a Framebuffer to the screen short; one that gives shapes
  and wants shapes drawn fast.

### The rest

- **The screen is 16 bits a pixel** (`Swconsole`: principia's choice).
  The firmware gives 32 as well, by the same request (the mailbox's
  depth: `kernel/squeak` asks for it, and mini-qemu and QEMU answer).
  With 32: the program's pixels are the screen's, the draw is a copy
  (`Memdraw`'s path for one chan), the screen's memory doubles (1.2 MB
  at 640 by 480), every recorded screen's sum changes (the colours
  lose no bits any more), and the C pixels' twin check is no longer the
  C 9pi's. Not tried.
- **mini-9pi's clock ticks 100 times a second** and a sleep is counted
  in its ticks: the loop is woken each tick and asks the clock (done:
  52 frames, not 60: a frame longer than a tick draws two as one).
- **The Pi4's processes are arm's** (AArch32 at EL0): mini-ml's arm64
  code does not run there yet.
- **The C pixels** (`make PIXEL=c`) are no faster for Tetris today (42
  to 43 frames with `Redraw`, 2 whole): the kernel's part of a whole
  frame is 0.14 s of 0.8. They have not been measured on the load
  alone.

## The budget

A frame of 320 by 200 at 35 a second on a Pi1, were it 500 million
instructions a second (a guess, to be replaced by a measure): **14
million instructions a frame**, for the game, its pixels and their way
to the screen. Today a whole frame of Tetris's shapes at 480 by 480 is
144 million, and its load some tens more (not counted yet: the kernel's
instructions are mini-qemu's to count).

## The candidates

Each to be measured before and after (the toolchain plan's principles:
measured first, the simple path stays and the faster one is beside it,
switchable, the lines counted). The gains are guesses until then.

### The kernel (`kernel/9pi`)

| | what | aims at |
|---|---|---|
| K1 | **`Memimage.load` by rows**: a row whose pixels are whole bytes is one `String.blit` (a memmove), the bits' merge kept for the ends of the small depths | 0.091 s of the load's 0.12 |
| K2 | **No `String.sub` in `Devdraw`'s `y`**: the load takes the message and where its pixels start | 0.013 s |
| K3 | **The copy in, by pages, with memmove** (to look at: `Mmu.read`'s pieces put together) | 0.015 s |
| K4 | **A load straight into the window** when the pixels are the window's chan: no image between, no draw | a copy, and the draw |
| K5 | **The screen 32 bits** (the author's question): asked of the firmware; `Memdraw`'s copy path then does the program's pictures | the conversion, K4 made possible for 32-bit pixels; costs: above |
| K6 | **The screen's memory is the framebuffer**: no shadow copied to it at each flush (to look at: why there is one; the cursor) | a copy |
| K7 | **`String.blit` and `fill` in the kernel's runtime are C's memmove and memset, a word at a time** (to check that they are, and what mini-cc's or gcc's is) | every copy above |
| K8 | **The framebuffer in the program's memory** (a segment, as Plan 9's `segattach` gives one; to read how, and whether mini-9pi has it): the program writes the screen. Not the draw device's way, and nothing for a window of rio's; the fastest there is on the bare screen | everything after the program's own drawing |
| K9 | **The draw device scales**: 9front's Doom is said to give one row and have it drawn several times (a repl image); to read its code first | half or three quarters of a scaled picture's bytes |
| K10 | **The clock at 1,000 a second**, or a sleep that ends at its time by the timer's compare | 52 frames to 60 |

### The program's library (`lib_graphics`, `lib_playground`)

| | what | aims at |
|---|---|---|
| U1 | **`Display.load` without its copies**: the message's 21 bytes and the pixels written from where they are (one buffer kept, or two writes if the device took the pixels in a second one: it does not, a message is whole) | the 0.10 s, four copies of nine |
| U2 | **One write a frame**, not sixteen of 60 KB (what limits a message: to read in `Devdraw`; a window's writes go to the kernel's device, not through rio) | fifteen system calls |
| U3 | **The Framebuffer in the screen's format** when it is 16 bits (two bytes set a pixel, not four; half the load) or K5 | bytes |
| U4 | **`Redraw`** (done): what changed only | everything, for a game that changes little |
| U5 | **The rasterizer**: a shape outside the box drawn is not looked at (its bounds first); a rectangle that is not turned is spans, not a polygon with smooth edges; the edges an array, not lists; a span's closure gone | the 144 million instructions |
| U6 | **A game draws pixels**: the playground's `Bitmap` form and `Blit` (not copied yet): a Doom that makes its picture gives one bitmap, no shape | the rasterizer, for such a game |
| U7 | **The loop without its processes** when nothing else is waited for: a game on the bare screen reads the keyboard without waiting (to see what Plan 9 gives: a read of `/dev/cons` waits) | the pipe, two processes a key |

### mini-ml and its library (`languages/ml`, `lib_core`)

| | what | aims at |
|---|---|---|
| M1 | **`Bytes.unsafe_get` and `unsafe_set` the primitives**, as `String`'s are (done: Status) | a call of two a byte |
| M1b | **A string's byte read and written in place**: `%string_unsafe_get` and `_set` (and the checked ones, their test in place) instructions of the stack machine, as an array's `Index` is, not calls of C | the 73 instructions a byte: every pixel, every `Buffer.add_char`, every lexer |
| M4a | **A float's operation in place**: the two floats' bits loaded, the VFP's instruction, the result boxed (with the toolchain plan's A, the allocation in place too) | a call of C an operation: the renderer's, every float game's |
| M2 | **A pixel's four bytes in one store**: `Bytes.set_int32_le` (OCaml's) a primitive, one instruction; the same for 16 bits | four stores a pixel made one |
| M3 | **Bigarray** (the author's question). What it would give over `Bytes` once M1 and M2 are there: elements of 32 bits read and written whole (M2 gives that), memory outside the heap (the collector does not copy a megabyte at each collection: **to measure**, Cheney's copies everything live), and the playground's own source unchanged (`Framebuffer`, `Rgba_image`). Its cost: a type of its own in mini-ml, the `.{ }` syntax, a part of the runtime. Proposed: M1 and M2 first, the collector's share measured, then decide | the collector's copies, the source's sameness |
| M4 | **Floats not boxed** inside a function (a float that does not leave it stays in a register), and in a `float array`: the largest change, the renderer's and every float game's | the 12 |
| M5 | **The toolchain plan's A to D**: the allocation inline, `f a b` in one call, a call's entry, known functions called directly and small ones inlined | the same 12, and everything else |
| M6 | **A large object is not copied** by the collector (a space for them), or the collector is generational (that plan's G) | a Framebuffer of a megabyte, live for ever |
| M7 | **arm64 processes on the Pi4** (mini-9pi's, not mini-ml's: its arm64 code exists) | the Pi4 at its own speed |

### The measures themselves

| | what |
|---|---|
| E1 | **A real Pi1 and a real Pi4**, by the author: the same Tetris, `redraw=all` and not, its frames a second read on the screen. Everything above is an emulator's |
| E2 | **The kernel's instructions for a load**, by mini-qemu's count (`-prof`, `pcprof.py`: the toolchain plan's tools), so that the kernel's candidates are numbers of instructions too |
| E3 | **A second benchmark that is a Doom's inner loop**: columns of a texture drawn into a Framebuffer in integers, 320 by 200, no shape: `languages/ml/tests/bench/`, counted against ocamlopt's (`count.sh`). It says what M1 to M5 buy for that kind of game before one exists |
| E4 | `games/speed.sh` kept, its three numbers in this file's Status after each step |

## Decisions (the author, 2026-10-07)

1. **The target is the playground's TinyDoom** (`games/fps/TinyDoom.ml`,
   not TinyDoom3d): "ideally we take TinyDoom and make it run fast
   with ix's playground". It gives shapes: runs of screen columns of
   one colour as one polygon each (a staircase along the columns), a
   few rectangles, words; floats throughout. So what is to be fast is
   **shapes drawn**, the 0.57 s of a frame's 0.8, before the way from
   the pixels to the screen. What it needs that is not here yet:
   `Sectors` (the playground's gamekits/sectors, 174 lines) and **keys
   held** (it turns while left is down: `k.kleft`,
   [`plan_playground.md`](plan_playground.md)'s stage 4).
2. **The framebuffer in a program's memory (K8) is postponed**: "use
   that only as a last resort".
3. **The screen at 32 bits (K5) is accepted** ("I'm ok with it; will
   this help performance? What are the pro and cons?"). What it is
   worth, for this target:
   - For: the program's pixels are the screen's, so the draw is a copy
     and not a conversion (0.02 s a frame since `Memdraw` has a path
     for it: little is left to win there); a load could go straight
     into the window (K4: a copy and the draw less, a few hundredths
     of a second of a frame's 0.8); the colours keep their 8 bits (a
     gradient's bands go); one format in the system, and no conversion
     to explain.
   - Against: every pixel the kernel writes is twice the bytes: the
     console's scrolling, rio's windows moved, the fills, the copy of
     the screen's memory to the framebuffer (to measure: the boot's
     time under mini-qemu says it); 1.2 MB of screen for 0.6; the 162
     recorded screens recorded again; the C pixels' check against the
     C 9pi left at 16, or the C 9pi asked for 32 too.
   - So: **not the first thing**, and not a large gain for TinyDoom,
     whose time is in its shapes. Done at stage 4, measured both ways
     (a switch at build time, as `PIXEL` is), and kept if the console
     and rio do not pay more than the games gain.

## The stages (each measured before the next)

1. **TinyDoom runs**, slow: `Sectors` copied, the keys held
   (plan_playground.md's stage 4: the kernel's file of keys down and
   released, mini-rio's), the game in `games/fps/`, its golden frame
   against the playground's (the `ppm` platform), on mini-9pi. Its
   numbers: `games/speed.sh fps/tinydoom` (the instructions of a whole
   frame) and its frames a second under QEMU. **These are the plan's
   meter from then on.** With them E2 (the kernel's instructions for a
   load) and E1 (the author's boards).
2. **The cheap ones, whose cause is read already**: M1 (`Bytes`), K1
   and K2 (the load), U1 and U2 (the message). Expected: the load's
   0.22 s to a few hundredths. (Done but K2: Status.) Then **M1b**,
   mini-ml's own: a byte in place.
3. **The shapes, in the library**: U5 by what a profile of TinyDoom's
   frame says (its polygons are long and thin: the filler's lists of
   edges, the closure a span, the smooth edges' cells).
4. **The screen**: K5 (32 bits) as decision 3 says, K4, K6.
5. **The shapes, in mini-ml**: M4 (floats not boxed) and M5 (the
   toolchain plan's A to D), each by what it buys on TinyDoom's frame.
6. **By what is left**: K9, K10, M2, M3, M6, M7; a game that makes its
   own pixels (U6, E3) if one is wanted; K8 last.

## Open questions

- Bigarray (M3): only if the playground's source staying the same is
  worth its lines; the plan proposes not yet.
- The C 9pi's check when the screen is 32 bits: left at 16, or the C
  kernel asked for 32 too?

## Status

2026-10-07, **stage 2's cheap ones, before stage 1** (the author:
"ideally we can write fast in the draw device the image and the kernel
can then copy it fast to the real framebuffer"). A whole frame of
Tetris, 480 by 480, under QEMU:

| | the shapes | the load | a whole frame |
|---|---:|---:|---:|
| before | 0.57 s | 0.22 s | 0.8 s |
| M1: `Bytes.unsafe_get` and `unsafe_set` the primitives (`external`s in lib_core's `Bytes.ml`) | 0.36 | | |
| U1, U2: `Display.load_sub`, the pixels copied once into one message, one write a picture (921 KB: the kernel takes it) | | | |
| K1: `Memimage.load` a row a blit (`fast_load`) | 0.36 | 0.06 | 0.42 |

And in instructions (`games/speed.sh`, arm): a whole frame 143,921,679
before M1, **115,460,871** after; the program's start with a frame and
its picture written 764,570,668, then 574,443,878. On Linux (arm64),
five whole frames: 1.82 s, then 1.28. A frame's change by `Redraw`
went from 353,371 to 487,427, **not explained** (the collector's
copies of the picture are suspected: M6).

What M1 showed: the objects of a program that names a unit of
lib_core's are not made again when that unit changes (the games'
mkfile depends on its own sources): the first measure after the
change was the same number to the instruction, the games not
recompiled. `rm -rf _mk/5/games _mk/5/lib_playground
_mk/5/lib_graphics/software` before a measure, until the mkfiles say
it.

Not done of stage 2: K2 (`Devdraw`'s `String.sub`, 0.013 s: the
load's function is the C pixels' too), K3. What the load's 0.06 s is
now is not split again.


2026-10-07: plan written, after the survey; the author's decisions
(the target, K8 last, the screen's 32 bits). Nothing done but what
[`plan_playground.md`](plan_playground.md)'s stage 2 did on the way
(`Redraw`, `Memdraw`'s path from 32 bits to 16, the clock, the loop).
