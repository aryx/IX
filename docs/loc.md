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
