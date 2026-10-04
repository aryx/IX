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
- **Not in m-ix's lines**: the alternatives and the optional, which ix
  builds and runs the same without (`make loc` lists them last, each
  with its lines and its reason):
  - `compat/`: kept for a reference's exact output;
  - `opti/`, `ssa/`: optimizations behind a flag, an optimizing back end;
  - the kernel's (since 2026-10-04; in m-ix before): `kernel/step0-5/`,
    the steps mini-xv6 was built up by; the reference kernels' own
    files (ocaml-light's and gcc's start and C library); mini-9pi's
    pixels in C (`lib_graphics/c/`).
- **t-ix**: the tiny programs (`tiny/`), each a file, and tiny-os.

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
