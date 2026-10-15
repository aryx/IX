# tiny/

The tiny programs of ix (t-ix): the free variants of its mini
programs (m-ix), one `.ml` file each (but TinyCPU, whose CPU
is a library, `TinyMachineCPU.ml`, for TinyMachine.ml; and TinyMachine, whose machine is a library too,
`TinyMachineDevices.ml`, for `TinyMachineWeb.ml`, the same machine in a web
page by js_of_ocaml: `./tiny-machine -web dir tiny-kernel`), installed as
tiny-build, tiny-shell, ... (the second column): what is left of a
program when compatibility is dropped and only its idea is kept,
written after its faithful twin and from what that one taught. The
files, children and pipes they share with the twins come from
`lib_core/` (`FS`, `Procs`), not copied into each.

A program's `.mli` is where to start: its header comment (the idea,
a diagram, the history, the references: `docs/tags.md`), then `main`
and one function at the program's heart, with their types. The `.ml`
is the code alone. Every file has one, those tiny-ml compiles too
(TinyKernelGraphics, TinyLibDraw, TinyKernelNetwork, TinyWindows, TinyLibPlayground,
TinyAppTetris, TinyLibGUI, TinyAppCalculator, TinyAppTemperature): tiny-ml has no modules and does not read it, OCaml, which
builds the same files for their tests, checks it. `TinyKernel.mli` is
the header alone: only tiny-ml compiles `TinyKernel.ml`.

A file's name, or its place, says what it is when it is not a program
of the system:

- `TinyLibXxx` is a library that tiny programs are compiled with.
  For the programs of tiny-kernel, which tiny-ml compiles:
  `TinyLibCore.ml`, tiny-ml's prelude, in front of every one of them
  (the operators, the option, the exceptions, the `List` functions; it
  is tiny-ml's ML and not OCaml's, and the build puts its text in the
  compiler), then `TinyLibDraw`, `TinyLibPlayground` and `TinyLibGUI`,
  and `TinyLibStd.ml` for a tool that runs there too (tiny-shell):
  what it names of OCaml's standard library beyond the prelude
  (`String.split_on_char`, `Buffer`, `Hashtbl`), in tiny-ml's ML.
  For the host's programs when ix builds them: `TinyLibHost/`, a
  standard library (m-IX's is `lib_core/`).
- `TinyCRuntime/` and `TinyMLRuntime/` are not parts of the two
  compilers: they are what a program compiled by tiny-c or by tiny-ml
  is linked with (C's start, its division and its library; ML's
  allocator, collector and strings).
- `TinyAppXxx.ml` is an application, a program a person uses on
  tiny-kernel (`calc`, `temp`, `tetris`).
- `TinyLinker.ml` is a comment and no code: there is no tiny-linker,
  and it says where the two toolchains link (`TinyAssembler.ml`'s
  `link` for arm64, `TinyMachineCPU.ml`'s `assemble_files` for
  tiny-cpu) and why neither needs a linker of its own.
- Two things are more than a file, and have a directory of their name
  beside their program:
  - `TinyKernel.ml` and `TinyKernel/`: the kernel's parts in ML that
    are files of their own (`TinyKernelGraphics`, `TinyKernelNetwork`),
    its assembly and C, its programs (`user/`: the ones in C, and
    the last file of the ones in ML) and what they are linked with
    to call it, `libc/` for C (`user.h`, `sys.tm`, `draw.c`, `net.c`)
    and `libml/` for ML (`mlsys.c`, `calls.ml`, `TinyLibSystem.ml`);
  - `TinyMachine.ml` (and `TinyCPU.ml`) and `TinyMachine/`: the CPU
    (`TinyMachineCPU`), the devices (`TinyMachineDevices`), the other
    end of the wire (`TinyMachinePeer`, which runs the kernel's own
    `TinyKernelNetwork` on the host), and the three programs beside
    it, its window, its socket and its page.

The others are the system's programs, a file each (`TinyShell`,
`TinyC`, `TinyWindows`...). One of them is on both sides:
`TinyShell.ml` is the host's tiny-shell and, built by tiny-ml with
`TinyLibStd.ml`, tiny-kernel's `rc`; what it asks of the system is
`TinyLibSystem`, a file for each side (`TinyLibHost/TinyLibSystem.ml`
over Unix, `TinyKernel/libml/TinyLibSystem.ml` over the kernel's
calls).

[docs/projects.md](../docs/projects.md#what-a-tiny-program-stands-on)
has the picture: for a tool on the host, for a program in ML or in C
on tiny-machine, and for the kernel, which of these each one stands
on.

| file | executable | its twin | the idea kept |
|---|---|---|---|
| `TinyBuildSystem.ml` | tiny-build | `builder/` (mini-mk, mk) | rules, `%`, stamps as digests, one pass with `-j` |
| `TinyShell.ml` | tiny-shell | `shell/` (mini-rc, rc) | lists as the only value, words joined by adjacency, redirections around the command |
| `TinyEditor.ml` | tiny-editor | `editors/ed/` (mini-ed, ed) | sam's command language: dot a range, loops over matches, changes in parallel |
| `TinyAssembler.ml` | tiny-assembler | `assembler/`, `linker/` (mini-asm, mini-ld; 5a/5l, 7a/7l) | no separate compilation: all of a program's assembly into an arm64 executable, sizes known before addresses, a word per closure |
| `TinyC.ml` | tiny-c | `languages/c/` (mini-cc; 5c, 7c) | a C subset through a stack machine of its own, the stack in registers, 7c's calling convention so it links with goken's libc; and with `-tm` a second back end, for TinyCPU, with its runtime (`TinyCRuntime/`: `start.tm`, and a libc in C), the two printing the same |
| `TinyML.ml` | tiny-ml | `languages/ml/` (mini-ml; ocaml-light's ocamlopt) | an ML (variants, lists, closures, exceptions, Hindley-Milner) through TinyC's stack machine to arm64; the roots on a stack of values of its own (R26), so its collector, Cheney's, in C (`TinyMLRuntime/runtime.c`, by tiny-c), needs no frame table and no assembly; the prelude in ML; the output ocaml-light's, uncaught exceptions and stdout's buffer included |
| `TinyDatabase.ml` | tiny-db | `database/` (mini-chidb; chidb) | the relational algebra as the query language, a pipeline (`t \| where ... \| group ... \| sort ...`); a copy-on-write B-tree, so every statement is atomic by one header write |
| `TinyCPUArm.ml` | tiny-arm | `machine/` (mini-5i; 5i) | an arm64 CPU for the tiny toolchain's programs: an executable of tiny-assembler's loaded and run word by word, a word decoded and executed in one match, group by group as the manual tables them; Linux's four calls (read, write, exit, getpid); no assembler of its own, no instruction type; the subset is what tiny-c's and tiny-ml's programs execute, goken's libc included, and a word outside it stops the program; the same file runs on the real CPU and under mini-5i, and the three are compared |
| `TinyCPU.ml`, `TinyMachineCPU.ml` | tiny-cpu | `machine/` (mini-5i; 5i), with Knuth's MIX and MMIX | a machine of our own design, for teaching: 16 registers, r0 zero, no flags, one instruction format, every case defined; an assembler (a new machine has no other: nothing else writes its words) and an interpreter (the definition); the listing reassembles to the same words; the CPU a library, TinyMachine.ml's |
| `TinyMachine.ml` | tiny-machine | `raspberry/` (mini-qemu), with Project Oberon and RISC-V's privileged specification | TinyCPU's CPU with what a kernel needs, designed: two modes, one trap (epc, cause, tval, tvec) and eret, a timer counting instructions, protection by a window (base, bound), a console and a halt at the top of memory; a raw image (`-o`, linking several `.tm`) loaded at 0; a page of kernel, `TinyKernel/steps/v0/kernel.tm`, running four programs (`v0/a.tm` to `d.tm`), killing the two that misbehave; and for a window system, each an option: a screen that is memory (640 by 480 bytes, a byte a colour), a mouse that is a word, a window of the host's that shows them (`-window`, by another program, `TinyMachineWindow.ml`), a session replayed from a file, a wire to a network (`-net`: `TinyKernelNetwork.ml` below; its way to the host's own network by another program too, `TinyMachineSocket.ml`) |
| `TinyKernel.ml` (and `TinyKernel/`) | tiny-kernel (`./tiny-machine tiny-kernel`) | `kernels/9pi/` (mini-9pi; 9pi) | a kernel in ML for tiny-machine, compiled by `tiny-ml -tm`: the concepts kept (modes and system calls, preemption, protection, fork and exec, pipes, files and directories), each by the road ML makes short: the kernel a loop that runs a process until its next trap (`k_run`), a waiting call a closure the scheduler retries (no kernel stack per process, no sleep and wakeup), the files a tree of ML values in the heap (no disk); a screen programs draw on by messages and a mouse, a program's descriptors 3 and 4; `docs/notes_tiny_kernel.md` |
| `TinyKernelGraphics.ml` | in tiny-kernel | `lib_graphics/`, mini-9pi's `lib_memdraw` (libdraw, libmemdraw) | one operation, `draw dst r src mask p`, on images a byte a pixel; a colour is an image of one pixel that repeats; the kernel has the pixels and a program says what, by messages naming images by its own numbers |
| `TinyKernelNetwork.ml` | in tiny-kernel, and in tiny-machine | mini-9pi's `network/ip/`, `lib_networking/` (Plan 9's ip) | the stack is functions of strings, with no device and no clock: a packet that came gives the packets to send back and what a program hears; so the same file is the kernel's stack, its test on the host, and the other end of tiny-machine's wire (`-net`). IP's envelope, the echo (`ping`), and IL, Plan 9's protocol for messages that arrive once and in order (`get`, and `wiki`, a picture painted a row a message); `TinyMachinePeer.ml` is the few lines on top of it that make the wire's other end; [`plan_tiny_network.md`](../docs/plans/done/plan_tiny_network.md) |
| `TinyWindows.ml` | windows, a program of tiny-kernel | `windows/` (mini-rio; rio) | a window looks like the machine: a program is given five descriptors (its text, where it draws, its mouse) by the kernel or by the window system, and does not know which; so the window system runs in one of its own windows. Windows are images composed back to front; forwarding a program's drawing is renumbering its images |
| `TinyLibPlayground.ml` | with each game, a program of tiny-kernel | `lib_playground/` (the author's playground, Elm's) | a game is a model and three functions (its view as shapes, a key, a frame), with no loop and no drawing of its own: the library has them, and a game is tested with no screen |
| `TinyAppTetris.ml` | tetris, a program of tiny-kernel | `games/puzzle/Tetris.ml` | the game, in integers: the well, the seven pieces, rows, levels; its ground (the well's cells, the panel) kept in the model as shapes, so a piece that moves is five shapes |
| `TinyLibGUI.ml` | with each program that has buttons or fields, a program of tiny-kernel | `lib_gui/` (the author's playground's; libpanel) | an interface is a value the model is turned into, and what it sends back: widgets made again from each model, a button carrying the message it sends and a field the message of another text, one update where the model changes; the layout in two passes (a size asked up, a place given down); under the model one value, the mouse: the button held and the field that has the keys are places, so no widget has a name; only the widgets that changed drawn, a held button's edges and a caret over them |
| `TinyAppCalculator.ml` | calc, a program of tiny-kernel | none (`examples/Gui7Counter.ml` and the other 7GUIs are lib_gui's small programs) | the calculator of four operations: a number shown, a number kept, the operation that awaits; a key is its button's message |
| `TinyAppTemperature.ml` | temp, a program of tiny-kernel | `examples/Gui7Temperature.ml` | two fields, each the other's answer: the model is the two texts, not a temperature, since half of what is typed is not a number; the message says which field was typed in, so nothing echoes |
| `TinyBrowser.ml` | www, a program of tiny-kernel (so far only the part that reads a page: [`plan_tiny_browser.md`](../docs/plans/plan_tiny_browser.md)) | `browsers/` (mini-netscape, mini-lynx) | a page is read once, as it arrives, and turned directly into lines; there is no document tree and no style sheet, and the meaning of a tag is a row in a table; a table's cells are kept until the widths of its columns are known |
| `TinyVCS.ml` | tiny-vcs | `version_control/` (mini-git; git9) | git's objects, trees and DAG; the repository as one hash (an operation log, so every command is atomic and undoable); no staging area; merges that always succeed, conflicts committed as data |

The last four are ML for tiny-ml -tm, run on tiny-machine (`./tiny-machine
-window tiny-kernel`, then `windows`, and `tetris` in a window),
and OCaml too: the same files are built by dune, as libraries, and
tested on the host first. Three small files stand between them and
their machine: `TinyLibDraw.ml` (a program's side of the drawing
messages), and what the machine gives, by OCaml on the host,
`TinyMemory.ml` (its bytes: an array) and `TinyCalls.ml` (the kernel's
calls: kept or absent), both in `TinyKernel/host/`; on tiny-machine
these two are externals (`TinyKernel/memory.ml`,
`TinyKernel/libml/calls.ml`).
[`docs/plans/done/plan_tiny_windows.md`](../docs/plans/done/plan_tiny_windows.md)
is their plan and what was found.

[`TinyLibHost/`](TinyLibHost/README.md) is the library under the host's tiny
programs when ix builds them (`mini-mk` here, for arm64): lib_core's
modules that they name, with the functions they call, and a runtime
and a C library of its own. dune builds them on OCaml's standard
library and `lib_core/commons/`; `mini-mk LIB=core`, and arm's build,
on `lib_core/` whole, as m-ix's programs. The programs of tiny-kernel
do not use it: they are tiny-ml's, whose library is its prelude and
`TinyMLRuntime/`.

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
(TinyAssembler's, TinyC's and TinyML's, which need goken, by `make
test-goken`; TinyC's programs are `tests/TinyC_tests/`, and `tests/TinyC_fuzz.py`
writes random ones; TinyML's are `languages/ml/tests/tiny/`, with
ocaml-light's outputs);
the plans' Status logs (`docs/plans/`) tell how each was chosen and
checked.

[`docs/notes_tiny_spirit.md`](../docs/notes_tiny_spirit.md) says where
this directory departs from its own definition (a twin, an inherited
machine, a contract from outside), what each departure buys, and what
was decided.
