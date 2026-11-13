# tiny/

This directory holds the tiny programs of ix (t-IX). Each one is a free
variant of one of ix's mini programs (m-IX): what is left of a program
when compatibility is dropped and only its idea is kept. Each was
written after its faithful twin, and from what that twin taught.
Together they make a whole system: a CPU and its machine
(tiny-machine), a kernel in ML (tiny-kernel), and its toolchain, shell,
utilities, editors, window system and applications. Each program runs
on tiny-kernel, where it is in `/bin` under a short name (`build`,
`rc`...), and on the host as `tiny-build`, `tiny-shell`... for its
tests.

## Reading a program

A program is a file `TinyXxx.ml`, and its `.mli` is where to start
reading. The `.mli` begins with a header comment that explains the idea,
often with a diagram, names the program's twin, and says what it keeps,
drops and changes (the labels are in `docs/tags.md`). Then come `main`
and the functions at the program's heart, with their types. The `.ml`
holds the code alone. When a program is a pipeline, its `.mli` says so,
and each stage is a function (`TinyAssembler.mli`, `TinyC.mli`,
`TinyML.mli`). Once a program grows past about 700 lines, its parts
move into a directory beside it, each part a unit with its own `.mli`:
`TinyC/`, `TinyML/`, `TinyOffice/`, `TinyBrowser/`, `TinyMachine/`. The
kernel has a directory of its own, `TinyKernel/`, where `TinyKernel.ml`
boots it and its parts sit beside it.

## What is where

- `TinyLibXxx` is a library that several programs share, each a whole
  library in one file: `TinyLibSystem.mli` (the system, described
  below); `TinyLibDraw`, `TinyLibPlayground` and `TinyLibGUI`, for
  drawing, for a game's loop and for widgets; `TinyLibRegex`, Plan 9's
  regular expressions, for grep and the line editor; and
  `TinyLibMachine`, which plays the role of Plan 9's libmach: it knows
  the instructions, the objects and the labels, for the toolchain,
  prof and debug. `TinyLibCore/` is tiny-ml's standard library. It has
  OCaml's modules under the names a tiny program uses (`Stdlib`,
  `List`, `Hashtbl`...), each a subset of OCaml's that OCaml checks.
- `TinyAppXxx.ml` is an application written on the playground or on
  the widgets (`calc`, `temp`, `tetris`, `square`). `user/` has each
  program's main for tiny-kernel: one line for an ML program, the
  whole program for a C one (`sh.c`, `ping.c`, `paint.c`...).
- `runtime/` is what every compiled program is linked with, one
  directory per language, as `/lib/c` and `/lib/ml` are on the disk.
  `c/` has C's start-up code, its division, its library, the system
  calls (`user.h`, `sys.s`), and the calls for drawing and dialing
  (`draw.c`, `net.c`). `ml/` has ML's allocator and collector (`ml.c`),
  its glue to the system (`mlsys.c`) and the code that ends a program
  (`end.s`).
- `TinyKernel/` holds the kernel and nothing else: its parts in ML,
  its assembly and C, its Buildfile, and a `Makefile` that builds the
  image and the disk and runs the tests on tiny-machine. `steps/` has
  what ran before tiny-kernel: a C program on the bare CPU, `v0/` in
  assembly, and `t6/` in C.
- `TinyMachine.ml` and `TinyMachine/` are the machine, which runs on
  the host. They hold the CPU (`TinyMachineCPU`, which `TinyCPU.ml`,
  tiny-cpu, also runs alone), the devices, the other end of the network
  wire, and the machine's window, socket and web page (`./tiny-machine
  -web dir tiny-kernel`).
- `examples/` holds the same files as tiny-kernel's `/examples`: small
  programs in C and ML to read, build and run.
- `tests/` has each program's tests, `tests/TinyXxx_test.sh`.

## Conventions

- A program's parts are named for what they are, and their directory
  says which program they belong to: `TinyML/Lexer.ml`,
  `TinyBrowser/Http.ml`, not `TinyMLLexer`. Two programs may each have
  a part with the same name (`Lexer`), since each program is compiled
  with its own `-I` options (the Buildfile's `X_INCLUDES`). The
  kernel's parts, which other programs link too, start with a `K`
  (`KFS`, `KProcs`), and its assembly and C files with a `k`
  (`kentry.s`, `kruntime.c`), so you can tell what goes into the
  kernel's image rather than a program's.
- Names are qualified, not opened: `Compile.bind`, `KFS.fs_read`,
  `Strings.find`. Every file opens `Common` (`|||`, `let*`, `Error`),
  and a program also opens its core vocabulary, the module whose types
  all its parts use: `Model` in the office, `KProcs` in the kernel,
  `Lines` in the browser. The applications refer to their libraries by
  a one-letter name, `module P = TinyLibPlayground`, `G = TinyLibGUI`,
  `D = TinyLibDraw` (`P.Move (x, y, P.Rect ...)`, `msg G.widget`). A
  test may open the module it tests.
- A record field or constructor from another module is found by its
  type, given by an annotation where nothing else says it
  (`(sc : Screen.screen)`, `let fds : (int * KFiles.file) list =
  ...`), rather than by a module prefix on each label. tiny-ml does not
  accept `_` in a type.
- Lines are at most 80 columns, occasionally 85.

## One program, two systems

A program never names the system it runs on. It names one interface,
`TinyLibSystem.mli`, which has an implementation for each system in
[`TinyLibSystem/`](TinyLibSystem/README.md): `unix/`, built on OCaml's
Unix and `lib_core/`, for the tools on the host; `tinykernel/`, built
on the kernel's calls; `sdl/`, which opens a window on the host, for
the graphical programs; and `teststub/` for the tests. So the same
file is both tiny-kernel's `rc` and the host's tiny-shell, and a
graphical program draws on its `fd_draw` whether it runs on
tiny-kernel or in a window on the host (tiny-calc, tiny-tetris,
tiny-www...).
[docs/projects.md](../docs/projects.md#what-a-tiny-program-stands-on)
has the picture of what each kind of program stands on.

## The programs

A program's lines are all the lines of its files, its `.mli` and its
directory of parts included, comments and blank lines too, but not the
header comments, as `make loc` counts them (2026-11-13). The libraries
the programs share (`TinyLibCore/`, `TinyLibSystem/`, `TinyLibMachine`,
`TinyLibRegex`, `TinyLibDraw`) and the runtimes (`runtime/c/`,
`runtime/ml/`) are not in a program's lines: about 6,300 more.

**The machine**: what everything else runs on.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-cpu** | a CPU of our own design, for teaching | 350 | mini-5i, Knuth's MIX | [`TinyCPU.ml`](TinyCPU.ml), [`TinyMachineCPU.ml`](TinyMachine/TinyMachineCPU.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyCPU.ml)) |
| **tiny-machine** | tiny-cpu with what a kernel needs: two modes, traps, a timer, protection, a console, a disk, a screen and a mouse ([run it in your browser](https://aryx.github.io/IX/t-ix.html)) | 3,180 | mini-qemu | [`TinyMachine.ml`](TinyMachine.ml), [`TinyMachine/`](TinyMachine/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyMachine.ml)) |

**The kernel**, and what it is made of.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-kernel** | a kernel in ML for tiny-machine: fork and exec, preemption, pipes; files on a disk (the root, Plan 9's way: a union with the boot image's) where nothing is written over: a change copies its blocks up to the root and a commit is one block, so a crash needs no fsck, each boot's files kept in `/dump`; a screen that programs draw on by messages, one operation, `draw`, its loops in assembly; a network, Plan 9's IL over IP, for `ping`, `get`, `www` (a web page, its pictures painted as their packets arrive) and `httpd` (its files in a browser) | 5,720 | mini-9pi, mini-xv6's Fs | [`TinyKernel/`](TinyKernel/): [`TinyKernel.ml`](TinyKernel/TinyKernel.ml), [`KFS.ml`](TinyKernel/KFS.ml), [`KGraphics.ml`](TinyKernel/KGraphics.ml), [`KNetwork.ml`](TinyKernel/KNetwork.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyKernel)) |

**The tools**, in tiny-kernel's `/bin` (`rc`, `ed`, `build`, `db`,
`vcs`, `prof`).

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-shell** | a shell in rc's spirit: lists as the only value | 850 | mini-rc | [`TinyShell.ml`](TinyShell.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyShell.ml)) |
| **tiny-editor** | an editor with sam's command language | 800 | mini-ed | [`TinyEditorLine.ml`](TinyEditorLine.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyEditorLine.ml)) |
| **tiny-build** | a build system: rules, `%`, digests, `-j` | 710 | mini-mk | [`TinyBuildSystem.ml`](TinyBuildSystem.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBuildSystem.ml)) |
| **tiny-db** | a database whose query language is the relational algebra, over a copy-on-write B-tree | 840 | mini-chidb | [`TinyDatabase.ml`](TinyDatabase.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyDatabase.ml)) |
| **tiny-vcs** | version control with git's objects, an undo log, and no staging area | 970 | mini-git | [`TinyVCS.ml`](TinyVCS.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyVCS.ml)) |
| **tiny-prof** | a profiler: every instruction counted by its address, the kernel's and each program's apart, named by the linker's map | 170 | mini-prof | [`TinyProfiler.ml`](TinyProfiler.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyProfiler.ml)) |

**The toolchain**, also in tiny-kernel's `/bin` (`cc`, `ml`, `as`,
`ld`). There, each tool makes byte for byte what the same tool makes on
the host, and step 8 of
[plan_tiny_self_hosting.md](../docs/plans/done/plan_tiny_self_hosting.md)
builds t-IX with them.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-cc** | a C subset compiler, to tiny-cpu | 1,830 | mini-cc | [`TinyC.ml`](TinyC.ml), [`TinyC/`](TinyC/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyC.ml)) |
| **tiny-ml** | an ML compiler (Hindley-Milner types, closures, exceptions, a garbage collector) to tiny-cpu | 3,800 | mini-ml | [`TinyML.ml`](TinyML.ml), [`TinyML/`](TinyML/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyML.ml)) |
| **tiny-as**, **tiny-ld** | tiny-machine's assembler, a file to an object (its words, its labels, the places a label's address goes), and its linker, objects to an image, filling each place by encoding again | 760 | mini-asm, mini-ld | [`TinyAssembler.ml`](TinyAssembler.ml), [`TinyLinker.ml`](TinyLinker.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAssembler.ml)) |

**The window system** and the programs in its windows.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-windows** | a window system, a program in ML: a window looks like the machine, so it runs in one of its own windows | 560 | mini-rio | [`TinyWindows.ml`](TinyWindows.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyWindows.ml)) |
| **tiny-playground** | what a game is written on: a model, a view as shapes, a key, a frame; the loop and the drawing are the library's | 370 | the playground | [`TinyLibPlayground.ml`](TinyLibPlayground.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibPlayground.ml)) |
| **tiny-gui** | what a program with buttons and fields is written on: widgets made from the model, each carrying the message it sends; the layout, the mouse, the keys' focus and the drawing are the library's | 790 | lib_gui | [`TinyLibGUI.ml`](TinyLibGUI.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyLibGUI.ml)) |
| **tiny-tetris** | Tetris, in a window of tiny-windows | 320 | the playground's Tetris | [`TinyAppTetris.ml`](TinyAppTetris.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppTetris.ml)) |
| **tiny-calculator**, **tiny-temperature** | two programs on it, in a window of tiny-windows: a calculator of four operations, sixteen buttons; two fields typed in, Celsius and Fahrenheit, each the other's answer | 130, 70 | lib_gui's 7GUIs | [`TinyAppCalculator.ml`](TinyAppCalculator.ml), [`TinyAppTemperature.ml`](TinyAppTemperature.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyAppCalculator.ml)) |
| **tiny-office** | an office suite in one program: a document of pages of boxes, each a text edited as it is shown (bold, italic, large), a sheet with its formulas, a drawing, a paint or a chart that follows its sheet; pull-down menus; its file Markdown with a few LaTeX commands | 2,200 | mini-office | [`TinyOffice.ml`](TinyOffice.ml), [`TinyOffice/`](TinyOffice/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyOffice.ml)) |
| **tiny-troff** | the office's documents, or Markdown, printed as text, a web page or PDF | 600 | mini-troff | [`TinyTroff.ml`](TinyTroff.ml) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyTroff.ml)) |
| **tiny-browser** | a web browser, `www`: a page read as it arrives, its links followed, its pictures painted as their packets come, Wikipedia's articles fetched by the host | 2,370 | mini-netscape | [`TinyBrowser.ml`](TinyBrowser.ml), [`TinyBrowser/`](TinyBrowser/) ([map](https://aryx.github.io/IX/codemap.html?focus=tiny/TinyBrowser.ml)) |

### What each keeps, changes and drops

A tiny program is not a smaller copy of its twin: it starts from what
the twin taught, keeps the idea that makes that kind of program work,
and redesigns the rest, now that no file format, command line or
output has to stay compatible. The table gives each program's choices
in a few words: what it keeps of its twin; its twist, an idea of its
own that the twin, bound to compatibility, could not take (tiny-build's
stamps by content, not by time); and what it drops. Read together, the
rows are an overview of the whole system, and a row next to its twin's
code shows what is essential to that kind of program and what is
accident. Each program's `.mli` says more, in its `twin:`, `kept:`,
`twist:` and `dropped:` paragraphs ([docs/tags.md](../docs/tags.md)).

Each row gives the program by its name in the tables above, linked to
its file, then by its name on tiny-kernel (alone for a program not in
them), with its twin under it; a "—" is a paragraph its `.mli` does
not have.

| program | kept | twist | dropped |
|---|---|---|---|
| [tiny-build](TinyBuildSystem.ml) `build`<br>mini-mk, mk | mk's rules, `%` and `&`; cycles and ambiguous rules found before anything runs | up to date by content: a stamp is a digest of the recipe and the prerequisites, not a time | attributes, regular-expression rules, quoting, backquotes, several targets by one recipe |
| [tiny-shell](TinyShell.ml) `rc`<br>mini-rc, rc | every value a list of strings, so `$x` needs no quotes; words joined by adjacency | a word is its pieces side by side, where rc's lexer inserts a free caret | switch, here documents, most builtins, functions in the environment, signals |
| [tiny-utils](TinyUtilities.ml) `utils`<br>mini-cat, mini-ls... | one executable with a name per utility, BusyBox's way; the twins' output where it costs nothing | the walkers (du, rm, ls...) share one fold over the tree | most options, UTF-8, most of `ls -l`, each program's own wording of errors |
| [tiny-editor](TinyEditorLine.ml) `ed`, `sam`<br>mini-ed, ed | sam's command language: dot a range of characters, loops over matches, changes in parallel | — | the screen, several files, the mark, `! < > \|`, cd |
| [`emacs`](TinyEditorScreen.ml)<br>mini-emacs | Emacs's keys on one text in one window, the text its lines split at the cursor | — | several buffers and windows, undo, the region, query-replace, characters beyond ASCII |
| [tiny-office](TinyOffice.ml) `office`<br>mini-office | a document of pages of boxes: texts, sheets, drawings, paints, charts; its file Markdown with a few LaTeX commands | a sheet computed again at each view, with no dependency graph, so a chart follows it for free | charts other than bars, floats and functions but sum, fonts, text flowing between boxes |
| [`play`](TinyPlay.ml)<br>mini-play | a WAV to the speaker a block at a time, the kernel pacing it | the file decoded as it plays, where mini-play decodes it whole into floats first | MOD, MIDI, MP3, a WAV's other encodings |
| [tiny-troff](TinyTroff.ml) `troff`<br>mini-troff | the office's documents, or Markdown, as text, HTML or PDF | one format, the office's, read by the office's own functions: no roff, no LaTeX | text flowing onto the next page, a paint as a real image, colours and fonts in HTML |
| [tiny-cc](TinyC.ml) `cc`<br>mini-cc; 5c, 7c | C's types (long 4 bytes, as Plan 9's), every operator and statement, `#include` and `#define` of a name | a stack machine in between, P-code's idea but compiled, its stack kept in registers, so the front end knows no instruction and the back end no C; types at parse time | floats, unions, bitfields, structs by value, goto, macros with arguments, `#if`, long long |
| [tiny-ml](TinyML.ml) `ml`<br>mini-ml; ocamlopt | variants, closures, exceptions, Hindley-Milner; types checked, then forgotten: every value a word | a `Printf` with a literal format rewritten into concatenations: no format type, nothing read at run time | ocamlopt's functors, classes, polymorphic variants, GADTs and optional arguments (none in mini-ml either); mini-ml's floats, labeled arguments, `-g`, derived printers and young generation |
| [tiny-db](TinyDatabase.ml) `db`<br>mini-chidb; chidb | tables with a key, indexes, joins, a file that outlives the program | a query a pipeline of the relational algebra; a copy-on-write B-tree, so a statement commits by one write | SQL, NULL, the register machine, SQLite's file format |
| [tiny-cpu](TinyCPU.ml)<br>mini-5i; MIX, MMIX | a machine of our own, for teaching: 16 registers, r0 zero, no flags, one format, every case defined | no header and no loader: the image is the first bytes of memory, where mini-5i reads an ELF | mini-5i's instruction trace, counts and system-call log; all calls but three |
| [tiny-as](TinyAssembler.ml) `as`, [tiny-ld](TinyLinker.ml) `ld`<br>mini-asm, mini-ld | sizes known before addresses, so the link never moves what it placed | ld's sweep leaves out what nothing reaches, so an archive is linked whole; `as -S`'s text reassembles to the same object, so the compilers write no text | `-data`, names private to a file, line tables, `-T` and `-E` |
| [tiny-ar](TinyArchiver.ml) `ar`<br>mini-ar | objects in one library, in their order | — | all keys but `t`; the date, owner and mode, so a library made twice has the same bytes; the index |
| [tiny-prof](TinyProfiler.ml) `prof`<br>mini-prof | each function's count, named by tiny-ld's maps; `-diff` | every instruction counted under a kernel, where mini-qemu samples; the kernel's counts and the program's apart | a function's instructions (mini-prof's `-a`), source files, the call graph |
| [tiny-machine](TinyMachine.ml)<br>mini-qemu; Oberon, RISC-V | what a kernel needs: two modes, one trap and eret, a timer counting instructions, protection by base and bound | devices designed with the kernel, a few words each; a session replayed from `-events`, its screen a file | being a real board: other kernels (xv6, 9pi), real devices' protocols, a monitor |
| [tiny-kernel](TinyKernel/TinyKernel.ml)<br>mini-9pi | modes, system calls, preemption, fork and exec, pipes, files | a waiting call a closure the scheduler retries: no kernel stack per process, no lost wakeup | swapping, the kernel on several cores, users and permissions, signals but kill |
| [its files](TinyKernel/KFS.ml)<br>mini-9pi's Kfs; xv6's fs | xv6's inode, its direct then indirect blocks; a directory a file of (name, number) pairs | nothing written over: a commit is one block, free blocks found by a collector, snapshots in `/dump` | xv6's buffer cache and locks, `.` and `..` entries, device files |
| [its graphics](TinyKernel/KGraphics.ml)<br>libdraw, libmemdraw | one operation, `draw dst r src mask p`; a colour an image of one pixel; a program sends messages | a text carries its characters and a style; the kernel makes bold, large and italic from one font | depths but a byte, alpha, ellipses and polygons, fonts but the machine's |
| [its sound](TinyKernel/KAudio.ml)<br>lib_audio; SID, NES | a sound a message of five numbers, made where it is played | the recipe and the mixing in the kernel: each open of `/dev/audio` a voice | most of sfxr's recipe (sine, envelope, vibrato, filters, echo), a soft mix, a volume |
| [its network](TinyKernel/KNetwork.ml)<br>mini-9pi's IP | IP, the echo, Plan 9's IL | the stack functions on strings: one file is the kernel's stack, its test, and the wire's other end | Ethernet, ARP, routes, fragments, IP options |
| [tiny-windows](TinyWindows.ml) `windows`<br>mini-rio, rio | a window looks like the machine, so the window system runs in its own window; forwarding is renumbering | the kernel holds every pixel, so no layers; a mouse is a box that keeps only the last write | each window's menu, scrolling back, snarf and paste, resizing, the files rio serves |
| [tiny-playground](TinyLibPlayground.ml)<br>lib_playground | a game a model and functions, with no loop and no drawing, so it is tested with no screen | a sound comes from what changed: two models give what is heard | floating-point transforms, circles and images, the mouse, subscriptions |
| [tiny-tetris](TinyAppTetris.ml) `tetris`<br>m-IX's Tetris | the well never changed once in a model; the background kept as shapes; m-IX's sounds and theme | each rotation 16 bits, so a fit is sixteen bit tests, with no case per piece | the shadow, holding a piece, wall kicks, the bag, pause, high scores |
| [tiny-gui](TinyLibGUI.ml)<br>lib_gui; libpanel | an interface a value the model is turned into: widgets made again from each model | the state below the model three points of the mouse: the focus is a position, no widget needs a name | a moving caret, selection, sliders and lists, themes, resizing, time |
| [tiny-browser](TinyBrowser.ml) `www`<br>mini-netscape | a page's text, links and pictures, in the ASCII of the machine's font | read once as it arrives, straight into lines: no document tree, a tag a row in a table | style sheets, scripts, forms, a page's colours and fonts |
| [`debug`](TinyDebugger.ml)<br>principia's acid | one descriptor and text commands; the kernel keeps the breakpoints; gdb's letters | a step is the timer's interrupt after one instruction, nothing decoded | the source: instructions only, no line of C or ML; watchpoints, conditional breakpoints, printing by type, the kernel |
| [`trace`](TinyTracer.ml)<br>ratrace, strace | a stop before and after each call; the bytes as C strings, strace's way | the kernel decodes nothing, where ratrace's formats every call; children followed without parsing lines | strace's options (`-e`, `-t`, `-c`, `-s`), detaching |
| [tiny-vcs](TinyVCS.ml) `vcs`<br>mini-git; git9 | git's objects, trees and DAG; Myers' diff, diff3's merge; remotes as directories | the repository one hash, an operation log: every command atomic and undoable; no staging area | git's formats, packs, the wire protocol, the index, tags, rebase |

### The system as a whole

The table above says, for each program, what it keeps of its twin,
what it drops, and its twist. The same can be said of t-IX as a whole,
with the same labels a program's `.mli` uses:

twin: m-IX, the mini programs, each a faithful twin of its Plan 9 or
Unix program, running on Linux and on the Pi. t-IX is what remains of
the whole system when compatibility is dropped: its CPU, its machine,
its kernel and its formats are its own, and each program keeps its
twin's idea.

kept:
- **Plan 9's ideas.** Everything a program uses is a file. A program
  draws by writing messages on its descriptor 3 and reads its mouse on
  descriptor 4, and a window system passes them on as a pipe would.
  The disk is the root, in a union with the boot image's files. rc is
  the shell, build reads mk's language, and cc, as and ld make Plan 9's
  kind of a.out.
- **Unix's conventions, as seen from outside.** An object is a `.o`, a
  library a `.a`, and assembly a `.s`. Programs are in `/bin`, what
  they link with is in `/lib`, and the sources are in `/src`.
  `start.o`, the C start-up code (crt0), is linked first and appears in
  every link line. Inside the tools, anything simpler goes.
- **The system builds itself.** tiny-kernel rebuilds its own image
  from `/src` with its own tools, using the same Buildfile as the host,
  and gets the same bytes ([Bootstrapping](#bootstrapping)).
- **One language.** The kernel, the tools and the programs are written
  in ML. C is used for the runtime and a few programs, and assembly
  only for what ML cannot express (`TinyKernel/kentry.s`: the traps and
  the context switch).

dropped:
- **Generated code.** There is no lex or yacc, and no tiny-lex or
  tiny-yacc: every lexer and parser is written by hand, by recursive
  descent (tiny-cc, tiny-ml, rc, build...), so no build step generates
  a source file.
- **Configuration.** There is no configure script and no install
  prefix: there is one Buildfile, and `build install` copies the
  results into `/lib`.
- **Dynamic linking and ELF.** Programs are linked statically into an
  a.out whose header is three words. An object file is tiny-as's items,
  marshalled (`TinyLibMachine`), not ELF.
- **Compatibility.** There is no POSIX: the system calls are the
  kernel's own, and the instructions are TinyCPU's. tiny-ml has no
  floats, functors, labeled arguments or objects (`TinyML.mli`).
- **What the tools leave out of their twins.** Each `.mli` says what
  its program leaves out, for example mk's backquotes in a variable
  (`TinyBuildSystem.mli`), or a separate naming pass in the compiler
  (`TinyML.mli`'s design section).

twist:
- **The machine is designed with the system.** TinyCPU and its
  devices were made for this kernel and its programs, not inherited:
  the screen is driven by messages, protection is a relocating window
  of memory, and the network is a wire to the host.
- **One program, two systems.** A program names only
  `TinyLibSystem.mli`, so it runs both on tiny-kernel and on the host,
  for its tests or in a window. The Buildfiles run on both too, with
  `TINY=tiny-` on the host.
- **The same input gives the same bytes.** tiny-ar keeps no dates,
  so a library made twice is the same file; build's stamps are digests
  of contents; tiny-prof counts instead of sampling; a graphical session
  is replayed from its events; and the system rebuilds itself to the
  host's bytes. Every result can be checked with `cmp`.
- **What can be a function is one.** A game, an interface, a sheet and
  the network stack are functions of their state, with no device
  inside, so each is tested on the host with no screen, no wire and no
  clock; in the kernel, even a waiting system call is a closure.

## Building and testing

A file is built in three ways:

- by tiny-build, for tiny-kernel, from the [`Buildfile`](Buildfile).
  The same Buildfile is used on the host (`tiny-build TINY=tiny-`) and
  on tiny-kernel, which rebuilds its own image from `/src`. `make -C
  TinyKernel run` builds the image and boots it, and `make -C
  TinyKernel check` runs the system's tests on tiny-machine;
- by dune with OCaml, for the host's programs and their tests;
- by ix's `mini-mk` (`mkfile`), on `lib_core/`, as a test of m-IX's
  compiler.

`make test` in this directory runs every `tests/TinyXxx_test.sh` and
the system's smaller checks. TinyC's tests compare its output with the
host's cc, and TinyML's tests (`../languages/ml/tests/tiny/`,
`tests/TinyML_fuzz.py`) compare it with OCaml.

## Bootstrapping

t-IX builds itself, on its own system. The first build happens on the
host: dune and OCaml make the tools (`tiny-ml`, `tiny-cc`, `tiny-as`,
`tiny-ld`, `tiny-build`...), and those tools, following the
[`Buildfile`](Buildfile), make tiny-kernel's image and its system:
`/bin`, `/lib`, and a disk with the sources in `/src`. Then tiny-kernel,
running on tiny-machine, runs the same Buildfile in `/src` with the
tools in its own `/bin`, which the host's tools made. It produces the
same files: the image and every file of the system are byte for byte
the host's. A difference means a bug in tiny-kernel's tools, in the
runtime or in the kernel.

```bash
make -C TinyKernel self-quick   # a few targets (ping, the library) rebuilt on tiny-kernel, 3 minutes
make -C TinyKernel self         # the whole image and system, hours
make self-quick-tix             # the same, from the top directory
```

The plan and its history are in
[plan_tiny_self_hosting.md](../docs/plans/done/plan_tiny_self_hosting.md).

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
