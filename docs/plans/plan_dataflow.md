# Plan: a monotone dataflow framework and abstract interpretation (`lib_code/Dataflow`)

The author (2026-11-04), after notes_analysis.md was written: "Do we have
the kildall and abstract interpretation and other basics implemented
somewhere in analyzers/ ?", "(and dataflow monotone style framework)",
then, told that only instances exist and no framework: "yes let's write a
plan for it".

The short answer: **one solver, Kildall's, over any lattice given as a
record of functions, forward or backward, with widening; liveness
rewritten on it and checked against the four copies ix has; reaching
definitions and constant propagation as the next instances; then
intervals, the first abstract interpretation in ix, whose client is
mini-ml's own speed (a loop's counter untagged, an index's bounds check
dropped), not a bug report.** About 150 lines for the solver and the
lattices, 100 to 150 a client. Nothing of this plan is written.

**Status: planned (2026-11-04).**

## What there is

| | where | what |
|---|---|---|
| liveness, OCaml | `lib_code/Liveness` (38 lines) | SSA's, a loop to its fixpoint, used by mini-ml's and mini-cc's `ssa/Alloc` |
| liveness, OCaml | mini-cc's `Opti` (regs), `Peep` | C's variables, the machine's registers: their own loops |
| liveness, Datalog | `analyzers/datalog/liveness.dl`, `liveness_ssa.dl` | the equations as rules; the same sets as the compilers' (`analyzers/c/tests/ix.sh`, `analyzers/ml/tests/ix.sh`) |
| dominators | `lib_code/Dominators`, `dominators.dl` | a path property, no lattice |
| a bound on a value's bits | mini-ml's `ssa/Untag` | a domain without the name: a byte 8 bits, `x land 63` 6, a sum one more; no loop: "a loop's counter, a sum of a tagged value: tagged, as before" |
| constants | mini-ml's `simple/Fold` | a toplevel constant folded on the tree, not a dataflow |
| 31-bit ints | `bugs/intwidth.dl` | a large constant's flow; intervals were plan_bug_analyses.md's A4 step 2, judged not worth it for bugs |

So Kildall's framework is in ix four times as liveness, each with its
lattice, its direction and its loop written in, and abstract
interpretation not at all. notes_analysis.md §3 teaches both on toys
and can point at no general code.

## Decisions (proposed)

1. **A lattice is a record of functions, not a functor.** mini-ml has no
   functors (ocaml-light has none), and ix compiles with both compilers:
   ```ocaml
   type 'a lattice = {
     bottom : 'a;
     leq : 'a -> 'a -> bool;
     join : 'a -> 'a -> 'a;
     widen : 'a -> 'a -> 'a;     (* join, for a lattice of finite height *)
   }
   ```
   A powerset of ints (`Set_`) is one value of it, intervals another.
2. **The graph is functions too**, as `Liveness.ssa` takes them: nodes 0
   to n - 1, `succs`, `preds`, the entries. A node is a block; what an
   instruction does inside its block is the transfer function's to fold.
   Neither the SSA's types nor the stack code's are known to `lib_code`,
   so both compilers' SSA, mini-cc's `Ir` and `Ssa_facts`' facts can be
   given.
3. **One solver, two directions, a worklist in reverse postorder**
   (backward: of the reversed graph). Kildall's iteration, Kam and
   Ullman's conditions said in the `.mli`: monotone transfers, finite
   height or a widening, and the answer is then the least fixpoint, the
   meet over all paths when the transfers distribute.
   ```ocaml
   val forward :
     'a lattice -> graph -> init:'a ->
     transfer:(int -> 'a -> 'a) -> edge:(int -> int -> 'a -> 'a) ->
     'a array * 'a array          (* in and out of each node *)
   val backward : (* the same, the in and out exchanged *)
   ```
   `edge` refines a fact along one edge: a `Br` on `x < n` gives `x <
   n` to its true successor, what intervals need; sets pass `fun _ _ s
   -> s`. Required, not `?edge`: lib_core's interfaces have no optional
   argument, mini-ml being the other compiler.
4. **Widening where loops close.** `widen` is applied at a node with an
   entering back edge (`Dominators`: the target dominates the source),
   and nowhere else; then a few rounds of narrowing (a plain
   re-iteration, decreasing) take back what the widening lost at the
   exit. Bourdoncle's weak topological order (1993) is the better choice
   of widening points; loop headers by dominators are what ix has.
5. **The simple path first, the old code kept** (optimization style).
   `lib_code/Liveness` stays the compilers' until the framework's
   liveness gives the same sets on every ML and C function of ix and
   costs no more (mini-ml's build of itself timed, `make loc`'s lines
   counted). Then it is replaced, its loop kept as an `old:` comment, or
   not, by those numbers.
6. **A client in a compiler goes in its `opti/`** (plan_datalog.md's
   decision 10): a switch each, none on by default, the compiler without
   it the one of today.
7. **No Datalog engine change.** Lattices in mini-datalog (Flix's) are
   another plan; intervals are OCaml's. What the analyses compute may be
   written as facts after (`range(V, Lo, Hi)`), for rules to read.

## The stages (each checked before the next)

1. **The solver, and liveness on it** (`lib_code/Dataflow`, its `.mli`
   teaching as headers do: the framework's history, a diagram, the
   conditions). Liveness of an SSA function as a backward instance over
   `Set_`. Check: the same sets as `Liveness.ssa` on every function
   `analyzers/ml/tests/ix.sh` reads, and on mini-cc's through
   `analyzers/c/tests/ix.sh`'s functions; toys in `lib_code/tests/`
   (the liveness of notes_analysis.md §3, as `liveness.facts` says it).
2. **Reaching definitions and constant propagation.** Reaching
   definitions on mini-cc's stack code, where a variable is written
   several times (in SSA it is trivial: a value has one definition);
   constant propagation on both SSAs, the lattice of one constant, top
   and bottom, a branch on a constant making its other edge dead
   (Wegman and Zadeck's conditional propagation, dense first). Check:
   toys by hand; on ix, the constants found against `Fold`'s on the same
   units (Fold's inside the framework's, decision 7b's containment).
3. **Intervals, with widening and narrowing.** A bound is `Neg_inf | Int
   of int | Pos_inf`; arithmetic on bounds saturates to the infinities
   rather than wrapping, since the analyzer's own int is 31 bits when
   mini-ml builds it for arm (and the target's width is a parameter: a
   value past it is top). The transfers of `Op`'s integer operations,
   `land` with a constant, `ByteGet`, `Array.length`; the edges of `Br`
   on a comparison. Check: notes_analysis.md §3's loop, `x` in `[100,
   100]` at the exit, as a toy; every `Untag` bound inside the
   interval's bits on every function of mini-ml (containment again: the
   new domain must not be less precise than the one it generalizes).
4. **The client: mini-ml's speed, in `opti/`.** Two switches, each
   measured by plan_ml_speed.md's benchmarks (`tests/bench.sh`, the
   games' frame counts) on arm, the Pi 2 first:
   - `-Ountag-loops`: a loop counter whose interval fits the target's
     bits untagged, what `Untag` cannot do for want of a fixpoint;
   - `-Obounds`: an `Index` whose index is in `[0, Array.length a - 1]`
     by its interval, the check dropped (`for i = 0 to Array.length a -
     1`, the common case).
   Check: every test of mini-ml the same with and without each; the
   fixpoint of ix built by ix still reached; each switch a row of what
   it bought.
5. **The tutorial pointed at it.** notes_analysis.md §3: the solver's
   signature, liveness's instance, the widening listing checked by
   `lib_code/tests/` instead of "a sketch, not in ix". And a sign or
   parity domain as one more toy instance, a few lines, for teaching
   only.

Not in this plan: relational domains (octagons, polyhedra: a relation
between two variables, `i < n` kept after the branch); the heap's values
(Adler's `b`, a ref, plan_bug_analyses.md's reason to skip A4's step 2:
intervals over the SSA's locals do not reach the heap); interprocedural
intervals (each function alone, its parameters top; a summary's job,
plan_analysis_scale.md); a bug analysis by intervals (A4 step 2's
reasons stand); lattices in mini-datalog; the sparse forms (SCCP over
def-use chains, a sparse interval analysis), which follow if stage 2 or
3's dense solver is slow on mini-ml's big functions.

## Open questions

- **Where its tests go.** `lib_code/` has none today; `lib_code/tests/`
  with a `run.sh` in make test, or the toys in `analyzers/`, the
  framework being used there too?
- **mini-cc's `Opti` and `Peep`**: their liveness on the framework as
  well (stage 1), or left as 5c's, their twin's shape?
- **How much stage 4 buys is not known.** plan_ml_speed.md's pixels
  bench says the tags cost 11 of 35 instructions in mini-doom's span;
  how many of ix's hot loops have a counter the intervals can bound, and
  how many bounds checks are in them, is to measure before the switches
  are promised: a count over mini-ml's own SSA (the loops found, the
  counters bounded, the `Index`es proved) is stage 3's last check.
