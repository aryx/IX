# <img src="docs/logo.svg" alt="IX" height="48">

**A whole computer system in small, readable OCaml programs: a kernel,
a shell, C and ML compilers, an assembler and a linker, an editor, a
windowing system, a web browser, a build system, a database, version
control, and more.** It boots on real hardware: the
[Raspberry Pi](https://www.raspberrypi.com/), a computer anyone can
afford, and on its own emulator.

Website: **[aryx.github.io/IX](https://aryx.github.io/IX/)**, with a
[code map](https://aryx.github.io/IX/codemap.html) of the whole
repository to explore in the browser ([below](#the-code-map)), and
the system itself [running in a page](#two-sizes-of-each-program-m-ix-and-t-ix).

IX is a way to learn how a computer system works, end to end, by
reading its code. Each part of the system is a separate program, and
each program is small enough to read in a few sittings. None of them
is a toy, though. The compiler makes real ARM binaries. The kernel
runs a real operating system's user programs, up to its windowing
system and the network, and it boots on a real Raspberry Pi. IX's
emulator runs the same binaries and the same kernel.

The system IX follows is **Plan 9**, the successor of Unix written at
Bell Labs by Unix's own authors. Plan 9 is small, clean, and complete:
it has its own kernel, compilers, shell (`rc`), build tool (`mk`),
editor and windowing system (`rio`). It is explained program by
program in [Principia Softwarica](https://principia-softwarica.org/), a
series of books I (Yoann Padioleau) wrote, and my
[xix](https://aryx.github.io/xix/) project ports those programs to
OCaml at full size. You don't need to know either to read IX. IX
takes the same programs and makes each of them as small as it can.

## The goal: code a person can understand

Teaching people is the main goal of IX, and the test it sets itself is
that one person can understand all of it, not only each program.

Most software fails that test. A kernel, a compiler or a browser of
today is millions of lines and grows every year, until no single
person understands it, its own authors included. Plan 9 is one of the
few exceptions, which is why IX follows it.

Most of IX's code is written by an AI (see
[Who wrote it](#who-wrote-it)), but it does not start from nothing.
It starts from designs made by people (Plan 9's, xv6's, xix's), and it
is directed to write the smallest and most readable code that does the
job. That code is then meant to become
[literate programs](https://principia-softwarica.org/literate-programming.html), as in
Principia Softwarica: books of a reasonable size that explain all of
the code to a human reader.

That is the paradox of IX. The trend these days is to use AI to write
more and more code, faster than anyone can read it, until only the AI
can add a feature to the program. This was already partly true before
AI: many programs had grown so big that they were very hard to change.
IX uses AI the other way. Here it rewrites giant programs in far
**less** code, until a whole system is small enough for a person to
understand again, and to extend: by hand, or by asking the AI, but in
a way that person can still follow. AI can help people take back
control of the programs they use.

**Smaller programs, bigger understanding.**

## Two sizes of each program: m-IX and t-IX

Each program in IX comes in two versions:

- **mini** (`mini-mk`, `mini-rc`, `mini-cc`, ...): a faithful
  reimplementation of the Plan 9 program, only smaller. It is named
  after the original and does the same thing: its output is the
  original's, byte for byte. The executables `mini-cc` and `mini-ld`
  make are the ones Plan 9's compiler and linker make. Together, the
  mini programs are **m-IX** (a nod to Knuth's MIX computer).
- **tiny** (`tiny-build`, `tiny-shell`, `tiny-c`, ...): a free
  variant, in a single file under [`tiny/`](tiny/) (the largest
  with their parts in a directory beside it). It is named after
  what it does, not after the original. It keeps the idea of the
  original and redesigns the rest, now that compatibility no longer
  matters. Together, the tiny programs are **t-IX**.

For example, `mini-mk` reads real Plan 9 mkfiles and builds all of
xix from them, and all of Principia Softwarica's Plan 9, kernel
included. `tiny-build` is a build system in one file of about
370 lines. It keeps mk's rules and `%` patterns, and uses content
digests instead of timestamps. Reading the two side by side shows
what is essential to a build system and what is history.

What boots on the Raspberry Pi is m-IX's kernel, mini-9pi: from an SD
card, on a Pi 1 so far, with its shell, its window system and a USB
keyboard and mouse. The same kernel and the same card boot under QEMU
and under mini-qemu, IX's own Raspberry Pi emulator. t-IX boots on
tiny-machine, a machine of IX's own design, which is a program: it has
no board, and does not run under QEMU.

Both also run in your browser, on the website:
**[m-IX](https://aryx.github.io/IX/m-ix.html)** is mini-qemu compiled
to JavaScript, booting mini-9pi from its SD card (a first version,
slow), and **[t-IX](https://aryx.github.io/IX/t-ix.html)** is
tiny-machine compiled to JavaScript, booting tiny-kernel, its window
system and tetris.

## The code map

[IX's code map](https://aryx.github.io/IX/codemap.html) shows the
whole repository as a map, in the browser: each folder a region, each
file a block the size of its code, each block the code itself once you
zoom in. Every folder and file carries a one-line summary, and the
X-ray (`x`) shows each part's skeleton, the few definitions the rest
hangs on and how they connect. `/` searches, a click on a name shows
its definition, `g` shows the dependencies between the parts as a
matrix, and `h` lists every key.

[![IX's code map: every folder a region, every file a block](docs/pics/codemap.png)](https://aryx.github.io/IX/codemap.html)

A link can open it on any part of the code:
[a folder](https://aryx.github.io/IX/codemap.html?focus=version_control),
[a file](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyShell.ml),
[a definition](https://aryx.github.io/IX/codemap.html?focus=version_control&def=diff);
the tables below link each program so. It is tinybox's code map, from
[ocaml-elm-playground](https://github.com/aryx/ocaml-elm-playground),
after the author's [codemap](https://github.com/aryx/codemap); what it
says of each part comes from the `.codemapconfig` files in each
directory.

## m-IX: the mini programs

The line counts are OCaml, comments and `.mli` files included, tests
excluded (`make loc`'s rows, as of 2026-10-11). Each program's *map*
link opens it in the code map.

| program | what it is | lines | Plan 9 original | code |
|---|---|---:|---|---|
| **mini-9pi** | Plan 9's kernel in OCaml, on the Pi 1 and the Pi 4: boots Plan 9's own user programs up to the shell, the `rio` windowing system and TCP | 14,300 | `9pi` | [`kernels/9pi/`](kernels/9pi/) ([map](https://aryx.github.io/IX/codemap.html?focus=kernels/9pi)) |
| **lib_core** | what all the programs share: IX's own library, mini-ml's standard library, its threads, and the C library under its runtime | 19,400 | `libc`, ocaml-light's stdlib | [`lib_core/`](lib_core/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_core)) |
| **mini-rc** | the shell | 2,300 | `rc` | [`shell/`](shell/) ([map](https://aryx.github.io/IX/codemap.html?focus=shell)) |
| **the utilities** | the command-line programs, each a file or a few: mini-cat, mini-ls, mini-cp, mini-grep, mini-sed, mini-sort, mini-awk, mini-hoc, mini-dc, mini-bc, ... | 8,600 | `cat`, `ls`, `grep`, `sed`, `awk`, `hoc`, `dc`, `bc` | [`utilities/`](utilities/) ([map](https://aryx.github.io/IX/codemap.html?focus=utilities)) |
| **mini-troff**, **mini-man** | the typesetter, of manual pages, of papers, of Markdown and of books, for a terminal (the pages of Plan 9's manual come out with troff's own lines) and as PDF, with their tables, their pictures and the pictures they take from files (PNG, JPEG, GIF); it reads the macros of `man` and `ms`, `tbl` and `pic`, not troff's language under them; a format of IX's own, Markdown's lines and `\name{text}`, which it also writes: a manual page converted; and simple LaTeX with noweb's chunks of code, a table of commands and not TeX: principia's 21 books, 8,369 sheets, with their pages' numbers (the table of contents, noweb's 12b); IX's own manual pages for all its 93 programs, each saying how it differs from Plan 9's, listed by groups (`man 1`), on mini-9pi's card ([the plan](docs/plans/done/plan_typesetting.md): equations) | 6,700 | `troff -man -ms`, `tbl`, `pic`, `man`, `latex`, `noweave`, `bibtex` | [`typesetting/`](typesetting/) ([map](https://aryx.github.io/IX/codemap.html?focus=typesetting)) |
| **mini-cc** | the C compiler for arm and arm64; the same instructions as Plan 9's `5c` and `7c` | 6,000 | `5c`, `7c` | [`languages/c/`](languages/c/) ([map](https://aryx.github.io/IX/codemap.html?focus=languages/c)) |
| **mini-ml** | a native compiler for OCaml (the subset IX is written in), for arm and arm64; it compiles all of IX, the kernels included | 6,800 | ocaml-light's `ocamlopt` | [`languages/ml/`](languages/ml/) ([map](https://aryx.github.io/IX/codemap.html?focus=languages/ml)) |
| **mini-asm** | the assembler for arm and arm64 | 1,100 | `5a`, `7a` | [`assembler/`](assembler/) ([map](https://aryx.github.io/IX/codemap.html?focus=assembler)) |
| **mini-ld** | the linker, to Plan 9's a.out, Linux's ELF and macOS's Mach-O (arm64); the same executables as the original's, byte for byte | 3,100 | `5l`, `7l` | [`linker/`](linker/) ([map](https://aryx.github.io/IX/codemap.html?focus=linker)) |
| **mini-ed** | the line editor | 1,400 | `ed` | [`editors/ed/`](editors/ed/) ([map](https://aryx.github.io/IX/codemap.html?focus=editors/ed)) |
| **mini-emacs** | the screen editor, written after efuns: buffers, windows, the minibuffer, the kill ring, searches, keyboard macros, dired, the languages' colors; in a terminal, a window on Linux, and one of mini-rio's | 3,500 | efuns (the author's Emacs in OCaml) | [`editors/emacs/`](editors/emacs/) ([map](https://aryx.github.io/IX/codemap.html?focus=editors/emacs)) |
| **lib_graphics** | the graphics stack: points, rectangles, images, fonts, the display, the mouse, the keyboard and menus; the draw device itself is in mini-9pi | 6,100 | `libdraw`, `libmemdraw`, `devdraw` | [`lib_graphics/`](lib_graphics/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_graphics)) |
| **mini-rio** | the windowing system: a file server that gives each window its own `/dev/cons` and mouse, so a program in a window sees a machine of its own | 1,500 | `rio` | [`windows/`](windows/) ([map](https://aryx.github.io/IX/codemap.html?focus=windows)) |
| **lib_gui** | a GUI toolkit: widgets, themes, layouts, a text and its editing | 3,700 | `libpanel` | [`lib_gui/`](lib_gui/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_gui)) |
| **mini-office** | an office suite on lib_gui: rich text, a sheet with its formulas, drawing and painting | 6,900 | the author's playground's TinyOffice | [`apps/office/`](apps/office/) ([map](https://aryx.github.io/IX/codemap.html?focus=apps/office)) |
| **lib_networking** | the network outside the kernel: 9P, and a URL fetched over TCP, TLS 1.3 and HTTP, with mini-curl and mini-httpd; the IP stack itself is in mini-9pi | 4,600 | `lib9p`, `devip`, `webfs` | [`lib_networking/`](lib_networking/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_networking)), [`networking/`](networking/) |
| **mini-netscape** | a web browser: HTML, CSS, layout, a JavaScript engine and the pages' web API, over IX's own TLS 1.3 ([its window](browsers/netscape/) is 1,500 lines) | 28,200 | Netscape Navigator; the author's mini-chrome | [`browsers/`](browsers/) ([map](https://aryx.github.io/IX/codemap.html?focus=browsers)) |
| **lib_playground** | what the games are written on: Elm's Playground in OCaml (a picture, an animation, a game); Tetris and two others are in [`games/`](games/) | 7,700 | `games/4s` | [`lib_playground/`](lib_playground/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_playground)) |
| **mini-mk** | the build system; builds all of xix and of Principia Softwarica's Plan 9 from their mkfiles | 2,500 | `mk` | [`builder/`](builder/) ([map](https://aryx.github.io/IX/codemap.html?focus=builder)) |
| **mini-chidb** | a relational database: SQL, a query optimizer, B-trees | 3,100 | [chidb](https://github.com/uchicago-cs/chidb), SQLite's teaching twin | [`database/`](database/) ([map](https://aryx.github.io/IX/codemap.html?focus=database)) |
| **mini-git**, **mini-diff**, **mini-merge3** | version control, compatible with git repositories | 5,000 | `git9`, `diff` | [`version_control/`](version_control/) ([map](https://aryx.github.io/IX/codemap.html?focus=version_control)) |
| **mini-5i** | an ARM emulator for user programs, arm32 and arm64, with Linux's or Plan 9's system calls | 5,000 | `5i` | [`machine/`](machine/) ([map](https://aryx.github.io/IX/codemap.html?focus=machine)) |
| **mini-qemu** | a Raspberry Pi 1 and Pi 4 (MMU, interrupts, timer, UART, SD card, framebuffer, USB keyboard, mouse and network), which boots xv6, Plan 9 and IX's own kernels, as QEMU does | 4,300 | QEMU's raspi machines | [`raspberry/`](raspberry/) ([map](https://aryx.github.io/IX/codemap.html?focus=raspberry)) |

The table's programs, its five libraries apart, are about 103,900
lines of OCaml. With mini-lex and mini-yacc (1,600), and the rest
(what the kernel's boards share and its tools, two small applications:
2,200), the mini programs are 107,700 lines of OCaml.
Under them: 4,900 lines of C and assembly (mini-ml's runtime, the
kernel's start), and the libraries (44,200 lines): the table's five,
[`lib_crypto/`](lib_crypto/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_crypto)) (SHA-1, and what TLS 1.3 stands on) and
[`lib_compression/`](lib_compression/) ([map](https://aryx.github.io/IX/codemap.html?focus=lib_compression)) (zlib).
m-IX is **about 157,000 lines** in all, 130,000 without the header
comments that tell each module's idea and history, which is what its
budget of 150,000 counts
(`make loc`; its log is [docs/loc.md](docs/loc.md); the budget is
[below](#the-budget)).

## t-IX: the tiny programs

Each program is a single `.ml` file in [`tiny/`](tiny/) (the kernel
and the machine have a directory of parts beside theirs), with an `.mli`
beside it that is where to start reading (the idea, a diagram, the
history, and the types of `main` and of one function) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny)).
[tiny/README.md](tiny/README.md) says what idea each one keeps from
its original and what it redesigns.

Every program of t-IX runs on tiny-machine, under tiny-kernel; the
host (Linux, macOS) is the machine itself, and a test bench where dune
builds the same files with OCaml to try them.

**The machine**, the host's programs: what everything else runs on.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-cpu** | a CPU of our own design, for teaching | 350 | mini-5i, Knuth's MIX | [`TinyCPU.ml`](tiny/TinyCPU.ml), [`TinyMachineCPU.ml`](tiny/TinyMachine/TinyMachineCPU.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyCPU.ml)) |
| **tiny-machine** | tiny-cpu with what a kernel needs: two modes, traps, a timer, protection, a console, a disk, a screen and a mouse ([run it in your browser](https://aryx.github.io/IX/t-ix.html)) | 710 | mini-qemu | [`TinyMachine.ml`](tiny/TinyMachine.ml), [`TinyMachineDevices.ml`](tiny/TinyMachine/TinyMachineDevices.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyMachine.ml)) |

**The kernel**, and what it is made of.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-kernel** | a kernel in ML for tiny-machine: fork and exec, preemption, pipes, files (the disk the root, Plan 9's way: a union with the boot image's), a screen that programs draw on by messages | 800 | mini-9pi | [`TinyKernel.ml`](tiny/TinyKernel.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel.ml)) |
| **tiny-graphics** | the kernel's drawing: one operation, `draw`, on images a byte a pixel; texts, lines; a program says what by messages | 210 | mini-9pi's draw device | [`TinyKernelGraphics.ml`](tiny/TinyKernel/TinyKernelGraphics.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel/TinyKernelGraphics.ml)) |
| **tiny-fs** | the kernel's file system on the disk: inodes and their blocks as in Unix, but nothing written over: a change copies its blocks up to the root, and a commit is one block, so a crash needs no fsck; a collector finds the free blocks; each boot's files kept in `/dump` | 210 | mini-xv6's Fs | [`TinyKernelFS.ml`](tiny/TinyKernel/TinyKernelFS.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel/TinyKernelFS.ml)) |
| **tiny-network** | the kernel's network, and the other end of tiny-machine's wire: functions of strings: IP's envelope, the echo (`ping`), and Plan 9's IL for messages that arrive once and in order (`get`, `www`: a web page, its pictures painted as their packets arrive; `httpd`: its files in a browser) | 660 | mini-9pi's ip | [`TinyKernelNetwork.ml`](tiny/TinyKernel/TinyKernelNetwork.ml), [`TinyMachinePeer.ml`](tiny/TinyMachine/TinyMachinePeer.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel/TinyKernelNetwork.ml)) |

**The tools**, in tiny-kernel's `/bin` (`rc`, `ed`, `build`, `db`,
`vcs`, `prof`).

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-shell** | a shell in rc's spirit: lists as the only value | 610 | mini-rc | [`TinyShell.ml`](tiny/TinyShell.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyShell.ml)) |
| **tiny-editor** | an editor with sam's command language | 750 | mini-ed | [`TinyEditorLine.ml`](tiny/TinyEditorLine.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyEditorLine.ml)) |
| **tiny-build** | a build system: rules, `%`, digests, `-j` | 390 | mini-mk | [`TinyBuildSystem.ml`](tiny/TinyBuildSystem.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBuildSystem.ml)) |
| **tiny-db** | a database whose query language is the relational algebra, over a copy-on-write B-tree | 630 | mini-chidb | [`TinyDatabase.ml`](tiny/TinyDatabase.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyDatabase.ml)) |
| **tiny-vcs** | version control with git's objects, an undo log, and no staging area | 650 | mini-git | [`TinyVCS.ml`](tiny/TinyVCS.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyVCS.ml)) |
| **tiny-prof** | a profiler: every instruction counted by its address, the kernel's and each program's apart, named by the linker's map | 130 | mini-prof | [`TinyProfiler.ml`](tiny/TinyProfiler.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyProfiler.ml)) |

**The toolchain**, in tiny-kernel's `/bin` too (`cc`, `ml`, `as`,
`ld`), where each makes what the host's makes, byte for byte;
[plan_tiny_self_hosting.md](docs/plans/done/plan_tiny_self_hosting.md)'s
step 8 has t-IX built there.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-c** | a C subset compiler, to tiny-cpu | 1,020 | mini-cc | [`TinyC.ml`](tiny/TinyC.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyC.ml)) |
| **tiny-ml** | an ML compiler (Hindley-Milner types, closures, exceptions, a garbage collector) to tiny-cpu | 2,000 | mini-ml | [`TinyML.ml`](tiny/TinyML.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyML.ml)) |
| **tiny-assembler**, **tiny-linker** | tiny-machine's assembler, a file to an object (its words, its labels, the places a label's address goes), and its linker, objects to an image, filling each place by encoding again | 460 | mini-asm, mini-ld | [`TinyAssembler.ml`](tiny/TinyAssembler.ml), [`TinyLinker.ml`](tiny/TinyLinker.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAssembler.ml)) |

**The window system** and the programs in its windows.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-windows** | a window system, a program in ML: a window looks like the machine, so it runs in one of its own windows | 420 | mini-rio | [`TinyWindows.ml`](tiny/TinyWindows.ml), [`TinyLibDraw.ml`](tiny/TinyLibDraw.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyWindows.ml)) |
| **tiny-playground** | what a game is written on: a model, a view as shapes, a key, a frame; the loop and the drawing are the library's | 110 | the playground | [`TinyLibPlayground.ml`](tiny/TinyLibPlayground.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibPlayground.ml)) |
| **tiny-gui** | what a program with buttons and fields is written on: widgets made from the model, each carrying the message it sends; the layout, the mouse, the keys' focus and the drawing are the library's | 220 | lib_gui | [`TinyLibGUI.ml`](tiny/TinyLibGUI.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibGUI.ml)) |
| **tiny-tetris** | Tetris, in a window of tiny-windows | 150 | the playground's Tetris | [`TinyAppTetris.ml`](tiny/TinyAppTetris.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppTetris.ml)) |
| **tiny-calculator**, **tiny-temperature** | two programs on it, in a window of tiny-windows: a calculator of four operations, sixteen buttons; two fields typed in, Celsius and Fahrenheit, each the other's answer | 70, 40 | lib_gui's 7GUIs | [`TinyAppCalculator.ml`](tiny/TinyAppCalculator.ml), [`TinyAppTemperature.ml`](tiny/TinyAppTemperature.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppCalculator.ml)) |
| **tiny-office** | an office suite in one program: a document of pages of boxes, each a text edited as it is shown (bold, italic, large), a sheet with its formulas, a drawing, a paint or a chart that follows its sheet; pull-down menus; its file Markdown with a few LaTeX commands | 860 | mini-office | [`TinyOffice.ml`](tiny/TinyOffice.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyOffice.ml)) |
| **tiny-troff** | the office's documents, or Markdown, printed as text, a web page or PDF | 310 | mini-troff | [`TinyTroff.ml`](tiny/TinyTroff.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyTroff.ml)) |
| **tiny-browser** | a web browser, `www`: a page read as it arrives, its links followed, its pictures painted as their packets come, Wikipedia's articles fetched by the host | 1,040 | mini-netscape | [`TinyBrowser.ml`](tiny/TinyBrowser.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBrowser.ml)) |

A program is in what both OCaml and tiny-ml compile, and asks the
system through one interface with a file for each side:
`TinyLibSystem` for the tools
([`TinyKernel/host/`](tiny/TinyKernel/host/TinyLibSystem.mli)'s over
Unix, [`TinyKernel/libml/`](tiny/TinyKernel/libml/TinyLibSystem.ml)'s
over the kernel's calls), `TinyCalls` for the graphical programs
(a virtual library of dune's, whose host side is a window of SDL's:
[`tiny/sdl/`](tiny/sdl/)). Its three builds:

| | compiled by | its standard library |
|---|---|---|
| on tiny-machine | tiny-ml | [`tiny/TinyLibCore/`](tiny/TinyLibCore/Stdlib.mli) (Stdlib, List, String, Buffer, Hashtbl...: OCaml's subset, which OCaml checks), on [`tiny/TinyMLRuntime/`](tiny/TinyMLRuntime/) |
| on the host, for the tests | OCaml and dune | OCaml's own, and [`lib_core/commons/`](lib_core/commons/) |
| on the host, by IX (a test of m-IX's compiler) | mini-ml, by `mini-mk` | IX's own, in `lib_core/` |

The programs are about 24,100 lines of OCaml and ML; with their C
(tiny-c's and tiny-ml's runtimes, tiny-kernel's programs in C)
t-IX is **about 26,300 lines** in all (the header comments are in
the `.mli` files, which are not counted), of a budget of 30,000. tiny-cpu and tiny-machine also
run [`tiny/TinyKernel/steps/`](tiny/TinyKernel/steps/), the steps before tiny-kernel, written for
them in their assembly and in C for `tiny-c`: a page-long kernel (v0)
and a kernel in C with a disk and a shell (t6). Their 2,000 lines are not counted in t-IX: t-IX's kernel is
tiny-kernel, which needs none of them.

## Build and run

```bash
./configure   # checks the tools, installs the opam packages (Linux, macOS)
make          # builds everything; the executables are then in bin/
make test
./bin/mini-mk -h            # every program has -h, with examples
./mini-pi mini-9pi          # boot mini-9pi on mini-qemu, with ix's own programs (mini-rc...)
./mini-pi mini-9pi-principia -g   # with principia's programs and SD card: type rio
./tiny-machine t6           # boot t6, a kernel in C with a disk, a step before tiny-kernel
./tiny-machine -window tiny-kernel   # tiny-kernel and its screen: type windows, then tetris in a window
```

`./configure` wants OCaml, opam and make; the rest it only warns about,
saying what does without it. The other projects' checkouts
(`~/ocaml-light`, `~/principia`, `~/xv6`) are optional: `./mini-pi
mini-9pi` needs nothing but IX, its kernel compiled by ocaml-light when
that is there and by IX's own tools (mini-ml, mini-cc...) when not. On
macOS, which has no GNU cross compiler for the Pi 1, it finds
Homebrew's clang and lld (`brew install llvm lld`) and writes them in
`Makefile.config`.

mini-9pi under mini-qemu, running Plan 9's own `rio`
(`kernels/9pi/tests/screenshot.py` made the picture):

![mini-9pi under mini-qemu: a rio window, with echo, date, ls and ps typed in it](docs/pics/mini-9pi.png)

tiny-kernel on tiny-machine, Tetris in a window of tiny-windows (the
screen at the end of a recorded session, `tiny/tests/TinyKernel_tests/tetris.events`):

![tiny-kernel on tiny-machine: a window of tiny-windows, Tetris played in it](docs/pics/tiny-tetris.png)

The tests, short and whole:

```bash
make test-lite      # under a minute, on all the cores: unit tests, mini-ml on IX,
                    # IX built by IX from nothing, a kernel booted
make test-all       # every test suite, one after the other, with a summary: half an
                    # hour (tests/all.sh -l lists them; -quick: the short ones)
```

`dune install` installs both the mini and the tiny executables.
`make build-docker` builds and tests IX in a fresh Ubuntu (the
[`Dockerfile`](Dockerfile), which GitHub Actions runs with OCaml 4.14.2
and 5.5.1).

The plans, tutorials, manuals and related-work notes are indexed in
[docs/README.md](docs/README.md), and
[docs/projects.md](docs/projects.md) maps the projects inside IX: the
machines (real ARM, or our own) and what runs on each.

## Bootstrapping

IX builds itself. The first build needs a compiler from outside:
`make` uses dune, OCaml 4.14 and, under OCaml, gcc. After it, IX's own
tools are enough: mini-mk runs the mkfiles, mini-ml, mini-lex and
mini-yacc compile the OCaml, mini-cc and mini-asm the C library and
mini-ml's runtime, mini-ar and mini-ld link. No OCaml compiler, gcc,
GNU binutils or glibc is run or linked; the results are under `_mk/`.

```bash
make                # stage 0: IX built by OCaml and dune (bin/)
make ix             # stage 1: IX built by stage 0's tools, for arm64 (make ix-arm: for arm)
make test-fixpoint  # stage 2: IX built by stage 1's tools: the same files
make kernels-ix     # mini-xv6 and mini-9pi for the Pi 4, the same way
make test-ix        # each program of stage 1 against dune's build of it
```

Stage 2 is the fixed point: IX built by the programs that IX built
gives the same 383 files as stage 1, byte for byte, in about a minute
on a large machine. On arm, where the programs run under qemu-arm, the
second and third builds are the same 358 files (`make
test-fixpoint-arm`). The kernels built this way boot on the Pi 4 under
mini-qemu and QEMU and pass the same checks as the ones built by
ocaml-light and gcc (`make test-kernels-ix`).

What is not built by IX: mini-qemu, which opens its window with SDL,
and the tests. The plan and its history are in
[docs/plans/done/plan_mkfiles.md](docs/plans/done/plan_mkfiles.md) and
[docs/plans/done/plan_ml_bootstrap.md](docs/plans/done/plan_ml_bootstrap.md).

## Tiny (and mini), not Toy

There is a good tradition of teaching computer systems by their code:
[Nand2Tetris](https://www.nand2tetris.org/)
([*The Elements of Computing Systems*](https://www.nand2tetris.org/book))
for the whole stack, [Minix](https://www.minix3.org/)
([*Operating Systems: Design and Implementation*](https://en.wikipedia.org/wiki/Operating_Systems:_Design_and_Implementation))
for an operating system, and [xv6](https://pdos.csail.mit.edu/6.828/xv6)
for a kernel. The Nand2Tetris route makes everything minimal: a made-up machine, a
made-up assembler, a made-up OS. IX aims for the full stack too, but
makes the *programs* tiny, not the things they deal with:

- **The machine is real ARM**, arm32 and arm64. mini-5i runs user
  programs; mini-qemu is a whole Raspberry Pi, so that real kernels,
  not just user programs, run on it. The emulator stops with
  "unimplemented instruction" on what it does not know, so it also
  checks that a binary stays inside what IX handles.
- **The binaries are real.** mini-cc, mini-asm and mini-ld make them as
  Plan 9's compilers do, in three formats: ELF for Linux (arm and
  arm64), Mach-O for macOS (arm64, to sign with `codesign`), and
  Plan 9's a.out. So you can use the toolchain for programs on your
  own machine, as with [goken](https://github.com/aryx/goken9cc). The
  same binary runs on IX's emulator, on
  QEMU and on a real ARM machine. Running it on several and comparing
  the results is the main test.
- **The system calls are real.** User programs talk to the kernel
  with Plan 9's system call ABI, and mini-9pi runs Plan 9's own user
  programs, unmodified, from Plan 9's own SD card image.

One group of tiny programs takes the other road on purpose. tiny-cpu
and tiny-machine are a made-up machine, as Knuth's MIX and
[MMIX](https://www-cs-faculty.stanford.edu/~knuth/mmix.html)
([*MMIXware: A RISC Computer for the Third Millennium*](https://www-cs-faculty.stanford.edu/~knuth/mmixware.html))
and Nand2Tetris's Hack are, because what they teach is the design of an
instruction set: the choices a real one made for history's reasons,
made again with hindsight. tiny-cpu stands next to mini-5i, the
same program for real ARM, so that the two roads can be compared.

## Still to come

The rest of the system, following the Principia Softwarica books (the
names are not final):

| part | mini | tiny | Plan 9 original |
|---|---|---|---|
| Debuggers | mini-db, mini-acid | tiny-debugger | `db`, `acid` |
| Profilers | mini-prof | tiny-profiler | `prof`, `tprof` |

What else was on this list is in [m-IX's table](#m-ix-the-mini-programs)
now. t-IX has its graphics, its windows, its network, a GUI toolkit,
an office suite and a web browser.

### The budget

A system a person can read needs a limit set before it is full:
**150,000 lines for m-IX** and **30,000 for t-IX**, without the tests
and without the header comments that tell each module's idea and
history (m-IX's was 100,000 until 2026-10-09, when the office suite
and the two libraries under it, the GUI toolkit and the playground,
came to be counted, and 125,000 until 2026-10-10, the web browser
in; t-IX's was 20,000 until 2026-10-13, its GUI toolkit in, 25,000
until 2026-10-19, its file system in, then 30,000, and 25,000 again
the same day, its arm64 side and TinyLibHost out, and 30,000 since
2026-10-21, its code rewrapped to 80 columns).
What is still to come has to fit in what is left, and when it does
not, something is trimmed first.

| | budget | today (2026-10-21) | left | what is missing |
|---|---:|---:|---:|---|
| **m-IX** | 150,000 | 151,000 | -1,000 | the debuggers, the profiler |
| **t-IX** | 30,000 | 26,300 | 3,700 | tiny-debugger, several cores (plan_tiny_multicore.md) |

[docs/loc.md](docs/loc.md) is the log of these numbers, with what
moved them.

## Design

- **Everything is OCaml, the kernel included, and it runs as a real
  binary.** Unlike Nachos, where the "OS" is ordinary code running on
  the host, mini-9pi is an actual ARM binary: a thin layer of C and
  assembly boots the machine and starts a stripped-down OCaml runtime,
  and the kernel is OCaml from there on. The same binary boots on
  mini-qemu, on QEMU, and on a real Raspberry Pi (a Pi 1 so far).
  Processes, address
  spaces, context switches, supervisor and user mode and the system
  call boundary are therefore real. Today mini-9pi is compiled by
  ocaml-light's `ocamlopt`; mini-ml is being written to take over.

  ```
   user program (a.out)                          user mode
   ----------------- SWI / trap / irq -----------------------
   mini-9pi (OCaml + thin C/asm runtime shim)     supervisor mode
   ---------------------------------------------------------------
   ARM CPU + CP15 (MMU, modes): a real Raspberry Pi, or
   mini-qemu emulating one, with disk, timer, framebuffer,
   keyboard, mouse and network
  ```

- **Most tools are terminal programs.** They read and write files,
  stdin and stdout, and depend on nothing graphical. They follow
  [xix](https://aryx.github.io/xix/)'s capability style (`Cap.*`) for
  OS access.
- **Only mini-qemu depends on a GUI library** (SDL), to show the
  machine's framebuffer and feed it the keyboard and mouse. The
  machine itself is a pure library, so it also runs in a terminal. The
  graphical programs (rio and those it runs) run *inside* the machine
  and draw into its framebuffer, as on a real computer.

## Who wrote it

IX is mostly written by Claude (Anthropic's AI, in Claude Code), under
my direction: I choose the design and review the code, and Claude
writes most of the lines, for people to read
([the goal](#the-goal-code-a-person-can-understand)). xix, on the other hand, I mostly wrote
myself. Putting each mini program next to its xix twin makes a fair
comparison of the two ways of working. The project started on
2026-09-21; [docs/history.md](docs/history.md) tells how.

[docs/yoann_notes/prompt-history.md](docs/yoann_notes/prompt-history.md)
shows the other side of that work: every prompt I wrote to Claude to
build IX, in order and verbatim (typos included), each followed by a
short summary of Claude's answer. Hooks in `.claude/` append the
entries as I work, so the file grows with the repository. Read next to
`git log`, it shows what directing an AI to write a codebase looks like
day to day.

## The name

IX is 9 in roman numerals (Plan 9), and ix is xix with a letter
removed: a smaller xix, as 9 is smaller than 19. It is also the "-ix"
of Unix, Minix and Linux with nothing in front. And it has two
letters, like `rc`, `mk`, `ed` and the other Unix and Plan 9 names,
and like "ai", which writes most of it. In text it is written IX, as
UNIX was, and ix where it is a name in the code (`ix_core`, `ix_db`).

## License

LGPL 2.1 with the OCaml-style linking exception, like
[xix](https://aryx.github.io/xix/): see [license.txt](license.txt) and
[copyright.txt](copyright.txt).
