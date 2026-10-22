# Plan: ssa/, an optimizing back end in SSA form, beside simple/ and opti/

Status: **phases 1 to 3c done (SSA, -dssa; ssa's own emission;
registers; parallel moves), and ssa ahead of simple (2026-10-22: 0.57
to 0.91 of its instructions, floats aside); the mkfiles' flags, the
author's to choose; floats unboxed, a call's entry (zeroing), known
functions and inlining next.**
Written 2026-09-27. For mini-ml
first, then mini-cc. Companions: [`opti.md`](opti.md)
(the measurements that ask for it), [`simple.md`](simple.md)
and [`compat.md`](compat.md).

## The question

mini-ml's first `opti` passes (`tails`, `eqs`) stopped where passes of
the stack machine's own instructions stop: `fib` is still 3.22 times
ocamlopt's instructions, and its trace says why. A call costs a
prologue of 14 instructions (8 of them zeroing value-stack slots), an
argument goes to a slot and back to a register, `n < 2` tests at run
time that `n` is an integer, and the epilogue is 5 more. That is the
code generator's, not an instruction's: an optimizing back end is the
next step. ocamlopt's own is not SSA (Mach: virtual registers,
liveness, spill and reload, graph coloring); the author asked "should
we use a modern SSA as IR for mini-ml? (or mini-cc too)", then: "can
we make this SSA thing optional again? And keep the old compat/ and
simple/ and opti/ and then add SSA separately? (even to have an ssa/)",
and "can we also combine and have both the (existing) opti/ and also
ssa/ opti working for the same program?".

## Decisions

### 1. A back end of its own, in ssa/, behind a flag

```
languages/ml/
  compat/   Gas                     GNU's assembly (unchanged)
  simple/   Lower, Gen              the stack machine (unchanged)
  opti/     Opti                    passes on the stack IR (unchanged)
  ssa/      new                     SSA, its passes, allocation, emission
```

`mini-ml -ssa` picks it; without the flag mini-ml is what it is today.
`ssa/` reads `Lower`'s stack IR as it is and changes nothing in
`simple/` or `opti/` (the author's rule: optional, not polluting the
simple code path). If it needs something of `simple/`'s (the machines'
records, the data's layout), `simple/` exports it, and that is all it
gives. Like `opti/` and `compat/`, `ssa/` is out of `make loc`
(`scripts/stats/loc.py`, `.codemapignore`).

### 2. The stages compose

`-O` (opti's passes on the stack IR) and `-ssa` (the back end) are
independent, so the four combinations work, and are all tested:

| flags | pipeline |
|---|---|
| (none) | `Lower` -> simple's `Gen` |
| `-O` | `Lower` -> `Opti` -> simple's `Gen` |
| `-ssa` | `Lower` -> `ssa/` |
| `-O -ssa` | `Lower` -> `Opti` -> `ssa/` |

`ssa/`'s own passes each have their flag too (`-Ossa-copies`...), all
on with `-ssa` unless one is named, as `opti`'s with `-O`.

### 3. The contract between the two back ends: simple's ABI

Code by `-ssa` calls, and is called by, code without it (the stdlib
compiled either way, the runtime's C, the start): the calling
convention stays simple's. The closure in R0, the arguments in R1..,
the result in R0; the value stack's top in R26 (arm64) or R10 (arm),
raised by a function's frame; a handler's record as `ml_try` makes it,
`ml_raise` unwinding to it; an allocation through `ml_alloc` with
`ml_vsp` set. Inside a function, `ssa/` is free: which values live in
registers, which slots a frame has, what is zeroed.

### 4. SSA from the stack machine: Braun et al.

The stack IR goes to SSA directly, as JITs do from JVM bytecode: a
stack entry is a value, a frame's slot a variable, and Braun, Buchwald,
Hack, Leissa, Mallon and Zwinkau's "Simple and Efficient Construction
of Static Single Assignment Form" (CC 2013) makes the phis while it
reads the blocks (`readVariable`, `writeVariable`, `sealBlock`), with
no dominance frontiers; trivial phis removed as they are found. The
blocks come from the labels and jumps; a handler's entry (`Catch`) is
a block whose predecessors are the calls inside its `try`.

### 5. The collector's roots

mini-ml's collector (Cheney's, copying) finds its roots on the value
stack and moves them. So at a **safepoint** (an allocation, a call of
ML or of C, since each may collect), every ML value live across it is
in a value-stack slot, and read back after, the object perhaps moved.
Between safepoints values live in registers. This is ocamlopt's
constraint too (its frame descriptors say which stack slots hold roots
at each call); here the slots are the value stack's, which needs no
table. A slot is zeroed only if a safepoint can come before its first
write (the liveness says), not all at every entry: `fib`'s 8 stores.
`ML_HEAP=64` (a collection at almost every allocation) is the test.

### 6. Out of SSA, and registers

Phis become parallel copies on the edges (a critical edge split),
sequentialized with a temporary for a cycle. Then liveness, and
registers by **graph coloring** (Chaitin's, with Briggs's conservative
coalescing), as ocamlopt's `Interf` and `Coloring`: a value that does
not fit spilled to a slot. (Coloring the SSA form itself, chordal since
Hack's thesis, is the road to compare with once the first one works.)

### 7. The passes on SSA

In the order the measurements will ask for them, each measured by
`count.sh` (languages/ml/tests/): copy and constant propagation, dead
code, integer comparisons known by their operands (a tagged integer
compared with one: an `Int`'s, or a value that an integer operation
made), then value numbering if it pays. Scheduling is out: an
instruction count cannot see it.

## Phasing

1. **SSA and its dump**: blocks, Braun's construction, `mini-ml -dssa`;
   checked by construction's invariants (every use has one definition
   that dominates it) on the tests and the fuzzer's programs.
2. **Emission without optimizing**: every SSA value in its own slot,
   the simplest correct code, `-ssa` passing everything simple passes
   (`run.sh 5` and `7`, `ML_HEAP=64`, ocaml-light's tests,
   `TinyML_fuzz.py` live against ocamlopt), with and without `-O`.
3. **Registers**: out of SSA, liveness, coloring, safepoints; the same
   tests, then `count.sh`.
4. **The passes**, one at a time, each measured.
5. **mini-cc**: a `languages/c/ssa/` from its stack IR (no collector,
   7c's calling convention); what the two really share then moves to a
   common library, not before.

*Phase 1 done (2026-09-27)*: `languages/ml/ssa/` (`Ssa`, the library
`ix_ml_ssa`), `mini-ml -dssa`. Blocks from the stack code's runs (a
try's handler a successor of the block its try ends; the runs the
entry does not reach dropped, as Gen drops dead code; an empty entry
before a first label, which opti's `tails` makes a loop's head); each
block's stack depth by a forward flow; Braun et al.'s construction
(slots and the stack's positions at a block's edge as variables, a
block sealed once its predecessors are filled); the trivial phis out
by a fixpoint; a function with a handler keeps its slots in memory for
now. The check (every use dominated by its definition, by Cooper,
Harvey and Kennedy's dominators; a phi's operands its block's
predecessors) passes on ocaml-light's 41 stdlib units, `tests/tiny`,
`bench/`, ocaml-light's 16 test programs and 100 of the fuzzer's, each
with and without `-O`: 348 runs, some 6,250 functions. `count` with
`-O` is a loop in SSA:

```
b1:		; from b0 b3
	v4 = phi [b0 v1] [b3 v10]
	v6 = phi [b0 v2] [b3 v8]
	v3 = int 0
	v5 = cmp eq v4 v3
	br v5 b2 b3
```

(the closure, never read, has no phi: Braun's construction makes one
only where a variable is read).

*Phase 2 done (2026-09-27)*, `mini-ml -ssa`, correct before fast (the
author: "correct before fast! I totally agree"). The simplest correct
emission is none of ssa's own: each function goes through SSA and back
to the stack machine, every value in a slot of its own, and simple's
`Gen` compiles that. An instruction is its operands pushed from their
slots, its stack instruction, its result stored; a phi a parallel copy
at each predecessor's end (all pushed, then all stored), on an edge of
its own when the predecessor branches; a parameter is the slot the
prologue stores it in, a never-written variable a slot the prologue
zeroes. So calls, allocations, handlers and the collector's roots are
simple's by construction, and the construction and its destruction
are tested end to end. All four combinations of decision 2 pass:
arm64, live against ocamlopt and with `ML_HEAP=64`, `tests/tiny`,
`bench/`, ocaml-light's 16 tests and 100 fuzzer programs; arm, `make
test-ocaml`'s nine and `bench/`; 0 failures. Slower, as expected
(every value in memory): fib 4.72 times ocamlopt's instructions, tak
4.28, where simple with `-O` is 3.22 and 2.58. Phase 3 replaces the
way back to the stack machine by ssa's own emission, with registers.

*Phase 3a (2026-09-27)*: `Emit`, ssa's own emission, every value still
in its slot, simple's ABI reproduced (the prologue, the calls, C's with
`ml_vsp`, `ml_alloc`, `ml_try` and `ml_raise`'s records) and each
operation simple's sequence, operand for operand (the first try had
three operands swapped: `CMP Rb, Ra` is b - a); the data still simple's
`Gen`'s, on a unit without functions. `-ssa` is Emit's; `-ssa-stack`
keeps phase 2's way, to bisect with. All four combinations pass, both
machines. fib 4.42, tak 4.55.

*Phase 3b (2026-09-27)*: `Alloc`, registers. Liveness at the blocks'
edges (a backward dataflow, a phi's operand live at its
predecessor's end); memory for what the collector must see (a value
live across a safepoint: an allocation, whose fields are read after
it, a call of ML or C, a polymorphic comparison, which may call
`compare`; a value live into a handler, since a raise restores no
register; a parameter); the others colored in the dominator tree's
order, each the lowest register no value live after its definition
holds, which for SSA's chordal interference is optimal (Hack, 2006):
the plan's Chaitin-Briggs is now the variant to compare. R20-R25 on
arm64 (not the arguments' R0-R15, not the scratch, not R18 and R19,
which `ml_raise` and a far slot use); arm has none free and stays as
3a, which keeps that path tested. `Emit` reads a value's register
directly and computes into the result's, in three-operand forms of
simple's sequences. All four combinations pass, both machines. The
counts (`count.sh`, `-O -ssa`, against simple's `-O`): fib 2.85 (3.22),
loops 5.04 (6.13), tak 3.13 (2.58): tak's loop (opti's `tails`) has
three phis, each copied through the staging slots, which 3c removes.

*Phase 3c and after (2026-10-22)*, toward ssa as the back end the
mkfiles use (the author: "let's do it", for keeping loops' values in
registers, after the profiler showed mini-doom's to_rgba at 55
instructions a pixel; "keep them under opti/ and/or ssa/"; "what
matters is the ratio of added lines in mini-ml compared to the
speedup it provides to most programs"). Measured by `tests/bench.sh`
(the loops of three of ix's programs, besides fib, tak, maps and
sched), each step against the last; `-O -ssa`'s instructions as a
share of simple's (no flag); lines of code, about (262 in all, 80 of
step 1's simple's sequences again):

| step | lines | pixels arm | limbs arm | sched arm | pixels arm64 | limbs arm64 |
|---|---:|---:|---:|---:|---:|---:|
| `-ssa` before (a byte, a float, a block: the runtime's calls) | | 3.26 | 1.26 | | 3.00 | 0.76 |
| 1. Prim: bytes, floats in place, blocks inline (simple's Gen's) | +100 | 1.41 | 1.24 | 1.30 | 1.28 | 0.74 |
| 2. opti's `refs` (a ref a variable), `drops`; tails past 7 | +51 | 1.39 | 1.19 | 1.21 | 1.51 | 0.99 |
| 3. constants made where read, parallel copies, arm's R4-R8 and arm64's R4-R15 | +40 | 1.00 | 0.97 | 0.82 | 0.81 | 0.64 |
| 4. the values chosen by their loops' weight | +34 | 0.82 | 0.72 | 0.82 | 0.81 | 0.64 |
| 5. a comparison fused with its branch; small constants as operands | +37 | **0.67** | **0.64** | **0.74** | **0.65** | **0.57** |

Step 2 alone made `-O -ssa` worse: a ref made a variable is a phi at
its loop's head, and the phis' copies went through memory; step 3's
parallel copies are what it needed. fib 0.82, tak 0.91, maps 0.88 on
arm after step 5; samples (floats) 1.06, the only one worse: each
float a block, a safepoint at each operation (unboxing next). mini-doom
on arm, its own units by `-O -ssa` (the libraries and the stdlib
simple's), a frame of 30 walking: 43.2 million instructions, 37.4
(the same picture). mini-ml by mini-ml writes the same assembly as by
OCaml. The tests (`tests/tiny`, `runtime`, `bench`, `ML_HEAP=64`, both
machines, `-ssa` and `-O -ssa`) fail as without (arm's 64-bit outputs,
costs and marshalling).

*The mkfiles' flags (2026-10-22)*: `mini-ml -O3`, every optimization
mini-ml has (opti's passes and `-ssa` today, what is added later with
them), and `-O0`, none (the author: "let's have a -O3 indicating max
opti so that as we add stuff, we don't have to modify the mkfiles and
always use -O3. we will probably also want to make sure things also
compile without opti, so sanity check the simple code generation").
mkconfig's `ML` has `$MLOPT`, `-O3` unless the environment sets it
(`mkfiles/config.rc`): `MLOPT=-O0 mini-mk` builds the tree the simple
way, and `MLOPT=-O0 tests/lite.sh` checks it. Both pass `make
test-lite` (ix built by ix from nothing, the games' recorded frames, a
kernel's step and mini-xv6 booted); mini-9pi's programs and image
built with `-O3`.

The macro set (the author: mini-doom's and mini-quake's frames a
second under QEMU, cameltry, rebirth, xv6, mini-ml itself, m-ix built
under m-ix), two copies of the tree built for arm, `MLOPT=-O0` and
`-O3`, every unit by its flag (`tests/macro.sh`: a frame, frames 31 to
61 of a walk, by mini-5i's count; mini-ml compiling Lower, Typing and
Ssa_build):

| | -O0 | -O3 | |
|---|---:|---:|---:|
| mini-doom, a frame | 43,583,340 | 37,488,660 | 0.86 |
| mini-quake, a frame | 62,624,537 | 51,976,850 | 0.83 |
| cameltry, a frame | 4,970,497 | 4,528,236 | 0.91 |
| mini-ml compiling three of its units | 11,654,716,315 | 10,353,188,555 | 0.89 |

Under QEMU (mini-9pi on raspi1ap, a card of each tree, `live.py` with
LIVE_START=6: the up arrow before doom reads the keyboard is lost),
mini-doom's 40 frames walking, one run each: -O0 7.5 s (the view 49
ms, the showing 78), -O3 6.7 s (37 ms, 95): 5.3 frames a second to
6.0, the view 24% less; the showing varies by run. (mini-ml's row was
first 349 million to 301: mini-ml stopping at a statx mini-5i did not
have, which it has since.) The flags' own cost, the same three units:
-O3 is 1.0% more instructions to compile than -O0 by a mini-ml built
-O0, 0.6% by one built -O3: compiling without the optimizations saves
nothing worth having (the author's question, for m-ix built under
m-ix), and mini-ml built -O3 compiles 11% faster. Not measured yet:
rebirth (in mini-9pi's build, not Linux's), xv6, m-ix under m-ix.

## Tests and numbers

The four combinations of decision 2 through the same tests, on both
machines; `count.sh` (`ML_FLAGS=-ssa`, `ML_FLAGS="-O -ssa"`) against
ocamlopt, beside simple's and opti's numbers in opti.md.

## Out of scope, for now

Inlining, float unboxing and scheduling (ocamlopt has them; each a
later pass, measured); an SSA shared with mini-cc before mini-cc's
own exists.
