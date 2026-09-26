# Plan: ssa/, an optimizing back end in SSA form, beside simple/ and opti/

Status: **phases 1 and 2 done (SSA, -dssa; -ssa correct); phase 3,
registers, next.**
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

## Tests and numbers

The four combinations of decision 2 through the same tests, on both
machines; `count.sh` (`ML_FLAGS=-ssa`, `ML_FLAGS="-O -ssa"`) against
ocamlopt, beside simple's and opti's numbers in opti.md.

## Out of scope, for now

Inlining, float unboxing and scheduling (ocamlopt has them; each a
later pass, measured); an SSA shared with mini-cc before mini-cc's
own exists.
