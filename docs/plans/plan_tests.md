# Plan: one fast test before each commit, the rest by tiers (`tests/`, the top `Makefile`, `.github/workflows/`)

The author (2026-10-26): "we currently don't have a fast and reliable
way to test for regressions; the different tests (test-speed,
test-all, test-lite, self-quick, etc.) are slow, often broken, and
spread in different Makefiles. We need to reorganize a bit things so
it's clearer what tests to run before a commit so we break less CI.",
then "ideally each time we modify some code we can run a test command
and have good confidence it would catch regression and ideally would
take less than a min, 2min max", "actually GHA CI is currently
broken, and looking at the history has been broken many times across
the commits", "another thing might be to separate tests for m-ix and
t-ix, so we could even run those in parallel, and get them clearly
separated", and "one big issue is that the build t-ix under t-ix, or
m-ix under m-ix, which long term are what we want, is too slow right
now, but ultimately that's one of the most important thing we want to
check regressions for".

The short answer: **`make test-lite` is the gate, made to deserve
it**: a budget of 2 minutes it checks itself, OCaml 5.5 in it, its
jobs in three groups (shared, m-ix, t-ix) said apart, a check of each
system building itself small enough to fit, and the rest of the tests
in tiers that say when they run. Not a new test runner.

## The survey (2026-10-26)

### What CI said

`.github/workflows/docker.yml` has two jobs: `build`, `make test-lite`
in Docker with OCaml 4.14.2 and 5.5.1, and `test-all`, `make test-all`
on an arm64 runner (half an hour). Over the runs of 2026-10-23 to
2026-10-26 (`gh run list`):

- **`build (5.5.1)` failed in every run since 2026-10-23**:
  `games/fps/quake/game/Weapons.ml`, line 85: "Syntax error: end
  expected" (and Combat, Game, Monsters). `effect` is a keyword since
  OCaml 5.3; mini-quake (9e4941ba) has a function of that name. The
  sessions build with 4.14.2 only (the switch installed and selected);
  a 5.5.1 switch is installed and nothing runs it but CI. Other files
  have the word (Tetris, lib_playground's Audio, Gui7Cells,
  Arm32_isa): to look at once quake is fixed.
- **The matrix stops at the first failure**: when 5.5.1 fails, 4.14.2
  is cancelled, and whether it passed is not known.
- **test-all's `make test` fails on `tiny/TinyKernel`'s
  `_make/check/tetris.wav.sum`** (other sounds than recorded). The
  TinyKernel check is in `make test`, not in test-lite: nothing a
  session runs before a commit boots tiny-kernel.
- **Once, `mini-ml compiles games` failed in CI** (run 39938822935)
  and not in the session that committed. Likely the shared checkout:
  sessions commit by pathspec (commit-by-pathspec), and test-lite ran
  on a working tree that had another session's files; 4073913c is the
  same mistake, seen and repaired.

### The targets

| target | what | time | who runs it |
|---|---|---|---|
| `make test` | each program's tests, one after the other | ~4 min | test-all |
| `make test-lite` | the gate, 66 jobs on the cores | ~1-2 min | sessions, CI |
| `make test-quick` | test-all's suites of a few minutes | ~15 min | nobody |
| `make test-all` | every suite, `tests/all.sh` | ~30 min | CI |
| `make test-ix`, `-fixpoint`, `-arm`... | ix built by ix | 2-6 min each | test-all |
| `make test-goken`, `-ocaml`, `-pi`... | against references | minutes | the author |
| `make self-quick` | t-ix and m-ix in themselves, a part | ~5 min | by hand |
| `make self` | the same, everything | hours | by hand |

test-lite measured (2026-10-26, the load 27 on 64 cores, other
sessions building): **402 s**, not "under a minute". Two jobs make it:
"ix built by ix, a kernel booted" 397 s and "games, mini-drscheme,
examples, mini-office: recorded frames" 399 s; then "tiny: cpu, c, ml,
machine, graphics, pi" 125 s, "mini-ml compiles games" 86 s and
"lib_core" 80 s; the 65 others under 35 s.

`make test` and test-lite mostly overlap; what is in `make test` alone
(the TinyKernel check, the long random counts) is found by CI only.
`tiny/TinyKernel/Makefile` and `kernels/9pi/Makefile` have their own
`check`, `self` and `self-quick`.

### The display

test-lite prints a line per job as it ends, in the order they end:
m-ix's and t-ix's mixed. A job's name is at times a bundle whose
meaning is not in it: "tiny: shell, editor, db, vcs" is four test
scripts one after the other (tiny-shell against 9base's rc,
tiny-editor against sam -d, tiny-db against SQLite, tiny-vcs's laws on
random work), on the tiny programs built by dune; when it fails, which
one is in the log only.

### Building itself

The two systems building themselves are the goal, and the slowest to
check: `make self` hours, `self-quick` about 5 minutes
(plan_self_hosting.md: 4 min 46 s, both systems side by side; mini-ml
on Pervasives 0.07 s on Linux, 4 s on the emulated card). What a self
build can break is of two kinds:

1. **the build and its tools**: self.rc, the Buildfile, the mkfiles,
   mini-mk and tiny-build, mini-rc, the toolchain's bytes; the most
   frequent, and checkable on the host in seconds;
2. **the platform under it**: mini-ml's 32-bit arm code, the kernel's
   calls and file system, the emulator; checked only inside, but any
   compile there exercises most of it: one unit as well as all.

## The design

### Tiers

| tier | command | when | budget |
|---|---|---|---|
| gate | `make test` (`test-tix`, `test-mix`) | before every commit | 2 min |
| touched | `make self-quick` | the toolchain, kernels, emulators changed | 5 min |
| full | `make test-all` | CI, each push; by hand before a large change | 30 min |
| night | `make self` | each night, CI's schedule or the author's machine | hours |
| references | goken, ocaml-light, chidb, QEMU, speed | the author's machine | — |

`docs/testing.md` says this, in a page; the top Makefile's header and
the README point to it.

### The gate

- **Its budget checked**: `lite.sh` says when the whole took more than
  120 s or a job more than 60 s (on the author's machine: a warning in
  CI, whose runners are slower). A job past it goes to test-all, or is
  made shorter; the gate does not grow to 5 minutes by small steps.
- **OCaml 5.5 in it**: a job `opam exec --switch=5.5.1 -- dune build
  @check --build-dir _build5` (types only, incremental: seconds), when
  the switch is there; a skip line otherwise.
- **tiny-kernel booted in it**: the part of `tiny/TinyKernel`'s check
  that fits (a boot to the shell, a program run), the rest in test-all.
- **On what is committed**: `tests/lite.sh -index` tests the index in a
  private copy, not the working tree (not git stash: no-git-stash). If
  dune's build from nothing there is too slow (to measure: step 4), a
  cheaper guard instead: the files of the directories a commit touches
  that are modified and not committed, said before committing.
- **`make test` goes**: what is in it and not in test-lite goes to the
  gate (fast) or to test-all (slow); `test-quick` goes too.

### Three groups

Each job is in one of:

- **shared**: dune's build, OCaml 5.5, mini-ml compiles ix, lib_core,
  the generators; first;
- **m-ix**: the mini programs, ix built by ix, the kernels' step,
  mini-xv6 booted, mini-9pi;
- **t-ix**: `tiny/tests/*`, tiny-kernel booted, the tiny programs built
  by ix.

```
tests/lite.sh            # the three (make test-lite)
tests/lite.sh tix        # shared and t-ix
tests/lite.sh mix        # shared and m-ix
```

Run together they share the cores (test-lite already uses them all):
one group alone is what is faster, for a change in one system. A group
chosen by `git diff --name-only` is possible later, optional: a change
to lib_core breaks both in ways a rule on paths does not foresee. CI
runs the three.

### The display

A line per job as it ends, its group first, at a fixed width (`grep
'^\[t-ix\]'` keeps one), then a summary by group:

```
[shared] ok    12.3 s  dune build
[t-ix]   ok     1.8 s  tiny-shell: scripts against 9base's rc
[t-ix]   ok     2.4 s  tiny-db: random sessions against SQLite
[m-ix]   FAIL  31.0 s  mini-ml compiles games
...
== shared  9 ok                                      14 s
== t-ix   14 ok, 1 skipped                           41 s
== m-ix   41 ok, 1 FAIL (mini-ml compiles games)     74 s
test-lite: 66 jobs, 1 failure, 74 s
```

A job tests one program (or one library), named first, then what is
checked: "tiny: shell, editor, db, vcs" becomes four jobs. More jobs,
each short: the cores take them.

### Building itself, in the gate

- **The self build on the host**: the same self.rc and Buildfile run on
  Linux by ix's own mini-rc, mini-mk and tiny-build, each file
  compared with dune's. kernels/9pi's `tests/self.sh` does it as its
  second half; test-lite's "ix built by ix" is most of it for m-ix;
  for t-ix, tiny-build on TinyKernel's Buildfile, new.
- **A self smoke test in each system**: boot, one OCaml unit and one
  C file compiled, a small program linked and run, each `cmp`'d with
  the host's; under a minute, the two side by side. self-quick's first
  step. If the boot is most of it: a machine's state saved after the
  boot and started from (tiny-machine is ours).
- **What a commit touches says self-quick**: lite.sh prints "touches
  the toolchain (linker/): run make self-quick" for the paths of tier
  "touched".

And the full build faster, besides the gate:

- **a sample of units** compiled inside (large ones, floats, C and
  OCaml): a byte apart is the platform's fault, not a unit's;
- **only what changed** since the last full self build that passed (no
  help when the compiler changes: then everything did);
- **the systems and emulators faster**: plan_self_hosting.md's levers
  (the cores, Plan 9's shared text pages), plan_tiny_multicore.md's
  `-cores-parallel`;
- **its time kept**, as `tests/speed_history.txt`: a slower self build
  is a regression too.

### CI

- `fail-fast: false` in the matrix;
- test-all green once, then a short list of the known failures, each
  with why and its bug in `docs/plans/bugs/`: a red run is a new
  failure;
- `make self` (or self-quick first) each night by a scheduled
  workflow, if it fits GitHub's 6 hours and needs nothing outside the
  repository (mini-9pi's fonts are principia's: to check); the
  author's machine otherwise.

## The steps

1. **CI green**: `effect` renamed in mini-quake and wherever OCaml 5.5
   says; `fail-fast: false`; tetris.wav.sum looked at (fixed, or the
   recording made again if the sounds changed on purpose).
   Done: Edict's `effect` (the type and its function) now `burst`,
   Particles' `effect` now `run_effect` (R_RunParticleEffect); the
   rest of ix builds with 5.5.1 (but the js_of_ocaml pages, whose
   library the local switch lacks); `fail-fast: false`. tetris.wav:
   re-recorded by 19414457 already, test-all green since.
2. **OCaml 5.5 in the gate**, and tiny-kernel's boot.
   Done: lite.sh's "ix by OCaml 5.5.1, its types" (`dune build
   @check` in _build5 by the switch, js_of_ocaml installed in it: 3 s
   when built, a skip line without the switch or when dune's build is
   already 5's, as in CI's 5.5 image); "tiny-kernel: booted, mltests,
   a shell's files" (an image of its own, 1.6 s, in the job's
   directory, not TinyKernel's _make the sessions share; mltests' ALL
   OK, then a shell's file, pipe and wc, its lines and not its banner;
   12 s). TinyKernel's whole check: 81 s, 12 minutes of cores, too
   much for the gate. Seen on the way: its tetris.wav changes with
   what is on the disk image (another session's TinyBrowser split in
   the working tree: a byte shorter, the same bytes each run): a
   recording that moves with unrelated changes, not one for the gate;
   to make independent of the image (the events timed by the game's
   own clock?) or left to test-all.
3. **The groups, the display, the budget**: lite.sh's jobs in shared,
   m-ix, t-ix; a job a program; `lite.sh tix|mix`; the summary by
   group; the warnings past 60 and 120 s.
   Done: the two jobs of 400 s were games/tests/audio.sh's comparison
   with ~/playground's own games (ix's sessions 0 to 3 s each, the
   playground's TinyVirtuaRacing 235 s; "ix built by ix" ran it too on
   its build): test-lite sets PLAYGROUND=/nonexistent (audio.sh 273 s
   to 5 s, frames.sh 41 to 35), and test-all's new suite playground
   runs them against it where it is built. The groups: `group` before
   the jobs, `tests/lite.sh mix|tix` (shared always: OCaml 5's types,
   the sources as text, lib_core by mini-ml; each "mini-ml compiles"
   in its directory's group; mini-ml's programs, libc and -pp m-ix's;
   ix built by ix m-ix's, the tiny programs it builds tested in it).
   The bundles split, a job a program: 98 jobs where 72. The lines
   tagged, a line a group at the end, the jobs past the budget said.
   Measured (load 1): **165 s** where 417 (shared 16 s, t-ix 74 s,
   m-ix 165 s); `tix` alone 75 s. Past the budget still: ix built by
   ix 160 s, mini-ml compiles games 72 s and lib_compression's group
   65 s, tiny-ml's programs 70 s: next.
   Then: "ix built by ix" a build job (94 s) and 21 jobs of checks,
   each waiting for the build (`job -after-ix`, its clock started then;
   a skip if the build failed); games/tests/frames.sh's sessions 16 at
   a time (J), their lines in the list's order (dune's 35 s to 6.5 s,
   ix's 70 s to 13 s; examples' and office's 9 s to 1 s; RECORD=1 the
   same list). Waiting for another session's run took longer than a
   run: ix built in the run's own directory ($W/mk/7, 258 MB, removed
   when it passes), no wait; lite.sh in braces, read whole before it
   runs (sessions edit it while others run it). Two runs at once found
   networking/tests/tls.sh's ports: two scripts on the same port, a
   server of the other run answering (another certificate): a port
   taken only when no one listens there, and its own server checked
   alive. Measured: **115 s** and 113 s, 119 jobs, another session's
   run at the same time (load 25). `make test-tix` 70 s.
4. **Measured**: the self build on the host for each system; a self
   smoke test inside each; dune's build from nothing in a private copy
   (for `-index`). What fits goes in the gate.
   Done for t-ix: TinyKernel's self-quick 167 s on one core (bin/ping
   48 s: all of libc.c; lib/Stdlib.o 80 s: the library's 17 units, one
   Buildfile recipe), so the gate calls the tools directly: lite.sh's
   "t-ix built in tiny-kernel: cc, as, ml, ld, a part", on a disk of its
   own, ping.c by cc and as (its .tm and .o the host's, read from the
   disk by TinyKernelFS_tests' Cat), Stdlib.ml by ml -c and as (the
   host's /lib/ml/Stdlib.o and .tmi), a C program without libc linked
   by ld and run (status 42); 24 s alone, 32 s in make test (120 jobs,
   0 failures, 123 s). The Buildfile itself is not run there
   (self-quick and self do). For m-ix: self-quick needs make
   card-self (mini-9pi by ix and a card of 1 GB with ix's sources, in
   kernels/9pi/build/, the sessions'), principia and QEMU; to decide.
5. **`make test` and `test-quick` gone**, their jobs placed;
   Done in part: `make test` is the gate (`test: test-lite`, the author:
   "have make test, run by default this lite.sh", "the default make
   test is the one we should use for most cases"); the old list is
   `make test-long`, test-all's suite long, its jobs still to place;
   `make test-tix`, `make test-mix`; the README says so. Left:
   `docs/testing.md`; the Makefile's header, the README.
6. **The commit's own files tested** (`-index`) or the guard instead,
   by step 4's numbers.
7. **The night**: `make self`'s time kept, a scheduled run.

## To decide

- the gate's name: `test-lite` kept (fewer renames: memories, docs,
  CI), or `make check`;
- whether the gate warns or fails past its budget (warns, to start);
- where the night runs: GitHub (what `make self` needs from outside the
  repository) or the author's machine.
