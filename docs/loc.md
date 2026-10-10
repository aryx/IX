# The lines of ix, over time

ix's goal is a whole operating system and its tools in a number of
lines a reader can go through. This is the log of that number: what
`make loc` prints last, without the tests. Fewer lines for the same
functionality and the same clarity is progress; more, for something new,
is to be weighed.

- **m-ix**: the mini programs (the faithful twins: the toolchain, the
  machines, the kernel, mk, rc, ed, the database, git, the generators)
  and the libraries (`lib_*/`: ix's own, the stdlib, the C library).
  OCaml, C and assembly.
- **Not in either number, from 2026-10-10**: the header comments, a
  module's documentation at the top of its `.mli` (or of its `.ml`
  when it has no interface), where its idea, its history and its
  references are told (`docs/tags.md`). `make loc` prints m-ix and
  t-ix with them and without them; the log's numbers are without. A
  number to keep small must not be a reason to teach less.
- **Not in m-ix's lines**: the alternatives and the optional, which ix
  builds and runs the same without (`make loc` lists them last, each
  with its lines and its reason):
  - `compat/`: kept for a reference's exact output;
  - `opti/`, `ssa/`: optimizations behind a flag, an optimizing back end;
  - the kernel's (since 2026-10-04; in m-ix before): `kernels/step0-5/`,
    the steps mini-xv6 was built up by; the reference kernels' own
    files (ocaml-light's and gcc's start and C library); mini-9pi's
    pixels in C (`lib_graphics/c/`);
  - the games' software platform (since 2026-10-07; in m-ix before):
    `lib_graphics/software/` and `lib_playground/platforms/software/`,
    the pixels by the program; the games draw by the draw device.
- **t-ix**: the tiny programs (`tiny/`), each a file, with what a
  program has beside its file, in a directory of its name:
  `tiny/TinyC/` (tiny-c -tm's C library), `tiny/TinyML/` (tiny-ml's
  runtime), `tiny/TinyKernel/` (tiny-kernel's start and programs). Not
  tiny-os (since 2026-10-09; in t-ix before): `tiny/tiny-os/`, the
  other kernels of tiny-machine, in C, as `kernels/xv6/` is not in
  m-ix; what tiny-kernel took from it (the C library, six programs)
  is in those directories, tiny-os's own a link.

The budget (the author's, 2026-10-08): **100,000 lines for m-ix** and
**20,000 for t-ix**. On that day m-ix is at 85,312 and t-ix at 16,079:
about 14,700 and 3,900 lines left. What is planned is weighed against
what is left, and past the budget something is trimmed or moved apart
before something new comes in.

Since 2026-10-09 m-ix's budget is **125,000 lines** (the author:
"let's move the budget to 125 000 LOC"), the day `apps/` (mini-office:
"an Office is also pretty fundamental in an OS for a user"),
`lib_gui/` and `lib_playground/` came to be counted, which put m-ix
at 101,052: about 23,900 left.

A line is added when a step lands that moves the numbers
(`scripts/stats/loc.py -l` prints it, for the commit it is run at),
with what moved them.

| date | commit | m-ix | compat/ (not in m-ix) | opti/ (not in m-ix) | the kernel's steps and references (not in m-ix) | t-ix | what moved |
|---|---|---:|---:|---:|---:|---:|---|
| 2026-10-02 | `579b564` | 80,559 | 2,452 | 1,548 | (in m-ix) | 15,964 | the first entry. m-ix has just gained the C library (`lib_core/libc/`, 9,149 lines copied from goken, to trim), mini-lex and mini-yacc (1,246), and mini-ar; the stdlib is in it since 2026-10-01 (about 10,000 lines then, from ocaml-light) |
| 2026-10-02 | `fe18f11` (and step 3, the commit after) | 80,767 | 2,452 | 1,554 | (in m-ix) | 15,964 | signal handlers in mini-ml's runtime and stdlib (+160), the rest of plan_mkfiles.md's steps 2 and 3 (the runtime's seeks, small changes in the stdlib); the mkfiles are not counted |
| 2026-10-04 | `93e0269` | 75,687 | 2,456 | 1,554 | 6,767 | 15,964 | the kernel's steps, the reference kernels' own files and mini-9pi's pixels in C are counted apart (10,777 with compat/ and opti/: `make loc`'s last lines), and the steps' `libc.c` is one file (-1,179). Since the last entry m-ix also gained the Pi 4's and the Pi 1's kernels by ix's tools (their `l.s`, the mkfiles' `shim.c`), the runtime's callbacks and per-process stacks, mini-ld's raw images and system instructions |
| 2026-10-04 | `3b43f59` | 73,859 | 3,021 | 1,554 | 6,767 | 15,964 | a day of trimming, the functionality the same: deriving for the compilers' four dumps (ppx_deriving's text, by mlpp in mini-ml: -284 for +35), `Set` and `Map` out of the stdlib (-506), `Format` to what ix uses and no `Fmt` (-389), `Either` and `Result` to their core (-247), `Asm.mli` and `database/Ast.mli` out (types said once), and moved to `compat/`: mini-cc's `-x` tree, the two disassemblers (objdump's text, 482). Also in: mini-xv6 and mini-9pi on the Pi 1 by ix (`kernel/lib/pi1/l.s`, 320) |
| 2026-10-04 | `1b3320e` | 69,038 | 3,030 | 1,528 | 6,767 | 15,964 | the trimming, on: the stdlib to what is general and its comments shorter (an experiment), types said once in files of their own without a `.mli` (`Errors`, `P9`, `Tree`, `Arm64_isa` with the CPU's state, `Host_calls`, `Program`, `Bytecode`, `Ir`, `Ssa`), mini-cc's lexer by ocamllex, the C library's formatter and arm's vlongs ix's own (`lib_core/libc/ix/`: 940 lines for 3,634), and mlpp's `type t = [%mli]` in mini-mk and the MMUs (a pilot) |
| 2026-10-07 | after `b180cd1` | 84,340 | 2,956 | 1,479 | 6,592 | 15,852 | three days of programs: mini-awk (2,437), dc, bc and hoc (2,317), sed, sort and other utilities, mini-9pi's filesystems and buses, mini-rio, the C library's Plan 9 files. Counted apart from now: the games' software platform (`lib_graphics/software/` and the playground's platform over it, 1,855), the other systems of `kernel/` and mini-smalltalk. Marshal in ML: 444 lines of C for 372 of ML (-130) |
| 2026-10-09 | after `f1222c2` | 83,967 | 2,956 | 1,492 | 5,971 | 17,880 | t-ix's window system (plan_tiny_windows.md, done): TinyGraphics (270), TinyWindows (442) with TinyDraw (54), TinyPlayground (161) with TinyCalls and TinyMemory (55), TinyTetris (195); TinyKernel.ml 564 to 756 and TinyMachine.ml 415 to 598 for a screen, a mouse, a box, ready; tiny-kernel's C and assembly +330. 1,800 lines where the plan had 1,200. m-ix's number is the tree's that day, other sessions' work in it |
| 2026-10-09 | after `b998f87` | 101,052 | 2,956 | 1,492 | 5,971 | 17,880 | counted from now: `apps/` (5,639: mini-office, the playground's TinyOffice, with its kits, parts and a sheet's formulas, plan_office.md; mini-colors), `lib_gui/` (3,480) and `lib_playground/` (7,219, its software platform apart as before): 16,338 lines that were there, apart or in no group; m-ix's budget 125,000, where it was 100,000 |
| 2026-10-09 | after `6742ccc` | 102,782 | 2,956 | 1,492 | 5,971 | 12,913 | not counted from now: the `sdl/` and `tty/` directories, a program's hosts on Linux (about 300 lines of m-ix: mini-emacs's terminal, the playground's SDL platform), and `tiny/tiny-os/` (5,160 of t-ix: the other kernels of tiny-machine; t-ix's is tiny-kernel). What tiny-kernel took from tiny-os is t-ix's and moved: tiny-c -tm's C library to `tiny/TinyC/libc/` (192), cat, echo, ls, wc, mkdir and rm to `tiny/TinyKernel/user/` (143), tiny-os's own links to them; tiny-ml's runtime is `tiny/TinyML/` (578). m-ix also has the day's programs, other sessions' |
| 2026-10-10 | `1021864` | 128,561 | 2,956 | 1,515 | 5,977 | 18,786 | not counted from now: the header comments (`docs/tags.md`), 13,397 lines of m-ix's 141,958 in 1,168 files and 1,604 of t-ix's 20,390 in 101; a pilot of 30 of them written or extended (`lib_compression/`, `shell/`, `utilities/files/`, `utilities/calc/dc/`), 1,000 lines under a tag. m-ix also has the day's programs, other sessions' |
| 2026-10-10 | after `d219226` | 128,576 | 3,065 | 1,760 | 6,119 | 18,824 | the header comments of the whole tree, written or extended (526 files, comments only): m-ix's 13,397 lines to 26,618 in 1,140 header comments, t-ix's 1,604 to 2,967 in 101, neither counted; 6,187 of m-ix's lines under a tag, in 716 paragraphs. m-ix's 15 lines and t-ix's 38 over the last entry are the day's programs, other sessions' |
