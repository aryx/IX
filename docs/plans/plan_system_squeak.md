# Plan: mini-squeak, Squeak on the bare Pi (`kernel/squeak/`), over mini-smalltalk, the author's own Smalltalk (`languages/smalltalk/`)

The author (2026-10-07), of the last answer to "what else could we
add?" (an image that persists; [`plan_system_l4.md`](plan_system_l4.md),
"After it"): "what about a mini-alto? it was a legendary machine? It
even had smalltalk running on it no?"; then: "I actually have a
tinySmalltalk and tinySqueak under ~/playground/, and a
languages/smalltalk/ under it too"; "so a smalltalk80 and squeak on
the bare metal is attractive option"; and, told that Squeak's host is
the smaller one: "no need for smalltalk-80; we can go directly to
squeak since it's a superset mostly, and from what you say it's
actually a simpler path". And, on this plan's first version, which
kept the virtual machine inside the kernel's directory: "maybe we
could have the smalltalk under languages/smalltalk/ and be general
enough it can be also compiled by ocaml and dune and run on Linux,
like the other mini-xx programs"; "also ideally we can build squeak
both on bare metal, and also as an app that [could] run under Linux,
but maybe also under 9pi itself!".

mini-squeak is **a machine that boots into Smalltalk and has nothing
else**: no process, no file, no shell. The Pi starts a virtual
machine, the virtual machine starts Smalltalk, and everything one
then sees and touches (the windows, the menus, the Browser, the text
typed, the atoms that bounce) is an object drawn by Smalltalk with
BitBlt, which Smalltalk's own Browser can change while it runs. What
the Alto was to those who used Smalltalk on it; in Squeak's form of
1996, Smalltalk-80 "made live again, in colour".

**Most of it exists.** The author's playground has the Blue Book's
virtual machine in OCaml and the system in Smalltalk, with Squeak's
Morphic. What is new here is small: the machine under it, and the
OCaml made what mini-ml takes.

What is kept, and what is free (as the other `plan_system_*`: the
look, the feel and the approach kept, what is under free, and the
code in one directory):

- **Kept: the look and the feel**, which are TinySqueak's: the grey
  world, morphs picked up and dropped with the left button (the red
  one), the text's menu on the right (the yellow: do it, print it,
  inspect it, accept), the halo on any morph with the middle (the
  blue) and its coloured handles, the Browser opened on what draws
  the atoms, the car that drives by its script of tiles.
- **Kept: the approach**, which is the Blue Book's: a compiler to its
  bytecodes, an interpreter over an object table, contexts that are
  objects, the kernel written in Smalltalk and brought up from its
  text, the whole memory saved as an image.
- **Free: what is under**: the board's framebuffer, `kernel/lib_machine`'s USB
  driver, mini-ml's collector under the object table.
- **Not here**: Squeak's own virtual machine and image (the
  playground's choice, kept: "our own Smalltalk, not Xerox's image");
  Smalltalk-80's MVC and its windows (the author, above).

**Status**: the survey done and this plan written (2026-10-07);
stages 0 to 4 done the same day ("Status", at the end: Squeak runs on
the emulated bare Pi 4); stage 1
found that the machine is wrong on arm (32 bits): **the Pi 4 only for
now**, the author's answer. The decisions were mine to propose; **taken by the
author as they are** (2026-10-07: "I like this plan and agree with all
the items"), and of the one left to him, decision 11: "let's not
count languages/smalltalk and kernel/squeak as part of make loc".

## The survey (2026-10-07, checked by `kernel/squeak/survey.sh`)

The reference is the author's own: `~/playground/languages/smalltalk/`
and `apps/devtools/TinySqueak.ml`, with their plans and notes there
(`plan_tiny_smalltalk.md`, `plan_tiny_squeak.md`, `notes_smalltalk.md`,
`notes_squeak.md`). I read the plans' heads, the catalog's rows, the
host's type and the benchmark's output; **not the code itself**.

| part | lines | what |
|---|---:|---|
| the virtual machine, OCaml | 4,652 | 15 files: `St_compile` 762, `St_interp` 716, `St_primitives` 624, `St_parse` 331, `St_lexer` 302, `St_memory` 296 (the object table), `St_class` 273, `St_colorblt` 259 and `St_bitblt` 166, `St_debug` 210, `St_image` 204, `St_boot` 166, `St_bytecode` 150, `St_chunk` 104, `St_ast` 89 |
| its interfaces | 1,404 | |
| the Blue Book's kernel, Smalltalk | 3,340 | `Numbers` 1,004, `Collections` 888, `Objects` 360, `Classes` 344, `Definitions` 319, `Graphics` 272, `Streams` 139, `System` 14 |
| Squeak's, Smalltalk | 2,813 | `Morphs` 803, `Morphic` 743, `Etoys` 383, `Tools` 330, `Color` 257, `Text` 190, `Closures` 107 |
| MiniMorphic, Smalltalk | 394 | Morphic in one file, black and white: fifty squares, the left button picks one up |
| the host, OCaml | 281 | `TinySqueak.ml`, over the playground's graphics |
| the tests | 361 | `Unit_squeak` 127, `Unit_smalltalk` 234 |

What it asks of what is under it:

- **Of a host, five functions** (`St_interp.mli`): the Transcript's
  output, a clock in milliseconds, an Inspector to open, where the
  mouse is with its three buttons, the next key typed. And the Display
  shown: a Form of 32 bits a pixel.
- **Of the system, one**: `Sys.time`. No file, no channel: the kernel's
  text is strings in the program.
- **Of the language: floats** (`Float`'s `sqrt`, `sin`, `exp`, `log`,
  `atan`; a float's bits through `Int64`).

**mini-ml compiles 5 of the 15 files as they are.** The first thing
it refuses in each of the others: optional arguments (`?(simple =
false)`: 7 files), `for _ = `, a polymorphic variant (1 file), and
`String.fold_left`, which ix's library lacks. Only the first: what is
behind each is not known.

**How fast**, by ocamlopt on the author's desktop (the playground's
`tests/bench`): 16 to 18 million bytecodes a second on sends. What a
gesture costs: a cycle where nothing changed 800 bytecodes; fifty
atoms bouncing 185,426; a window of 20 lines redrawn 157,875; the
Browser opened 147,674; a character typed 43,300; a print it 960,352.

What ix has:

| mini-squeak needs | ix | |
|---|---|---|
| an OCaml program on the bare Pi with a screen, a keyboard and a mouse | mini-oberon, whole: `kernel/lib_machine` by links, its `Usbhost` 178 among them, and `Input` 24, which it tells | there |
| the floating point | both boards' boots turn it on | there |
| a framebuffer of 32 bits | the kernels ask 16; mini-qemu's model has both | to try |
| a check by screens | mini-oberon's: steps by QMP, a screen's MD5 after each | there |

## Two directories, three hosts

**`languages/smalltalk/`, mini-smalltalk**: the virtual machine and
the system's text, a program of ix's like the others: built by dune
and by mini-ml, run on Linux (and under mini-5i), with no screen: a
file of Smalltalk filed in, an expression printed, an image saved and
loaded, the Display written out as a picture. The author's word,
above.

**Squeak is that machine with a host**, and a host is five functions
and a way to show the Display. One module says the rest once (the
image started, the world's cycle run a budget of bytecodes, what
changed shown): `Squeak`, over a host given to it. Three hosts, the
author's three:

| host | the screen, the mouse, the keys | built by | where |
|---|---|---|---|
| **the bare Pi** | the board's framebuffer, `kernel/lib_machine`'s USB driver | mini-ml | `kernel/squeak/` |
| **Linux**, a window | SDL, as mini-qemu's own window (`raspberry/Sdl_display`, 80 lines) | dune only: SDL is outside what mini-ml compiles | `languages/smalltalk/hosts/` |
| **mini-9pi**, a window of mini-rio | `/dev/draw`, `/dev/mouse` and the keyboard, through ix's `lib_graphics` (`Display`, `Draw`, `Mouse`, `Keyboard`) | mini-ml, for Plan 9 | `languages/smalltalk/hosts/` |

`kernel/squeak/` is, as the other systems' directories, what is its
own, the rest reached by symbolic links, a file each; and as
mini-oberon leaves mini-ml's run-time system outside as "the
language", this one leaves Smalltalk's there too.

    languages/smalltalk/
      dune  mkfile  Main.ml  CLI.ml
      St_*.ml         the virtual machine: the playground's files, made
                      what mini-ml takes
      Squeak.ml       the system run over a host: the same on the three
      hosts/          Host_sdl.ml (Linux), Host_draw.ml (Plan 9), each
                      with its Main
      kernel/         the system's text, as it is in the playground:
                      *.st, squeak/, morphic/
      tests/          the playground's, an expression and its answer

    kernel/squeak/
      mkfile  survey.sh  numbers.sh  README.md
      Main.ml         the boot: the devices, then Squeak
      Host.ml         the five functions and the Display, over Machine
      machine/        links: Machine, the boards' C and assembly, Usbhost
      tests/          the session's steps and screens

## Decisions to take (the author's; my proposals)

0. **The names: mini-smalltalk in `languages/smalltalk/`, mini-squeak
   in `kernel/squeak/`.**
1. **The virtual machine is the playground's, copied and changed
   where mini-ml refuses it**; not written again. The author's rule
   is that ix's programs are written anew and a file is imported only
   when he names it; he named this directory, and it is his own code,
   under the same licence. What changes is said in each file's
   header, so that the two can be compared. **Two copies then live
   apart**, in two repositories. The other way round (the playground
   made to use ix's simpler OCaml, one source) is cleaner and is the
   playground's affair.
2. **The OCaml made simpler, not mini-ml made richer**: the author's
   policy. An optional argument becomes a plain one or a second
   function; the polymorphic variant a variant; `String.fold_left` a
   loop (or a function ix's library gains).
3. **The system's text is not touched.** `languages/smalltalk/kernel/`
   holds the `.st` files byte for byte; the survey's script says if they have parted
   from the playground's.
4. **mini-smalltalk is a program for Linux first**, by dune and by
   mini-ml as ix's others: the machine's tests run there in seconds
   with no emulator, and a fault of the port is found before a kernel
   is. Its command: a file filed in, an expression's answer printed,
   an image saved and loaded, the Display written as a picture.
   **Its window on Linux is dune's alone** (SDL: the one host mini-ml
   does not build, as mini-qemu's window is not, and left out of
   `compile_ix.sh` the same way), and is where Squeak is first seen:
   stage 2, before any kernel.
5. **Under mini-9pi it is a program like ix's others there**, in a
   window of mini-rio: the Display's changed rectangles loaded into
   the window's image, the mouse and the keys read from their files.
   The window's size is the Display's; a window resized is to decide
   (Squeak's world can be told its new bounds). Then **Squeak runs
   twice on the Pi**: as the machine itself, and as one window among
   others of a Plan 9, and the two can be timed against each other:
   what a kernel, a file server for pixels and a window system cost.
6. **On the bare Pi the host is five functions over `Machine`**
   (`Host`), after
   mini-oberon's `Input`: the mouse and the keys from `Usbhost`, the
   clock from the board's timer, the Transcript also on the serial
   line (the tests read it), the Inspector Smalltalk's own. The
   Display: the board asked for 32 bits a pixel, and the Form's pixels
   copied there, only the rectangles Morphic says it damaged, if the
   machine lets the host know them.
7. **Brought up from its text first, then from an image.** At first
   the kernel carries the `.st` files as data and the machine compiles
   them at each boot: simple, and slow by an amount not known. Then
   the image: **the build's host program boots the system once and
   saves it** (`St_image`), the kernel carries that, and the Pi starts
   by loading it. That is Smalltalk's own way, and it is OCaml making
   it, as the build asks.
8. **What is done in the session is lost when the machine stops**, as
   mini-oberon's. The image saved to the SD card, and loaded from it
   at the next boot, is what this system was first named for (an
   image that persists); a later stage, with mini-9pi's card driver by
   a link.
9. **Squeak's kernel is the target; MiniMorphic the first step**: one
   file, black and white, no tools, and the same host.
10. **Speed is the plan's risk, and is measured before anything is
   built on it.** mini-ml's code is a stack machine's, not optimized;
   if a bytecode costs some hundreds of instructions, fifty atoms are
   tens of millions of instructions a cycle: several seconds of the
   board's time under mini-qemu, a fraction of one on the Pi 4, and
   the Pi 1 between. Stage 1 says. What follows from it, apart and
   switchable: the interpreter's hot paths, BitBlt in C, fewer morphs
   in the first world.
11. **Both directories counted apart in `make loc`**, not in m-ix:
    `kernel/squeak/` as mini-oberon, and `languages/smalltalk/` with
    it (the author's answer; `scripts/stats/loc.py` has the row).

## What is checked

- **mini-smalltalk's tests, by dune and by mini-ml**: the
  playground's `Unit_squeak` and `Unit_smalltalk` (an expression, its
  printed answer), run against the copy; the same expressions through
  the kernel's Transcript on the serial line.
- **The Display is the same everywhere**: after the boot and after
  each step of a session, the Form's pixels by their MD5, on the host,
  under mini-qemu and QEMU, on both boards, and in the window of each
  of the two other hosts. No pixel depends on the machine; any
  difference is a fault.
- **A session** (mini-oberon's way, by QMP): a morph picked up and
  dropped; a halo and its resize; print it on `100 factorial`; in the
  Browser, `EllipseMorph>>drawOn:` changed and accepted, and the atoms
  drawn the new way. Not in it: what moves by itself.
- **The numbers** (`numbers.sh`): bytecodes a second and instructions
  a bytecode on each board under mini-qemu; the boot from text and
  from the image; the benchmark's gestures.

## The stages (each checked before the next)

0. **mini-smalltalk, by dune**: `languages/smalltalk/`, the fifteen
   files and the text copied, the ten changed, its command, the
   playground's tests green, and `compile_ix.sh` taking all fifteen.
1. **mini-smalltalk, by mini-ml, and the measure**: the same program
   for Linux under mini-5i, the same tests; then the benchmark's
   sends: instructions a bytecode. Decision 10 answered before a
   kernel is written.
2. **Squeak in a window on Linux**: `Squeak`, the SDL host;
   MiniMorphic first, then Squeak's kernel. The whole system seen and
   used, by dune, with no emulator: what the port lost, if anything,
   shows here.
3. **MiniMorphic on the bare Pi**: `kernel/squeak/` after
   mini-oberon's mkfile; the boot from text, the Display copied, the
   squares bouncing, one picked up. Its first screen's MD5, which is
   stage 2's.
4. **Squeak on the bare Pi**: colour, Morphic, the tools, Etoys; the
   session and its screens.
5. **Squeak under mini-9pi**: the Plan 9 host, in a window of
   mini-rio; the same screens inside the window.
6. **The image**: made by the build, loaded at the boot; the two
   boots timed.
7. **Speed**, as far as stage 1 and 4 ask; `README.md`, `./mini-pi -g
   mini-squeak`.
8. Later, each to be decided: the image saved to the card (decision
   8), and under mini-9pi to a file, which is there today; the boards themselves; a domain of mini-xen
   ([`plan_system_xen.md`](plan_system_xen.md)), beside the others.

## The size

Not much is written. Copied and changed: the machine's **4,652**
lines and its interfaces. Copied as they are: **6,547** lines of
Smalltalk. New: mini-smalltalk's command **100 to 200**; `Squeak`
and the three hosts **400 to 700** in all (the playground's one is
281); the mkfiles and dune's file,
the tests' steps. Unknown: how many lines the ten files'
changes touch, past the first refusal of each.

## Not checked yet

- the playground's code: not read; its plans and notes by their
  heads. Nothing was built or run here but its benchmark and mini-ml
  on its files;
- **what mini-ml refuses after the first thing** in each of the ten
  files, and whether the machine leans on something it cannot be
  rewritten out of cheaply;
- **instructions a bytecode** by mini-ml (decision 10): not measured,
  the figures there are a guess;
- how long the boot from text takes (the benchmark does not say), and
  whether `St_image`'s format is the same on a machine of 32 bits and
  one of 64: OCaml's integers are 31 bits on the Pi 1, and Smalltalk's
  small integers and the image's words may assume more;
- how the host learns what Morphic damaged, or whether the whole
  Display is copied at each cycle (1024 by 768 at 32 bits: 3 MB);
- a framebuffer of 32 bits from the firmware, and from mini-qemu's
  mailbox;
- the Plan 9 host: how `lib_graphics` loads a rectangle of 32-bit
  pixels into a window and at what cost; whether ix's programs for
  Plan 9 have floats; mini-rio's state on the boards (`plan_rio.md`);
  how much memory a process of mini-9pi may have;
- the memory: the object table's size for Squeak's kernel against the
  kernel's heap (mini-oberon's is two halves of 4M words);
- whether the playground's tests need Testo's snapshots
  (`tests/snapshots/smalltalk`) to move too.

## Status

2026-10-07, **stage 0: mini-smalltalk, by dune** (the author, asked
whether to start: "yes!"). `languages/smalltalk/` is the playground's
Smalltalk as a program of ix's:

    mini-smalltalk -e '100 factorial printString size'        158
    mini-smalltalk Mine.st -e 'Mine new answer'               42
    mini-smalltalk -k squeak -o squeak.image                  the system saved (523,688 bytes)
    mini-smalltalk -i squeak.image -e 'EllipseMorph new bounds'   0@0 corner: 50@40
    mini-smalltalk -k mini -ppm atoms.ppm -e '... (WorldMorph bouncingAtoms: 50). World doOneCycle'

(the last one's picture: MiniMorphic's fifty squares, looked at).

- **The plan's second unknown is answered: there was little behind
  each file's first refusal.** mini-ml compiles the fifteen files, and
  the kernel's text as dune makes it (`St_kernel.ml`, 6,547 lines in
  quoted strings); `compile_ix.sh` takes the directory's 17. What was
  changed, in ten files, about a hundred lines (`kernel/squeak/survey.sh`
  counts the copy's lines that are not the playground's):
  - the ten optional arguments: a label always said (`~simple`,
    `~declare`, `~stepping`, `~budget`), or two functions (`run` and
    `run_until`; `evaluate` and `evaluate_with`), or plain arguments
    (`boot host kernel`, `load_vm host image`);
  - the polymorphic variants of the arithmetic primitives: one variant;
  - what ix's library says otherwise: `Option.value o ~default:d` (16
    times) written as a `match`, `Float.abs`, `sqrt`... by `Pervasives`'
    names, `Float.is_integer` and `is_finite` by a comparison,
    `String.fold_left` and `Bytes.init` by loops;
  - `for _ =`; a function chosen by a condition before its labelled
    arguments, written out; one function nothing called.
  Each changed file says so under its header; five are the
  playground's but for the header. **That it compiles is all that is
  known of mini-ml's side**: stage 1 runs it.
- **The system's text is the playground's, byte for byte** (16 files;
  the survey's script compares).
- **The tests are the playground's**, seven of its eight files (not
  `Unit_highlight_st`: the code map's colours are not here): 55, all
  passing against the copy, before and after the changes; in `make
  test` and in `tests/lite.sh`.
- **The command** (`CLI`, 137 lines with its interface; its `-h` is its
  manual): the system from its text (`-k blue`, `squeak`, `mini`) or
  from an image (`-i`), files filed in, expressions printed (`-e`, or
  the lines read), the Display written (`-ppm`), the image saved
  (`-o`). The Transcript is the terminal.
- **Brought up from its text in 45 ms** (Squeak's kernel, by ocamlopt,
  on the author's desktop); from the image in 22. So decision 7's
  image is worth what mini-ml's slowness makes of those 45 ms, not
  known before stage 1.
- **Squeak's world is made by its host**, not by the kernel's text:
  the playground's `TinySqueak.ml` evaluates a start (the world on the
  Display, a Browser, a Workspace, the atoms, the car). That text is
  `Squeak`'s to carry (stage 2); `-k squeak` alone has no `World`.
- Not done: the mkfile (stage 1); the playground's `claude:` tags are
  gone from the copies, as ix's comments have none; `languages/smalltalk/`
  is not in `make loc`'s m-ix (decision 11: 6,117 lines apart).

2026-10-07, **stage 1: mini-smalltalk by mini-ml, and the measure**
(the author: "yes commit and go on stage 1"). `languages/smalltalk/mkfile`
builds it by ix's tools (`St_kernel.ml` made there too: dune's bytes),
and it runs under mini-5i.

- **On arm64 it is the same program as dune's.**
  `tests/differential.sh`: the unit tests' expressions (48 on the Blue
  Book's system, 9 on Squeak's), a line each, given to both: the same
  answers and errors. And Squeak's image saved by one is the other's,
  byte for byte: **an image made by the build's host program is good
  for the Pi 4** (decision 7).
- **The measure** (`mini-5i -s`, `mini-smalltalk -s`;
  `tests/bench/fib.st`, the playground's benchmark of sends, `20
  benchFib`: 229,945 bytecodes more than the start's):

  | instructions | arm64 | arm |
  |---|---:|---:|
  | the start, the Blue Book's system from its text (4,591 bytecodes) | 269 million | 275 million |
  | Squeak's from its text (6,780 bytecodes) | 673 million | 675 million |
  | Squeak's from its image | 209 million | 219 million |
  | **a bytecode** (fib's) | **2,435** | **2,266** |

  The plan guessed "some hundreds". ocamlopt's code runs the same
  bytecodes 16 to 18 million a second on the author's desktop, some
  two hundred of its instructions each: mini-ml's is ten times that.
  What it makes of the playground's figures: fifty atoms' cycle
  (185,426 bytecodes) 450 million instructions, a character typed 105
  million, the Browser opened 360 million. A guess of what a board
  does with them, not a measure: a fraction of a second each on the
  Pi 4, a second or more on the Pi 1; under mini-qemu and mini-5i (13
  million instructions a second on this desktop) half a minute a
  cycle. **Decision 10's remedies are wanted, not maybe**; where the
  2,435 go was not looked at (the interpreter's `step`, a send's
  context, mini-ml's calls of labelled functions, the collector: to
  profile first).
- **The start is the text compiled, not bytecodes run**: 673 million
  instructions for 6,780 bytecodes. The image saves two thirds; what
  is left (209 million) is the image read and the primitives set.
- **On arm (32 bits) the machine is wrong**, and the build had first
  to be made possible:
  - mini-ml gives a function seven parameters at most there. Seven
    functions had nine to eleven: the blits take a record now (`copy`:
    BitBlt's own fields), and a method's source, pc map and names are
    one tuple. Done, the 55 tests as before.
  - **OCaml's integers have 31 bits on arm, and the machine wants
    32.** A SmallInteger has 31 bits and its oop is that doubled, with
    a tag: `1073741823 + 1` answers 0, a SmallInteger, and `100
    factorial printString size` 159 (3 of the 48 expressions differ;
    Squeak's 9 agree). The playground's is written for the web's
    integers of 32 bits (its comments say so), one more than here. The
    same for a pixel of 32 bits held in an integer (`St_colorblt`):
    Squeak's colour, not tried, cannot be right. And the image saved
    on arm is not arm64's.
  - **The author's to decide**: (a) the Pi 4 only for now, as
    mini-xen, arm when someone wants the Pi 1; (b) SmallIntegers of 30
    bits everywhere, one Smalltalk on every host and images that
    travel, at the price of parting from the playground's (the tests'
    1073741823, `Numbers.st`'s one use of it) and of two halves for a
    pixel; (c) 30 bits on a host of 31 only: two Smalltalks. I would
    take (a) now and (b) when the Pi 1 is wanted.
  - **Taken** (the author, 2026-10-07): "I agree to make it Pi 4 only
    for now. Ok to also use less bits; it's ok to deviate from the
    playground". So (a) now: the stages after this one are arm64's,
    and decision 1's Pi 1 waits; and (b) is allowed when the Pi 1 is
    wanted, the copy free to part from the playground's.
- The command has `-s` (the bytecodes run). mini-smalltalk is not in
  the root mkfile's programs nor in `mkfiles/check.sh`: apart, as
  mini-oberon; `differential.sh` is run by hand (4 minutes).

2026-10-07, **stage 2: Squeak in a window on Linux** (the author,
asked whether the window or the interpreter's speed comes first:
"let's follow what you think is best"; the window). `mini-squeak`
opens it: the Browser on `EllipseMorph>>drawOn:`, a Workspace, the
Transcript, the atoms bouncing, the car driving by its script; seen
running on the author's display (its picture taken, the atoms and the
car moved between two).

- **`Squeak`** (163 lines with its interface): what the three hosts
  share and all they call. The system brought up over a host
  (`St_interp.host`: the mouse, the keys, a clock, the Transcript), the
  start's text (the playground's `TinySqueak`'s: the world on a
  Display of 800 by 600 in 32 bits, and what is on it), the world's
  cycle run a budget of bytecodes, an error said in Smalltalk's
  Transcript and the world going on, the Display's pixels when they
  changed. mini-ml compiles it; it is in the mkfile's program.
- **`hosts/sdl/`** (145 lines: `Window`, `Main`, dune's file): the
  Display as a texture, the mouse's buttons by Smalltalk's colours
  (left red, right yellow, middle or Control and left blue), the
  characters typed, Control-C. Dune's alone: `compile_ix.sh` leaves
  the directory out, as mini-qemu's window. Its `-h` is its manual.
  The mouse and the keys I could not try (no tool here to move the
  one or type the others in a window); the author did: "it works!".
- **`mini-smalltalk -world n`**: the world started as a host starts it
  and cycled n times with a clock of its own, so `-ppm` shows Squeak's
  screen with no window. The pictures are the same at every run:
  `Unit_world` holds three by their MD5 (Squeak's after 3 and 30
  cycles, MiniMorphic's after 100). 57 tests.
- **By mini-ml the screen is the same, pixel for pixel**
  (`mini-smalltalk -k squeak -world 3 -ppm`, under mini-5i, against
  dune's): the colour's code is right on arm64.
- **And what it cost says more than stage 1's measure did: 6.4
  thousand million instructions** to Squeak's first screen and three
  cycles (1,026,041 bytecodes), of which the kernel's text compiled is
  0.67. So 5,600 instructions a bytecode here, not fib's 2,435: the
  rest is the primitives, BitBlt drawing every window and every
  character of the start a pixel at a time in mini-ml's code. Eight
  minutes under mini-5i; on the Pi 4, a guess, some seconds to the
  first screen. **BitBlt's cost under mini-ml is the first thing to
  look at**, before the interpreter's own.
- Not done: the window resized (800 by 600, or `-x n` times it);
  an image started from (`Squeak.start` is from the text); a README
  for the directory.

2026-10-07, **where the instructions go, looked at** (the author:
"let's commit and move forward"). Stage 2's guess was wrong: **it is
not BitBlt.**

- ocamlopt's build runs the same start and three cycles in 550 million
  instructions (valgrind), against mini-ml's 6,406: **11.7 times**. Its
  profile is flat: the interpreter's `step` 12%, the object table's
  one-line accessors 11%, `caml_modify` 8%, closures applied 6%, the
  collector 6%, BitBlt under 1%. Nothing to rewrite in one place.
- mini-ml's switches do not help: fib with `-O` 2,436 instructions a
  bytecode, with `-O -ssa` 2,591.
- So **the speed is mini-ml's code, not this program's**, and the
  remedy is [`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md)'s,
  on hold since 2026-10-02: an allocation without a call of C, a known
  function called without a closure, small functions inlined. The
  author: "it's also a great bench for future improvements to mini-ml!
  to compare with ocamlopt and reduce the gap". Recorded there as its
  second benchmark, with `tests/bench/numbers.sh` (the start 5.2 times
  ocamlopt's, fib 7.5, the world 11.7).
- What is left to this plan: the image (the start's 0.67 thousand
  million saved), fewer morphs or cycles at the start if the Pi wants
  them, and the machine's own hot paths written by hand only if the
  compiler's work does not come.

2026-10-07, **stages 3 and 4: MiniMorphic, then Squeak, on the bare
Pi 4** (the author: "yes let's commit and let's do stage 3").
`kernel/squeak/` boots to Squeak's screen under QEMU's `raspi4b` in
11 seconds, and a USB mouse and keyboard work it:

    mini-squeak
    mini-squeak: everything here is a morph.
    mini-squeak: started, 578256 bytecodes.
    mini-squeak: drawn.

- **The first screen on the Pi is the one on Linux, pixel for pixel**:
  `mini-mk check` compares QEMU's dump of it with `mini-smalltalk -k
  squeak -world 1 -ppm` by dune (and MiniMorphic's the same, `mini-mk
  SYSTEM=Mini`). The claim of "What is checked", for the first screen:
  no pixel depends on the machine. So the kernel keeps no picture.
- **The directory** (`README.md` there): `Host` 107 lines with its
  interface (the five functions and the Display over `Machine` and
  `Usbhost`), `Main` 25, `clock.c` 21 (the milliseconds, by the
  generic timer), the mkfile 139, eleven links. Smalltalk's objects are
  languages/smalltalk's, built there (decision's "the language left
  outside"). The heap: two halves of 64 MB.
- **Tried by hand under QEMU** (QMP's mouse and keys, three seconds
  between two): the pointer moved into the Workspace, a click, `hi`
  typed: at the caret, the atoms and the car going on. Not in a check:
  what moves by itself makes no screen twice.
- **Showing the Display was the first cost, and is gone.** The
  host's `rgba` (a pixel at a time, a closure called for each: a
  thousand of mini-ml's instructions) made a pass of MiniMorphic's
  world seven seconds under QEMU. A Display of 32 bits is now written
  to the framebuffer as it is, in one call: its bytes are alpha, red,
  green, blue, the board's red, green, blue and a byte it does not
  look at, so the same bytes one further on (`Squeak.bits32`,
  `Host.show32`). Squeak's first screen went from 16 seconds to 11.
  MiniMorphic's Display, one bit a pixel, still goes the slow way.
- **Found in mini-qemu: its framebuffer of 32 bits had red and blue
  changed places** (no kernel had asked 32 bits before): fixed, with
  its window's format (`raspberry/Framebuffer`, `Sdl_display`;
  `bugs/ix.md`). Which order the real board's firmware gives is not
  known: the Pi itself may show Squeak's blue as orange, a line of
  `Host` to change then.
- **Under mini-qemu**: MiniMorphic's first screen is QEMU's (compared,
  before the fix above, which black and white does not see); Squeak's:
  the same lines and the same first screen as QEMU's and Linux's, colours
  and all, after 308 seconds (`mini-mk check SLOW=1` does it).
- `./mini-pi mini-squeak` (`-g -q`: QEMU's window); `compile_ix.sh`
  takes the kernel's files; `mini-smalltalk -world`'s mouse is at the
  Display's middle, as a board's.
- Not done: the board itself; the image (stage 6: every start
  compiles the text); a session's check; the Display's changed
  rectangles only (all of it is written at each pass: 1.9 MB).
