# tiny/

The tiny programs of ix (t-ix): the free variants of its mini
programs (m-ix), one file each (but TinyCPUArm and TinyCPU, whose CPUs
are libraries, `TinyLibArm.ml` and `TinyLibCPU.ml`, for TinyMachinePi.ml
and TinyMachine.ml), installed as
tiny-build, tiny-shell, ... (the second column): what is left of a
program when compatibility is dropped and only its idea is kept,
written after its faithful twin and from what that one taught. The
files, children and pipes they share with the twins come from
`lib_core/` (`FS`, `Procs`), not copied into each.

| file | executable | its twin | the idea kept |
|---|---|---|---|
| `TinyBuildSystem.ml` | tiny-build | `builder/` (mini-mk, mk) | rules, `%`, stamps as digests, one pass with `-j` |
| `TinyShell.ml` | tiny-shell | `shell/` (mini-rc, rc) | lists as the only value, words joined by adjacency, redirections around the command |
| `TinyEditor.ml` | tiny-editor | `editors/ed/` (mini-ed, ed) | sam's command language: dot a range, loops over matches, changes in parallel |
| `TinyAssembler.ml` | tiny-assembler | `assembler/`, `linker/` (mini-asm, mini-ld; 5a/5l, 7a/7l) | no separate compilation: all of a program's assembly into an arm64 executable, sizes known before addresses, a word per closure; or, with `-raw`, into a kernel's image, with the system instructions a kernel's first page needs |
| `TinyC.ml` | tiny-c | `languages/c/` (mini-cc; 5c, 7c) | a C subset through a stack machine of its own, the stack in registers, 7c's calling convention so it links with goken's libc; and with `-tm` a second back end, for TinyCPU, with its runtime (`tiny-os/libc/`: `start.tm`, and a libc in C), the two printing the same |
| `TinyML.ml` | tiny-ml | `languages/ml/` (mini-ml, planned; ocaml-light's ocamlopt) | an ML (variants, lists, closures, exceptions, Hindley-Milner) through TinyC's stack machine to arm64; the roots on a stack of values of its own (R26), so its collector, Cheney's, in C (`TinyML_runtime.c`, by tiny-c), needs no frame table and no assembly; the prelude in ML; the output ocaml-light's, uncaught exceptions and stdout's buffer included |
| `TinyDatabase.ml` | tiny-db | `database/` (mini-chidb; chidb) | the relational algebra as the query language, a pipeline (`t \| where ... \| group ... \| sort ...`); a copy-on-write B-tree, so every statement is atomic by one header write |
| `TinyCPUArm.ml`, `TinyLibArm.ml` | tiny-arm | `machine/` (mini-5i; 5i) | an arm64 CPU for the tiny toolchain's programs: an executable of tiny-assembler's loaded and run word by word, a word decoded and executed in one match, group by group as the manual tables them; Linux's four calls (read, write, exit, getpid); no assembler of its own, no instruction type; the subset is what tiny-c's and tiny-ml's programs execute, goken's libc included, and a word outside it stops the program; the same file runs on the real CPU and under mini-5i, and the three are compared |
| `TinyCPU.ml`, `TinyLibCPU.ml` | tiny-cpu | `machine/` (mini-5i; 5i), with Knuth's MIX and MMIX | a machine of our own design, for teaching: 16 registers, r0 zero, no flags, one instruction format, every case defined; an assembler (a new machine has no other: nothing else writes its words) and an interpreter (the definition); the listing reassembles to the same words; the CPU a library, TinyMachine.ml's |
| `TinyMachine.ml` | tiny-machine | `raspberry/` (mini-qemu), with Project Oberon and RISC-V's privileged specification | TinyCPU's CPU with what a kernel needs, designed: two modes, one trap (epc, cause, tval, tvec) and eret, a timer counting instructions, protection by a window (base, bound), a console and a halt at the top of memory; a raw image (`-o`, linking several `.tm`) loaded at 0; a page of kernel, `tiny-os/v0/kernel.tm`, running four programs (`v0/a.tm` to `d.tm`), killing the two that misbehave; and for a window system, each an option: a screen that is memory (640 by 480 bytes, a byte a colour), a mouse that is a word, a window of the host's that shows them (`-window`, by another program, `TinyMachineWindow.ml`), a session replayed from a file |
| `TinyMachinePi.ml` | tiny-pi | `raspberry/` (mini-qemu, its Pi 4; QEMU's raspi4b) | TinyCPUArm's CPU (`TinyLibArm.ml`) in the Pi 4: the exception levels (EL0, EL1, and EL2 where the firmware leaves a kernel) and their stack pointers, the exceptions (svc, undefined, an interrupt) taken to EL1 and their return by eret, mrs and msr, wfi, the PL011, the virtual timer and the GIC-400 at their real addresses, time from instructions; a raw image (tiny-assembler's `-raw`) loaded at 0x80000 as the firmware loads kernel8.img; a page of kernel (`TinyMachinePi_tests/tick.s`: user mode, system calls, an undefined instruction, five timer interrupts) that runs the same here, under mini-qemu and under QEMU |
| `TinyKernel.ml` (and `TinyKernel/`) | tiny-kernel (`./tiny-machine tiny-kernel`) | `kernels/9pi/` (mini-9pi; 9pi) | a kernel in ML for tiny-machine, compiled by `tiny-ml -tm`: the concepts kept (modes and system calls, preemption, protection, fork and exec, pipes, files and directories), each by the road ML makes short: the kernel a loop that runs a process until its next trap (`k_run`), a waiting call a closure the scheduler retries (no kernel stack per process, no sleep and wakeup), the files a tree of ML values in the heap (no disk); a screen programs draw on by messages and a mouse, a program's descriptors 3 and 4; `docs/notes_tiny_kernel.md` |
| `TinyGraphics.ml` | in tiny-kernel | `lib_graphics/`, mini-9pi's `lib_memdraw` (libdraw, libmemdraw) | one operation, `draw dst r src mask p`, on images a byte a pixel; a colour is an image of one pixel that repeats; the kernel has the pixels and a program says what, by messages naming images by its own numbers |
| `TinyWindows.ml` | tiny-windows, a program of tiny-kernel | `windows/` (mini-rio; rio) | a window looks like the machine: a program is given five descriptors (its text, where it draws, its mouse) by the kernel or by the window system, and does not know which; so the window system runs in one of its own windows. Windows are images composed back to front; forwarding a program's drawing is renumbering its images |
| `TinyPlayground.ml` | with each game, a program of tiny-kernel | `lib_playground/` (the author's playground, Elm's) | a game is a model and three functions (its view as shapes, a key, a frame), with no loop and no drawing of its own: the library has them, and a game is tested with no screen |
| `TinyTetris.ml` | tetris, a program of tiny-kernel | `games/puzzle/Tetris.ml` | the game, in integers: the well, the seven pieces, rows, levels; its ground (the well's cells, the panel) kept in the model as shapes, so a piece that moves is five shapes |
| `TinyVCS.ml` | tiny-vcs | `version_control/` (mini-git; git9) | git's objects, trees and DAG; the repository as one hash (an operation log, so every command is atomic and undoable); no staging area; merges that always succeed, conflicts committed as data |

The last four are ML for tiny-ml -tm, run on tiny-machine (`./tiny-machine
-window tiny-kernel`, then `tiny-windows`, and `tetris` in a window),
and OCaml too: the same files are built by dune, as libraries, and
tested on the host first. Three small files stand between them and
their machine: `TinyDraw.ml` (a program's side of the drawing
messages), and what the machine gives, by OCaml on the host,
`TinyMemory.ml` (its bytes: an array) and `TinyCalls.ml` (the kernel's
calls: kept or absent); on tiny-machine these two are externals
(`TinyKernel/memory.ml`, `TinyKernel/user/calls.ml`).
[`docs/plans/done/plan_tiny_windows.md`](../docs/plans/done/plan_tiny_windows.md)
is their plan and what was found.

`tiny-os/` is not OCaml: it is an operating system for tiny-machine,
in its assembly (`.tm`) and in C for tiny-c -tm, built by the tiny
tools as a program is built by its toolchain. A kernel per version
(`v0/`: a page of assembly and four programs linked with it; `v6/`,
xv6's kind of kernel in C, with its disk made by `tiny-mkfs`, a shell
and `usertests`; `t6/`, its free variant, with `spawn` and no `fork`, a
FAT, one kernel stack), and the C runtime they
share (`libc/`: `start.tm`, `libc.c`, `libc.h`); `hello.c` runs on
tiny-cpu. Its Makefiles take the tools from the PATH (after `dune
install`) or from ix's `bin/`: `make -C tiny/tiny-os run`, `make -C
tiny/tiny-os run-hello`. [`docs/projects.md`](../docs/projects.md)
places it among ix's other projects.

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
