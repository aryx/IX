# Plan: ix built by ix, with mkfiles

Companion of [`plan_ml_bootstrap.md`](plan_ml_bootstrap.md) (goal 2:
mini-ml compiles ix) and [`plan_lex_yacc.md`](plan_lex_yacc.md) (step
4: the programs linked and run). Every file of ix compiles alone by
mini-ml; here the programs are made, by ix's own tools, and run. The
author (2026-10-02): "I was planning actually to make install so the
mini-xxx binaries are in the PATH, and then write assembler/mkfile
that calls mini-ml, mini-lex, etc.", "so we also dogfood mini-mk".

## What a program's build is

1. the C library: goken's libc, each file by mini-cc or mini-asm, the
   archive by mini-ld;
2. mini-ml's runtime, `runtime.c`, by mini-cc;
3. the stdlib and ix's library (`lib_core/`), each unit by mini-ml;
4. the program's units: mini-lex and mini-yacc on its `.mll` and
   `.mly`, then mini-ml on each `.ml`;
5. the start object, `mini-ml -start` with the units in the order they
   are initialized;
6. the link, by mini-ld.

Everything is ix's but the sources of the C library (goken's, until
they are in `lib_core/libc/`) and the machine under it.

## Decisions

1. **mini-mk runs it**, with the installed programs: `make install`
   (dune's, into opam's bin), or `PATH=$PWD/bin:$PATH`.
2. **`mkfiles/`**, as xix's: `mkconfig` (the machine, the tools, the
   stdlib's units in their order) and `mkprog` (a program's rules). A
   directory's `mkfile` says its units, in order, by hand: it is what a
   mkfile is for, and it says what the program is made of.
3. **What is made is under `_mk/$O/`**, a directory a program, not
   beside the sources as Plan 9 does: dune reads the source directories
   too, and would take a generated `Parser.ml` for a source. dune skips
   `_mk` (a name with `_`); it is in `.gitignore`.
4. **The whole stdlib is linked**, each of its units initialized: a
   program's mkfile doesn't say which it needs (mini-asm is 816 KB so).
   mini-ld leaving out the units nothing names is for later.
5. **A unit is remade when any source of its directory changes**:
   mini-ml reads the other units' interfaces from their sources, and a
   directory is a second to compile. Exact dependencies (`mini-ml -M`)
   later, if it is felt.
6. **The contract: the program dune builds.** A program made by ix's
   tools gives the same bytes as dune's on the same inputs
   (`mkfiles/check.sh`).

## Steps

1. `lib_core/mkfile` and `assembler/mkfile`: mini-asm. **Done**
   (2026-10-02): `mini-mk` from nothing makes the C library, the
   runtime, 53 units of the stdlib and of ix's library, and mini-asm,
   in 12 s; that mini-asm writes the same objects as dune's on goken's
   31 arm and arm64 `.s` files, and the hello it assembles runs.
2. mini-ld (`linker/`, with `assembler/`'s units), then mini-cc
   (`languages/c/`: its grammar by mini-yacc), mini-chidb (`database/`:
   mini-lex and mini-yacc), mini-mk, mini-rc, mini-ed.
3. mini-lex, mini-yacc and mini-ml themselves; then the fixed point:
   ix's tools built by themselves build the same tools again.
4. On arm (`O=5`), under mini-5i.

## Found on the way

- mk gives the name `X` for `${X:%=-I %}` when X is empty or not set
  (goken's mk too): a mkfile says `LIBI=` whole.
- An object is a marshalled value, and OCaml shares the blocks of a
  unit's equal literals (two `0L` are one block): mini-ml had a block
  for each, so two of 31 objects had 6 bytes more. mini-ml now shares a
  unit's float, int32 and int64 literals of one value, as it did
  strings.
