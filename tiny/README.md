# tiny/

The tiny programs of ix (t-ix): the free variants of its mini
programs (m-ix), one `.ml` file each (but TinyCPU, whose CPU
is a library, `TinyMachineCPU.ml`, for TinyMachine.ml; and TinyMachine, whose machine is a library too,
`TinyMachineDevices.ml`, for `TinyMachineWeb.ml`, the same machine in a web
page by js_of_ocaml: `./tiny-machine -web dir tiny-kernel`), on tiny-kernel's
`/bin` as `build`, `rc`, ... and on the host as tiny-build,
tiny-shell, ... (the second column): what is left of a
program when compatibility is dropped and only its idea is kept,
written after its faithful twin and from what that one taught. The
files, children and pipes they share with the twins come from
`lib_core/` (`FS`, `Procs`), not copied into each.

The largest are a file and a directory of its parts, as a
module past some 700 lines is elsewhere in ix: `TinyC.ml` and
`TinyC/` (the types, the tokens, the typed tree, the stack machine,
the parser, TinyCPU's code), `TinyML.ml` and `TinyML/` (the tokens,
the tree, Printf's formats, the parser, the types, the stack machine,
the tree compiled), `TinyOffice.ml` and `TinyOffice/` (the page's
model, a module for each kind of box, the file), `TinyBrowser.ml`
and `TinyBrowser/` (the reading of a page: the characters, the
tokens, the lines, HTML's tags; the addresses, HTTP, the screen). The
file is the program
and its `.mli` the place to start; the parts are its units, compiled
before it by OCaml (a library of their own in the directory's `dune`)
and by tiny-ml (`TinyKernel/Makefile`'s units, in their order). The
kernel is the same: `TinyKernel.ml` the boot, its parts in
`TinyKernel/` beside those it had already (the machine, the files,
the processes, the devices, the reads and writes, the system calls,
the scheduler), one program for tiny-ml (`KML`), never OCaml's.

A program's `.mli` is where to start: its header comment (the idea,
a diagram, the history, the references: `docs/tags.md`), then `main`
and one function at the program's heart, with their types. The `.ml`
is the code alone. Every file has one, those tiny-ml compiles too
(TinyKernelGraphics, TinyLibDraw, TinyKernelNetwork, TinyKernelAudio, TinyKernelFS, TinyWindows, TinyLibPlayground,
TinyAppTetris, TinyLibGUI, TinyAppCalculator, TinyAppTemperature): tiny-ml reads its vals for the
interface it writes (tiny-ml -c), OCaml, which builds the same files for their tests, checks it. `TinyKernel.mli` is
the header alone: only tiny-ml compiles `TinyKernel.ml`.

A file's name, or its place, says what it is when it is not a program
of the system:

- `TinyLibXxx` is a library that tiny programs are compiled with.
  For the programs of tiny-kernel, which tiny-ml compiles:
  `TinyLibCore/`, tiny-ml's standard library, in front of every one of
  them: OCaml's modules, as a tiny program names them (`Stdlib`,
  `List`, `String`, `Bytes`, `Buffer`, `Hashtbl`...; and ix's `Common`
  and `Sha1`), each a subset of OCaml's that OCaml checks, in tiny-ml's
  ML, their text the compiler's; then `TinyLibDraw`,
  `TinyLibPlayground` and `TinyLibGUI`;
  and `TinyLibRegex.ml`, regular expressions in Plan 9's notation,
  for grep (whether a line matches) and for the line editor (where
  the match is, and its groups): a backtracker with a memo, so a
  line costs its length times the pattern's at most. And
  `TinyLibSymbols.ml`, a program's labels as tiny-linker writes them
  (its map, or after the image), for tiny-prof's names and for
  tiny-kernel's `debug` (`TinyDebugger.ml`, beside `trace`).
  The host's programs, when ix builds them, are on m-IX's
  `lib_core/`.
- `TinyCRuntime/` and `TinyMLRuntime/` are not parts of the two
  compilers: they are what a program compiled by tiny-c or by tiny-ml
  is linked with (C's start, its division and its library; ML's
  allocator, collector and strings).
- `TinyAppXxx.ml` is an application, a program a person uses on
  tiny-kernel (`calc`, `temp`, `tetris`).
- `TinyAssembler.ml` and `TinyLinker.ml` are tiny-machine's toolchain
  after the compilers: a `.tm` file to an object (its words, its
  labels, the places a label's address goes), objects to an image or
  an a.out, and its map for tiny-prof. tiny-cpu and tiny-machine only
  run images. The words they make are `TinyMachine/TinyMachineISA.ml`'s
  (encode, decode), apart from the CPU, which keeps OCaml's 32-bit
  loads for the machine's speed: tiny-ml compiles the one, not the
  other.
- Two things are more than a file, and have a directory of their name
  beside their program:
  - `TinyKernel.ml` and `TinyKernel/`: the kernel's parts in ML that
    are files of their own (`TinyKernelGraphics`, `TinyKernelNetwork`,
    `TinyKernelAudio`),
    its assembly and C, its programs (`user/`: the ones in C, and
    the last file of the ones in ML) and what they are linked with
    to call it, `libc/` for C (`user.h`, `sys.tm`, `draw.c`, `net.c`)
    and `libml/` for ML (`mlsys.c`, `TinyCalls.ml`, `TinyLibSystem.ml`);
  - `TinyMachine.ml` (and `TinyCPU.ml`) and `TinyMachine/`: the CPU
    (`TinyMachineCPU`), the devices (`TinyMachineDevices`), the other
    end of the wire (`TinyMachinePeer`, which runs the kernel's own
    `TinyKernelNetwork` on the host), and the three programs beside
    it, its window, its socket and its page.

The others are the system's programs, a file each (`TinyShell`,
`TinyC`, `TinyWindows`...). Each runs on tiny-kernel, built by tiny-ml,
under a short name (the table's second column), and on the host,
built by dune with OCaml, for its tests. The machine alone
(`TinyMachine.ml`, `TinyCPU.ml` and the programs beside them) is only
the host's; the toolchain is both, the host's building tiny-kernel,
tiny-kernel's (`cc`, `ml`, `as`, `ld`) making the same files there
([`plan_tiny_self_hosting.md`](../docs/plans/done/plan_tiny_self_hosting.md),
step 7). A tool asks the system through `TinyLibSystem`, a file for
each side (`TinyKernel/host/TinyLibSystem.ml` over Unix,
`TinyKernel/libml/TinyLibSystem.ml` over the kernel's calls), so a
recipe of `build` is in its system's shell; a graphical program asks
through `TinyCalls` (below).

[docs/projects.md](../docs/projects.md#what-a-tiny-program-stands-on)
has the picture: for a tool on the host, for a program in ML or in C
on tiny-machine, and for the kernel, which of these each one stands
on.

| file | on tiny-kernel (on the host) | its twin | the idea kept |
|---|---|---|---|
| `TinyBuildSystem.ml` | `build` (tiny-build) | `builder/` (mini-mk, mk) | rules, `%`, stamps as digests, one pass with `-j` |
| `TinyShell.ml` | `rc` (tiny-shell) | `shell/` (mini-rc, rc) | lists as the only value, words joined by adjacency, redirections around the command |
| `TinyUtilities.ml` | `utils`, as `cat`, `ls`, `wc`... (tiny-utils) | `utilities/` (mini-cat, mini-ls...; Plan 9's) | one executable with a name per utility, BusyBox's way; a filter is a function over its input's pieces, opened and reported once for all of them; a walker is one fold over a tree, its order where it folds the entries (walk before, du and rm -r after); the same file on the host and on tiny-kernel; [`plan_tiny_utilities.md`](../docs/plans/done/plan_tiny_utilities.md) |
| `TinyEditorLine.ml` | `ed`, also named `sam` (tiny-editor) | `editors/ed/` (mini-ed, ed) | sam's command language: dot a range, loops over matches, changes in parallel |
| `TinyEditorScreen.ml` | `emacs`, also named `editor` (tiny-emacs) | `editors/emacs/` (mini-emacs) | Emacs's keys on one text in one window; the text as its lines split at the cursor (Emacs's gap, made of lists and strings that cannot change); the editor a state and the keys that change it, with no system under it; M-x, keyboard macros, and OCaml and C in colors |
| `TinyOffice.ml`, `TinyOffice/` | `office` (tiny-office) | `apps/office/` (mini-office) | a document of pages of boxes, each a kind of document whose data is text: a text edited as it is shown (WYSIWYG, its styles the kernel's fonts), a sheet, a drawing, a paint, a chart of a named sheet; pull-down menus (TinyLibGUI's); its file Markdown and a few LaTeX commands (`\box`, `\newpage`); its view shapes, run by TinyLibGUI's run_canvas, which draws what changed ([`plan_tiny_office.md`](../docs/plans/done/plan_tiny_office.md)) |
| `TinyPlay.ml` | `play` (tiny-play) | `apps/music/play/` (mini-play), `lib_audio/formats/wav/` | a WAV file to the speaker, a block at a time, the kernel pacing it: RIFF's chunks read, the file's frame at each of the speaker's samples (8,000 a second) taken exactly by Bresenham's stepping, its channels' mean, its top byte; WAV only, no filter |
| `TinyTroff.ml` | `troff` (tiny-troff) | `typesetting/` (mini-troff) | the office's documents, or Markdown, as text, HTML or PDF, read by the office's own functions; PDF in Courier, a standard font, 8 points a character at 13.33 points |
| `TinyC.ml`, `TinyC/` | `cc` (tiny-c) | `languages/c/` (mini-cc; 5c, 7c) | a C subset through a stack machine of its own, the stack in registers, for TinyCPU, with its runtime (`TinyCRuntime/`: `start.tm`, and a libc in C); Plan 9's names, ANSI's rules, the host's cc its tests' reference |
| `TinyML.ml`, `TinyML/` | `ml` (tiny-ml) | `languages/ml/` (mini-ml; ocaml-light's ocamlopt) | an ML (variants, lists, closures, exceptions, Hindley-Milner) through TinyC's stack machine to tiny-machine; the roots on a stack of values of its own (r12), so its collector, Cheney's, in C (`TinyMLRuntime/core.c`, by tiny-c), needs no frame table and no assembly; its library, TinyLibCore/, in ML, compiled once; the output OCaml's (ocaml-light's for the recorded tests, uncaught exceptions and stdout's buffer included) |
| `TinyDatabase.ml` | `db` (tiny-db) | `database/` (mini-chidb; chidb) | the relational algebra as the query language, a pipeline (`t \| where ... \| group ... \| sort ...`); a copy-on-write B-tree, so every statement is atomic by one header write |
| `TinyCPU.ml`, `TinyMachineCPU.ml` | (tiny-cpu) | `machine/` (mini-5i; 5i), with Knuth's MIX and MMIX | a machine of our own design, for teaching: 16 registers, r0 zero, no flags, one instruction format, every case defined; an interpreter (the definition); the listing reassembles to the same words; the CPU a library, TinyMachine.ml's |
| `TinyAssembler.ml`, `TinyLinker.ml` | `as`, `ld` (tiny-assembler, tiny-linker) | `assembler/`, `linker/` (mini-asm, mini-ld; 5a/5l) | a new machine's toolchain, since nothing else writes its words: a file to an object, text (its words made at once, a label's place left 0 with a `reloc` line), objects to an image or an a.out; a place filled by decoding the word, setting its immediate and encoding again, so `encode`'s checks hold; sizes never wait for addresses (one format) |
| `TinyProfiler.ml` | `prof` (tiny-prof) | mini-qemu's `-prof` (`raspberry/observe/Prof.ml`) and `kernels/9pi/tests/perf/pcprof.py` | every instruction counted by its address (`tiny-cpu -prof`, `tiny-machine -prof`), not sampled, so two runs give the same profile; the kernel's and each program's apart; the names from tiny-linker's map of the link; a baseline run taken off (`-diff`) to measure one action, as a page down of `www` |
| `TinyMachine.ml` | (tiny-machine) | `raspberry/` (mini-qemu), with Project Oberon and RISC-V's privileged specification | TinyCPU's CPU with what a kernel needs, designed: two modes, one trap (epc, cause, tval, tvec) and eret, a timer counting instructions, protection by a window (base, bound), a console and a halt at the top of memory; a raw image (`-o`, linking several `.tm`) loaded at 0; a page of kernel, `TinyKernel/steps/v0/kernel.tm`, running four programs (`v0/a.tm` to `d.tm`), killing the two that misbehave; and for a window system, each an option: a screen that is memory (1024 by 768 bytes, a byte a colour), a mouse that is a word, a window of the host's that shows them (`-window`, by another program, `TinyMachineWindow.ml`), a session replayed from a file, a wire to a network (`-net`: `TinyKernelNetwork.ml` below; its way to the host's own network by another program too, `TinyMachineSocket.ml`), a speaker that is memory too (a ring of samples the kernel places, played at 8,000 a second and silenced behind; `-audio` a WAV, `-window` heard) |
| `TinyKernel.ml` (and `TinyKernel/`) | tiny-kernel (`./tiny-machine tiny-kernel`) | `kernels/9pi/` (mini-9pi; 9pi) | a kernel in ML for tiny-machine, compiled by `tiny-ml`: the concepts kept (modes and system calls, preemption, protection, fork and exec, pipes, files and directories), each by the road ML makes short: the kernel a loop that runs a process until its next trap (`k_run`), a waiting call a closure the scheduler retries (no kernel stack per process, no sleep and wakeup), the files a tree of ML values in the heap (no disk); a screen programs draw on by messages and a mouse, a program's descriptors 3 and 4; a speaker programs play on by messages too (`/dev/audio`), each open a voice mixed with the others; `docs/notes_tiny_kernel.md` |
| `TinyKernelGraphics.ml` | in tiny-kernel | `lib_graphics/`, mini-9pi's `lib_memdraw` (libdraw, libmemdraw) | one operation, `draw dst r src mask p`, on images a byte a pixel; a colour is an image of one pixel that repeats; the kernel has the pixels and a program says what, by messages naming images by its own numbers |
| `TinyKernelAudio.ml` | in tiny-kernel (and the host's tiny-tetris) | `lib_audio/` (Sfx.ml, sfxr's recipe), the sound chips (SID, the NES's APU) | the kernel has the samples, a program says what: a sound is a message of five numbers (a wave, a pitch that slides, a length, a volume that falls), made where it is played, added to the ring; no samples cross a pipe, no allocation (tiny-ml's strings of samples were 2,750 instructions a sample); [`plan_tiny_audio.md`](../docs/plans/done/plan_tiny_audio.md) |
| `TinyKernelNetwork.ml` | in tiny-kernel, and in tiny-machine | mini-9pi's `network/ip/`, `lib_networking/` (Plan 9's ip) | the stack is functions of strings, with no device and no clock: a packet that came gives the packets to send back and what a program hears; so the same file is the kernel's stack, its test on the host, and the other end of tiny-machine's wire (`-net`). IP's envelope, the echo (`ping`), and IL, Plan 9's protocol for messages that arrive once and in order (`get`, and `www`, a web page, its pictures painted a row a message); `TinyMachinePeer.ml` is the few lines on top of it that make the wire's other end; [`plan_tiny_network.md`](../docs/plans/done/plan_tiny_network.md) |
| `TinyWindows.ml` | `windows` | `windows/` (mini-rio; rio) | a window looks like the machine: a program is given five descriptors (its text, where it draws, its mouse) by the kernel or by the window system, and does not know which; so the window system runs in one of its own windows. Windows are images composed back to front; forwarding a program's drawing is renumbering its images |
| `TinyLibPlayground.ml` | with each game | `lib_playground/` (the author's playground, Elm's) | a game is a model and three functions (its view as shapes, a key, a frame), with no loop and no drawing of its own: the library has them, and a game is tested with no screen; and a fourth, its sounds, from the model before and the model after: a sound is what changed, as the picture is what is; and a fifth, the tune the model wants playing, its parts given their notes half a second ahead, a voice of `/dev/audio` each |
| `TinyAppTetris.ml` | `tetris` (tiny-tetris) | `games/puzzle/Tetris.ml` | the game, in integers: the well, the seven pieces, rows, levels; its ground (the well's cells, the panel) kept in the model as shapes, so a piece that moves is five shapes; m-ix's sounds (a landing, rows, four rows, a level, the game over) and theme (Korobeiniki, a melody and an octave bass, faster each level; `m` mutes it) |
| `TinyLibGUI.ml` | with each program that has buttons or fields | `lib_gui/` (the author's playground's; libpanel) | an interface is a value the model is turned into, and what it sends back: widgets made again from each model, a button carrying the message it sends and a field the message of another text, one update where the model changes; the layout in two passes (a size asked up, a place given down); under the model one value, the mouse: the button held and the field that has the keys are places, so no widget has a name; only the widgets that changed drawn, a held button's edges and a caret over them |
| `TinyAppCalculator.ml` | `calc` (tiny-calc) | none (`examples/Gui7Counter.ml` and the other 7GUIs are lib_gui's small programs) | the calculator of four operations: a number shown, a number kept, the operation that awaits; a key is its button's message |
| `TinyAppTemperature.ml` | `temp` | `examples/Gui7Temperature.ml` | two fields, each the other's answer: the model is the two texts, not a temperature, since half of what is typed is not a number; the message says which field was typed in, so nothing echoes |
| `TinyBrowser.ml`, `TinyBrowser/` | `www` (tiny-www; `www OCaml`, with its links and pictures, its menus and its address field on `TinyLibGUI.ml`, a search by `?words` or `s` (DuckDuckGo Lite), HTTP/1.0 to the wire's other end and a WAV or a PDF given to `play` or `page` by its Content-Type: [`plan_tiny_browser.md`](../docs/plans/done/plan_tiny_browser.md)) | `browsers/` (mini-netscape, mini-lynx) | a page is read once, as it arrives, and turned directly into lines; there is no document tree and no style sheet, and the meaning of a tag is a row in a table; a table's cells are kept until the widths of its columns are known |
| `TinyDebugger.ml` | `debug` (`debug -window` on `TinyLibGUI.ml`) | none in m-ix; principia's `debuggers/` (db, acid; libmach) | the program stopped, looked at and resumed by text lines on one descriptor (`trace(pid)`), the kernel keeping the breakpoints; a step by the timer's interrupt after one instruction, not by decoding where the next one is; the names a.out's text lines (`tiny-linker -s`); the backtrace read from the prologues, an ML function's value-stack slots with it; gdb's letters; [`plan_tiny_debugger.md`](../docs/plans/done/plan_tiny_debugger.md) |
| `TinyTracer.ml` | `trace` (`trace -f`, the children too) | none in m-ix; principia's `debuggers/tracers/` (ratrace), strace | a stop before each system call and one after it, so the kernel keeps and decodes nothing: the tracer reads an exec's path before and a read's bytes after; a table of the calls and their arguments' kinds |
| `TinyVCS.ml` | `vcs` (tiny-vcs) | `version_control/` (mini-git; git9) | git's objects, trees and DAG; the repository as one hash (an operation log, so every command is atomic and undoable); no staging area; merges that always succeed, conflicts committed as data |

The graphical programs (`./tiny-machine -window tiny-kernel`, then
`windows`, and `tetris` in a window) are built by dune too, as
libraries, and tested on the host first. Three small files stand
between them and their machine: `TinyLibDraw.ml` (a program's side of the drawing
messages), and what the machine gives, by OCaml on the host,
`TinyMemory.ml` (its bytes: an array) and `TinyCalls` (the kernel's
calls), both in `TinyKernel/host/`; on tiny-machine these two are
externals (`TinyKernel/TinyMemory.ml`, `TinyKernel/libml/TinyCalls.ml`).
`TinyCalls` is a virtual library of dune's (`TinyCalls.mli`) with two
implementations: the tests' stub (`TinyKernel/host/stub/`: what is
drawn kept, no keys) and a window's ([`sdl/`](sdl/TinyCalls.ml): what
is drawn drawn by `TinyKernelGraphics.ml` and shown by SDL, the
window's mouse and keys, the host's files, clock and web), on which
the programs' own few lines in `TinyKernel/user/` are built for the
host as they are: tiny-office, tiny-emacs, tiny-calc, tiny-tetris,
tiny-www, tiny-troff.
[`docs/plans/done/plan_tiny_windows.md`](../docs/plans/done/plan_tiny_windows.md)
is their plan and what was found.

A file is built three ways: by tiny-ml for tiny-kernel, on
`TinyLibCore/` and `TinyMLRuntime/`; by dune for the host's tests, on
OCaml's standard library and `lib_core/commons/`; and by ix
(`mini-mk` here) on `lib_core/` whole, as a test of m-ix's compiler.

`TinyKernel/steps/` has what ran on tiny-cpu and tiny-machine before
a kernel in ML did, kept as `kernels/steps/` keeps m-ix's kernel's:
`hello.c`, a C program on the bare CPU; `v0/`, a page of kernel in
assembly and four programs linked with it; `t6/`, a kernel in C with
`spawn` and no `fork`, a FAT on a disk, one kernel stack. They are
built by the tiny tools as a program is built by its toolchain, on
`TinyCRuntime/`; t6's disk is made on the host by tiny-mkfs
(`TinyKernel/steps/t6/TinyMkfs.ml`, the one OCaml file there). Their
Makefiles take the tools from the PATH (after `dune install`) or from
ix's `bin/`: `make -C tiny/TinyKernel/steps run`, `make -C
tiny/TinyKernel/steps run-hello`. None of it is counted in t-ix's
lines. (Until 2026-10-13 this was `tiny/tiny-os/`, with a third
kernel, `v6/`, xv6's structure and names in C: a faithful twin, which
m-ix has as mini-xv6; it is in git's history.)
[`docs/projects.md`](../docs/projects.md) places them among ix's
other projects.

[`docs/manuals/t-ix.md`](../docs/manuals/t-ix.md) is the manual of
the tiny machine and what runs on it: how t-ix is put together (what
is the host's and what the machine's, what each program needs outside
`tiny/`, the two ways it is built), the CPU, the machine's registers
and devices with their addresses, the screen and the mouse, how a C
or an ML program is built, the kernels, tiny-kernel's drawing
messages, tiny-windows and how a game is written.

Each has its tests in `tests/`, `tests/TinyXxx_test.sh`, run by `make test`
(here, as the top's `make test-tix`; `make` here builds `tiny/` alone;
TinyC's programs are `tests/TinyC_tests/`, with the host's cc's outputs, and `tests/TinyC_fuzz.py` writes random ones; TinyML's are
`languages/ml/tests/tiny/`, with ocaml-light's outputs, and
`tests/TinyML_fuzz.py`'s are compared with OCaml's);
the plans' Status logs (`docs/plans/`) tell how each was chosen and
checked.

[`docs/notes_tiny_spirit.md`](../docs/notes_tiny_spirit.md) says where
this directory departs from its own definition (a twin, an inherited
machine, a contract from outside), what each departure buys, and what
was decided.
