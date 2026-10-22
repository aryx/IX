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

**Status: stages 1, 2 and 3's first half done** (2026-10-21: mini-mk
on mini-9pi builds lib_core and a program by their mkfiles, the
program Linux's bytes; Status below).

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
  | mini-mk (`builder/`) | yes since 2026-10-21 (Plan 9's `Unix.utimes`, a wstat) | 816 KB |

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
5. **The tree on the card**: `/src` as the repository (the mkfiles
   name `$TOP/...`), `/src/_mk/5-plan9/` for what is made. What
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
   `/src` (`utilities/misc`: mini-echo) with `mkfiles/`, built by
   `mk`, `cmp`'d. Then lib_core built there (69 units, the C runtime,
   the C library).
4. **The tools built on the card**: mini-asm, mini-ld, mini-cc, mini-ml
   by the mkfiles, each `cmp`'d with Linux's; then mini-ml built by
   the mini-ml built there (the fixed point, as on Linux).
5. **All of `/src`**, and the kernel: mini-9pi's image built under
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
- **`/src`'s layout**: decided, 2026-10-21: `/src` is the repository,
  on make card-self's card (the author: "the code should be put under
  /src/ on the card, like I think we do for t-ix"); the everyday card
  keeps its five small examples there.
- **The sources on the card and in git**: a card built from a commit;
  a file changed on the card with emacs comes back how (mini-git is
  there, `version_control/`)?
- **What is not built there**: dune's programs (SDL windows), the
  tests in Python, the playground's games' assets.

## Status

- 2026-10-21: stages 1 and 2 done, under QEMU; stage 3 begun (the
  author: "we recently build t-ix under t-ix. We should try to do the
  same for m-ix: building m-ix from under m-ix").
  - **Stage 1**: mini-asm and mini-ld built for Plan 9 and on the card
    (`/progs/toolchain`: `asm`, `ld`, mini-X as X as every program
    there); `/src/hello.s` assembled and linked on mini-9pi, the 136
    bytes Linux's (`xd`).
  - **Stage 2**: mini-ml, lib_core's sources and its Plan 9 objects on
    the card; `hello.ml` compiled, its start made, linked, run, the
    three files Linux's (`cmp`). Under QEMU (Pi 1): the unit 2.9 s,
    the start 2.5 s, the link 18.8 s; on Linux (arm64) 0.01, 0.02 and
    0.37 s. The link's 50 times: 3.6 for ix's 32-bit code (the same
    link as a Linux arm program, natively on this host: 1.33 s), 4.4
    for QEMU's emulation (under `qemu-arm`: 5.85 s), 3.2 for the
    system emulated and mini-9pi (the card read at 1.3 MB/s, the
    faults, the heap's growth). A small unit's 300 is start-up: `ml`
    itself (2.7 MB, 0.9 s) and lib_core's interfaces read through Kfs.
  - **The card's file system**: names of 62 characters (a fifth of
    ix's files have names of more than 14: `Out_channel.mli`), in
    entries of 64 bytes, ix's third extension to xv6's format; xv6's
    own images are no longer read (the author: "there is no need to
    remain backward compatible with the actual xv6 filesystem").
    Kfs's cache keeps what a call writes and writes each changed
    piece of 4 KB once when the call ends (each write was five small
    ones to the card, and forgot the pieces it touched): `cp` of 5.6
    MB 58.6 s, now 24.6 s; a read 1.3 MB/s.
  - **mini-mk for Plan 9**: Plan 9's `Unix.utimes` (a wstat).
  - **The mkfiles' recipes are rc's, on Linux too** (the author chose
    "rc everywhere" over an sh on mini-9pi; then: "you can also set
    the MKSHELL env var so no need set MKSHELL in every mkfile"):
    `MKSHELL=mini-rc` exported by the Makefiles and the scripts that
    run mini-mk (mini-mk's default stays sh, goken's mk's); on the
    card boot.rc sets it, with Plan 9's `objtype=arm` and `NPROC` (a
    line of `#c/sysstat` a core). mkconfig names the tools by
    `$objtype` (`mini-ml` on Linux, `ml` on the card: `$ML`, `$MK`,
    `$WALK`, `$RC`) and takes `O` and `OS` from it on Plan 9 (plain
    `mk` there). `mkfiles/units.sh` is `units.rc`, with `dirs.rc`
    (rc scripts under mkfiles/ end in .rc, the author: "to
    differentiate them clearly from mkfile components"). Two rules of
    Plan 9's mk and rc met: a backquote ends at its first `}` (no
    braces inside: `if(...) x; if not y`), and `=` in an argument is
    quoted (`$MK 'O='$O`). Still sh's (`MKSHELL=sh` in them): the
    oberon, singularity, squeak and xv6 kernels. (This corrects the
    above: on Linux sh ran the recipes, not mini-rc.)
  - **Checked**: the whole Plan 9 build on Linux by rc's recipes, in a
    copy of the tree, against sh's: the same 1,306 files, the same
    bytes but the 20 libraries' `dirs` (each copy's path); make
    test-lite, 69 jobs, 0 failures; xv6fs.sh.
  - **`make card-self`**: a card of 1 GB with `/src/ix` (`/src` since,
    below; the
    repository but docs/: 4,894 files), the whole toolchain, and room
    for a build (346 MB on Linux for mini-9pi's programs); the
    everyday card stays 128 MB.
  - **Stage 3, its first half**: on that card, the Pi 2 under QEMU,
    `mk` in /src/ix/lib_core (69 units, the C runtime, the C library)
    then in utilities/misc (eleven programs): mini-echo made there is
    `/bin/echo`'s bytes (`cmp`), and runs. lib_core 771 s, misc 311
    s; on Linux 4.95 s each, one job at a time: 156 and 63 times
    (misc is mostly links). One core: `NPROC` was 1, the Pi 2's kernel
    runs its other cores under an emulator only when built `SMP=1`
    (check-cores' image).
  - **Four cores, measured** (lib_core by `mk` on the card, the Pi 2
    under QEMU): the normal kernel, one job, 771 s; the SMP kernel
    (`SMP=1`, check-cores'), one job, 1,160 s; the SMP kernel, four
    jobs, 1,315 s (each compile 27 s where it is 6 s alone, about 2.6
    at a time). The SMP kernel costs 1.5 times under QEMU by itself
    (QEMU's cores as threads: their exclusive loads and stores,
    barriers, TLB flushes across them), and four jobs do not overlap:
    a build here is mostly in the kernel, under its one lock (the
    card read word by word, Kfs, the faults). More cores pay once
    less of it is under the lock: plan_multicore.md's finer locks, or
    less kernel time a build (the profile).
  - **The whole build on one core** (74 directories by `mk`, their
    `time` lines the profile: `mk 'ML=time ml -m 5' ...`): 4 h 52 min
    the first (2026-10-21), its times 0.00r for 71 minutes (the
    kernel's clock stopped: a timer compare written already past,
    bugs/ix.md, fixed in timer_arm); 2 h 59 min with the speedups
    below, 1.6 times less where both were timed (13,088 s to 8,116),
    the libraries 2.3. On Linux the same build, four jobs: 2 min.
    Three directories failed in both: games twice (`mkdir -p` in
    parallel jobs, each making the same parent: fixed in mini-mkdir),
    browsers/netscape (mini-ld out of memory: the link takes 540 MB
    as an arm32 Linux program, a half of mini-ml's heap is 192 MB on
    Plan 9). The 1,269 files made against Linux's from the card's
    `/src`: the same bytes but the 20 libraries' `dirs` (each tree's
    path) and 5 of libc's objects, mini-cc built by mini-ml sharing
    other blocks than built by OCaml (fixed: objects marshalled
    without sharing, bugs/ix.md). Not yet run again on the card.
  - **Where a compile's time goes** (the Pi's PC sampled by QEMU's gdb
    stub, mini-ml on Pervasives: 0.07 s on Linux, 7.0 s on the card):
    the SD card's driver 40% (Kfs's cache of 2 MB, all forgotten when
    full, smaller than mini-ml's 2.7 MB: each compile read it from the
    card again, word by word), mini-ml 40% (its collector a quarter of
    it), the rest of the kernel 20%. Not QEMU, not exec (0.12 s). Done:
    Kfs's cache 32 MB (5.1 s); what a call writes kept, written by 1 MB
    or each second by a kernel process (4.3 s); mini-ml's first heap 4
    MB on Plan 9 (4.05 s); mini-ar's members their source and names
    beside their bytes (ar t reads no object, ar u keeps the others':
    lib_core.a 49 s on the card); mklib's and mkprog's recipes without
    their mkdir and an ls a directory (up to ten processes a unit, mk's
    own part a fifth of a library's time). Not done: pages filled from
    the file still zeroed first (under 1%); text pages shared between
    execs of a program (Plan 9's image cache), to decide on the next
    profile.
  - **The time to expect**: the Plan 9 build on Linux is 40 s for the
    libraries and 173 s for the programs, one job at a time; 50 to
    300 times that is 3 to 4 hours on one emulated core. The levers:
    the Pi 2's four cores (QEMU's -smp, mini-qemu's domains), the
    card's I/O, a profile of the first whole build (the author: "we
    can also profile and see where the time is spent").
- 2026-10-09: this plan, with the tools tried for Plan 9
(above); `/src` on the card with `hello.ml`, `hellodraw.ml`,
`hellorio.ml`, `hello.c` and `hello.s` (`kernels/9pi/Makefile`:
`CARD_SRC`), texts for mini-emacs.
