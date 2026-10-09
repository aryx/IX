# Plan: ix built from its sources under mini-9pi (`/src` on the card)

The author (2026-10-09, mini-emacs just running on mini-9pi): "let's
start to have a /src/ where we put some code because ultimately we
will want to copy the source of ix/ in the card and compile ix from
under mini-9pi", "but let's start with a small /src/ with just those
little ocaml and maybe little c programs and assembly too, to test
emacs mostly for now", "we should probably start a plan document
actually for being able to compile ix from under m-ix running mini-9pi
and its card".

The short answer: **ix's tools already build for mini-9pi, all but
one; none is on the card, no source is, and nothing has been compiled
there. The plan is five stages, from `hello.s` assembled on the card
to mini-ml compiling itself there, each a program built on the card
and compared, byte for byte, with the one Linux builds.**

**Status: not started** (this plan; a first `/src` of five small
files on the card, for mini-emacs).

## Where it starts from (2026-10-09)

- **ix is built by ix on Linux** (`plans/done/plan_mkfiles.md`): mini-mk
  reads the mkfiles, mini-ml, mini-cc, mini-asm, mini-ld, mini-ar,
  mini-lex and mini-yacc do the work, mini-rc runs the recipes. The
  build has no Python and no dune in it.
- **For mini-9pi the programs are built on Linux** (`mini-mk O=5
  OS=plan9`, Plan 9's a.out for arm) and put on the card by mini-mkfs
  (`kernels/9pi/Makefile`: `CARD_BIN`, 52 programs; the file system is
  xv6's, 95 MB).
- **The tools for mini-9pi**, tried now in a copy of the tree (`mini-mk
  O=5 OS=plan9` in each directory):

  | | builds | its size |
  |---|---|---:|
  | mini-asm (`assembler/`) | yes | 638 KB |
  | mini-ld (`linker/`) | yes | 1,089 KB |
  | mini-ar (`linker/tools/`) | yes | 585 KB |
  | mini-cc (`languages/c/`) | yes | 1,940 KB |
  | mini-lex, mini-yacc (`generators/`) | yes | 570, 631 KB |
  | mini-ml (`languages/ml/`) | yes | 2,565 KB |
  | mini-rc (`shell/`) | yes, in the kernel's image | 743 KB |
  | mini-mk (`builder/`) | **no**: `CLI.ml:62: unbound value Unix.utimes` (Plan 9's `Unix` has none) | |

  None of them has been run on mini-9pi but mini-rc.
- **The sources**: 2,021 files of code, 8.0 MB (947 `.ml` 5.4 MB, 635
  `.mli` 1.4 MB, 178 `.c`, 68 `.h`, 115 `.s`, 14 `.mll` and `.mly`, 64
  mkfiles; `tests/ix_files.sh`): a twelfth of the card.
- **An editor there**: mini-emacs (`emacs`, 2026-10-09), and mini-ed.

## What it requires

1. **mini-mk for Plan 9**: `Unix.utimes` (a file's time set: `mk -t`,
   touch), then what it finds missing when run: a recipe run by
   `/bin/rc`, a process waited for, a file's time read (the xv6 file
   system keeps a time a file: to check), the environment.
2. **Processes and memory.** mini-ml compiling a unit is a process of
   tens of megabytes (its heap; `ML_HEAP`), mini-ld linking mini-ml
   more; a Pi1 has 512 MB, QEMU's the same. What the kernel gives a
   process, and what the tools take, are to be measured: the first
   thing that can stop the plan.
3. **The file system**: a build writes thousands of objects. xv6's
   file system on the card: a file's largest size (mini-ld's output,
   1 to 3 MB; a library, `lib_core.a`), the number of files, the time
   of a write; no permissions (an executable is one by its content).
4. **Time.** A unit compiled by mini-ml on Linux is under a second;
   on arm under an emulator, or on a Pi1 (700 MHz), to be measured at
   stage 2: lib_core is 69 units, ix 2,000. A build of all of ix there may be hours; a build of one
   program is the goal first.
5. **The tree on the card**: `/src/ix/` as the repository (the mkfiles
   name `$TOP/...`), `/src/ix/_mk/5-plan9/` for what is made. What
   mini-mkfs is given: the list of `tests/ix_files.sh`, not 2,000
   arguments on a command line.
6. **The same bytes.** A program built on the card must be the one
   Linux builds (`cmp`): if the tools give the same bytes at each run
   (to check first, on Linux: two builds compared), a difference is a
   bug of the kernel, of a tool on arm, or of the file system. This is the test of every
   stage.
7. **What a build on Linux has and Plan 9 has not**: `ls` in a
   mkfile's backquotes (mini-ls is there), `case` and `for` of rc (in
   mini-rc: to check on the mkfiles as they are), `mkdir -p`, `rm
   -rf`, `cp` (utilities/'s: their flags).

## The stages (each checked before the next)

1. **A file assembled and linked on the card.** mini-asm, mini-ld on
   the card; `/src/hello.s` (there now) made a program by hand
   (`asm`, `ld`), run, and `cmp`'d with Linux's. Then `hello.c` with
   mini-cc and the C library (`libc.a` on the card, or built there).
2. **A file compiled by mini-ml on the card.** mini-ml and
   `lib_core.a` on the card; `/src/hello.ml` compiled, linked, run,
   `cmp`'d. Measured: the seconds and the megabytes of one unit.
3. **mini-mk on the card, and a program built by its mkfile.**
   `Unix.utimes` and what follows; a small program's directory in
   `/src/ix/` (`utilities/misc`: mini-echo) with `mkfiles/`, built by
   `mk`, `cmp`'d. Then lib_core built there (69 units, the C runtime,
   the C library).
4. **The tools built on the card**: mini-asm, mini-ld, mini-cc, mini-ml
   by the mkfiles, each `cmp`'d with Linux's; then mini-ml built by
   the mini-ml built there (the fixed point, as on Linux).
5. **All of `/src/ix`**, and the kernel: mini-9pi's image built under
   mini-9pi, booted. What a session of it costs in time decides what
   of it is a test.

## Open questions

- **The machine it is run on to develop**: QEMU (fast, minutes a
  session), mini-qemu (ix's, slower), a real Pi1. The stages' checks
  are long sessions: which are in `make check`, which are run by hand?
- **Memory**: if a tool does not fit (mini-ld linking mini-ml), is the
  answer in the tool (the heap's size, a collection before it grows),
  in the kernel (more for a process), or is that program not built
  there?
- **The file system**: stay with xv6's (simple; its limits to be
  read), or is this the day for another (Plan 9's kfs, cwfs)?
- **`/src`'s layout**: `/src/ix/...` as the repository, with today's
  five files moved into it where they come from
  (`/src/ix/kernels/9pi/tests/hello/Hello.ml`), or a flat `/src` of
  examples beside it?
- **The sources on the card and in git**: a card built from a commit;
  a file changed on the card with emacs comes back how (mini-git is
  there, `version_control/`)?
- **What is not built there**: dune's programs (SDL windows), the
  tests in Python, the playground's games' assets.

## Status

Not started. 2026-10-09: this plan, with the tools tried for Plan 9
(above); `/src` on the card with `hello.ml`, `hellodraw.ml`,
`hellorio.ml`, `hello.c` and `hello.s` (`kernels/9pi/Makefile`:
`CARD_SRC`), texts for mini-emacs.
