# Plan: t-IX building itself in 5 minutes instead of 50 (`tiny/TinyMachine/`, `tiny/TinyKernel/`, `tiny/TinyC/`, `tiny/TinyML/`, `tiny/runtime/`)

The author (2026-11-13): "in tiny/, doing make run, and then cd /src;
build will build t-ix under t-ix, but it is really slow. I think it's
50min at least on this macOS. Any thing we can do to significantly
improve the speed? For instance we can build all of t-ix using dune
and ocaml in a few seconds, so it's sad to require 50min when run
under t-ix"; then, after the analysis: "I think if we reach 5min
instead of the current 50min would be a good result for this plan".

**Status: steps 0 to 3 done** (2026-11-15). The analysis below is
done, the baseline is measured (step 0), the long runs use a release
build of tiny-machine (step 1), names are looked up in place (step 2),
tiny-cc keeps variables in registers (step 3), and steps 4 to 6 have
not been started. make self went from 50 minutes to 28 after step 2.

## The problem

The same build, run on the host, takes 3.2 seconds. That is
tiny/Buildfile's `build -j 1 boot.img install` in a copy of tiny/, as
TinyKernel/Makefile runs it, with the tiny tools built natively by
OCaml (tiny-ml, tiny-cc, tiny-as, tiny-ld, tiny-ar and tiny-build).
The host's tools run the same code that tiny-kernel's tools run, and
they do the same work: 136 runs of ml take 1.55 s, 33 runs of ld take
0.89 s, and cc, as and ar together take 0.2 s. On tiny-kernel, in
/src, the same build takes about 50 minutes (49 at be2f0aa8, the last
make self timed).

**t-IX building itself is about 1000 times slower than the same tools
building the same files on the host. That is insane.** An emulator
costs a factor, and a simple compiler costs another, but a factor of
1000 means that several costs multiply, and that each one is larger
than it needs to be.

**The goal is 5 minutes for make self's first build on this Mac, ten
times faster than today.** The host's 3 seconds are not the goal: to
get there tiny-machine would need a real JIT, which is not in t-IX's
spirit.

The author also wants the page to gain (2026-11-13): "ideally as we
speedup things here it would also benefit the speedup of t-ix.html and
running tiny-machine on the web quickly there too". So a step that
helps both the build and the page comes before a step that helps the
build alone. See [The page](#the-page-t-ixhtml) below.

## Where the time goes

Measured on 2026-11-13 on this Mac (macOS, arm64, 12 cores), with
tiny-machine's `-prof` read by tiny-prof, and the host's own counters
(`/usr/bin/time -l`, `sample`). There are two sessions. The first is
self-quick's (self-quick.keys: `build ping TinyLibCore/stdlib.a` in
/src). The second is `build ml` in /src, which compiles the standard
library and tiny-ml's units, then links ml. That session is the
closest to make self's work.

| | self-quick | build ml |
|---|---|---|
| the machine's instructions | 5.0 G | 15.9 G |
| in the kernel | 61% | 37% |
| the host's time (tiny-machine built in release, no -prof) | | 287 s, 55 M instructions a second |

The factor of 1000 is the product of three factors, each of which can
be reduced on its own.

### 1. tiny-machine: 330 to 420 of the host's instructions for each of the machine's

A short session (the boot, `seq 3000 | sort -rn | wc`, the halt) runs
547 M instructions of the machine. The host retires 230 G instructions
to run them, so tiny-machine spends about 420 of the host's
instructions on each instruction of the machine. A simple interpreter
written as a switch usually needs 20 to 40.

- tiny-cpu, which has the same CPU without the window, the pages or
  the devices, runs a loop of loads, stores and branches at 113 M
  instructions a second. tiny-machine runs 41 to 55 M a second. The
  difference is what each access pays: `env.fetch`, `env.load` and
  `env.store` are closures (`caml_apply2` and `caml_apply3` are high
  in the host's profile), and each fetch, load and store calls
  `translate`, then `check`, which tests the supervisor bit, relocate,
  split and the bound. Each word is also hashed again by
  `decode_kept`.
- dune's default profile (dev) compiles each library with `-opaque`,
  so nothing is inlined across libraries. TinyMachineDevices is a
  library of its own, and it calls TinyMachineCPU's `ult`, `addr`,
  `m32` and `load` as real functions: they show as functions of their
  own in the host's profile. tiny-machine built with `--profile
  release` ran the same session in 10.7 s instead of 13.3 s, 20%
  faster, without a line changed.

### 2. The kernel: from 37% to 61% of all the instructions, mostly in looking up names

The top of the kernel's profile is the same in both sessions:
`ml_string_concat` (16% to 19% of the kernel's instructions),
`k_string` (15% to 18%), `ml_alloc` (11% to 13%), then `len`, `go`,
`rev`, `find`, `exists` and `ml_string_sub`. Nearly all of it comes
from one function. `KFS.fs_lookup` calls `fs_entries`, which reads the
whole directory into one string: `fs_contents` copies each block with
`k_string`, then joins the blocks with `String.concat`. It then cuts
every entry of 68 bytes into a name with `String.sub` (the loop `len`
alone is 5% to 6%), and finally searches the list with
`List.assoc_opt`. This happens for each name of each path that a
program opens or stats. /src has about 230 entries, so each lookup of
a name in it copies about 15 KB twice, byte by byte, and allocates 230
strings.

The kernel runs on core 0 only (KMachine.ml, the cores): every system
call of every core waits for it. This is why four cores in turns only
took make self from 190 minutes to 135 (2d6aa9ef). Until the kernel is
cheaper, more cores cannot help much.

### 3. The code that the tools run: most of it is the runtime's C, compiled by tiny-cc

In `build ml`, about 70% of the programs' instructions are in the
runtime, which is C compiled by tiny-cc, and not in the ML code of the
tools:

| function | share of the programs' instructions |
|---|---|
| `ml_alloc` | 14.6% |
| `sha_block` (tiny-build's digests) | 11.0% |
| the collector (`copy`, `collect`, `wosize`) | 13.1% |
| `compare` | 4.8% |
| strings: `ml_string_sub`, `u_read`, `ml_string_concat`, `ml_concat`, `ml_bytes_blit_string`, `length` | about 17% |

tiny-cc keeps every local variable in memory. A `for` loop that copies
bytes is compiled to 32 instructions for each byte, where a loop that
copies words, such as kcopy.s's `k_copy`, needs about 1.5. The
kernel's copies (`k_string`, `k_blit`) and the runtime's (`u_read`,
string concatenation) are such loops, and so is every primitive above.

tiny-ml's own code costs less, but it has the same kind of waste:
about a third of what it writes is a load or a store of a slot of the
value stack (3,315 of the 9,827 instructions of TinyML/Types.ml). Each
function also clears all its slots on entry, and a test such as `match
l with [] ->` makes a boolean (`sub`, `sltiu`, `shli`, `ori`), then
compares it with 1. Each cons, tuple and closure is a call to the C
function `ml_alloc`, and every collection copies all the live data,
since there is no young generation.

## The steps

They are in order of cost, the cheapest first. Each one is a general
cause, fixed where it is (tiny-machine, the kernel, tiny-cc, tiny-ml,
the runtime), never a rewrite of one hot function in assembly. The
gains are estimates read from the profiles, except step 1's, which was
measured. Gains that come from different layers multiply, so the
estimates multiply too, but each step is measured again on the tree it
lands on.

| # | Step | Estimated gain | Cost | The page gains |
|---|---|---|---|---|
| 0 | The baseline: make self timed, and profiled | none | an hour of the machine | (its baseline too) |
| 1 | tiny-machine built without `-opaque` (done) | 1.27 (measured) | minutes | no: native only |
| 2 | Looking a name up without building the directory's strings (done) | 1.43 (measured) | small | yes: fewer instructions |
| 3 | tiny-cc keeping scalar locals in registers (done) | 1.49 on self-quick (measured) | medium | yes: fewer instructions |
| 4 | tiny-ml allocating inline (done) | 1.10 on self-quick (measured) | small to medium | yes: fewer instructions |
| 5 | tiny-machine's fast path, one look for each batch | 2 to 3 | medium | yes: a faster interpreter |
| 6 | Several cores by default, on OCaml 5's domains | 2 to 3, after step 2 | small | no: no domains in a page |

Steps 1 to 5 together make an estimated factor of 6 to 15, which takes
50 minutes to between 3 and 8. Step 6 is what should make the 5
minutes certain.

### Step 0: the baseline

Run make self once, timed, with tiny-machine as it is today, then
again with `-prof`, and split the profile by phase (the compilations,
the links, tiny-build's digests, the installation). Record the numbers
in this plan and in notes_tiny_opti_inventory.md. Run
tiny/tests/TinyMachine_bench.sh too, natively and under node, as the
page's baseline. The numbers above come
from two smaller sessions, and the links (33 runs of ld, 30% of the
host's time) are not in them.

Done on 2026-11-14, at c45e5910, with bin/tiny-machine as make builds
it (dune's dev profile). Two sessions ran side by side on fresh copies
of make self's disks, with make self's `-date` and `-seed`. A was make
self's own session, timed; B was only the first build (`build -t all
boot.img` in /src), under `-prof`. Both ran `build -t`, so each recipe's
time is in the log.

- **The time: 50 minutes 24 seconds** (A, 3024 s of the host), for
  make self's whole session: the boot, the first build, `build
  install`, and the three builds after a change (a comment in
  TinyLibRegex.ml, a line in calc.ml, nothing). The first build is
  most of it, but it was not timed alone without `-prof`. B, only the
  first build, took 85 minutes with `-prof`. Both made the host's boot image byte for
  byte, and A's 121 installed files are the host's (FSCAT and cmp, as
  make self checks them).
- **The instructions: 100.8 G** (B's profile), 41% of them in the kernel
  and 59% in the programs. If the first build were all of A's time, that
  would be 33 M instructions of the machine for each second of the host.
  It is somewhat more, but still less than build ml's 55 M, because
  this binary is the dev profile's (step 1).
- **The phases**, by A's `-t` and the machine's clock (about 8 M
  instructions for each second of that clock, so the totals are larger
  than the host's seconds; B's split differs from A's by up to a
  fifth, and a few short recipes show 0 ms, so these shares are good
  to about a tenth):

  | phase | share |
  |---|---|
  | the compilations of the units (`*.o`, 54 + 33 recipes) | 36% |
  | the links of the programs (ml's `.start.o`, then ld) | 30% |
  | the kernel's build in TinyKernel/ (its units and its link) | 13% |
  | tiny-build's own work outside the recipes (the digests, the stats) | 13% |
  | the standard library, boot.img, and the rest | 8% |

  So the links are as large a part on tiny-kernel as on the host. ml
  alone (467 s of the machine's clock) and the kernel (1490 s) are the
  largest targets.
- **The profile** is the same as the smaller sessions'. In the kernel:
  `ml_string_concat` 7.8% of all the instructions, `k_string` 7.4%,
  `ml_alloc` 5.0%, `len` 2.5%, `go` 1.9%, `ml_string_sub` 1.6%, then
  `runnable`, `rev` and `find`, about 1.2% each: fs_lookup's work is
  about a quarter of the whole build (step 2). In the programs, by the
  runtime's symbols (which are at the same addresses in every program):
  `ml_alloc` 7.1%, `compare` 2.1%, `ml_string_concat` 2.1%,
  `ml_string_sub` 1.9%, `u_read` 1.8%, `copy` 1.8%, `length` 1.1%,
  `sha_block` 1.1%, `collect` 1.0%, and a long tail.

The page's baseline (tests/TinyMachine_bench.sh, the same day) is in
[The page](#the-page-t-ixhtml).

### Step 1: tiny-machine compiled for speed

Build tiny-machine as mini-pi already builds mini-qemu (`dune build
--profile release`, mini-pi line 311), or find a way for the dev
profile not to make TinyMachineCPU opaque to TinyMachineDevices.
TinyKernel/Makefile takes tiny-machine from bin/, so the question is
which binary bin/ gets.

Done on 2026-11-14, the author's choice: dune's dev profile stays the
default, for its quick rebuilds after an edit, and only the long runs
use a release build. TinyKernel/Makefile builds it with `dune build
--profile release --build-dir _build_release`, in a build directory of
its own, so that dune build and these runs do not rebuild everything
each time the profile changes. make run, run-window, self, self-quick
and self-cores use it. make check keeps bin/'s, the binary everyone
uses, and a MACHINE given on the command line still wins.

Measured on step 0's images (c45e5910), self-quick's session one run
after the other: 108.6 s with the dev build, 85.5 s with the release
build, 21% less time (1.27 times faster), both with the host's files.
So make self should go from about 50 minutes to about 40.

### Step 2: names looked up in place

`fs_lookup` should read the directory a block at a time and compare
the name in the block's buffer, without making a string for each
entry, and stop at the first match. `fs_entries` stays for what needs
all the entries (`ls`, `fs_unlink`). If that is still too slow, the
kernel can keep a small cache from a directory and a name to an inode,
forgotten at each change of the directory, as Unix's namei cache does.
This step also frees core 0 for step 6.

Done on 2026-11-14: `fs_lookup` reads the directory's blocks one at a
time into a buffer and compares the name byte by byte there (an entry
can straddle two blocks), up to the first match. Its comment keeps the
old one-line version, `List.assoc_opt name (fs_entries fs r d)`, under
`old:`. The cache was not needed. Measured with the release
tiny-machine, before and after side by side on images of the same
tree, each with the host's image and files:

| | before | after | |
|---|---|---|---|
| self-quick | 85.5 s | 60.1 s | 1.42 times faster |
| make self's session | 40 min 22 s | 28 min 11 s | 1.43 times faster |
| the first build's instructions | 100.8 G | 82.4 G | 1.22 times fewer |
| the kernel's share | 41% | 27% | |

`ml_string_concat` and `k_string`, 15% of all the instructions, are
gone from the top. The time fell more than the instructions did,
probably because those copies were all loads and stores, which cost
tiny-machine the most (translate and check at each access). What is
left at the top of the kernel is another cause: its `ml_alloc` (5.8%)
with `runnable`, `find`, `rev` and `exists` (about 8% together), which
look like the scheduler building lists at each switch. It is not in
this plan yet; it is a candidate after step 3.

### Step 3: tiny-cc's locals in registers

A local whose address is never taken, of a scalar type (int, char, a
pointer), can live in a register instead of in the frame. TinyC
already has a stack machine kept in registers, so the change is a
simple allocation for those locals, spilled around the calls, without
a full register allocator. Every loop of the runtime and of the
kernel's C is faster with it: the copies, `sha_block`, `compare`, the
collector. A word-at-a-time copy (a memcpy in the C library, used by
the runtime's string functions) is a second, smaller change, and it
only makes sense if the first one leaves the copies at the top of the
profile.

Done on 2026-11-14 and 15, in two commits. TinyC/Machine.ml's comment
at its top follows a loop that copies bytes through the stages, from 31
instructions an iteration to 11:

1. Lower finds the variables of 1 or 4 bytes whose address is never
   taken, weighs them by their uses (8 times more in each loop), and
   reads and writes them by Get and Set. Machine runs a function twice:
   the first run, with every variable in memory, tells how deep the
   stack goes, and the second gives the registers above that depth,
   up to r12, to the heaviest variables, saved around each call. The
   loop takes 23 instructions.
2. A slot of the stack can have its value in a variable's register or
   be a constant not loaded yet, so that an instruction reads the
   variable's register directly and takes a constant as its immediate.
   A value dropped is not computed (x++ as a statement), and an
   instruction writes a variable's register directly. 11 instructions.

Measured on self-quick, with the release tiny-machine, side by side on
images of the same tree, each with the host's files:

| | self-quick | |
|---|---|---|
| step 2 | 59.2 s | |
| 1, the variables in registers | 52.4 s | 1.13 times faster |
| 2, operands in place, immediates | 39.8 s | 1.30 times faster |
| step 3 | | 1.49 times faster |

make self's session, the same way: 28 min 11 s to 19 min 21 s (1.46
times faster; 2.6 times since step 0's 50 min 24 s), the host's image.
The first build, by -prof: 82.4 G instructions to 56.9 G, the kernel
28%. At the top now: `ml_alloc`, 14% of all the instructions (9.4% in
the programs, 4.5% in the kernel), which is step 4; the kernel's
scheduler lists (`runnable`, `go`, `find`, `rev`, `exists`), about
9.5%; then `compare` 2.5%, the collector (`copy`, `collect`, `wosize`)
about 3%, and the strings (`u_read`, `ml_string_concat`,
`ml_string_sub`) about 4%.

The fuzzer (TinyC_fuzz.py, 200 programs against the host's cc), make
test and make self-quick-tix pass. The word-at-a-time copy is left for
after step 4, with the other routines that a profile may still show at
its top; the author suggested writing a few of them in assembly then.

### Step 4: tiny-ml's allocation inline

This is the exercise already listed in TinyML.mli: keep the heap's
pointer and its limit where the code can reach them, allocate a block
with a few instructions, and call the collector only when the block
does not fit. The value stack's slots stay as they are (the collector
still finds every root there). The same step can make a test of a
constructor a branch on the word, without making a boolean first.
Whether the collector needs a larger first heap (fewer collections,
each one copying the same live data) is measured here.

Done on 2026-11-15, for the allocation. The runtime's heap pointer and
limit are the first two words of `ml_heap` (ml.c), with the two
stacks' limits after them (none: the highest address for the value
stack, 0 for the machine stack). TinyML/Machine.ml's `alloc` checks
the two stacks and the room for the block, moves the heap pointer and
writes the header itself, about 16 instructions, and the fields are
stored from the stack's registers. Only a stack past its limit or a
block that does not fit calls `ml_alloc`, which reports the overflow
or collects, as before. Its old version is kept as `alloc_c`, which a
block of more than 1000 fields still uses. A deep recursion that
allocates on its way down still ends in "Fatal error: stack overflow
(the value stack)", the same as before.

| | self-quick | instructions |
|---|---|---|
| step 3 | 39.3 s | 2.21 G |
| step 4 | 35.8 s | 2.00 G |
| | 1.10 times faster | |

`ml_alloc` was about 9% of self-quick's instructions and is gone from
the top of its profile. The test of a constructor and the first heap's
size are not done.

### Step 5: tiny-machine's fast path

Within one batch of `ticks`, nothing can change the mode or the
window: a change is a trap, an `eret` or a write of a register of
control, and each of these ends the batch. So the batch can compute
the window's base and bound once, and use a step that loads, stores
and fetches with them directly, without the closures of `env` and
without calling `translate` on each access. The slow path stays for
the pages, the devices and the first tick of a batch. The goal is that
tiny-machine runs about as fast as tiny-cpu does (113 M instructions a
second) or faster.

### Step 6: several cores by default

make self-cores already runs `build -j 4` on `tiny-machine -cores 4`,
and with `-cores-parallel` each core runs on an OCaml 5 domain
(`_build5`; OCaml 5.5.1 is installed here). Once step 2 has made the
kernel cheap, make the parallel setup what make self (and make run)
use when OCaml 5 is there, and measure it with 4 and 8 cores.

## The page (t-ix.html)

The page runs the same tiny-machine (TinyMachineDevices and
TinyMachineCPU) compiled by js_of_ocaml (TinyMachineWeb.ml), and the
same boot image. Two kinds of speed matter there, and the steps reach
them in two ways.

- **The machine needs fewer instructions** (steps 2, 3 and 4). The
  page runs the machine at a fixed rate, `TinyMachineDevices.rate`, 8
  million instructions a second. Every program then finishes sooner
  at the same rate: a directory listed, a file opened, a page of the
  browser read, a program built in /examples, a collection of the
  heap. These steps change the kernel, the runtime and the programs,
  which every host runs, so the page gains exactly what the build
  gains, with nothing to do for the page.
- **The host runs each instruction faster** (step 5). Under node,
  tiny-machine ran 8.1 million instructions a second in October
  (notes_tiny_opti_inventory.md, T1 and T3), before `wfi` (T12). Step
  0's bench gives the rates below, in the machine's instructions a
  second, which include the time the machine slept in a `wfi` (free for
  the host). So the sessions that compute, office and tetris, are the
  ones that matter:

  | session | native | node |
  |---|---|---|
  | paint | 113.8 M | 29.8 M |
  | emacs | 171.7 M | 49.8 M |
  | windows | 124.4 M | 39.7 M |
  | office | 87.3 M | 27.4 M |
  | tetris | 59.2 M | 19.6 M |

  Node is about 3 times slower than native, and its worst session,
  tetris, still has room above the page's 8. A slower browser or a busy
  frame falls behind, and the page then shows "Running at N% of full
  speed". Step 5's fast path is in TinyMachineDevices and
  TinyMachineCPU, which the page shares, so it gives the page more
  room. With tetris near 20 M under node, the page's rate could perhaps
  already be raised to the window's 20, and step 5 would make that
  safe on slower browsers. That is the change a visitor would see
  most.

Steps 1 and 6 are native only. js_of_ocaml compiles the bytecode of the
whole program at once and does its own inlining, so `-opaque` does not
apply to it (step 1). A page has no OCaml domains, and running the
cores in web workers would be a project of its own (step 6). This is
why steps 2 to 5 come first: they help both the build and the page.

Step 5 is measured on both hosts with `tiny/tests/TinyMachine_bench.sh`,
which runs a recorded session natively and under node, and checks that
the screen at the halt is the recorded one. A change of step 5 that
makes the native machine faster but node slower (an OCaml idiom that
js_of_ocaml compiles badly, such as `Int32` or a closure made at each
step, T2's lesson) is not kept as it is.

## The gate

Each step is kept only if all of these pass:

1. **The image is the same**: make self's image is the host's, byte
   for byte, and so is each file that build install puts on the disk.
   This is what proves that tiny-kernel's tools are still right.
2. **make test** and **make self-quick-tix** pass, and so does
   TinyKernel's make check: the recorded sessions' screens and sounds
   do not change (for step 5 especially, since an interrupt must still
   be taken at the same instruction).
3. **The time is measured**: make self timed before and after on this
   Mac, and the step's row added to notes_tiny_opti_inventory.md, with
   its gain and its lines. A step that changes tiny-machine (1 and 5)
   is also measured by TinyMachine_bench.sh, natively and under node,
   and it must not make the page slower.
4. **The code stays readable**: a fast path that doubles a piece of
   code is kept only if its gain is large. The rule of
   [t-IX's inventory of optimizations](../notes/notes_tiny_opti_inventory.md)
   holds: a gain that is not measured is not kept.

## Not in this plan

- A JIT for tiny-machine (the machine's code translated into the
  host's). It is the only way to get close to the host's few seconds,
  and m-IX has one for mini-5i, but it is a large piece of code for a
  tiny machine, and 5 minutes do not need it.
- Making the build do less: tiny-build hashing fewer files, or ld
  linking stdlib.a fewer times. Those are possible, but the goal is to
  make the same work cheaper, so that every program on tiny-kernel
  gains, not only the build.
- A general optimizer for tiny-ml (keeping values in registers across
  a function). Step 4 takes the cheap part of it. The rest can come
  later if the value stack's traffic is at the top of the profile once
  steps 2 to 5 are done.
