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
- **compat/, opti/, ssa/**: not in m-ix's lines. Code a program runs
  the same without: kept for a reference's exact output, optimizations
  behind a flag, an optional back end.
- **t-ix**: the tiny programs (`tiny/`), each a file, and tiny-os.

A line is added when a step lands that moves the numbers
(`scripts/stats/loc.py -l` prints it, for the commit it is run at),
with what moved them.

| date | commit | m-ix | compat/ | opti/ | ssa/ | t-ix | what moved |
|---|---|---:|---:|---:|---:|---:|---|
| 2026-10-02 | `579b564` | 80,559 | 2,452 | 588 | 960 | 15,964 | the first entry. m-ix has just gained the C library (`lib_core/libc/`, 9,149 lines copied from goken, to trim), mini-lex and mini-yacc (1,246), and mini-ar; the stdlib is in it since 2026-10-01 (about 10,000 lines then, from ocaml-light) |
