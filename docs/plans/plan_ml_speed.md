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
- **`.depend`**, a directory's, by `mkfiles/depend.rc` (`mini-ml -uses`:
  the units whose values a unit names, not `-M`'s, which are every
  interface read, and make cycles in lib_core): `mini-mk depend` at the
  top, after a build, for every mkfile that includes mkprog, mklib or
  games/mkgames or has a depend target (lib_core's, tiny's,
  kernels/singularity's, apps/misc's, lib_graphics/tests', windows',
  windows/tests', profilers/misc', and the three games'). 74 files.
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
