# tiny/

The tiny programs of ix (t-IX): the free variants of its mini programs
(m-IX), what is left of a program when compatibility is dropped and only
its idea is kept, written after its faithful twin and from what that one
taught. Together they are a whole system: a CPU and its machine
(tiny-machine), a kernel in ML (tiny-kernel), its toolchain, its shell,
utilities, editors, window system and applications. Each program runs
on tiny-kernel, in `/bin` by a short name (`build`, `rc`...), and on the
host as `tiny-build`, `tiny-shell`... for its tests (the table's second
column).

## Reading a program

A program is `TinyXxx.ml`, and its `.mli` is where to start: its
header (the idea, a diagram, its twin, what it keeps, drops and adds:
`docs/tags.md`), then `main` and the functions at its heart, with their
types; the `.ml` is the code alone. Where a program is a pipeline, its
`.mli` says so, a stage a function (`TinyAssembler.mli`, `TinyC.mli`,
`TinyML.mli`). Once it grows past some 700 lines, a program has a
directory of its parts beside it, its units, each with its own `.mli`:
`TinyC/`, `TinyML/`, `TinyOffice/`, `TinyBrowser/`, `TinyMachine/`. The
kernel is a directory alone, `TinyKernel/`, its boot `TinyKernel.ml`
beside its parts.

## What is where

- `TinyLibXxx` is a library several programs share, a whole library in
  one file: `TinyLibSystem.mli` (the system, below), `TinyLibDraw`,
  `TinyLibPlayground` and `TinyLibGUI` (drawing, a game's loop,
  widgets), `TinyLibRegex` (Plan 9's regular expressions, for grep and
  the line editor), `TinyLibMachine` (libmach: the instructions, the
  objects, the labels, for the toolchain, prof and debug).
  `TinyLibCore/` is tiny-ml's standard library: OCaml's modules as a
  tiny program names them (`Stdlib`, `List`, `Hashtbl`...), each a
  subset that OCaml checks.
- `TinyAppXxx.ml` is an application on the playground or the widgets
  (`calc`, `temp`, `tetris`, `square`); `user/` has each program's main
  on tiny-kernel: an ML program's one line, a C program whole (`sh.c`,
  `ping.c`, `paint.c`...).
- `runtime/` is what every compiled program is linked with, each
  language's in its directory, as the disk's `/lib/c` and `/lib/ml`:
  `c/`, C's start, its division, its library, the system's calls
  (`user.h`, `sys.s`), drawing and dialing (`draw.c`, `net.c`); `ml/`,
  ML's allocator and collector (`ml.c`), its glue to the system
  (`mlsys.c`) and the program's end (`end.s`).
- `TinyKernel/` is the kernel and only it: its parts in ML, its
  assembly and C, its Buildfile, and `Makefile`, which
  builds the image and the disk and runs the tests on tiny-machine;
  `steps/` has what ran before it (a C program on the bare CPU, `v0/` in
  assembly, `t6/` in C).
- `TinyMachine.ml` and `TinyMachine/` are the machine on the host: the
  CPU (`TinyMachineCPU`, which `TinyCPU.ml`, tiny-cpu, runs alone), the
  devices, the other end of the wire, and its window, its socket and
  its web page (`./tiny-machine -web dir tiny-kernel`).
- `examples/` is tiny-kernel's `/examples`, the same files: small
  programs to read, build and run, in C and ML.
- `tests/` has each program's tests, `tests/TinyXxx_test.sh`.

## Conventions

- A program's parts are named for what they are, their directory saying
  whose: `TinyML/Lexer.ml`, `TinyBrowser/Http.ml`, not `TinyMLLexer`.
  Two programs' parts may share a name (`Lexer`), since each program is
  compiled with its own `-I`'s (the Buildfile's `X_INCLUDES`). The
  kernel's parts, which other programs link too, carry a `K` (`KFS`,
  `KProcs`), and its assembly and C a `k` (`kentry.s`, `kruntime.c`):
  what goes in the kernel's image, not a program's.
- Names are qualified, not opened: `Compile.bind`, `KFS.fs_read`,
  `Strings.find`. A file opens `Common` (`|||`, `let*`, `Error`), and a
  program its core vocabulary, the types all its parts speak: office's
  `Model`, the kernel's `KProcs`, the browser's `Lines`. The apps'
  libraries go by a letter, `module P = TinyLibPlayground`, `G =
  TinyLibGUI`, `D = TinyLibDraw` (`P.Move (x, y, P.Rect ...)`, `msg
  G.widget`). A test may open what it tests.
- Another module's record or constructor is found by its type, given by
  an annotation where nothing else says it (`(sc : Screen.screen)`,
  `let fds : (int * KFiles.file) list = ...`), rather than by a prefix
  on each label. tiny-ml takes no `_` in a type.
- Lines at 80 columns, 85 now and then.

## One program, two systems

A program never names its system: it names one interface,
`TinyLibSystem.mli`, implemented for each in
[`TinyLibSystem/`](TinyLibSystem/README.md): `unix/` over OCaml's Unix
and `lib_core/`, for the tools on the host; `tinykernel/` over the
kernel's calls; `sdl/`, a window on the host, for the graphical
programs; `teststub/`, the tests'. So the same file is tiny-kernel's
`rc` and the host's tiny-shell, and a graphical program draws on its
`fd_draw` whether it runs on tiny-kernel or in a window on the host
(tiny-calc, tiny-tetris, tiny-www...).
[docs/projects.md](../docs/projects.md#what-a-tiny-program-stands-on)
has the picture of what each kind of program stands on.

## The programs

A program's lines are its code lines (no comment, no blank line), its
`.mli` and its directory of parts included, as `make loc` counts them
(2026-11-13).

**The machine**, the host's programs: what everything else runs on.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-cpu** | a CPU of our own design, for teaching | 220 | mini-5i, Knuth's MIX | [`TinyCPU.ml`](TinyCPU.ml), [`TinyMachineCPU.ml`](TinyMachine/TinyMachineCPU.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyCPU.ml)) |
| **tiny-machine** | tiny-cpu with what a kernel needs: two modes, traps, a timer, protection, a console, a disk, a screen and a mouse ([run it in your browser](https://aryx.github.io/IX/t-ix.html)) | 2,530 | mini-qemu | [`TinyMachine.ml`](TinyMachine.ml), [`TinyMachine/`](TinyMachine/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyMachine.ml)) |

**The kernel**, and what it is made of.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-kernel** | a kernel in ML for tiny-machine: fork and exec, preemption, pipes; files on a disk (the root, Plan 9's way: a union with the boot image's) where nothing is written over: a change copies its blocks up to the root and a commit is one block, so a crash needs no fsck, each boot's files kept in `/dump`; a screen that programs draw on by messages, one operation, `draw`, its loops in assembly; a network, Plan 9's IL over IP, for `ping`, `get`, `www` (a web page, its pictures painted as their packets arrive) and `httpd` (its files in a browser) | 3,880 | mini-9pi, mini-xv6's Fs | [`TinyKernel/`](TinyKernel/): [`TinyKernel.ml`](TinyKernel/TinyKernel.ml), [`KFS.ml`](TinyKernel/KFS.ml), [`KGraphics.ml`](TinyKernel/KGraphics.ml), [`KNetwork.ml`](TinyKernel/KNetwork.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel)) |

**The tools**, in tiny-kernel's `/bin` (`rc`, `ed`, `build`, `db`,
`vcs`, `prof`).

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-shell** | a shell in rc's spirit: lists as the only value | 650 | mini-rc | [`TinyShell.ml`](TinyShell.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyShell.ml)) |
| **tiny-editor** | an editor with sam's command language | 650 | mini-ed | [`TinyEditorLine.ml`](TinyEditorLine.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyEditorLine.ml)) |
| **tiny-build** | a build system: rules, `%`, digests, `-j` | 530 | mini-mk | [`TinyBuildSystem.ml`](TinyBuildSystem.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBuildSystem.ml)) |
| **tiny-db** | a database whose query language is the relational algebra, over a copy-on-write B-tree | 670 | mini-chidb | [`TinyDatabase.ml`](TinyDatabase.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyDatabase.ml)) |
| **tiny-vcs** | version control with git's objects, an undo log, and no staging area | 770 | mini-git | [`TinyVCS.ml`](TinyVCS.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyVCS.ml)) |
| **tiny-prof** | a profiler: every instruction counted by its address, the kernel's and each program's apart, named by the linker's map | 120 | mini-prof | [`TinyProfiler.ml`](TinyProfiler.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyProfiler.ml)) |

**The toolchain**, in tiny-kernel's `/bin` too (`cc`, `ml`, `as`,
`ld`), where each makes what the host's makes, byte for byte;
[plan_tiny_self_hosting.md](../docs/plans/done/plan_tiny_self_hosting.md)'s
step 8 has t-IX built there.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-cc** | a C subset compiler, to tiny-cpu | 1,410 | mini-cc | [`TinyC.ml`](TinyC.ml), [`TinyC/`](TinyC/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyC.ml)) |
| **tiny-ml** | an ML compiler (Hindley-Milner types, closures, exceptions, a garbage collector) to tiny-cpu | 2,860 | mini-ml | [`TinyML.ml`](TinyML.ml), [`TinyML/`](TinyML/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyML.ml)) |
| **tiny-as**, **tiny-ld** | tiny-machine's assembler, a file to an object (its words, its labels, the places a label's address goes), and its linker, objects to an image, filling each place by encoding again | 520 | mini-asm, mini-ld | [`TinyAssembler.ml`](TinyAssembler.ml), [`TinyLinker.ml`](TinyLinker.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAssembler.ml)) |

**The window system** and the programs in its windows.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-windows** | a window system, a program in ML: a window looks like the machine, so it runs in one of its own windows | 490 | mini-rio | [`TinyWindows.ml`](TinyWindows.ml), [`TinyLibDraw.ml`](TinyLibDraw.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyWindows.ml)) |
| **tiny-playground** | what a game is written on: a model, a view as shapes, a key, a frame; the loop and the drawing are the library's | 220 | the playground | [`TinyLibPlayground.ml`](TinyLibPlayground.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibPlayground.ml)) |
| **tiny-gui** | what a program with buttons and fields is written on: widgets made from the model, each carrying the message it sends; the layout, the mouse, the keys' focus and the drawing are the library's | 520 | lib_gui | [`TinyLibGUI.ml`](TinyLibGUI.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibGUI.ml)) |
| **tiny-tetris** | Tetris, in a window of tiny-windows | 200 | the playground's Tetris | [`TinyAppTetris.ml`](TinyAppTetris.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppTetris.ml)) |
| **tiny-calculator**, **tiny-temperature** | two programs on it, in a window of tiny-windows: a calculator of four operations, sixteen buttons; two fields typed in, Celsius and Fahrenheit, each the other's answer | 80, 40 | lib_gui's 7GUIs | [`TinyAppCalculator.ml`](TinyAppCalculator.ml), [`TinyAppTemperature.ml`](TinyAppTemperature.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppCalculator.ml)) |
| **tiny-office** | an office suite in one program: a document of pages of boxes, each a text edited as it is shown (bold, italic, large), a sheet with its formulas, a drawing, a paint or a chart that follows its sheet; pull-down menus; its file Markdown with a few LaTeX commands | 1,540 | mini-office | [`TinyOffice.ml`](TinyOffice.ml), [`TinyOffice/`](TinyOffice/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyOffice.ml)) |
| **tiny-troff** | the office's documents, or Markdown, printed as text, a web page or PDF | 460 | mini-troff | [`TinyTroff.ml`](TinyTroff.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyTroff.ml)) |
| **tiny-browser** | a web browser, `www`: a page read as it arrives, its links followed, its pictures painted as their packets come, Wikipedia's articles fetched by the host | 1,830 | mini-netscape | [`TinyBrowser.ml`](TinyBrowser.ml), [`TinyBrowser/`](TinyBrowser/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBrowser.ml)) |

### The idea each keeps

| file | on tiny-kernel (on the host) | its twin | the idea kept |
|---|---|---|---|
| `TinyBuildSystem.ml` | `build` (tiny-build) | `builder/` (mini-mk, mk) | rules, `%`, stamps as digests, one pass with `-j` |
| `TinyShell.ml` | `rc` (tiny-shell) | `shell/` (mini-rc, rc) | lists as the only value, words joined by adjacency, redirections around the command |
| `TinyUtilities.ml` | `utils`, as `cat`, `ls`, `wc`... (tiny-utils) | `utilities/` (mini-cat, mini-ls...; Plan 9's) | one executable with a name per utility, BusyBox's way; a filter is a function over its input's pieces, a walker one fold over a tree |
| `TinyEditorLine.ml` | `ed`, also named `sam` (tiny-editor) | `editors/ed/` (mini-ed, ed) | sam's command language: dot a range, loops over matches, changes in parallel |
| `TinyEditorScreen.ml` | `emacs`, also named `editor` (tiny-emacs) | `editors/emacs/` (mini-emacs) | Emacs's keys on one text in one window, the text its lines split at the cursor (Emacs's gap, of values that cannot change), the editor a state and the keys that change it |
| `TinyOffice.ml`, `TinyOffice/` | `office` (tiny-office) | `apps/office/` (mini-office) | a document of pages of boxes, each a kind of document whose data is text (a text edited as shown, a sheet, a drawing, a paint, a chart); its file Markdown with a few LaTeX commands ([`plan_tiny_office.md`](../docs/plans/done/plan_tiny_office.md)) |
| `TinyPlay.ml` | `play` (tiny-play) | `apps/media/play/` (mini-play), `lib_audio/formats/wav/` | a WAV file to the speaker a block at a time, the kernel pacing it, each of the speaker's samples taken exactly by Bresenham's stepping |
| `TinyTroff.ml` | `troff` (tiny-troff) | `typesetting/` (mini-troff) | the office's documents, or Markdown, as text, HTML or PDF, read by the office's own functions; PDF in Courier, a standard font, 8 points a character at 13.33 points |
| `TinyC.ml`, `TinyC/` | `cc` (tiny-cc) | `languages/c/` (mini-cc; 5c, 7c) | a C subset through a stack machine of its own, the stack in registers, with its own runtime (`runtime/`); Plan 9's names, ANSI's rules |
| `TinyML.ml`, `TinyML/` | `ml` (tiny-ml) | `languages/ml/` (mini-ml; ocaml-light's ocamlopt) | an ML (variants, closures, exceptions, Hindley-Milner) through TinyC's stack machine; its roots on a stack of values of its own, so its collector, Cheney's, in C, needs no frame table |
| `TinyDatabase.ml` | `db` (tiny-db) | `database/` (mini-chidb; chidb) | the relational algebra as the query language, a pipeline (`t \| where ... \| group ... \| sort ...`); a copy-on-write B-tree, so every statement is atomic by one header write |
| `TinyCPU.ml`, `TinyMachine/TinyMachineCPU.ml` | (tiny-cpu) | `machine/` (mini-5i; 5i), with Knuth's MIX and MMIX | a machine of our own design, for teaching: 16 registers, r0 zero, no flags, one instruction format, every case defined; the interpreter is its definition |
| `TinyAssembler.ml`, `TinyLinker.ml` | `as`, `ld` (tiny-as, tiny-ld) | `assembler/`, `linker/` (mini-asm, mini-ld; 5a/5l) | a new machine's toolchain, since nothing else writes its words: a file to an object, objects to an image or an a.out, a place filled by encoding the word again so that `encode`'s checks hold |
| `TinyArchiver.ml` | `ar` (tiny-ar) | `linker/tools/Ar.ml` (mini-ar; Plan 9's ar) | objects in one library, in their order, with no index, date or owner, so that a library made twice has the same bytes |
| `TinyProfiler.ml` | `prof` (tiny-prof) | mini-qemu's `-prof` (`raspberry/observe/Prof.ml`) and `kernels/9pi/tests/perf/pcprof.py` | every instruction counted by its address, not sampled, so that two runs give the same profile; the kernel's and each program's apart, named by tiny-ld's map |
| `TinyMachine.ml` | (tiny-machine) | `raspberry/` (mini-qemu), with Project Oberon and RISC-V's privileged specification | TinyCPU with what a kernel needs, designed: two modes, one trap and eret, a timer counting instructions, protection by a window (base, bound); and, as options, a screen and a speaker that are memory, a mouse, a disk, a wire to a network |
| `TinyKernel/` (`TinyKernel.ml`) | tiny-kernel (`./tiny-machine tiny-kernel`) | `kernels/9pi/` (mini-9pi; 9pi) | a kernel in ML: the concepts kept (modes, system calls, preemption, fork and exec, pipes, files), each by the road ML makes short: the kernel a loop running a process to its next trap, a waiting call a closure the scheduler retries (no kernel stack per process); [`notes_tiny_kernel.md`](../docs/notes/notes_tiny_kernel.md) |
| `KGraphics.ml` | in tiny-kernel | `lib_graphics/`, mini-9pi's `lib_memdraw` (libdraw, libmemdraw) | one operation, `draw dst r src mask p`, on images a byte a pixel; a colour is an image of one pixel that repeats; the kernel has the pixels and a program says what, by messages naming images by its own numbers |
| `KAudio.ml` | in tiny-kernel (and the host's tiny-tetris) | `lib_audio/` (Sfx.ml, sfxr's recipe), the sound chips (SID, the NES's APU) | the kernel has the samples, a program says what: a sound is a message of five numbers, made where it is played, so no samples cross a pipe ([`plan_tiny_audio.md`](../docs/plans/done/plan_tiny_audio.md)) |
| `KNetwork.ml` | in tiny-kernel, and in tiny-machine | mini-9pi's `network/ip/`, `lib_networking/` (Plan 9's ip) | the stack is functions of strings, with no device and no clock, so the same file is the kernel's stack, its test on the host, and the other end of tiny-machine's wire; IP, the echo, and Plan 9's IL ([`plan_tiny_network.md`](../docs/plans/done/plan_tiny_network.md)) |
| `TinyWindows.ml` | `windows` | `windows/rio/` (mini-rio; rio) | a window looks like the machine (a program's descriptors, given by the kernel or by the window system), so the window system runs in one of its own windows; forwarding a program's drawing is renumbering its images |
| `TinyLibPlayground.ml` | with each game | `lib_playground/` (the author's playground, Elm's) | a game is a model and functions (its view as shapes, a key, a frame, its sounds, its tune), with no loop and no drawing of its own, so a game is tested with no screen |
| `TinyAppTetris.ml` | `tetris` (tiny-tetris) | `games/puzzle/Tetris.ml` | the game in integers, its ground kept in the model as shapes, so that a moving piece is five shapes; m-ix's sounds and theme (Korobeiniki) |
| `TinyLibGUI.ml` | with each program that has buttons or fields | `lib_gui/` (the author's playground's; libpanel) | an interface is a value the model is turned into: widgets made again from each model, a button carrying the message it sends; the layout in two passes, and only the widgets that changed drawn |
| `TinyAppCalculator.ml` | `calc` (tiny-calc) | none (`examples/Gui7Counter.ml` and the other 7GUIs are lib_gui's small programs) | the calculator of four operations: a number shown, a number kept, the operation that awaits; a key is its button's message |
| `TinyAppTemperature.ml` | `temp` | `examples/Gui7Temperature.ml` | two fields, each the other's answer: the model is the two texts, not a temperature, since half of what is typed is not a number; the message says which field was typed in, so nothing echoes |
| `TinyBrowser.ml`, `TinyBrowser/` | `www` (tiny-www; `www OCaml`, with its links and pictures, its menus and its address field on `TinyLibGUI.ml`, a search by `?words` or `s` (DuckDuckGo Lite), HTTP/1.0 to the wire's other end and a WAV or a PDF given to `play` or `page` by its Content-Type: [`plan_tiny_browser.md`](../docs/plans/done/plan_tiny_browser.md)) | `browsers/` (mini-netscape, mini-lynx) | a page is read once, as it arrives, and turned directly into lines; there is no document tree and no style sheet, and the meaning of a tag is a row in a table; a table's cells are kept until the widths of its columns are known |
| `TinyDebugger.ml` | `debug` (`debug -window` on `TinyLibGUI.ml`) | none in m-ix; principia's `debuggers/` (db, acid; libmach) | the program stopped, looked at and resumed by text lines on one descriptor, the kernel keeping the breakpoints; a step by the timer's interrupt after one instruction; gdb's letters ([`plan_tiny_debugger.md`](../docs/plans/done/plan_tiny_debugger.md)) |
| `TinyTracer.ml` | `trace` (`trace -f`, the children too) | none in m-ix; principia's `debuggers/tracers/` (ratrace), strace | a stop before each system call and one after it, so the kernel keeps and decodes nothing: the tracer reads an exec's path before and a read's bytes after; a table of the calls and their arguments' kinds |
| `TinyVCS.ml` | `vcs` (tiny-vcs) | `version_control/` (mini-git; git9) | git's objects, trees and DAG; the repository as one hash (an operation log, so every command is atomic and undoable); no staging area; merges that always succeed, conflicts committed as data |

## Building and testing

A file is built three ways:

- by tiny-build for tiny-kernel, from [`Buildfile`](Buildfile), the
  same file on the host (`tiny-build TINY=tiny-`) and on tiny-kernel,
  which rebuilds its own image from `/src`;
  `make -C TinyKernel run` builds the image and boots it, `make -C
  TinyKernel check` runs the system's tests on tiny-machine;
- by dune with OCaml for the host's programs and their tests;
- by ix's `mini-mk` (`mkfile`), on `lib_core/`, as a test of m-IX's
  compiler.

`make test` here runs every `tests/TinyXxx_test.sh` and the system's
smaller checks; TinyC's tests are compared with the host's cc, TinyML's
(`../languages/ml/tests/tiny/`, `tests/TinyML_fuzz.py`) with OCaml.

## The system as a whole

As a program's `.mli` says it of the program:

twin: m-ix, the mini programs, each a faithful twin of its Plan 9 or
Unix program, on Linux and on the Pi. t-ix is what remains of the whole
system when compatibility is dropped: its CPU, its machine, its kernel,
its formats are its own, and each program is its twin's idea.

kept:
- **Plan 9's ideas.** What a program uses is a file: it draws by
  messages written on its descriptor 3 and reads its mouse on 4, a
  window system passes them on as a pipe would; the disk is the root, in
  a union with the boot image's files; rc is the shell, build is mk's
  language, cc, as and ld make Plan 9's kind of a.out.
- **Unix's conventions outside.** An object is a `.o`, a library a
  `.a`, assembly a `.s`; programs in `/bin`, what they link in `/lib`,
  the sources in `/src`; `start.o`, crt0, linked first and seen in every
  link line. Inside the tools, anything simpler.
- **The system builds itself.** tiny-kernel rebuilds its own image
  from `/src` with its own tools, by the same Buildfile as the host, to
  the same bytes (`make -C TinyKernel self`).
- **One language.** The kernel, the tools and the programs are ML;
  C is the runtime and a few programs; assembly is what ML cannot say
  (`TinyKernel/kentry.s`, the traps and the switch).

dropped:
- **Generated code.** No lex, no yacc, no tiny-lex or tiny-yacc: every
  lexer and parser is written by hand, recursive descent (tiny-cc,
  tiny-ml, rc, build...), so no build step makes a source.
- **Configuration.** No configure, no install prefix: one Buildfile,
  `build install` a copy into `/lib`.
- **Dynamic linking and ELF.** Programs are linked statically into an
  a.out whose header is three words; an object is tiny-as's items,
  marshalled (`TinyLibMachine`), not ELF.
- **Compatibility.** No POSIX: the system calls are the kernel's own,
  the instructions TinyCPU's. tiny-ml has no floats, functors, labels
  or objects (`TinyML.mli`).
- **What the tools leave out of their twins**, each said in its
  `.mli`: mk's backquotes in a variable (`TinyBuildSystem.mli`), a
  naming pass in the compiler (`TinyML.mli`'s design)...

twist:
- **The machine is designed with the system.** TinyCPU and its
  devices were made for this kernel and its programs, not inherited:
  a screen of messages, a relocating window, a wire to the host.
- **One program, two systems.** A program names `TinyLibSystem.mli`
  alone, so it runs on tiny-kernel and on the host (its tests, a
  window); the Buildfiles run on both, `TINY=tiny-` on the host.
- **Up to date by content.** build's stamps are digests, so a comment
  added to a unit recompiles it and links nothing again.
- **A kernel in ML.** A waiting system call is a closure the scheduler
  tries again: no kernel stack for each process, no sleep and wakeup.

## More

- [`docs/manuals/t-ix.md`](../docs/manuals/t-ix.md), the manual: the
  CPU, the machine's devices, how a C or an ML program is built, the
  kernels, the drawing messages, the window system, how a game is
  written.
- [`docs/projects.md`](../docs/projects.md) places t-IX among ix's
  projects.
- [`docs/notes/notes_tiny_spirit.md`](../docs/notes/notes_tiny_spirit.md)
  says where this directory departs from its own definition, and what
  was decided.
- The plans' Status logs (`docs/plans/`) tell how each part was chosen
  and checked.
