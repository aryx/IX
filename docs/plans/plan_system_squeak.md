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
- **Free: what is under**: the board's framebuffer, `kernel/lib`'s USB
  driver, mini-ml's collector under the object table.
- **Not here**: Squeak's own virtual machine and image (the
  playground's choice, kept: "our own Smalltalk, not Xerox's image");
  Smalltalk-80's MVC and its windows (the author, above).

**Status**: the survey done and this plan written (2026-10-07);
nothing else is. The decisions were mine to propose; **taken by the
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
| an OCaml program on the bare Pi with a screen, a keyboard and a mouse | mini-oberon, whole: `kernel/lib` by links, its `Usbhost` 178 among them, and `Input` 24, which it tells | there |
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
| **the bare Pi** | the board's framebuffer, `kernel/lib`'s USB driver | mini-ml | `kernel/squeak/` |
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
