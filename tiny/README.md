# tiny/

The tiny programs of ix (t-IX): the free variants of its mini programs
(m-IX), what is left of a program when compatibility is dropped and only
its idea is kept, written after its faithful twin and from what that one
taught. Together they are a whole system: a CPU and its machine
(tiny-machine), a kernel in ML (tiny-kernel), its toolchain, its shell,
utilities, editors, window system and applications. Each program runs
on tiny-kernel, in `/bin` by a short name (`build`, `rc`...), and on the
host as `tiny-build`, `tiny-shell`... for its tests.

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

**The toolchain**, in tiny-kernel's `/bin` too (`cc`, `ml`, `as`,
`ld`), where each makes what the host's makes, byte for byte;
[plan_tiny_self_hosting.md](../docs/plans/done/plan_tiny_self_hosting.md)'s
step 8 has t-IX built there.

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

Each row gives the program by its name on tiny-kernel, linked to its
file, with its twin under it; a "—" is a paragraph its `.mli` does not
have.

| program | kept | twist | dropped |
|---|---|---|---|
| [`build`](TinyBuildSystem.ml)<br>mini-mk, mk | mk's rules, `%` and `&`; cycles and ambiguous rules found before anything runs | up to date by content: a stamp is a digest of the recipe and the prerequisites, not a time | attributes, regular-expression rules, quoting, backquotes, several targets by one recipe |
| [`rc`](TinyShell.ml)<br>mini-rc, rc | every value a list of strings, so `$x` needs no quotes; words joined by adjacency | a word is its pieces side by side, where rc's lexer inserts a free caret | switch, here documents, most builtins, functions in the environment, signals |
| [`utils`](TinyUtilities.ml)<br>mini-cat, mini-ls... | one executable with a name per utility, BusyBox's way; the twins' output where it costs nothing | the walkers (du, rm, ls...) share one fold over the tree | most options, UTF-8, most of `ls -l`, each program's own wording of errors |
| [`ed`, `sam`](TinyEditorLine.ml)<br>mini-ed, ed | sam's command language: dot a range of characters, loops over matches, changes in parallel | — | the screen, several files, the mark, `! < > \|`, cd |
| [`emacs`](TinyEditorScreen.ml)<br>mini-emacs | Emacs's keys on one text in one window, the text its lines split at the cursor | — | several buffers and windows, undo, the region, query-replace, characters beyond ASCII |
| [`office`](TinyOffice.ml)<br>mini-office | a document of pages of boxes: texts, sheets, drawings, paints, charts; its file Markdown with a few LaTeX commands | a sheet computed again at each view, with no dependency graph, so a chart follows it for free | charts other than bars, floats and functions but sum, fonts, text flowing between boxes |
| [`play`](TinyPlay.ml)<br>mini-play | a WAV to the speaker a block at a time, the kernel pacing it | the file decoded as it plays, where mini-play decodes it whole into floats first | MOD, MIDI, MP3, a WAV's other encodings |
| [`troff`](TinyTroff.ml)<br>mini-troff | the office's documents, or Markdown, as text, HTML or PDF | one format, the office's, read by the office's own functions: no roff, no LaTeX | text flowing onto the next page, a paint as a real image, colours and fonts in HTML |
| [`cc`](TinyC.ml)<br>mini-cc; 5c, 7c | C's types (long 4 bytes, as Plan 9's), every operator and statement, `#include` and `#define` of a name | a stack machine in between, P-code's idea but compiled, its stack kept in registers, so the front end knows no instruction and the back end no C; types at parse time | floats, unions, bitfields, structs by value, goto, macros with arguments, `#if`, long long |
| [`ml`](TinyML.ml)<br>mini-ml; ocamlopt | variants, closures, exceptions, Hindley-Milner; types checked, then forgotten: every value a word | a `Printf` with a literal format rewritten into concatenations: no format type, nothing read at run time | ocamlopt's functors, classes, polymorphic variants, GADTs and optional arguments (none in mini-ml either); mini-ml's floats, labeled arguments, `-g`, derived printers and young generation |
| [`db`](TinyDatabase.ml)<br>mini-chidb; chidb | tables with a key, indexes, joins, a file that outlives the program | a query a pipeline of the relational algebra; a copy-on-write B-tree, so a statement commits by one write | SQL, NULL, the register machine, SQLite's file format |
| [tiny-cpu](TinyCPU.ml)<br>mini-5i; MIX, MMIX | a machine of our own, for teaching: 16 registers, r0 zero, no flags, one format, every case defined | no header and no loader: the image is the first bytes of memory, where mini-5i reads an ELF | mini-5i's instruction trace, counts and system-call log; all calls but three |
| [`as`](TinyAssembler.ml), [`ld`](TinyLinker.ml)<br>mini-asm, mini-ld | sizes known before addresses, so the link never moves what it placed | ld's sweep leaves out what nothing reaches, so an archive is linked whole; `as -S`'s text reassembles to the same object, so the compilers write no text | `-data`, names private to a file, line tables, `-T` and `-E` |
| [`ar`](TinyArchiver.ml)<br>mini-ar | objects in one library, in their order | — | all keys but `t`; the date, owner and mode, so a library made twice has the same bytes; the index |
| [`prof`](TinyProfiler.ml)<br>mini-prof | each function's count, named by tiny-ld's maps; `-diff` | every instruction counted under a kernel, where mini-qemu samples; the kernel's counts and the program's apart | a function's instructions (mini-prof's `-a`), source files, the call graph |
| [tiny-machine](TinyMachine.ml)<br>mini-qemu; Oberon, RISC-V | what a kernel needs: two modes, one trap and eret, a timer counting instructions, protection by base and bound | devices designed with the kernel, a few words each; a session replayed from `-events`, its screen a file | being a real board: other kernels (xv6, 9pi), real devices' protocols, a monitor |
| [tiny-kernel](TinyKernel/TinyKernel.ml)<br>mini-9pi | modes, system calls, preemption, fork and exec, pipes, files | a waiting call a closure the scheduler retries: no kernel stack per process, no lost wakeup | swapping, the kernel on several cores, users and permissions, signals but kill |
| [its files](TinyKernel/KFS.ml)<br>mini-9pi's Kfs; xv6's fs | xv6's inode, its direct then indirect blocks; a directory a file of (name, number) pairs | nothing written over: a commit is one block, free blocks found by a collector, snapshots in `/dump` | xv6's buffer cache and locks, `.` and `..` entries, device files |
| [its graphics](TinyKernel/KGraphics.ml)<br>libdraw, libmemdraw | one operation, `draw dst r src mask p`; a colour an image of one pixel; a program sends messages | a text carries its characters and a style; the kernel makes bold, large and italic from one font | depths but a byte, alpha, ellipses and polygons, fonts but the machine's |
| [its sound](TinyKernel/KAudio.ml)<br>lib_audio; SID, NES | a sound a message of five numbers, made where it is played | the recipe and the mixing in the kernel: each open of `/dev/audio` a voice | most of sfxr's recipe (sine, envelope, vibrato, filters, echo), a soft mix, a volume |
| [its network](TinyKernel/KNetwork.ml)<br>mini-9pi's IP | IP, the echo, Plan 9's IL | the stack functions on strings: one file is the kernel's stack, its test, and the wire's other end | Ethernet, ARP, routes, fragments, IP options |
| [`windows`](TinyWindows.ml)<br>mini-rio, rio | a window looks like the machine, so the window system runs in its own window; forwarding is renumbering | the kernel holds every pixel, so no layers; a mouse is a box that keeps only the last write | each window's menu, scrolling back, snarf and paste, resizing, the files rio serves |
| [the playground](TinyLibPlayground.ml)<br>lib_playground | a game a model and functions, with no loop and no drawing, so it is tested with no screen | a sound comes from what changed: two models give what is heard | floating-point transforms, circles and images, the mouse, subscriptions |
| [`tetris`](TinyAppTetris.ml)<br>m-IX's Tetris | the well never changed once in a model; the background kept as shapes; m-IX's sounds and theme | each rotation 16 bits, so a fit is sixteen bit tests, with no case per piece | the shadow, holding a piece, wall kicks, the bag, pause, high scores |
| [the GUI](TinyLibGUI.ml)<br>lib_gui; libpanel | an interface a value the model is turned into: widgets made again from each model | the state below the model three points of the mouse: the focus is a position, no widget needs a name | a moving caret, selection, sliders and lists, themes, resizing, time |
| [`calc`](TinyAppCalculator.ml)<br>none | four operations; an error, not a trap, on overflow or a division by zero | a key is its button's message, so the keyboard and the mouse cannot differ | fractions, a sign key, a memory, priorities and parentheses |
| [`temp`](TinyAppTemperature.ml)<br>lib_gui's 7GUIs | the model is the two texts, not a temperature; the message says which field, so nothing echoes | — | fractions, a red field for a text that is not a number |
| [`www`](TinyBrowser.ml)<br>mini-netscape | a page's text, links and pictures, in the ASCII of the machine's font | read once as it arrives, straight into lines: no document tree, a tag a row in a table | style sheets, scripts, forms, a page's colours and fonts |
| [`debug`](TinyDebugger.ml)<br>principia's acid | one descriptor and text commands; the kernel keeps the breakpoints; gdb's letters | a step is the timer's interrupt after one instruction, nothing decoded | watchpoints, conditional breakpoints, printing by type, debugging the kernel |
| [`trace`](TinyTracer.ml)<br>ratrace, strace | a stop before and after each call; the bytes as C strings, strace's way | the kernel decodes nothing, where ratrace's formats every call; children followed without parsing lines | strace's options (`-e`, `-t`, `-c`, `-s`), detaching |
| [`vcs`](TinyVCS.ml)<br>mini-git; git9 | git's objects, trees and DAG; Myers' diff, diff3's merge; remotes as directories | the repository one hash, an operation log: every command atomic and undoable; no staging area | git's formats, packs, the wire protocol, the index, tags, rebase |

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

## Bootstrapping

t-IX builds itself, on its own system. The first build is the host's:
dune and OCaml make the tools (`tiny-ml`, `tiny-cc`, `tiny-as`,
`tiny-ld`, `tiny-build`...), and those tools, by the
[`Buildfile`](Buildfile), make tiny-kernel's image and its system:
`/bin`, `/lib`, and a disk with the sources in `/src`. Then tiny-kernel,
on tiny-machine, runs the same Buildfile in `/src` with its own `/bin`'s
tools, the ones the host's made, and gives the same files: the image
and every file of the system the host's, byte for byte. A difference is
a bug of tiny-kernel's tools, of the runtime or of the kernel.

```bash
make -C TinyKernel self-quick   # a few targets (ping, the library) rebuilt on tiny-kernel, 3 minutes
make -C TinyKernel self         # the whole image and system, hours
make self-quick-tix             # the same, from the top directory
```

The plan and its history are in
[plan_tiny_self_hosting.md](../docs/plans/done/plan_tiny_self_hosting.md).

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
  the same bytes ([Bootstrapping](#bootstrapping)).
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
