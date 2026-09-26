# Plan: opti/, the originals' optimizations, freely

Status: **done for mini-cc (`-simple -O`); next mini-ml, then the
emulators (mini-5i, mini-qemu); the rest analyzed and left.** Written
2026-09-26. Companions: [`plan_compat.md`](plan_compat.md) and
[`plan_simple.md`](plan_simple.md).

## The idea

A twin reproduces its original's behavior, often without its
optimizations (mini-cc is 5c at `-O0`, mini-ml a stack machine where
ocamlopt allocates registers, the emulators interpreters where QEMU
translates). An `opti/` brings those optimizations back **by their
ideas, not their code**: the author, choosing between a byte-for-byte
`-O2` twin of 5c's `reg.c` and `peep.c` (2,700 lines of C per machine,
their bugs included) and the ideas freely, chose "free, in opti/",
"done in a more elegant/modern way".

The method, the one the author's rule for optimizations already asked
("we can optimize if the optimization keep the simple code path clear
and optimization can be separated clearly in a different section and
enabled/disabled", 2026-09-25):

- **measure first**: where the simple code spends what the original's
  does not (mini-5i's `-s` counts a program's instructions, `-t`
  traces them), and choose the passes by that;
- **each pass its own flag**, and one for all (`-O`), the program the
  same without them;
- **tested by behavior**, the same tests as the simple code, with the
  optimizations on (and libc compiled with them, for mini-cc);
- **measured after**, each pass's share (`languages/c/tests/count.sh`
  prints them added one at a time);
- **out of the count**: `make loc` leaves `opti/` out, as `compat/`.

## Done: mini-cc

`languages/c/opti/` (`ca8468f`, `9d44923`), `mini-cc -simple -O`, or
`-O<pass>`. On the stack machine's code (`Opti`, IR in, IR out, before
`Gen`):

- **incs**: `x++` as a statement is `++x`; of a variable, as a value,
  its old value kept by a `dup`;
- **places**: a variable's load or store at its address, found by the
  stack's height (each instruction's slots read and pushed);
- **imm**: immediates, and shifts for multiplications by powers of 2;
- **branch**: a comparison and its jump one compare-and-branch;
- **drops**: no move for a stored value then dropped, no conversion
  that changes no value, no `swap` before a commutative operation;
- **regs** (5c's `regopt`, freely): variables whose address is never
  taken in registers (arm64's R19-R25, F17-F23), chosen by uses
  weighted by loop depth less the calls they are live across (a
  backward liveness dataflow), saved to their slots around calls.

And on `Gen`'s instructions (`Peep`, 5c's `peep.c`, freely): copy
propagation, `subprop`, dead code by the registers' liveness, a dead
instruction a NOP that mini-ld drops (no pc renumbered).

The numbers (arm64, `count.sh 7`, libc included): -simple ran about
2.4 times compat's instructions, `-O` 1.13 to 1.34 times; §1's `sum`
is 17 instructions against 7c -O0's 26, its loop 10. Behavior: 227 of
228 on each machine, as without `-O`, and 300 more random programs
(seed 11), 299, the 300th 7c's bug 5d (gcc agrees with -simple).
163 + 130 lines of code (`Opti`, `Peep`), not in `make loc`'s count.

Remaining for mini-cc, by the counts:

- **the call's weight in regs**: in `control`, whose variables are
  live across `print`'s calls, regs costs more than it saves;
- **a result extended then stored narrower** (`sxtw` before a 32-bit
  store): no extension needed;
- **offsets folded into loads** (`*p`, `a[i]`), as 5c's `fold_offset`;
- **arm**: no register left for `regs` (plan_simple.md);
- SSA, if the counts say what it would buy.

## Next: mini-ml

- **The original**: ocaml-light's ocamlopt, whose back end is
  selection, liveness, graph coloring, spilling and scheduling (about
  3,500 lines), with float unboxing and inlining.
- **The gap**: plan_ml.md measured mini-ml 2.3 times slower (fib 30,
  tak, maps: 0.18s against 0.08s): every register spilled at every
  call, every allocation a call of C.
- **The plan**: as mini-cc's, on `Lower`'s IR (`languages/ml/opti/`):
  count and trace first (`mini-5i -s`, `-t`, on the fuzzer's programs
  and `tests/tiny/`); then the passes the traces ask for, likely a
  variable's slot on the value stack in a register, an allocation
  inlined (bump the heap pointer, call C only when full), known calls
  without the closure, a peephole. The collector is the new danger: a
  value in a register must still be a root when it runs, which
  `ML_HEAP=64` (a collection at almost every allocation) is the test
  for, with `TinyML_fuzz.py` against ocamlopt.
- **Measured** as mini-cc's, with a `count.sh` of its own.

*Measured (2026-09-27)*, `languages/ml/tests/count.sh` (built and
checked by `run.sh`, both counted under qemu-aarch64, one instruction
a block, each block logged: the count mini-5i gives mini-ml's, and
ocamlopt's executables too, whose glibc mini-5i cannot run): loops
7.97 times ocamlopt's instructions, fib 24 3.23, tak 2.76, exceptions
1.29; `gc` 0.76 and `lists` 0.62, fewer (the collector is not where
mini-ml loses); the short programs are ocamlopt's glibc start (about
225,000 instructions) more than their code. The log is slow on long
runs (`gc`'s 670 million instructions took most of 40 minutes): keep
count.sh to programs of a few million.

`mini-5i -t` on `loops` (`count n acc`, a million self tail calls, 50
instructions each) says where: (1) a self tail call is a whole call,
its prologue and epilogue each time, where ocamlopt jumps into the body
with the arguments moved in place; (2) every call zeroes its value
stack's slots for the collector (six stores), where only a slot live
at an allocation or a call needs it; (3) `n = 0` tests at run time that
both are integers and loads 0 from a literal pool, where the type
checker knows `n : int`. So the passes, in that order of measured
cost: self tail calls as jumps, the comparisons typed, the slots
zeroed by liveness; then virtual registers, liveness and graph
coloring (ocamlopt's `Interf` and `Coloring`), a register live across
an allocation or a call spilled to the value stack, where the
collector finds its roots. Scheduling is left out: an instruction
count cannot see it.

*First passes (2026-09-27)*, `languages/ml/opti/` (`mini-ml -O`,
`-Otails`, `-Oeqs`), IR in and IR out, made of Lower's own
instructions, so that the simple back end is the same with them or
without (the author: "those opti must be optional and not pollute the
existing simple code path"):

- **tails**: a self tail call with all its arguments pushes the
  closure and the arguments, stores them into the parameters' slots
  from the last, and jumps to a label before the body's first
  instruction; its label a new one for the whole unit (Lower's labels
  are the unit's, and the assembler's the file's: the first version
  took the function's highest plus one, which another function had,
  and three tests failed);
- **eqs**: `x = k`, `x <> k`, k an integer, compare the words (a
  tagged integer equals only itself, a block never one): no run-time
  test, no call of `compare`; not for an order.

Checked with `-O`, live against ocamlopt (`ML_FLAGS=-O LIVE=1 run.sh`),
each also with `ML_HEAP=64`: on arm64 `tests/tiny`, `bench/`,
ocaml-light's 16 test programs and 100 of `TinyML_fuzz.py`'s, 0
failures; on arm, `make test-ocaml`'s nine and `bench/`, 0. The counts
(`count.sh`, arm64): loops 7.97 to 6.13 times ocamlopt's instructions,
tak 2.76 to 2.58, fib 3.23 to 3.22.

Where passes of Lower's instructions stop: fib's cost is its calls (the
prologue, the epilogue, the slots zeroed: `Gen`'s, not an instruction
of the IR) and `n < 2` (an order: making it one `cmp` needs `n : int`,
which the type checker knows and the IR does not say). Both need more
than a pass: the types in the IR (Lower's output changes), or a code
generator of opti's own, sharing the IR with simple's; which one is the
next decision. *Decided (2026-09-27)*: a back end of its own in SSA
form, `ssa/`, optional and combinable with `-O`: plan_ssa.md.

## Then: mini-5i and mini-qemu

- **The original**: QEMU translates a basic block once into host code
  (TCG) and chains the blocks; mini-qemu interprets through a decode
  cache (27 MIPS; xv6 boots in 21s, QEMU in 0.1s; `usertests` takes
  minutes).
- **The idea, freely**: a basic block compiled once into an OCaml
  closure (threaded code), its successor cached in it, no machine code
  generated: pure OCaml, behind a flag.
- **The danger**: self-modifying code and the caches' invalidation;
  the decode cache is already emptied on TLB and I-cache operations,
  the hooks to reuse.
- **The tests**: the existing ones, 9pi's console byte for byte, xv6's
  `usertests`, mini-5i's 3,000 random instructions; the speed by
  `make test-pi`'s time and a boot's.

## Not worth it (analyzed 2026-09-26)

- **mini-mk**: builds in parallel already (`NPROC`, as mk).
- **mini-chidb**: has chidb's optimizer (a selection pushed down a
  join, an index seek); beyond it is SQLite's, not chidb's.
- **mini-git**: writes deltas in its packs; git's window heuristics
  would buy pack size nobody measures here.
- **mini-rc, mini-ed, mini-diff**: their originals optimize nothing to
  reproduce.
- **mini-9pi**: 9pi's fast paths would fight its console's byte
  contract.
- **mini-ld**: its one optimization, `follow`, is the reference's
  layout, in compat (plan_compat.md).
