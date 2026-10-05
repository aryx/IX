# Plan: mini-oberon, the Oberon system in OCaml on the Pi (`kernel/oberon/`)

The author (2026-10-05): "I wonder how difficult it would be to have a
kernel/oberon that imitates the Oberon system. I don't mean to
implement an Oberon compiler and so on like in the original book, but
instead get the same running system as Oberon (but using OCaml and the
kernel/9pi/lib_graphics library and lib_core present in ix)". Then:
"let's write a plan_system_oberon.md (we can add later a
plan_system_singularity.md and so on)"; and: "ideally the code would
be only in kernel/oberon/ and would not depend on the rest, only
through symlinks, so one can just look at one directory and know
everything is in there". And, on this plan's first version, which
aimed at the emulator's screens pixel for pixel: "we don't have to
match exactly what Oberon was. The idea is more to give this
historical book a place here, adapted to OCaml, and reusing some of
the existing code in ix"; "we definitely want though to match the
look and feel of the original, and general approach".

mini-oberon is Wirth and Gutknecht's Oberon system as one sees and
uses it (the two tracks of tiled viewers, texts everywhere, a command
a name `M.P` clicked in any text, the three buttons' interclicks),
**written in OCaml, running on the bare Pi 1 and Pi 4** as mini-xv6 and
mini-9pi do. Not its language: no Oberon compiler, no RISC5 code; a
"module" is an OCaml module. And **not a twin**: it is *Project
Oberon*, the book, given a place in ix. What is kept, and what is free:

- **Kept: the look and the feel.** The screen one knows (the
  emulator's `po2013.png`): a user track and a narrower system track,
  viewers tiled in them, each with a menu line (its name, then
  commands: `System.Close System.Copy System.Grow`) in inverse, the
  scroll bar at the left of a text, the log and `System.Tool` at the
  right at the boot, the arrow, Oberon's own proportional font. And the
  hand's side of it: a command clicked with the middle button, the
  selection with the right, the caret with the left, the interclicks,
  a viewer moved by its menu line.
- **Kept: the approach.** The book's modules by their names and their
  layering, the central loop, the frames and their messages, a text as
  pieces, a command a procedure with no parameter reading its
  arguments from the text after its name; so that one reads
  `kernel/oberon/` with the book open.
- **Free: what is under.** No pixel is compared with the original's.
  What ix has already (a file system, the pixels, the keyboard and the
  mouse, the collector) is taken where Oberon's own would only be
  written again, and OCaml's ways are used where Oberon's are its
  language's (a closure for an extended record, an exception for a
  trap).

The first of the `plan_system_*.md`: systems that are not Unix's nor
Plan 9's, each in a directory of `kernel/` one can read alone.

**Status**: the survey done and this plan written (2026-10-05); the
decisions below are mine to propose, the author's to take. No code yet
but the survey's script.

## The survey (2026-10-05, checked by `kernel/oberon/survey.sh`)

The reference is **Project Oberon 2013** (the book's 2013 edition, for
the RISC5 on an FPGA): its sources as ETH serves them
(`people.inf.ethz.ch/wirth/ProjectOberon/Sources/`), the 40 modules the script names, 11,832
lines. The script fetches them and counts.

| part | lines | modules |
|---|---:|---|
| inner core | 1,353 | Kernel 271 (heap, GC, the disk's sectors, the clock), FileDir 352 (the directory, a B-tree), Files 505 (files, riders), Modules 225 (the loader) |
| outer core | 3,245 | Input 79, Display 190, Viewers 206, Fonts 109, Texts 537, Oberon 410, MenuViewers 208, TextFrames 856, System 418, Edit 232 |
| **the system** | **4,598** | the 14 modules above: what boots to the screen one knows |
| the compiler | 3,124 | ORS, ORB, ORG, ORP, ORTool: **not in this plan** |
| graphics | 2,027 | Graphics 685, GraphicFrames 529, Draw, GraphTool, Rectangles, Curves, MacroTool: later, maybe |
| small programs | 372 | Blink 19, Stars 109, Checkers 47, Sierpinski 111, Hilbert 86 |
| others | 1,711 | Net, SCC, RS232, PCLink1, Tools, EBNF, RISC, ORC, BootLoad: not in this plan |

What the system is, for who writes it again:

- **One address space, one thread, no protection but the language's.**
  `Oberon.Loop` polls the mouse and the keyboard and sends a message to
  the viewer under the mouse (or the focus); background tasks are
  procedures the same loop calls. No process, no system call, no
  interrupt needed but the clock's. A command that traps is abandoned
  and the loop goes on.
- **The machine is under four modules.** `SYSTEM`'s uses: Kernel 95,
  Display 76, Modules 41, Fonts 17, Files 15, System 8, Input 6,
  Oberon 1; none in Viewers, Texts, MenuViewers, TextFrames, Edit,
  FileDir. So 2,391 lines of the 4,598 ask nothing of the machine.
- **Display** is five operations on a 1024 x 768 frame of one bit a
  pixel: `Dot`, `ReplConst`, `CopyPattern`, `CopyBlock`, `ReplPattern`,
  each in a mode: `replace`, `paint`, `invert`. The cursor, the caret
  and the selection are drawn by `invert`.
- **Frames by extension, messages by extension.** A frame is a record
  extended (`Viewers.ViewerDesc`, `MenuViewers.ViewerDesc`,
  `TextFrames.FrameDesc`; an application's own: `Stars.FrameDesc`,
  `Checkers.FrameDesc`, `GraphicFrames.FrameDesc`) with a `handle`
  procedure; a message is a record extending `Display.FrameMsg`: 8 in
  the system (`Viewers.ViewerMsg`, `MenuViewers.ModifyMsg`, Oberon's
  `InputMsg`, `SelectionMsg`, `ControlMsg`, `CopyMsg`, TextFrames'
  `UpdateMsg`, `CopyOverMsg`), and each application adds its own
  (Stars 2, GraphicFrames 6). A message is passed `VAR`: an answer
  comes back in its fields.
- **Commands**: 24 of System (`Open`, `Close`, `Copy`, `Grow`, `Free`,
  `Directory`, `CopyFiles`, `ShowModules`, `ShowCommands`...) and 9 of
  Edit (`Open`, `Store`, `Search`, `Locate`, `ChangeFont`...).
  `Modules.Load` reads a module's object file, links it and runs its
  body; `ThisCommand` finds a procedure by its name.
- **The files a running system reads**: its fonts
  (`Oberon10.Scn.Fnt`, the default; 8, 10, 12, 16, with `b` and `i`),
  `System.Tool`, and the texts; they are on the disk image of the
  emulator below (`strings` on it; not opened by a program yet).
- **An emulator to compare with**: Peter De Wachter's oberon-risc-emu
  (C, SDL2: `github.com/pdewacht/oberon-risc-emu`), with disk images
  of the 2013 system (`DiskImage/Oberon-2020-08-18.dsk`, 990,208
  bytes). Cloned, **not built nor run yet**; its options show no
  screen dump, so a screenshot is to be found (stage 0).

The author has Reiser's *The Oberon System* (1991, 363 pages), which
describes the first system, on the Ceres. The 2013 one is the same
design made smaller (no elements in texts, no colour, one display);
I know of no sources of the 1991 one as easy to fetch and run.

What ix has (the same script, lines of `.ml` and `.mli`):

| Oberon | ix | lines |
|---|---|---:|
| Kernel: the heap, the GC | mini-ml's runtime (`languages/ml/runtime`), its collector already in the kernels | |
| Kernel: the boot, the clock, the traps | `kernel/lib`: `Machine` 198, the board's `machine.c` (244, 270), `l.s` (320, 405), `runtime.c` 319 (the processes' side: more than Oberon wants) | |
| Display: the frame | `Memchan` 80, `Memimage` 344 (a pixel's `read` and `write`, `fill`, `load`), `Memdraw` 228 | 652 |
| Display: `invert` | **nothing**: `Memdraw`'s operators are Porter-Duff's, without xor. `kernel/lib/Screen`'s pointer inverts pixels by hand | |
| Fonts | `Memfont` 81 is Plan 9's subfont; Oberon's `.Fnt` is another format (a pattern a character, proportional) | |
| Input | `Kbd` 185 (scan codes), `usb.c` 143 (the USB keyboard and mouse, as mini-xv6's check drives them under QEMU: `-device usb-kbd -device usb-mouse`) | |
| FileDir, Files | `kernel/xv6/Fs` 459 is xv6's format; Oberon's is its own | |
| Texts | nothing to take: `editor/Text` is ed's, by lines | |
| the open messages | **mini-ml has no `type t = ..`** (no rule in its grammar); it has exceptions, which are an open type | |

## The rule: one directory

Everything mini-oberon is made of is **in `kernel/oberon/`**. What it
shares with the other kernels is there as a **symbolic link, one a
file** (not a directory's): `ls -l` says what is borrowed and from
where, a file not listed is not used, and what is not a link is
Oberon's own. The precedents: `kernel/step5/libc.c`,
`kernel/9pi/tests/threads/Threads.ml`.

What follows from it:

- **Its own `mkfile`**, naming its files by their paths in
  `kernel/oberon/`. It may not include `kernel/lib/mkkernel` (a
  dependency one does not see); either that file is a link too, or the
  mkfile says in full what a kernel is made of, which is short for a
  kernel with no processes. To see at stage 0.
- **A shared file is not bent for Oberon.** What Oberon alone wants
  (`invert`, its fonts) is written in its own modules, over the shared
  ones.
- **The language is outside**: the compiler, its runtime
  (`languages/ml/runtime`) and the standard library (`lib_core`) are
  mini-ml's, as gcc and its libc are not in xv6's directory. My
  proposal; the other reading (two more links, `runtime` and `stdlib`,
  these two a directory's) costs nothing if the author prefers it.

The layout I propose:

    kernel/oberon/
      mkfile  survey.sh
      Kernel.ml FileDir.ml Files.ml Modules.ml       the inner core
      Input.ml Display.ml Viewers.ml Fonts.ml Texts.ml
      Oberon.ml MenuViewers.ml TextFrames.ml System.ml Edit.ml
      Main.ml                                        the boot: the modules' table, Oberon.Loop
      machine/    links: Machine, the boards' Arch, machine.c, l.s, usb.c...
      graphics/   links: Memchan, Memimage, Memdraw
      files/      links: xv6's Fs
      disk/       the files of the image: the fonts, System.Tool, texts
      tests/      the sessions, the expected screens

Oberon's module names are kept: a reader with the book finds
`TextFrames.ml` where `TextFrames.Mod` is. One clash to settle at stage
0: `lib_core/commons` has a `Files` (the kernels link `COMMONS` whole
today); a kernel that names its libraries need not link it.

## Decisions to take (the author's; my proposals)

1. **Which Oberon**: Project Oberon 2013. It has sources one fetches,
   an emulator and a disk image to compare with, and it is the smallest
   telling of the design. Reiser's book describes what the user sees,
   which is nearly the same.
2. **The loader: a table, not a loader.** Every module is linked in
   the image; each registers its commands by name (`Modules.command
   "Edit.Open" Edit.open_`) when it starts. A click on `Edit.Open` in a
   text looks the name up. Lost: a module loaded at its first use,
   `System.Free`, a module added without a new image. `ShowModules` and
   `ShowCommands` list the table. A loader of mini-ml's objects in the
   kernel is another plan.
3. **The messages: exceptions as the open type.** `Display.msg = exn`;
   a module declares `exception Input of input` beside its frames, a
   handler is `frame -> exn -> unit` matching the ones it knows and
   ignoring the rest, as Oberon's `IF M IS InputMsg`. An answer comes
   back in a mutable field. It is OCaml 4.14's and mini-ml's both,
   and an application in its own module adds messages without a change
   to the system: Oberon's point. The alternatives: one closed variant
   (simpler, but Stars would edit Display), or `type msg = ..` added to
   mini-ml (a feature for one program). A frame's own state is what its
   handler's closure holds: no record to extend.
4. **Display over `Memimage`, `invert` its own.** The frame is a
   `Memimage.t` on the framebuffer, the fills, copies and characters go
   by `Memdraw`, and `invert` is a loop of `Memimage`'s `read` and
   `write` in `Display.ml`. **The fonts are Oberon's** (the look):
   `Fonts.ml` reads a `.Fnt` as `Fonts.Mod` does (109 lines there: a
   header, the runs of characters, a box and a pattern each), a
   character drawn as `CopyPattern`. `Memfont` is not used. The font
   files (Oberon10 first; the bold, the italic and the sizes when
   `Edit.ChangeFont` comes) are taken once from the emulator's disk
   image and kept in `disk/`.
5. **The files: `kernel/xv6/Fs`, by a link, the image in RAM.** Its
   root directory alone is Oberon's flat directory of names;
   `Files.ml` is Oberon's interface (`Old`, `New`, `Register`, riders)
   over it. The image is in the kernel as mini-xv6's is (`.incbin`),
   made by a tool ix has or a small one (stage 0). Oberon's own format
   (FileDir's B-tree, Files' sectors: 857 lines, a chapter of the
   book) is a later stage if that chapter is to have its place too;
   with it mini-oberon would read the real system's disk images.
6. **Both boards, QEMU and mini-qemu first**, as the other kernels; the
   screen 1024 x 768 as Oberon's and as `kernel/lib/Screen` asks today.
7. **A host's build for the tests.** The 2,391 lines that ask nothing
   of the machine (and the rest over a `Display` on an image in memory,
   an `Input` from a script) run on Linux under OCaml 4.14: a session's
   events in, the screen out as a PPM, in a second. For `tests/` only
   (not mini-ml's to compile); the kernel's check stays the one that
   counts.

## What is checked

mini-oberon's own screens, by the tests: a session (the mouse's moves
and clicks, the keys) played on the kernel under mini-qemu and QEMU,
the screen dumped and compared with the one kept in `tests/`, as
mini-9pi's (`kernel/9pi/tests/screenshot.py`); the same session on the
host's build (decision 7), the same screen.

The look and the feel, by the eye: at each stage the same session done
by hand on oberon-risc-emu, its screen beside ours, the differences
written in this plan (wanted, or to mend). Not a test that runs: the
original is what one looks at, not what one must equal.

## The book's chapters, and where each lands

From memory of the 2013 edition's contents: to check against the book
before stage 1.

| the book | here |
|---|---|
| the tasking system (the loop, the commands, the tasks) | `Oberon.ml`, `Modules.ml`'s table |
| the display system (viewers, tracks, frames, messages) | `Display.ml`, `Viewers.ml`, `MenuViewers.ml` |
| the text system (texts, text frames, fonts, the editor) | `Texts.ml`, `TextFrames.ml`, `Fonts.ml` (Oberon's fonts), `Edit.ml` |
| the module loader | a table (decision 2); the chapter's subject is lost |
| the file system | ix's (decision 5); Oberon's own later, maybe |
| storage layout and management | mini-ml's runtime: nothing to write |
| device drivers (keyboard, mouse, disk) | `Input.ml` over ix's `Kbd` and USB |
| the network, the servers | not in this plan |
| the compiler, the RISC | not in this plan |
| the graphics editor | later, maybe |

## The stages (each checked before the next)

0. **The ground.** `kernel/oberon/mkfile` and the links: an image that
   boots on both boards and prints a line; a disk image with a text in
   it, made by a tool, read by `Fs`. Settles: the mkfile without
   `mkkernel`, what of `runtime.c` a kernel without processes keeps,
   `Files`'s clash.
1. **Display and Fonts.** The five operations and the three modes;
   Oberon10 read from the disk, a text drawn in it. The emulator built
   and run here for the first time, its boot's screen beside ours.
2. **Input, Viewers, MenuViewers, Oberon's loop.** The two tracks, the
   cursor, the fillers; a viewer opened, its bar dragged, closed; the
   messages (decision 3) end to end.
3. **Texts and TextFrames**: the piece table, the looks of a run
   (font, colour, offset); scrolling by the bar; the caret, the
   selection; the interclicks (delete, copy, copy looks). The largest
   stage: 1,393 lines of Oberon. Checked on the host first (decision
   7), then on the boards.
4. **The commands**: the table (decision 2), `Oberon.Call`, the log;
   System's and Edit's commands that need no writing to the disk; a
   command that fails leaves the loop running; a background task
   (`Blink`).
5. **The files written**: Files' writing half, `Edit.Store`,
   `System.CopyFiles`, `RenameFiles`, `DeleteFiles`; a text stored, the
   kernel started again, the text there.
6. **Programs of others**: Stars and Checkers (a frame and messages of
   their own, in their own files: the test of decision 3), Sierpinski,
   Hilbert.
7. Later, each to be decided: Oberon's file system;
   the SD card; Graphics and Draw (2,027 lines); a loader.

## The size

The system is 4,598 lines of Oberon. What OCaml and ix give for
nothing: Kernel's heap and collector (about half of its 271), most of
Modules (225: a table instead), Display's bit arithmetic (decision 4),
FileDir and most of Files (857: decision 5). What they
cost: the links' glue, the mkfile. My guess is **2,500 to 3,500 lines
of OCaml**, against mini-9pi's 10,300 or so; a
guess until stage 3 is written, where it will be known.

## Not checked yet

- the book's table of contents (the table above is from memory);
- that `Fs` and a tool to make its image are enough for Oberon's
  `Files` (a file made, then registered under its name; a rider);
- the emulator, cloned only: not built, not run; how the font files
  come out of its disk image (its `tools/`, or Oberon's format read by
  a few lines on the host);
- the licence. Project Oberon's (`ProjectOberon/license.txt`, read) is
  a permissive one, for "this software and its accompanying
  documentation"; that the fonts and `System.Tool` on the emulator's
  image are under it is my reading, for the author to confirm before
  they are in the repository;
- the middle button and the interclicks through QEMU's USB mouse;
- `Kbd`'s and `usb.c`'s own dependencies inside mini-9pi and mini-xv6;
- that mini-mk and mini-ml take a file by a symbolic link as they do in
  `kernel/step5` (C only there).
