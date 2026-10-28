# Plan: mini-ml's code faster after the floats: calls, tags, loops

The author (2026-10-26), while another session unboxes the floats
([`plan_ml_floats.md`](plan_ml_floats.md)): "What are other big opti
worth adding to mini-ml to improve the speed of games and apps?", then
of the report's seven items, in its order: "excellent plan! I like it.
Let's start". The candidates are
[`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md)'s
left (D, J, K, L) and
[`plan_playground_speed.md`](plan_playground_speed.md)'s (M2, M6),
with what the profiles of today add. Its principles are that plan's:
measured first, the simple path kept beside, lines the budget, every
test with the pass on.

## The items, in order

| | what | aims at |
|---|---|---|
| 1 | **Calls**: the curry functions of more than 7 arguments shared (1a); a small known function inlined in its unit (1b); a function of another unit called directly, and inlined (1c) | 10 to 12% of a frame is the entry and exit of small functions; 7% of mini-doom's the curry functions of 8 and 10 |
| 2 | **Integers untagged in ssa/**, as Unbox does the floats: a word without its tag inside a function, tagged where it leaves | mini-doom's span and column loops, twice OCaml's, "mostly tags" |
| 3 | **ssa/'s classic passes**: constants folded, a computation made twice made once, a loop's invariants out of it | the reloads of globals and fields at each turn (arm's 6 registers) |
| 4 | **An index known in bounds** not checked (K) | lib_crypto's, the pixels' loops |
| 5 | **`int32` and `int64` not boxed** (L), and `Bytes.get_int32_le` / `set_int32_le` one load or store (M2) | sha256, a pixel's four bytes, the samples |
| 6 | After plan_ml_floats.md: **float-only records flat**, the doubles passed in registers to a known function, Unbox in a function with a handler | the 3D games' records |
| 7 | **A large block not copied** by the collector (M6) | a framebuffer, the meshes |

## Where the time goes (2026-10-26, HEAD 83189f2a)

Arm, mini-5i, -O3, a copy of HEAD built by `mini-mk O=5`
(`tests/macro.sh`, `games/frame_count.sh`, `tests/bench.sh 5`):

| | instructions |
|---|---:|
| mini-doom, a frame (31 to 61) | 13,997,421 |
| mini-quake, a frame | 29,129,434 |
| cameltry, a frame | 1,101,196 |
| mini-virtuaracing, a frame (3 to 23) | 110,956,694 |
| mini-ml compiling Lower.ml, Typing.ml, Ssa_build.ml | 7,115,792,935 |
| bench: pixels, limbs, samples, floats | 31.91, 15.70, 10.96, 12.62 million |
| bench: fib, tak, maps, sched | 3.39, 1.89, 13.16, 14.08 million |

`mini-prof` now prints each function's calls (its first instruction's
count) and its instructions a call. A frame's 30, by `mini-5i -prof`:

- **mini-doom**: 114 thousand calls of ML functions a frame. Those of
  fewer than 60 instructions a call are 19% of the frame (`View.norm`
  52, `fine` 35, `ifloor` 26, `fsin`, `fcos`, `sign_bit`), and their
  entry and exit about 15 instructions of it (the link saved, the
  parameters stored in the frame then loaded back, the slots zeroed).
  **The curry functions of 8 and 10 arguments: 7.1%**: `draw_column`
  and another have more parameters than the 7 whose curry functions
  are shared, and are called from another unit, so one argument at a
  time, a closure each. Then the floats (`ml_floor`, its block,
  `Float.min`'s `Int64`): plan_ml_floats.md's.
- **mini-quake**: 192 thousand calls a frame, small ones 12% (`clamp`
  19 instructions, 572 thousand calls; `dot` 45); `ml_modify` 3.7%,
  the collector's `copy` 3.3%.
- **mini-virtuaracing**: `floor` and `ceil` by C and their float's
  block about 20%, `Float.min` and `max` 10%: plan_ml_floats.md's
  (another session's, at work on them); `first`, 40 instructions,
  1.46 million calls in 10 frames.
- **mini-ml compiling**: the collector 24% (`copy` 15.6,
  `scan_copies` 8.4), `cmp` 5.7%; small functions 14%.

## Stage 1: calls

1a. **The curry functions shared up to 16 arguments** (`Lower.shared_most`,
7 before: the most whose block the stack machine builds in arm's 8
registers; past that the block is made as a big one, `obj_block`).
Then `calls_whole` calls a 10-argument function of another unit with
all of them.

1b. **Inlining in the unit** (`Lower`, `-Oinline`, in -O3): a call of
a known function, not recursive, small (its tree under a size), with
all its arguments, is its body with the parameters bound to the
arguments' slots. A toplevel function's body names nothing but its
parameters, the globals and the primitives (a toplevel value is a
global for the definitions after it: Scope), so it may be copied
anywhere in the unit; a local function that captures variables only
where they are its function's slots, the same frame. The typing's
tables (`immediates`, `float_cmps`...) are by the text's place: the
copy is the same text, the same answers. Not a body with a handler
(ssa's Unbox leaves such a function boxed). Only with -ssa: Gen's
stack has arm's 8 registers, and a body copied into an expression is
deeper than the call was.

1c. **Across units** (decided: the second way, the summary beside the
object and a `.depend`, Status): a unit sees another's
.mli only, so it knows neither the code's label nor its arity nor its
body. Two ways:

- The arity by the .mli's type (its arrows), which both units read:
  the defining unit gives each `val` of n arrows an entry `M.f$n`, its
  code if its arity is n, else a few instructions that apply the
  closure. A direct call, no new file, no order between the units'
  builds; no body, so no inlining.
- A file of the unit's small functions (their trees), written beside
  its object, read by the units that name it. Inlining across units
  (mini-doom's `View.fine` from `Bsp`), but the mkfiles then build a
  unit after those it names, which they do not today (a unit depends
  on the sources only), and a stale file is wrong code.

## Status

2026-10-26: plan written, the measures above.

**Stage 1, first measures** (in a copy of HEAD; nothing in the shared
tree's compiler yet). A frame of 31 to 61, arm, mini-5i, each build
whole by `mini-mk O=5` with its MLOPT, the frames the same bytes as
HEAD's:

| | mini-doom | mini-quake | doom's size | quake's | mini-ml's | the build |
|---|---:|---:|---:|---:|---:|---:|
| HEAD | 13,997,421 | 29,129,434 | 1,795,790 | 1,875,622 | 2,419,286 | 38 s |
| 1a: curry functions to 16 | 13,123,552 | 26,894,839 | 1,828,558 | 1,912,486 | 2,481,070 | |
| and 1d: small frames | 12,954,351 | 26,095,535 | 1,803,982 | 1,887,910 | 2,468,830 | 40 s |
| and inlining in the unit, 8 nodes | 12,892,880 | 26,068,517 | 1,853,134 | 1,937,062 | 2,538,566 | |
| ..., 16 | 12,772,981 | 25,932,069 | 1,943,246 | 2,014,886 | 2,690,118 | |
| ..., 20 | 12,773,082 | 26,098,724 | 1,967,822 | 2,043,558 | 2,751,606 | |
| inlining across the units of a directory too, 16 | 12,497,146 | 25,753,966 | 1,946,726 | 2,018,526 | 2,694,430 | 45 s |
| ..., 24 | 12,069,038 | 25,137,497 | 2,020,478 | 2,145,582 | 2,817,446 | 47 s |

- **1a** (the curry functions shared to 16): 0.94 and 0.92 of HEAD,
  33 KB more a program (the start object's 108 curry functions).
- **1d, small frames** (`Emit`, found on the way, `-full-frames` off):
  a function with no value in memory has no frame on the value stack,
  its parameters moved from their registers to theirs; one that calls
  nothing with BL (arm's DIV and MOD are the assembler's BL _div) leaves
  the machine stack and its link alone. `sq x = x * x + 1`: 15
  instructions to 9. 0.99 and 0.97 after 1a, and the code smaller.
- **1b, inlining in the unit**, little: the small functions a frame
  calls are another unit's (mini-doom's `View.norm`, `fine` from `Bsp`
  and `Segs`). The size of a body counts the copies it makes (a call of
  an inlined function is that function's size), and a body with a
  function or a handler is not copied: the first version, without,
  made mini-ml 2.42 MB to 3.00 (Unix's `tcgetattr` copied `bit` 25
  times, each with `u32` in it).
- **1c, across units** (prototype): a unit reads the .ml of each unit it
  names in its own directories, resolved and typed as when compiled, its
  places in the text made negative (Typing's tables are by place), and
  inlines their small toplevel functions as its own. The rule for which
  directories is the question: an `-I` under the current one, as
  prototyped, differs by how a path is spelled (tests/run.sh's are
  absolute: nothing read); the file's own directory is clearer. A
  unit's build must depend on what it copies: mkprog's and mklib's
  rules do (`$LOCAL`, the directory's sources), lib_core's mkfile does
  not (a unit on its own .ml), nor some programs' own rules. Bsp's
  compilation 0.05 s to 0.28 on the host.
- **cameltry's frame is not a measure**: dumping the frame is 330
  million instructions, and how much more depends on the frame and the
  heap (to frame 91 fewer than to 61), against 1.1 million a frame. Its
  numbers are left out; mini-doom's and mini-quake's are the same at
  each run.

Checked: tests/runtime and tests/tiny on arm and arm64, -O3, and with
ML_HEAP=64 (arm's arith and strings fail as before); `make test-lite`
in the copy with all of it on (-O3 = inlining 20, across units by the
prototype's rule): 70 jobs, 0 failures. Found by the tests: the small
frames first took arm's DIV for a plain instruction (the link lost),
and a double's register for a word's (`List.nth`).

**Stage 1 done** (the author: "do what you think is the best", then of
the prototype's rule: "I think what OCaml does make more sense long
term no? running mini-ml -M and have .depend is quite classic", and
"Let's get rid of this -siblings which looks hacky"). Not committed
yet. In the shared tree:

- **1a**, the curry functions shared to 16; and their block's stores
  without the write barrier (the start object's are Gen's, which had
  it at each field: `ml_curry8_6` 59 instructions a call became 109,
  as ssa's `Emit` leaves it out for `obj_block`'s young block).
- **1d**, the small frames (`Emit`, `-full-frames` off).
- **A value in no block has no slot** (`Alloc`): the phis that
  `Ssa_build.simplify` took out, the values `Unbox` replaced, each had
  a slot of the frame, zeroed at each call (Float.min's 13 of 15). In
  HEAD too; inlining made it show (the floats bench 4.5% slower, then
  2.7% faster than HEAD). The largest single gain of the stage.
- **Shared slots** (`Alloc`, `-own-slots` off): two values in memory
  whose lives do not meet share a slot. mini-doom 0.995, mini-ml
  compiling 0.989, 1% less code.
- **1b and 1c**, inlining at 16 nodes (`-O3`'s; `-inline n`), in the
  unit and from the summaries of the units it uses
  (`simple/Summary.mli`: `X.inline` beside `X.5`, OCaml's .cmx; the
  trees without their types, the typing's answers by place, X.ml's
  digest). **Only a summary beside the unit's own object is read**: the
  same build directory, which its `.depend` orders. Every directory's
  (lib_core's `Float.min` in a game) bought mini-doom 0.994 and mini-ml
  6% larger, and a program's unit is not made again when a library's
  source changes: its copy would be stale.
- **`.depend`**, a directory's, by `mkfiles/depend.rc` (`mini-ml -depend`:
  the units whose values a unit names, not `-M`'s, which are every
  interface read, and make cycles in lib_core), made by the build:
  each mkfile includes it by mkfiles/mkdepend (mkprog's, mklib's, a
  mkfile's own) or games/mkgames, which writes it again when it is older
  than the mkfile or a source. Not in the repository since 2026-10-28
  (old: 78 files, made by `mini-mk depend` after a build, when one
  thought to: four directories had none, self-mix's 27 files), and
  beside the objects, `$B/<dir>/.depend`, not the sources: a build from
  nothing (make test's, CI's) makes each anew, where make test's found
  the source tree's made.
  mkprog's rule for a unit now takes its source alone, the directory's
  others by `$OBJS: $LOCAL $GEN $LIBSRC` (mk drops a metarule's arc to a
  missing file only when no other arc of it stays: a unit in a folder
  had two rules); and a rule that compiled several units in one recipe
  (languages/ml's, languages/c's, machine's, database's,
  version_control's, smalltalk's folders) a rule a folder, one recipe
  a unit: mk ran such a recipe before the .depend's prerequisites of
  its other targets, and two builds differed.

Checked: two builds from nothing the same bytes (2,157 objects and
summaries; and with NPROC=2); a build after an edit of Float.ml the same
as one from nothing; tests/runtime (new: `inline/`, two units, at -O0
and -O3 the same answers) and tests/tiny on arm and arm64, -O3, -O0,
ML_YOUNG=256 (gc's timeout on arm as before); mini-ml built by mini-ml
writes the same assembly as by OCaml (12 of its files, mini-doom's Bsp,
Segs, View, arm and arm64); `make test-lite`, 70 jobs, 0 failures.
Not run: mini-9pi, the boards, kernels/singularity's build (its
`.depend` lacks Process's lines: Programs.ml, which its build makes).

Arm, mini-5i, against HEAD 1faa3baa (frames 31 to 121 for mini-doom and
mini-quake, the same bytes):

| | HEAD | stage 1 | |
|---|---:|---:|---:|
| mini-doom, a frame | 11,913,573 | 10,047,323 | 0.843 |
| mini-quake, a frame | 26,652,483 | 24,827,562 | 0.932 |
| mini-virtuaracing, a frame | 36,239,289 | 32,507,977 | 0.897 |
| its start | 2,899,308,934 | 2,638,620,081 | 0.910 |
| mini-ml compiling its three units | 7,126,318,177 | 6,910,652,356 | 0.970 |
| bench: pixels, maps | 31.91, 13.16 million | 28.95, 11.36 | 0.907, 0.863 |
| bench: floats, samples, sched | 7.73, 6.60, 14.08 | 7.52, 6.41, 13.69 | 0.97 |
| mini-doom's size, mini-ml's | 1,804,014, 2,431,886 | 1,857,262, 2,622,022 | 1.029, 1.078 |
| the build from nothing (loaded host) | 46 s | 61 s (49 without inlining) | |

Left of the stage: the build's time (inlining's code, 12 s of 15);
the comparisons that make a boolean before branching on a float's
(`Emit`'s fused is the integers'), stage 3's. Ledger: mini-ml +473
(Summary 171 of them), the mkfiles +146, 74 `.depend`.

2026-10-26, **stage 2 done** (the author: "let's do it"), 683bcee7. `ssa/Untag.mli`: an integer not tagged inside a function where
its bits are known small (no wrap where the tagged value would): a
byte read (8 bits), `x asr k` by a constant (one shift of the tagged x
by k + 1), `x land c` of an untagged x, sums and `lsl` of untagged
values while within 30 bits (arm) or 62 (arm64); read as it is by an
untagged operation, as a byte's index or the byte stored, and by a
tagged value plus or minus it (`ADD R2<<1, R1, R3`); tagged once after
its definition wherever else (`Ssa.Tag`). A value kept only while
something reads it untagged (but a byte read). In memory, a slot of
the machine stack (Alloc's Dmem): the collector does not scan it.
`-tagged-ints` off; `-dssa` says each value's bits. The full version,
every int untagged, was weighed and not done: a sum that may pass 31
bits must be brought back (two instructions) before a comparison, a
shift or a division, and mini-doom's `xfrac`, a sum shifted, gained
nothing.

mini-doom's span: 35 instructions a pixel to 25 (`SRA $17`, `AND $63`,
`SRA $11`, `AND $4032`, an `ADD`, the flat's byte at its untagged
index, `ADD R8<<1` for `cmap +`, the colormap's byte stored as it is);
the column 29 to 21. What is left in both: the slots reloaded at each
turn (6 of 25: stage 3).

Found on the way: mini-asm and mini-ld for arm64 took `MOVBU (R1)(R2)`,
a register index, for `0(R1)`, the index dropped without a word; now
an error (docs/plans/bugs/ix.md). Nothing used the form.

Arm, mini-5i, against 88b5dda9 (stage 1), the frames the same bytes:

| | stage 1 | stage 2 | |
|---|---:|---:|---:|
| mini-doom, a frame (31 to 121) | 10,047,326 | 9,458,531 | 0.941 |
| mini-quake, a frame | 24,827,561 | 24,329,146 | 0.980 |
| mini-virtuaracing, a frame | 32,987,537 | 32,987,537 | 1 (its floats) |
| mini-ml compiling its three units | 6,910,466,819 | 6,799,674,655 | 0.984 |
| bench: pixels | 28.95 million | 26.65 | 0.920 |
| bench: the others | | the same | |

Checked: tests/runtime (new: `untagged.ml`, shifts of negative values,
masks a constant the instruction cannot hold, sums near and past an
int's bound, a value across a call and an allocation, checked bytes at
untagged indexes: the same at -O0 and -O3 on arm and arm64) and
tests/tiny on arm and arm64 at -O3, with ML_HEAP=64 and ML_YOUNG=256
(arm's arith, strings and gc's timeout as before); mini-ml by mini-ml
writes the same assembly as by OCaml (Untag, Emit, Alloc, Lower,
Typing, CLI, arm and arm64); `make test-lite` in a worktree, 72 jobs, 0
failures. Ledger: mini-ml +272 (Untag 174 of them with its .mli).

2026-10-26, **stage 3 begun** (the author: "let's do it", then of the
order: rebirth's floats and xv6's boot before more registers, "yes").
3a, a float's comparison that a branch alone reads made by the branch
(Emit's `fused`, `Floats`): `CMPD` then `B.cond`, where the boolean was
made, then compared with 1 (6 instructions a test on arm, now 3). A
double's, Unbox's, from its registers; a boxed one's loaded from its
block. The conditions are FloatCmp's of a nan (`Ne` true, the others
false: MI, LS, GT, GE), their opposites true of it (PL, HI, LE, LT).

Arm, mini-5i, against e0c26641, the frames the same bytes:

| | HEAD | 3a | |
|---|---:|---:|---:|
| mini-doom, a frame (31 to 121) | 9,030,299 | 8,925,890 | 0.988 |
| mini-quake, a frame | 24,304,574 | 24,169,374 | 0.994 |
| mini-virtuaracing, a frame | 32,879,638 | 32,197,663 | 0.979 |
| mini-ml compiling its three units | 6,799,649,193 | 6,799,670,091 | 1 |
| bench: floats, samples | 7.52 million, 6.41 | 7.33, 6.32 | 0.976, 0.986 |

Checked: tests/runtime and tests/tiny at -O3 on arm and arm64 (arm's
arith and strings as before); mini-ml by mini-ml writes the same
assembly for Emit as by OCaml. Ledger: mini-ml +36.

Where the next items go, by two programs the author named ("rebirth
for instance is very slow; I think xv6 was really slower with mini-ml
than ocaml-light ocamlopt"):

- mini-rebirth, a second of sound (frames 31 to 91): 5.79 thousand
  million instructions. The collector, `ml_modify` and the allocations
  29%: lib_audio's code from the playground keeps its state in float
  arrays (Diode_ladder.process makes a 4 x 4 matrix and three vectors
  a sample: `solve` 6.3%); C's `sin` (libc's `sinus`, 8.6%), `exp`,
  `floor`, `modf`, `ldexp`, `log`, `pow` 20%; ReBirth's spectrum looks
  at every bin for each of its 90 bars (`iteri`, `bin_frequency` 7%).
  Mostly lib_audio's and rebirth's own, as 581e1d8d's mixer was.
- mini-xv6 on QEMU's Pi 4 (`kernels/xv6/numbers.sh`): its session 28.0
  s against ocaml-light's 21.1 (1.33; 4.4 on 2026-10-02), the boot to
  `ls` 8.1 s against 3.2: the boot is what is left.

2026-10-26 and 27, **mini-rebirth** (the author: "let's commit. and
switch to rebirth opti (Float.Array and so on)", then "I'll be back
tomorrow morning; hopefully by then the perf of rebirth improved
significantly"). A second of sound with its panel (frames 31 to 91,
arm, mini-5i): 5,541,729,282 instructions, then 1,941,710,580 (0.35);
the frame and the sound the same bytes as HEAD's, and OCaml's build's
sound the same bytes (apps/music/tests). The profile's `sinus` above
was mostly the spectrum's FFT, not the sound's sines. By mini-ml a
float stored in a float array or a mutable float field is a new block
and the write barrier, and a float a function returns a new block;
what was done, each with its `ix:` comment and its `old:`:

- lib_audio on `Float.Array` where rebirth's sound is made: the diode
  ladder's state, matrix and vectors made once (25 arrays a sample
  before), Svf's two states, Vco's wraps, Modal's eight floats,
  Voicing's pitch, Delay's lines; the TB-303's and the drums' pieces,
  the drums' hits' out, the studio's drums. The state in variables
  while a block is made (Vco's phase, Drive's high-pass, Delay's
  delay and tones, the TB-303's envelopes).
- Calls not made, the same values: Svf.process_fixed, a cutoff that
  does not move, its tan once; Drive's gain once when its knob stays
  (a ramp from a value to itself is that value); Filter.chain, the
  four biquads in one function; the drums' envelopes once an age (the
  silence test read the next sample's); Vco.run_plain, the
  band-limited pulse and sawtooth in one loop (Oscillator's formulas
  in it); Signal.at_most and at_least, lib_core's Float.min and max
  for a bound not nan without a call.
- The spectrum (a third of the time): Spectrum.of_signal's FFT in two
  flat arrays, iterative, each size's w^k, window and bit reversal
  made once (the same butterflies as the recursion's); ReBirth's bars
  in one pass over the bins (90 passes before).
- lib_playground's Basics: + - * / and the ints' as externals (a
  value of another directory's unit is not inlined: each + of a
  program that opens Basics, Playground.ml among them, was a closure's
  call, its floats boxed). On arm64 OCaml now fuses a * b + c in
  rebirth's drawing (the memory's two compilers): three of its frames'
  OCaml sums recorded again, mini-ml's the old ones.
- **3b**, mini-ml (Emit, Unbox): a product by a small constant without
  MUL (a power of 2 a shift of the word without its tag); -x and abs x
  on doubles (Unbox's Float1; arm64's FNEGD and FABSD, arm's sign bit
  in memory, 5a having neither), where each was a new block; on arm a
  Float.Array's address in one ADD (b + 4i - 4 from the tagged i, the
  bound checked against 2n). tests/runtime/mul_neg.ml.

Arm, mini-5i, the same frames, against 076a65b1 (3a), each from
nothing:

| | 3a | now | |
|---|---:|---:|---:|
| mini-rebirth, a second | 5,541,729,282 | 1,941,710,580 | 0.350 |
| mini-virtuaracing, a frame | 32,197,663 | 29,212,213 | 0.907 |
| mini-quake, a frame | 24,169,374 | 22,689,731 | 0.939 |
| mini-doom, a frame | 8,925,890 | 8,832,450 | 0.990 |
| mini-ml compiling its three units | 6,799,670,091 | 6,788,853,190 | 0.998 |
| bench: pixels, floats, samples | 26.65 million, 7.33, 6.32 | 25.81, 7.33, 6.31 | 0.969, 1, 1 |

What is left of rebirth's (2.03 thousand million by the profiler): the
C library's exp and what it calls (modf, ldexp, floor), pow, log, 20%
(another session's exp.c without floor's and ldexp's calls, in the
working tree); the ladder's solve 6.4% (the index arithmetic made
again at each access: no common subexpressions); the floats C's
functions return, a new block each (copy_double, 1.8 million a
second); a float a known function returns, boxed (the floats plan's
item 6: a second entry returning the double).

Found on the way: mini-mk does not make an object again when mini-ml
changes; a compiler's measure is from nothing.

## 2026-10-27, 3c: C's math functions on doubles

exp, log, pow, tanh and the others were CallCs of the runtime's
exp_float: the argument boxed for it, copy_double's block for the
result, then unboxed. Lower makes them Ir's FloatCall (the runtime's
name, C's, the arity: Lower.float_calls), which simple's code still
calls as before; in ssa's (Unbox) a Dprim that stores the doubles at
w(SP), w+8(SP) and calls C's own, its result in F0, as 5c and 7c do.
A safepoint and a clobber for Alloc (C's code uses all the registers),
no allocation. The runtime's ml_tan, ml_sinh, ml_cosh, ml_tanh and
ml_fmod are no longer static. tests/runtime/float_calls.ml; the same
bits as before at %.17g, on arm and arm64.

Arm, mini-5i, from nothing, against 6020ad2f (which has the libc's exp
without floor and ldexp, ffe3c8b9):

| | 6020ad2f | 3c | |
|---|---:|---:|---:|
| mini-rebirth, a second | 1,820,194,302 | 1,687,426,190 | 0.927 |
| mini-virtuaracing, a frame | 29,212,213 | 29,056,330 | 0.995 |
| mini-quake, a frame | 22,476,581 | 21,875,894 | 0.973 |
| mini-doom, a frame | 8,619,294 | 8,547,775 | 0.992 |
| mini-ml compiling its three units | 6,791,818,340 | 6,775,085,883 | 0.998 |
| bench: samples | 6.31 million | 5.19 | 0.822 |

The frames and rebirth's sound the same bytes. ml_alloc and
copy_double are gone from rebirth's top; what is left of its boxes
(the collector's copy, 1.5 million a second, and ml_modify's 2.1
million) is the floats ML's functions return and the mutable fields'
(the floats plan's item 6, next).

## 2026-10-27, 3d: a double boxed where it is read

Counted for 3c (each `vstr dN, [r0]` after a block taken, by `mini-prof
-a` over rebirth's 150 first functions): 7.5 million floats boxed a
second. The first, Svf.solved, boxed low, band and high, of which it
returns one; Filter.chain its loop's sum at each turn, for the return
after the loop. Unbox boxed a double right after its definition; now,
when every read of it as a word is in one block, and that block cannot
run again but through the double's (no cycle avoiding it), the box is
there: at the block's start for a read in its body, at its end for its
terminator's. A double made before a loop and read in it stays boxed
before the loop. tests/runtime/box_where_read.ml.

Arm, mini-5i, from nothing, against afcb6f03 (3c):

| | 3c | 3d | |
|---|---:|---:|---:|
| mini-rebirth, a second | 1,687,426,190 | 1,613,983,459 | 0.956 |
| mini-doom, a frame | 8,547,775 | 8,444,770 | 0.988 |
| mini-quake, a frame | 21,875,894 | 21,874,980 | 1 |
| mini-virtuaracing, a frame | 29,056,330 | 29,056,324 | 1 |
| mini-ml compiling its three units | 6,775,085,883 | 6,775,085,883 | 1 |
| bench: floats | 7.33 million | 6.99 | 0.954 |

The frames and rebirth's sound the same bytes; mini-ml by mini-ml the
same assembly (Unbox, Emit, Lower). Found on the way: mini-ml refuses
`Option.value x ~default:[]` where OCaml takes it (a labelled function
of another unit not annotated): written as a match.

## 2026-10-27, 4a: int32's operations in place

The author: "ideally we want the int32 to be optimized especially for
the Pi where they are currently costly", then of the steps (the
operations in place first, unboxing after only if the boxes still
dominate): "let's do 1 and then 2". On arm an int has 31 bits, so an
int32 is a block, and each Int32 operation was a call of the runtime
(ints.c's int32_add...: the operands read, the result's block by
ml_alloc), some 170 instructions. lib_crypto's Sha256 (TLS's
handshakes, mini-curl and mini-netscape) is all of them; mini-9pi's
Tcp its sequence numbers.

Lower makes int32_neg, add, sub, mul, and, or, xor, the three shifts,
of_int and to_int Ir's Int32 (the runtime's name, the arity:
Lower.ints_in_place, off with -calls), which simple's Gen still calls;
ssa's Emit (Prims) loads the operands' 32 bits, computes in a word,
takes the result's block in place and stores its low 32 bits (arm64:
sign-extended loads, zero-extended for a logical shift right), the
runtime's call only when there is no room; to_int a tag, no block.
Division and remainder stay calls (Division_by_zero). tests/bench/sha.ml
(Sha256 as it is, 4 KB), tests/runtime/int32_ops.ml (the bounds, the
sign, a logical shift of a negative, a hash's loop).

Arm, mini-5i, from nothing, against d22c56e4: the sha bench 17,888,940
instructions to 6,946,210 (0.388; arm64 17,842,180 to 6,810,778); the
other programs the same (they use no Int32). Each result is still a
block: unboxing int32s in ssa, as Unbox's floats, is the next step if
they dominate.

Then Emit's open-coded primitives (prim, dprim and their helpers, a
third of it) moved to ssa/Prims.ml (the author: "yes let's try to move
this optimization code under opti/ or ssa/ if possible"): Emit 1,109
lines to 790, Prims 374 and its .mli 79, a record of what of
Emit.func they read (Prims.ctx). The same assembly from the compiler
before and after, on mini-ml's, lib_core's and the tests' units.

Then undone (the author: "I really don't think such a big record is
readable and improve the readability of the code that was before"):
Emit as before the move, its open-coded primitives a section with
Prims.mli's explanation at its head. Instead the open coding is out
of simple's Gen, the simple path: every primitive a call of the
runtime there (a string's byte, a float's arithmetic and comparison,
an allocation; -O0 slower, the reference), Gen 621 lines to 452; the
start object's functions (ml_program, the curry functions) compiled
by ssa's Emit with -ssa, as a unit's (Gen.startup's compile), so that
no -O3 code is Gen's: the start object 9,209 lines to 8,866 (arm), the
units' assembly the same. Emit.alloc_in_place and alloc_most, Gen's
before. Arm, mini-5i, both from nothing, against 7dd029cc: mini-ml
compiling its three units 6,799,634,141 instructions to 5,856,092,556
(0.861: the curry functions, at every partial application and every
call of a closure of several arguments, were the stack machine's),
mini-doom's frame 8,444,780 to 8,243,646 (0.976), mini-quake's,
mini-virtuaracing's, mini-rebirth's and the benches the same; the
frames and the sound the same bytes.

## 2026-10-27, 4b: a string's little-endian integers in place

The author: "ok let's follow your plan, 1, 2, 3", then of 3 (int32s
unboxed in ssa): not done, as the open coding already goes past
ocaml-light's ocamlopt (its Int32 calls of the runtime; no
Bytes.get_int32_le in OCaml 1.07). lib_core's Bytes.get_uint16_le,
get_int32_le, set_uint16_le and set_int32_le, and String's two getters,
were ML: through String's, two 16-bit halves of bytes and four int32s.
Now externals of OCaml's names (%caml_bytes_get16, get32, set16,
set32; only mini-ml compiles lib_core's base/, little-endian as ix's
machines), Ir's BytesGet and BytesSet (Lower: with strings_in_place,
ints_in_place for the 32 bits): in ssa's code the index checked twice
(0 <= i < the length, then i + n - 1), then on arm a byte at a time (a
word's load needs an address of 4, the Pi 1 traps or rotates), on
arm64 one load or store; the int32 a block taken in place. Simple's
Gen calls the runtime's caml_bytes_get16... (ints.c). The _be ones and
the int64s stay ML. tests/runtime/bytes_ints.ml (each offset, the sign,
the bounds at both ends, a short string).

tiny-machine's profile first (mini-5i -prof of the arm64 build, the
paint session, 17.5 thousand million instructions, mini-5i now writing
its profile at a SIGTERM): String.get_int32_le 11.8%, get_uint16_le
10.7%, Bytes.get_int32_le 3.0%, int32_to_int 1.0%, a quarter of it the
reads of the machine's memory (each 190 instructions in three calls;
now 37 in place). Then, natively on the host (arm64), the paint session:
3.28 s to 2.67 (0.81), OCaml's build 1.48 (2.2 times to 1.8). Arm,
mini-5i, from nothing, against b0ef73ed: mini-ml compiling its three
units 0.988, mini-doom's frame 0.999, the others the same. The rest of
tiny-machine's profile: TinyMachineCPU.step 15%, the devices' ticks 8.4%
and check 6.7%, Pervasives.lnot 1.2% (35.8 million calls: lib_core's
small functions are not inlined into another directory's units), the
curry functions 4.6% (the env record's closures).

Found: the emulators built by mini-ml do not run: on arm their memory,
one Bytes, is past a 32-bit block's size (tiny-machine, mini-5i:
Bytes.create), and mini-5i for arm64 is out of mini-ml's heap at its
start.


## 2026-10-27, found by mini-virtuaracing's sound: a loop's floats boxed at each turn

Not done; for whoever takes Unbox next. Synth.continue_into (lib_audio,
virtua's engine and wind: 8.5M of the race's 22.7M instructions of
sound in 20 frames, mini-5i -prof, arm, by mini-ml at 1c73082b) is a
loop over a voice's samples whose state is float refs (phase, time:
slots by Opti's refs, decision 1 of plan_ml_floats.md). phase is also
passed to a call each turn (Oscillator.wave_band_limited, a closure of
another unit), so it leaves as a word, and the loop's phi is a word: at
the head of each turn three blocks are taken and their doubles stored
(mini-prof -a continue_into: 44,160 turns, three allocations of 12
bytes each at its start), about 190 instructions a voice and a sample
where the arithmetic is some 40. The same shape is in every synthesis
loop of lib_audio (the filters' memory, the oscillators' phase): a
float carried by a loop and given to a function in it. What would
remove it: the phi a double, the box made at the call that needs a
word (3d's "where it is read", for a read inside a loop of a value the
loop carries). Asked of the author, 2026-10-27: done in mini-ml rather
than lib_audio's loops rewritten around it (a one-cell Float.Array),
which the playground's copy would need too.

## 2026-10-27, 4c: Pervasives' small functions as externals

The author: "let's do 2 first and then 3" (2: Pervasives.lnot and
lib_core's small functions, not inlined into another directory's
units; 3: jump tables). Two ways, both measured from nothing on arm
against HEAD (and tiny-machine's paint session natively on arm64):

- lib_core's summaries read by every directory's units (a scratch
  hack: CLI's summaries found in _mk/5/lib_core too): tiny-machine
  2.67 s to 2.50 (0.93), but mini-ml compiling 1.032, virtua's frame
  1.028, mini-ml 5.5% larger, doom and quake the same. Not done; it
  would also need every program's units made again at a change of
  lib_core (mkprog's $OBJS on lib_core.a), as OCaml's .cmx do.
- The few of Pervasives' functions that are a call where OCaml's are
  not: ( |> ), ( @@ ) and ignore, externals as in OCaml's stdlib since
  4.01 (%revapply, %apply, %ignore; ignore's was commented out, from
  ocaml-light), and lnot, mini-ml's own %lnot (an xor with -1; OCaml's
  a function, inlined from its .cmx). Lower's app: x |> f and f @@ x
  the call f x, x |> g a the call g a x (OCaml's translcore and
  simplif), a known g's code called with all, not a closure; the
  arguments in OCaml's order (x first, as ocamlopt's). Done.

The externals' numbers, against HEAD: tiny-machine 2.67 s to 2.47
(0.925, the same screen), mini-ml compiling 0.986, virtua's frame
0.997, doom and quake 0.998 to 1.000; rebirth's second 1.018, a phase
of the collector: 0.995 and 0.997 at ML_YOUNG=600000 and 300000. The
programs' sizes 0.993 to 0.999. tests/runtime/apply.ml (a known
function, a closure, a primitive, more arguments, a chain, each as a
value, the effects' order, lnot). Not done: abs (a branch, as min's),
left a call.


## 2026-10-28, found by 4d's measure: the assembler's labels in quadratic time

Parser_asm resolved each branch to a label (Target (-k)) by List.assoc
in the list of all of the unit's, a polymorphic compare for each one
passed: quadratic in a unit's branches. mini-ml assembles its own
output, so every compilation paid it; the jump tables' BCASEs, more
branches, made it show. Now an array by the number. mini-ml compiling
its Lower, Typing and Ssa_build (macro.sh's), on arm by mini-5i:
5903M instructions to 5788M (0.980); natively 4.5% of Lower's. The
same objects.

## 2026-10-28, 4d: a match's jump table

The author: "let's do 2 first and then 3" (3: jump tables, measured on
tiny-machine's step), then on the first numbers: "compiling efficiently
pattern matches is one of the most important thing for languages like
OCaml so we should keep the optimisation", and a benchmark of ADTs and
matches wanted, doom and quake being numeric.

Lower's match_cases tested the clauses in turn, each its constructor
(the tag loaded and compared: 6 instructions a clause on arm64). Now a
match naming four constructors or more jumps by a table (Ir.Switch, an
SSA terminator, the CASE and BCASE of 5c's switch, which ix's linker
had for mini-cc) to the first clause that may match the constructor,
past its own test of it; a type of constants and blocks tests which
first (ocamlopt's Uswitch, two tables). A clause that fails after goes
on to the next one's tests as before: no decision tree, only the first
constructor looked at. mini-ml -linear-matches: the old code, the same
assembly as HEAD's (636 compilations). Found: 5l (and ix's linker after
it) could flush a literal pool inside a CASE's table, which breaks the
jumps silently; never inside now, and before a CASE as at its table's
end (Go's 5l's casesz).

Against HEAD, both from nothing on arm:

- tests/bench/interp.ml (new: a stack machine's step on 14 constructors,
  an expression tree evaluated and simplified): 27.2M instructions to
  19.6M (0.722), and 0.776 at -O0.
- tiny-machine's paint session natively on arm64: 2.48 s to 2.46
  (0.99, the same screen); step's dispatch from 48 instructions at its
  last constructor to 8, but the step's time is mostly its fetch's
  closure, decode_kept and alu's call.
- doom 0.998, quake and virtua 1.000, the programs' sizes 0.993 to
  0.999; the other benches the same.
- mini-ml compiling: its tables made 0.6% more, its code with tables
  0.6% less, 1.000 measured with a heap large enough for few majors
  (ML_HEAP 4M to 16M words). At the default heap 1.023: one more
  major collection, the copy of all that is alive, in Lower's unit (at
  ML_YOUNG=300000 the two the same, at 600000 1.10).

tests/runtime/switch.ml: constants, blocks, both; or-patterns, guards,
aliases, a wildcard between, a clause failing on, Match_failure. Not
done: a decision tree (OCaml's Matching: a constructor's clauses
together, the fields tested once), integer and character constants
by a table (decode's opcodes).

## 2026-10-28, found profiling m-ix's build: mini-ld's arm64 pool searched

The author, of what to measure: the real programs and m-ix built under
m-ix, the Pi 1 and Pi 2 first; then "let's fix the arm64 pool now".
ix built from nothing for arm64 by the programs of a first build
(mkfiles/fixpoint.sh's second build: m-ix's tools, natively): 128 s,
80 by dune's; each tool's calls timed: mini-ld 644 s of user time in
123 links (4.6 s each), mini-ml 274 in 1,130 compilations. mini-ld
built by OCaml linked mini-ml in 8.2 s too (11.6 by mini-ml's build):
the algorithm. callgrind: 70% compare, under Arm64.layout's
List.assoc_opt of a constant in the literal pool, which on arm64 is
flushed only when its reach (1 MB) runs out: thousands of entries, each
new one searched in all (5l's addpool does the same, on arm's pool of
a few). Now a Hashtbl by the same key beside the list: the link 8.14 s
to 3.06 (0.38), the same bytes. arm's link (3.4 s by OCaml's build)
has no such search high; its profile under mini-5i, mini-ml's build,
is the Pi 2's next measure.

## 2026-10-28, the Pi 2's link: mini-ld's map without printing the program

The author: "our main focus is the Pi1 and especially Pi2", then on
the link's profile "let's do 1 if it's just a few lines". mini-ld
built by mini-ml for arm, linking mini-ml (under mini-5i -prof): 21.19
thousand million instructions, 30 s or more on the board. The
collector 31% (copy 15.5, scan_copies 8.2, ml_alloc, ml_modify), the
polymorphic compare and hash 8.5, Marshal's reading 6, select 5.1
(1 million calls: layout's, then encode's again), Printf 4.6 (2.7
million doprn calls). A heap of 8M words: 20.99 (0.991): the majors
are not it, the minor collections' promotion of what the link keeps
is.

The Printf calls were -map's (every link of m-ix's mkfiles writes
one): each instruction printed (Link.show), 650 thousand lines, to
find the TEXTs by their text. Now a TEXT found by its op, its name
from its operand: 21.19 to 15.70 (0.741), the same executable and
map (on arm64 too); natively, OCaml's build of the link 3.16 s to
2.65. The printing's strings had been the collector's too.

Next, not done: Marshal's reading into the old generation (OCaml's
intern.c reserves a value's whole size in the major heap, so what is
read is never promoted), after a profile of what is promoted (the
objects read, or the linker's progs made from them). Weighed and not
done: select's choice kept in the instruction (5l's p->optab), 2.5%.

## 2026-10-28, what Marshal reads made in the old generation

The author: "yes let's do the intern into the old generation". The
Pi 2's link spent its collector's 31% promoting what it keeps (a heap
of 8M words: 0.991, so not the majors). A program reading what the
link reads and keeping it (all of lib_core.a's members, more than a
link takes): 4.80 thousand million instructions, 2.19 of them copy and
scan_copies. OCaml's intern.c reserves the whole value read in the
major heap (intern_alloc). Here gc.c's ml_old_begin and ml_old_end
around Marshal.from_string's read: ml_hp and ml_limit the half's
meanwhile, the young generation's kept aside and put back for a
collection (gc). The blocks read point only to blocks read: none
remembered. Measured: mini-cat's link on arm by mini-5i (mini-ld built
by mini-ml) 3.19 to 2.91 thousand million (0.911), the same executable
and map; bench/marshalling.ml's reading natively on arm64 1.30 s to
0.85 (0.65). mini-ml's link, the long count, not waited for.

## 2026-10-28, large blocks of no pointers outside the halves

Found improving mini-5i (the author: "let's improve mini-5i", "and in
the process hopefully possibly improve mini-ml and other programs"):
mini-5i built by mini-ml for arm64 died at once, "Fatal error: out of
memory". An arm program's data (mini-ml's runtime: the halves are its
bss) is 642 MB, which mini-5i holds as one Bytes of 80M words, more
than a half (64M words). OCaml makes a block past Max_young_wosize
(256 words) in its major heap, which does not move it. Here (the
author: "yes. is it what OCaml does too?") a block of no pointers (a
tag from 251: bytes, strings, float arrays) of YOUNG / 2 words or more
has its own memory from the system (m_alloc, as a thread's), three
words before its header: the chain, its size, a mark. A major
collection marks those it reaches (copy, for a pointer between
large_lo and large_hi, checked against the chain), then frees the
others (munmap); a minor one has nothing to do with them. A major
collection is asked for when as much again as was kept, and a half
besides, was made since the last one, so dead ones do not pile up
while the half does not fill. Nothing is reserved (the author: "does
that mean mini-ml need to reserve a space for those large objects"):
a program that makes none has the memory it had. Plan 9 gives no
memory back (sbrk): a dead block is kept, for the next one it fits. A
kernel's runtime (MAXHEAP its own) has no system to ask: its large
blocks stay in the half. mini-5i's Linux had no mmap: now anonymous
mmap and munmap (arm's 192 and 91, arm64's 222 and 215), each a
segment in the highest hole below the stack's, as Linux's mmap_base.

Measured: tests/runtime/large.ml (300 MB of 5 MB blocks made and
dropped, a kept one and a float array read after collections) 31 MB at
most on arm64, 39 under qemu-arm; as a Plan 9 program under mini-5i
the break moved 6 times for 61 blocks. mini-5i built by mini-ml runs
interp's arm executable: 9.0 million instructions a second, the OCaml
build (dune's dev profile) 14.8, 1.64 times slower. A mark and sweep
for the whole old generation, as OCaml's, was weighed (the author:
"Should we move away from the copying collector long term to the mark
sweep of ocaml?"): its memory about 1.5 times what is alive against up
to 4 here, but free lists, fragmentation and about four times gc.c's
lines (ocaml-light's major_gc, freelist, memory, compact); the majors
are 1% of the Pi 2's link and 7% of mini-ml compiling. Kept copying;
if memory stops self-m-ix on the Pi 2 (the link of mini-ml takes 511
MB), this space is the first piece of such a heap.

## 2026-10-28, constants folded (simple/Fold), as ocamlopt's Closure

Found profiling mini-5i built by mini-ml (the author: "let's do it",
then "yes" to constant folding): Bits.ult32 is 26 nodes, past
-inline 16, for an `if native then ... else ...` whose native is
`Sys.int_size > 32`, known when compiling. ocamlopt's Closure keeps a
toplevel constant's value in the .cmx (Value_const) and computes its
uses; flambda more. The author: "I'd rather have the general opti
that hardcoding Sys.word_size thing in Lower, and have general
constant folding", "first the general one and check if it works in
practice". Fold, a pass on the Scope tree before Lower (-O and -O3;
-no-fold, -O0 without): a toplevel value whose definition folds to an
int, a char or a constructor of no arguments is that constant where it
is used; a primitive of constants (the integer operations, wrapped to
the target's 31 or 63 bits; a shift by the width or more, a division
by zero left to run) computed, a comparison of two a bool, && || not,
an if on a constant its branch. Not strings nor floats: a copy would
be another block. A unit's constants in its summary (format 2), read
by the units of its directory as its functions are.

Measured from nothing on arm (two trees, mini-mk O=5, -O3 against
-O3 -no-fold): mini-doom's frame 0.984 (its start 0.998), mini-quake's
0.998, mini-ml compiling Ssa_build.ml under mini-5i 0.999 (the same
object); sizes equal or smaller (quake and mini-5i 4 KB less, mini-ml
and mini-ld 224 bytes). tests/runtime/fold.ml, each folded value
checked against the same arithmetic on values known only when running,
on arm and arm64. Not yet: mini-5i, whose Bits.native reads lib_core's
Sys.int_size, another directory, whose summaries are not read (stage
1: a .depend of the directory only, a change of lib_core would leave
stale copies). Next: a .depend across directories, as ocamldep -I,
and Sys's word_size and int_size the externals %word_size and
%int_size, as OCaml's.

## 2026-10-28, constants across directories: lib_core's Sys.word_size

The author: "why lib_core summaries are not read from other
directories???", then "commit Fold first, then do the precise
.depend". Stage 1 read a summary only beside the unit's object: a
directory's .depend orders its own units, and a program's units were
not made again at a change of lib_core (mkprog's $LIBSRC is the
libraries', not lib_core's), so a copy of lib_core's code would have
been stale. ocamlopt finds a .cmx in the -I directories, and
ocamldep -native writes lines on them. Here likewise:

- mini-ml's summaries: one not beside the object is looked for in the
  -I directories (mkconfig's STDSUM, -I $L: lib_core's build), and
  only its constants are taken (Fold's), not its functions. Their
  bodies across directories were measured on 2026-10-27 (4c), mini-ml
  compiling 1.03, and are not taken.
- mini-ml -depend: for a unit of another directory whose summary an
  -I has, with constants, a line on that file (`$D/Bits.$O:
  ../_mk/7/lib_core/Sys.inline`). When lib_core's Sys is made again,
  Bits is, then what names Bits, by the directory's own lines.
- STDSUM is in the INCLUDES of mkprog and mklib only, which have a
  .depend (mkfiles/mkdepend). The mkfiles that compile with STDI and
  no .depend (utilities/, kernels/...) do not read them, and so cannot
  keep a stale constant.
- lib_core's Sys: word_size and int_size the externals %word_size and
  %int_size, as OCaml's stdlib since 4.03 (old: get_config's word).
  Fold computes them from the target's bits; Lower too, when not
  folded.

Measured on arm64, mini-5i built by mini-ml with and without (HEAD's
Sys and mkfiles), running the same Plan 9 qsort (qst.exe 5000, 1.4
million instructions, the same output) under the host's mini-5i:
732.1 million instructions to 626.0 (0.855), 53.8 s to 46.2. In
Memory: Bits.native and m32 no longer read (17 times each),
ult32 and ule32 inlined into fits; mini-5i 8 KB smaller. A change to
Sys.ml made Bits and the units after it in machine/ again; nothing
else. Not yet: fits inlined into load8... (its body still past 16
nodes); arm's Bits.top (1 lsl 31: the width on arm, left to run).
