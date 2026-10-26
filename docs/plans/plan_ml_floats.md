# Plan: mini-ml's floats not boxed, in a function, in a ref and in an array (`plan_playground_speed.md`'s M4)

The author (2026-10-26), of mini-virtuaracing's frame being 17 times its
budget on arm (`plan_virtuaracing.md`'s Status, stage 2): chose
"mini-ml floats unboxed (M4)" over fixed point in the game's renderer.
The choice is for every float program, not one game: the audio
(`plan_audio.md` waits for M4 in four places), the playground's 3D,
the physics. mini-virtuaracing's stage 3 waits for it.

## Where a float costs today (the survey, 2026-10-26)

A float in mini-ml is a block of its own (two words of the double and a
header: `Double_tag`, `runtime/floats.c`), always. Three things make
mini-virtuaracing's frame pay for it (`Render`, read by `mini-5i -prof`:
the collector 25% of the frame, `fill` and `face`, all floats, 38%):

1. **Each float result is a new block.** `Lower.floats_in_place` made
   `+.` the processor's (`Ir.Float2`): `Emit` loads both operands' bits
   from their blocks into F0 and F1, adds, and allocates a block for
   the result (`float_result`). In `(x *. rx) +. (y *. ry) +. (z *. rz)`
   that is five blocks, of which one is kept. And each new float is a
   safepoint (`Alloc.safepoint`): the collector may run there, so no
   value stays in a register across it.
2. **A `float array` holds pointers.** `r.vx.(i) <- e` allocates e's
   block and stores its address with the write barrier (`ml_modify`,
   7% of the frame by itself: the generations' remembered set). OCaml
   keeps a float array flat, the doubles themselves (`Double_array_tag`).
3. **A `ref` is a block**, at -O0 only. At -O and -O3 (every build of
   the mkfiles), Opti's `refs` (ocaml-light's `Simplif.eliminate_ref`,
   on the stack code) makes a ref that does not escape a slot of the
   frame: `let ymin = ref 0. in ... ymin := Float.min !ymin y` is a
   slot set, no block, no barrier. What stays is the new float that
   `Float.min` returns: cost 1's. (This survey said first that a ref
   was always a block, and stage 2 was written for it: corrected
   below.)

OCaml does all three (its Cmm's unboxing of a let-bound float, flat
float arrays and float-only records, refs as mutable variables;
mini-ml the third already): the
reason mini-virtuaracing's frame is 7.5 ms by OCaml and 185 by mini-ml
on the host, 25 times where mini-doom's (integers) is 2.5.

## Decisions (mine, for the author's review)

1. **Refs that do not escape are slots of the frame**: there already,
   Opti's `refs` (`-Orefs`, in -O and -O3). Nothing to do but a test
   (`tests/runtime/refs.ml`: the refs it makes slots and those it
   leaves blocks, the same answers at -O3 and -O0). Written first in
   `Lower`, then found to be the same pass, and taken out.
2. **Floats in registers inside a function: the SSA back end's.**
   `Ssa` gets a second kind of value, a double in a floating-point
   register (arm's VFP D registers, arm64's), beside the word. Made by
   `Float2`, `Float1`, `FloatOfInt` and by loading a float's bits (an
   operand that is a block); used by those and by `FloatCmp` and
   `IntOfFloat` as they are. A block is made only where the value
   leaves as a word: stored, passed to a call, returned, raised, a
   phi's operand of a word. Then `+.` of `+.` is no block, and once
   decision 1 has made a loop's float ref a phi, the loop's float stays
   in a register from turn to turn. A double is not something the
   collector reads, so it may stay in its register across a block's
   allocation (unlike a word, which `Alloc` keeps out of registers at
   safepoints): it is spilled at a call only, to slots the collector
   does not scan. `Alloc` gets a second class of registers. The simple
   back end (`Gen`) stays as it is: the stack machine's simple code is
   the teaching one, `-ssa` the optimizing one.
3. **Flat float arrays by `Float.Array`, OCaml's `floatarray`** (not
   OCaml's `float array` made flat). The two ways:
   - `float array` flat, as OCaml has it since the 1990s: `Array.make n x`
     looks at x and makes a flat array if it is a float; then every
     array operation whose element type the compiler does not know
     (`Array.get` in a polymorphic function, `Array.blit`, `sub`,
     `append`, `compare`, `Hashtbl.hash`, `Marshal`, `Obj`) tests the
     array's tag at run time. All of `lib_core/collections/Array.ml`,
     the runtime's arrays, compare, hash and marshal change, and every
     program's polymorphic array pays a test. OCaml itself has been
     backing away from it (`-no-flat-float-array`, 4.06, and
     `floatarray` given its own type for that reason).
   - `Float.Array` (OCaml 4.08's: `Float.Array.make`, `get`, `set`,
     `unsafe_get`, `length`...): its own type, always flat. dune's
     builds have it from OCaml's stdlib already; mini-ml needs it in
     `lib_core/base/Float.ml`, a tag of its own (`Double_array_tag`),
     a few primitives (`%floatarray_unsafe_get`... which `Lower` makes
     `Emit`'s loads and stores of doubles, no barrier: no pointer) and
     their C fallbacks. A program opts in where it matters (`Render`'s
     corners, the mixer's buffers), and nothing else changes.

   Proposed: `Float.Array`. Less code, no cost to the programs that do
   not use it, and the same text in both compilers.
4. **The same bytes.** None of this changes a result: a double in a
   register is the double that would have been in a block. Not fusing
   `a *. b +. c` stays a rule (arm64's OCaml fuses: notes in
   `games/tests/frames.sh`), so mini-ml's frames before and after are
   the same bytes, which is each stage's check.
5. **Measured as before**: `mini-5i -s` and `-prof` on arm, the
   programs' frames' instructions (mini-virtuaracing, mini-doom,
   mini-quake), `tests/bench.sh` and a new `tests/bench/floats.ml`
   (a dot product, a float ref's loop, a float array filled), and
   mini-ml compiling itself (which has few floats: it should not move).

## The stages (each checked before the next)

1. **The measure first**: `tests/bench/floats.ml`; the numbers of
   today, in a table here.
2. ~~Refs as slots~~ (decision 1): Opti's `refs` does it already; its
   test, `tests/runtime/refs.ml`.
3. **Floats in registers** (decision 2), arm then arm64. Check:
   tests/tiny and tests/runtime on arm and arm64, -O3 and -O0, with
   ML_HEAP=64; mini-ml built by mini-ml writes the same assembly as by
   OCaml; the games' frames the same bytes; `make test-lite`; the
   table.
4. **`Float.Array`** (decision 3). Check: tests/runtime (new: a float
   array's make, get, set, blit, length, compared to OCaml's output);
   `make test-lite`.
5. **mini-virtuaracing's `Render` on `Float.Array`**, its frame
   measured again (back to `plan_virtuaracing.md`'s stage 2: the faces
   turned away dropped, the start's searches). Then the audio's rows
   that waited for M4, said in `plan_audio.md`, not done here.

## Open questions

- **The registers across a call.** arm's VFP has D8 to D15 kept by
  the callee in C's convention; mini-ml's code is not C's. Spilling
  every live double at each call is simplest; measured at stage 3
  before anything else is tried.
- **Float-only records flat** (OCaml's), `Render`'s `mutable focal :
  float`: a read is a load today, cheap; a write is a block. Not in
  this plan unless a profile says so.
- **The simple back end** (`Gen`, -O2 and below) keeps boxed floats:
  is that right for the Pi 1's builds? They are -O3 (games/mkfile).

## Status

2026-10-26: plan written, after the survey above (the author: "yes I
agree, let's do it!").

**Stage 1 done, the measure.** `tests/bench/floats.ml`, new (Render's
corners turned into arrays, its rows' ymin and ymax, a sum in a ref),
in `tests/bench.sh`; `games/frame_count.sh`, new (a frame of
mini-doom, mini-quake, mini-virtuaracing by `mini-5i -s`, two runs'
difference). HEAD's numbers (b58ee632; arm by mini-5i, arm64 by
`tests/icount.c`), mini-ml -O3:

| | arm | arm64 | OCaml 4.14, arm64 |
|---|---|---|---|
| `floats` (bench) | 18.25 million | 16.34 | 2.77 |
| `samples` (bench: the audio's sine) | 12.08 | 11.28 | |
| a frame of mini-virtuaracing (the grid) | 194.97 | | |
| its start | 7,482 | | |
| a frame of mini-doom (frames 1 to 31, up held) | 12.83 | | |
| a frame of mini-quake (frames 1 to 31) | 32.10 | | |

`floats` by `mini-5i -prof`: `turn` 40% (its nine products and six
sums a corner, five blocks each row of three, and three stores with
the barrier: `ml_modify` 6%, `ml_alloc` and `copy` 7%), `sum` and
`rows` 6% each, and **`Float.min` and `Float.max` about a quarter**
with what they call (`cmp`, `is_nan`, `sign_bit`, `compare`, `copy_int64`, `div`):
lib_core's, OCaml's, which finds a float's sign by its bits as an
`Int64`, boxed in mini-ml. Not in this plan's decisions; said at the
end, since `Render.fill` calls both for each corner.

**Stage 2: nothing to do**, the survey was wrong: Opti's `refs`
already makes a ref that does not escape a slot (decision 1, corrected
above). Its test added, `tests/runtime/refs.ml` (13 one-field blocks
at -O0, 6 at -O: the 7 meant), run on arm and arm64 at -O0, the default,
-O3.

Found on the way, for later: `Float.min` and `Float.max` without the
`Int64` (the sign by `1. /. x < 0.`, or a primitive of the sign's bit),
a few lines of lib_core; the other programs that use them gain too.

2026-10-26: **stages 3 and 4 done** (the author: "let's do it", for
stage 4).

Stage 3, floats in registers: `ssa/Unbox.ml` (its `.mli` says how,
with an example), between `Ssa_build` and `Alloc`: the doubles (what
`Float2` and `FloatOfInt` make, the phis one reaches) and Ssa's
`Unbox`, `Box`, `Dprim`; `Alloc` colors them apart with the
floating-point registers (F2 to F14 on arm, F15 the linker's; F2 to
F15 on arm64), to memory only across a call (`clobbers`: a call of ML
or of C, compare's), into slots of the machine stack the collector
does not scan (`Dmem`); a function with a handler left as it was.
`-boxed-floats` turns it off; `-dssa` shows the form after it. Found
by the tests: arm64's frame must stay a multiple of 16 (the slots'
8 bytes broke it; rounded).

Stage 4, `Float.Array` (decision 3): lib_core's `Float.Array`, OCaml's
names (make, init, create, get, set, the unsafe two, length, fill, blit,
copy, to_list, of_list, iter, fold_left), its block tag 251
(`Double_array_tag` in mlvalues.h: OCaml's 254 is mini-ml's Int32), not
scanned by the collector; Ir's `FloatIndex` and `FloatSetIndex`, the
runtime's functions in simple's code, a double's load and store in
ssa's (no block, no barrier); compare by the floats, Marshal in
OCaml's codes (0x0E, 0x07: `tests/runtime/float_array.ml` prints the
bytes, OCaml's own). mini-virtuaracing's `Mesh` (corners, normals) and
`Render` (the corners turned, cut, projected; the rows' edges) on it.

And the collector (found by stage 3's measure, mini-virtuaracing's
frame on arm 1.56 times HEAD's over 20 frames): its table of the old
fields made to point to young blocks (`refs`, 4,096 entries) filled
between two minor collections once the floats made far fewer blocks,
each store of a float in a `float array` still a new block, and a full
table made the next minor collection scan the whole old generation
(the course's meshes, megabytes). Now at seven eighths of the table a
minor collection is asked for (`ml_limit` at `ml_hp`), OCaml's way
(gc.c's refs_soon; ml_modify's assembly in `Gen.startup`, `ml_store`).

Arm, mini-5i -s, mini-ml -O3 (`games/frame_count.sh`, its frames;
mini-virtuaracing's 3 to 23):

| | HEAD | stage 3 | 3 and 4 |
|---|---|---|---|
| a frame of mini-virtuaracing | 201.1 million | 164.2 (with the collector's change) | **111.0 (0.55)** |
| its start (to frame 3) | 7,872 | 6,805 | 5,327 (0.68) |
| a frame of mini-doom | 12.83 | 11.81 | 11.78 (0.92) |
| a frame of mini-quake | 32.10 | 26.36 | 25.84 (0.80) |
| `floats` (bench) | 18.25 | 12.86 | 12.62 (0.69) |
| `samples` (bench) | 12.08 | 10.90 | 10.96 (0.91) |

The other benchmarks (`pixels`, `limbs`, `fib`, `tak`, `maps`, `sched`)
within a few hundred instructions of HEAD's. On arm64, the host:
mini-virtuaracing's frame 565 million instructions (`tests/icount.c`,
frames 1 to 3) to 286 by stage 3.

Checked: tests/runtime (new: `refs.ml`, `float_array.ml`), the
benchmarks, tests/tiny on arm and arm64 at -O3, the default and -O0,
with ML_HEAP=64 (tiny's `arith` fails on arm as before: its numbers
are 64 bits', and lite.sh runs tiny's on arm64); with ML_YOUNG=256 too
(`gc` past run.sh's 20 s on arm under qemu, 73 s, the same with the
old rule); every recorded frame by mini-ml (mini-mk, arm64): the
games' 56, the examples' 33, mini-office's 26, mini-drscheme's 8, the
same bytes; mini-virtuaracing's on arm (qemu-arm) the same as HEAD's;
mini-ml built by mini-ml writes the same assembly as by OCaml (98
files, arm and arm64, `Render`, `Float`, `Marshal` among them); the
runtime compiled whole (228 functions: a C comment of mine ended as
OCaml's, `*)`, and swallowed `ints.c` silently, found by a link's
undefined symbol); mini-ml compiling three of its big files as fast
(0.44 s, 0.43 without); `make test-lite`, 70 jobs, 0 failures. Not
run: mini-9pi, the boards.

What is left, for the frame (`plan_virtuaracing.md`): 111 million
against 10 to 12. The game's own cuts next: the faces turned away
dropped, `Float.min` and `Float.max` without their `Int64` (lib_core),
a constant unboxed in a loop at each turn (Unbox could take it out),
the start's two searches.

2026-10-26, then (the author: "let's do 1 then 2": mini-virtuaracing's
frame profiled, then its cheap cuts):
- **floor and ceil without a call**: Ir's `FloatRound` (Lower's for
  `floor_float` and `ceil_float`; a call still in simple's code), a
  double in ssa's (Unbox), Emit's `round`: a double of 2^52 or more,
  an infinity, a nan, itself; below, x + 2^52 - 2^52 (x - 2^52 + 2^52
  for a negative x) and one step down or up; a zero x *. 0.0, its sign
  (the runtime's signed_zero). The same bits as the runtime's
  (`tests/runtime/floor.ml`: halves, -0., the 32 bits' edges, beyond
  2^52, infinities, nan). The constants the runtime's `ml_round`; a
  third scratch register for it (F14 on arm, the values' F2 to F13;
  F16 on arm64). The profile had ceil's call a fifth of the frame
  (85,600 a frame, 160 instructions each with its new float).
- **A word unboxed once**, after its definition, for all its reads;
  a float literal at the function's entry, once a symbol: a loop's
  constant no longer loaded at each turn. Found by its tests: an
  Unbox put between two parameters broke Emit's prologue (it loads
  them all at the entry, and Alloc gave the second the first's
  register, the first dead at the Unbox): what follows a parameter
  now goes after the last one (Unbox's `later`).

Arm, mini-5i: mini-virtuaracing's frame 63.5 million to **53.3**
(frames 3 to 23), its start to frame 3 2.91 billion to 2.85; the
benchmarks `floats` 7.97 to 7.73, `samples` 6.61 to 6.60, the others
the same. Checked: tests/runtime, bench, tiny on arm and arm64, -O3
and -O0; all 123 recorded frames by mini-ml; mini-ml by mini-ml the
same assembly (94 files); make test-lite, 70 jobs, 0 failures.
