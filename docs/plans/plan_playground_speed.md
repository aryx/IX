# Plan: the playground fast on mini-9pi: what a frame costs, from the program's shapes to the screen's pixels, and what would let a game that redraws everything (Doom) run on the Pi1 and the Pi4 (`lib_playground/`, `lib_graphics/`, `kernels/9pi/`, `languages/ml/`)

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
  depth: `kernels/squeak` asks for it, and mini-qemu and QEMU answer).
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

### The kernel (`kernels/9pi`)

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

2026-10-08 (later), **three things the author found playing**
(`docs/plans/bugs/ix.md`, the three rows of that day): a key that
stayed down after twenty seconds of TinyCameltry (QEMU's keyboard
queue of 16 filled by the host's repeat, the release dropped: the USB
keyboard is now read until it has nothing more, `Usbdwc.epread` and
`Kusb.clock`; `kernels/9pi/tests/perf/held.py`, 14 releases lost of 87
messages before, none after, by usbd and by the kernel's reader); no
echo at the console after a game was quit (`consctl`'s last close
turns raw off); Tetris at 4 frames a second (the frames drawn were
counted, and its picture seldom changes: the frames made are, 60).
A first fix of the first, in `Kusb.clock` alone, seemed to work: the
test compared two screens, and the moon rolling moved the maze; and
the card's kernel reads the keyboard by usbd, not there. The test
reads the game's own keys now (`keys=on`).

2026-10-08, **a frame of the draw platform, from 100 ms to 30 and 26**
(the author, having played: "the keyboard is not responding, the fps
are really slow; this is not a good platform for gaming :( we really
need to improve this"; then "you have 8 hours to try to figure out why
and have some optimizations ready, so we can do games on the pi1 with
mini-9pi"). Under QEMU, the right arrow held, the meter's lines
(`stats=on`: `kernels/9pi/tests/perf/frames.sh`), 480 by 480 on the
bare screen:

| | TinyWolfenstein | TinyCameltry |
|---|---:|---:|
| before (b180cd1) | 100 ms a frame: the view 9, the messages 39, the device 51 to 55 | 100: the update 21, the messages 14, the device 58 to 60 |
| the kernel: a polygon's and a line's runs written directly (`Memdraw.solid`), a fill's rows by adding, the screen's pattern computed | 82: the device 25 | |
| `Display`'s messages in its own bytes, written in place; a shape not turned placed by 8 products, a colour found in 256 places, a rectangle's corners | 65: the messages 19 | 57 |
| no sleep when the next tick is already due; a word's strokes kept | 55 | 50 |
| mini-ml: a block taken from the heap in place, a float's arithmetic in place | 47 | 35: the update 3 |
| the kernel: a narrow fill unrolled, memmove forward eight words a turn | 42 | |
| mini-ml: floats compared, negated in place | 42 | |
| the kernel: a fill's colour read once and by its bytes, its clip (`fillclip`) | the device 15 | |
| the kernel: a polygon's edges kept from row to row | | the device 19 to 12 |
| mini-ml: a function of another unit called with all its arguments (`calls_whole`) | 32: the view 4, the messages 10, the device 18 | 22 to 26: the update 2, the messages 3 to 8, the device 18 |
| the heap eight times what is alive for a game (`Gc.set`'s `space_overhead`); the runtime's blit and fill a word at a time; a narrow fill's rows by C (`mem_rows`); `Bytes.length` the primitive | **30** (33 a second): the view 2, the messages 9, the device 18 | **26** (38 a second) |
| the same two programs on principia's C kernel (`9pi`, its `devdraw`), under the same QEMU | 125 (the device 44 to 71): **10 a second** | 78 to 118 (the device 51 to 74) |

(The parts are read from a clock of 10 ms and summed over 40 frames:
right to 2 or 3 ms; the frames' time is the 40 frames'. Under 20 ms
a part's changes are QEMU's noise: the instructions, below, say what
the last rows bought.)

**And in instructions**, which no host changes: mini-qemu's clock is
its count (30 instructions a simulated microsecond), so the same meter
under mini-qemu (`tests/live.py` with `bin/mini-qemu`, the key held
five minutes) gives a frame's parts as instructions, 30,000 a
millisecond it prints. TinyWolfenstein, a frame:

| | a frame | the view | the messages | the device |
|---|---:|---:|---:|---:|
| after `calls_whole` (the first time this was measured) | 12.4 million | 2.1 | 3.2 | 5.9 |
| the heap for a game, the runtime's words | 11.3 | 1.8 | 2.8 | 5.8 |
| `mem_rows`, a message's room without a call | 10.5 | 1.8 | 2.6 | 5.3 |
| its rows unrolled, `Bytes.length` | **9.9** | 1.8 | 2.4 | 4.8 |

TinyCameltry (before the last two rows): 7.9 million a frame (the view
0.2, the messages 1.4, the device 6.3) and 0.48 a tick of its physics,
60 of them a second. A Pi1 that ran 350 million of these a second (a
guess: 700 MHz, half an instruction a cycle) would draw Wolfenstein in
28 ms and Cameltry in 25: **what the board is asked to say** (E1).
Under QEMU the same frames take 30 and 26 ms, by chance: QEMU runs a
tight loop of integers at a thousand million instructions a second and
this code, all calls and returns and floats, at 330.

**On principia's kernel the same game is slower** (the author: "I
wonder if the same game would be faster on the principia's kernel, on
the principia's sd card image"): the two programs copied into a copy
of its card (`mcopy -i qemu-sd.img@@512 tinywolfenstein ::wolf`), its
C `9pi` booted under the same QEMU, `bind -a '#m' /dev; bind -a '#i'
/dev; /root/wolf stats=on`: they run as they are (no `#c/kbd` there:
the keys as typed), 10 frames a second, the device 44 to 71 ms a frame
where mini-9pi's is now 18 (it was 51 to 55 before this night: the
same as the C's). Why the C's is that slow for these messages was not
looked at. Every
recorded screen is the same, pixel for pixel (`make check-all`: 118
lines, the two draw sessions among them), the games' 17 frames too by
both of mini-ml's machines (`games/tests/frames.sh`), and
`make test-lite` (ix built by ix).

**What was slow, and how it was found** (the method:
docs/notes_debugging_techniques.md, 16):

1. *The library that makes the messages* (`lib_graphics/Display.ml`):
   a number was four calls of `Buffer.add_char`, a message a Buffer of
   its own added to the display's: 12,000 instructions for a
   rectangle's 45 bytes. Now the display's own bytes, a number its four
   bytes set in place: about 1,000.
2. *The platform* (`lib_playground/platforms/draw`): three products of
   matrices and a sine for a shape that is not turned (now 8 products,
   or none); `Float.min` four times a rectangle (a function of 350
   instructions: whole numbers compared instead); a colour's name
   parsed by making a string; the table of colours' hash; the frames a
   second's words laid out and placed again at each frame (kept now).
   All behind `fast`, the old way beside.
3. *The loop* (`Plan9_loop`): when a frame is late, the next tick is
   due already, and the shortest sleep waited for the kernel's next
   tick: 5 ms of each frame for nothing. A sleep of 0 (a yield) then.
4. *mini-ml's code*, four things, each a switch (`mini-ml -calls` turns
   them all off; `languages/ml/tests/costs.sh` counts them, arm, in
   instructions an operation):

   | | by the runtime's calls | in place |
   |---|---:|---:|
   | a float multiplied or added | 63 | 20 |
   | a float negated | 83 | 21 |
   | two floats compared | 104 | 38 |
   | an integer to a float | 58 | 18 |
   | `Float.min` | 350 | 118 |
   | a pair or a list's cell made | 45 | 17 |
   | a byte stored, unchecked | 63 | 10 |
   | `Buffer.add_char` | 219 | 85 |
   | another unit's function of 2 arguments called | 137 | 56 |
   | of 3 (`Bytes.fill`) | 670 | 163 |
   | an integer division (the Pi1 has no instruction for it) | 200 | 200 |
   | `Float.floor` | 130 | 130 |

   - M4a and the toolchain plan's A: `Gen.alloc_in_place`, a block is
     the heap's pointer moved and compared (`ml_hp`, `ml_limit`), the
     runtime called when there is no room; `Lower.floats_in_place`,
     the VFP's instruction between two loads and a store; floats
     compared by the processor where the runtime's compare was called.
   - The toolchain plan's B: `Lower.calls_whole`. A function that is
     not known where it is called (every function of another unit: the
     whole library) was given its arguments one at a time, a closure
     made for each but the last; `ml_curry2_0` and `ml_curry2_1` were
     16% of TinyCameltry's instructions. Now the closure's first field
     says whether it takes as many as are given, and its code is
     called with them all. The curry functions are the program's, in
     its start object, no longer each unit's.
   - `languages/ml/tests/count.sh` (arm64, against ocaml-light's
     ocamlopt): `sched` 36,551,288 to 22,148,917 (4.63 times ocamlopt's
     to 2.81), `maps` 39,813,277 to 25,370,134 (1.26 to 0.80), `fib`
     and `tak` the same (3.23, 2.76: calls of known functions).
5. *The collector.* With the floats still made by calls, a frame made
   more than the heap's megabyte, and each collection copies all that
   is alive: `ML_HEAP=4194304` alone took the messages from 14 ms to 7.
   With the floats and the calls as they are now it was still 18% of
   the program's instructions (`copy`, `collect`). OCaml's own knob
   for it: `Gc.set { (Gc.get ()) with space_overhead = 700 }`
   (`lib_core/core/Gc`, the runtime's `gc_get` and `gc_set`: the heap
   eight times what is alive where twice was the rule, and is still
   the default), said by `Plan9_loop` for a game: 10% now. (M6 is
   still the answer for a game that keeps a megabyte of pixels alive.)
   And the runtime's `blit_string` and `fill_string` go a word at a
   time (the C library's `memmove` is a byte a turn): a whole frame of
   Tetris by the software platform, 103,690,330 instructions (six
   frames less one, by five) to 80,193,953; what is left there is the
   collector's copy of the picture (16%), the rasterizer's lists and
   their sort (15%).
6. *The kernel* (`Memdraw`, `Memimage`, `Memshape`; each behind
   `fast`, `fast_pattern`, `fast_read`, the old way in a comment):
   timed inside by the message's letter, a fill (`d`) was 55 µs under
   QEMU: its three images clipped (a dozen tuples, four divisions), its
   colour read three times channel by channel, a row of its pattern
   made, then its bytes set one at a time. A polygon was every edge
   looked at on every row and `List.sort compare`. memmove copied
   backwards, a word a turn, whenever the destination was after the
   source, in another string or not.

**What a frame is now** (Wolfenstein, 9.9 million instructions;
`kernels/9pi/tests/perf/steady.sh`, the kernel's functions then the
program's): the program 44% (its view 18%, the messages 24%: of the
program's own, `Display.long` 10%, the collector 10%, the rest spread
over the ray's loop, the shapes' places and the floats' boxes); the
kernel's copies 12% (`memmove`: four times the picture's 460 KB, the
image cleared, the ceiling and the floor, the image to the window, the
window to the framebuffer); the columns' pixels 10% before their rows
were unrolled; `Devdraw`'s reading of the messages 5%, `Memdraw` and
`Memimage` 6%, the kernel's collector 3%, its divisions 1%.

**Not a real board's numbers, and two things say they will differ**:

- **The Pi1's caches were never turned on.** `start.s` set the MMU,
  ARMv6's format and the high vectors, and nothing else: on a board
  every instruction and every word would be read from the memory, some
  thirty times slower than the emulators, which have no cache to be
  without. Written this night, from the ARM1176's manual, and **not
  run on a board**: `Machine.caches_on` (mini-9pi's `Main.caches`,
  true), and what the data cache then asks, in
  `kernels/lib_machine/pi1/machine.c` (its comment): the translation
  tables and a program's pages written through to the memory, the
  instructions' cache told, and the memory that a device reads by
  itself (the framebuffer, the mailbox's request, the USB controller's
  two pages) reached through a second mapping of the RAM that is not
  cached (0xA0000000). Under the emulators nothing changes (the same
  118 lines). If the first boot on the board does not go well:
  `let caches = false` in `kernels/9pi/init/Main.ml` is the kernel as it
  was. (The Pi4's start turns its caches on already; whether its
  kernel does what they ask was not looked at.)
- **QEMU's time is not a processor's**: three loops of known
  instruction counts, timed on mini-9pi under QEMU, run at 900 to
  1,400 million instructions a second for integers and bytes and 225
  for floats (it computes them in software); and a frame's 9.9 million
  instructions take it 30 ms, 330 million a second: calls and returns
  through a register cost it a search each. A real Pi1 has the floats'
  unit and predicts a return: the program's side will weigh less there
  than here, and the copies (its memory) more: 1.8 MB a frame is some
  5 to 10 ms of a Pi1's memory, which no instruction count shows.

**Next, by what the numbers say**: the board (E1), first; a number of
a message in fewer instructions (`Display.long` is 160: mini-ml's code
for four shifts and four stores, each through its slot: C of the
toolchain plan, or M2's store of four bytes); the integer
division (200 instructions, in the C library: the kernel's `mod`s and
the games'); `Float.floor` in place; the four copies of a frame (K6:
the window's image is the framebuffer; the clear skipped when the
first shape covers all); the fills of a frame in one message (a
column's rectangles are 45 bytes each for 4 that change); M4 (floats
not boxed inside a function), which the game's view and its physics
are; TinyDoom.

2026-10-07, **the meters are three games now** (plan_playground.md's
stages 3 and 4, done before this plan's stage 1 as written): Tetris,
TinyWolfenstein (every column changes when the view turns) and
TinyCameltry (every shape turns with the maze), each on the two Plan 9
platforms. Under QEMU, a key held: Wolfenstein 9 to 10 frames a second
on the draw platform (104 ms a frame) and under 1 on the software one;
Cameltry 9 (its physics 20 to 32 ms of a frame's 100) and 2 to 3. **The
C pixels change nothing there**: the cost is the program's (mini-ml's
floats and bytes: M1b, M4a) or `Devdraw`'s, not the filling. Next
here: that split (the program's instructions for a frame against the
kernel's), then M1b.


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
