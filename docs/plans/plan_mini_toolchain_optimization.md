# Plan: the mini toolchain, faster (the target: mini-xv6's numbers)

Companion of [`plan_kernel_mini_ml.md`](plan_kernel_mini_ml.md)
(mini-xv6 built by ix's tools, its step 7: the two builds' numbers) and
of [`plan_mkfiles.md`](plan_mkfiles.md), whose step 5 this is. The
earlier work on mini-ml's and mini-cc's code is in
[`variants/opti.md`](variants/opti.md) and
[`variants/ssa.md`](variants/ssa.md) (`-O`, `-ssa`: what was tried, what
each bought). The author (2026-10-02): "let's plan for an optimization
phase at some point", then "we can start a plan mini_toolchain
optimization document, with as a good target getting better numbers
for mini-xv6!".

**Status: on hold** (the author, 2026-10-02: "for now let's put the
optimization plan on hold"): a plan with its first measurements, to
review when it is taken up again. Nothing is optimized yet.

## The target

mini-xv6 on the Pi 4 has two builds of the same OCaml and the same C:
the Makefile's (ocaml-light, gcc, GNU's linker) and the mkfile's
(mini-ml, mini-cc, mini-asm, mini-ld). `kernel/numbers.sh`, under
mini-qemu:

| build | image | to `sh` and an `ls` | the check's session |
|---|---:|---:|---:|
| ocaml-light, gcc | 1,917,608 (an ELF) | 2.8 s | 20.1 s |
| ix's tools | 2,457,808 | 8.3 s | 88.4 s |

The session (ls, cat, mkdir, ln, wc, rm, grep, forktest) is 4.4 times
slower. **The target: that ratio under 2, without making the simple
path longer** (the principles below). A second target, the same code's
other use: ix built by ix. The fixed point's second build takes 3
minutes where the first, by ocamlopt's code, takes 1, and mini-ld by
mini-ml links mini-cc in 18 s (bugs/ix.md).

## Where the time goes

**The kernel is its scheduler.** A profile of each build under mini-qemu
(`-prof`, mapped by `kernel/9pi/tests/perf/pcprof.py`, which now reads
`mini-ld -v`'s listing too) says the same of both: when no process
runs, and between two, the kernel is in `Proc.all ()`:

    let all () = List.fold_right (fun o acc -> match o with Some p -> p :: acc | None -> acc) (Array.to_list procs) []

64 slots made a list, folded by a closure of two arguments, at every
pass. ocaml-light's build: `Array.to_list` 28%, the scheduler's loop
22%, `List.fold_right` 20%, `caml_apply2` 12%. ix's: `to_list` 19%,
`fold_right` 18%, `ml_alloc` 17%, the loop 10%, and 15% in `ml_curry2`,
which ocaml-light's does not have.

**So the scheduler's pass is the benchmark**:
`languages/ml/tests/bench/sched.ml`, the same line 2,000 times, in
user mode, where every instruction can be counted
(`languages/ml/tests/count.sh`, against ocaml-light's ocamlopt):

| | instructions | times ocamlopt's |
|---|---:|---:|
| ocamlopt | 7,889,568 | 1 |
| mini-ml | 36,532,638 | 4.63 |
| mini-ml `-O` | 34,788,691 | 4.41 |
| mini-ml `-O -ssa` | 32,757,342 | 4.15 |

4.63: the session's 4.4. The kernel's ratio is this code's. And
mini-ml's instructions, function by function (`mini-5i -t`, the same
script):

| | share | what it is |
|---|---:|---|
| `Array.to_list`'s loop | 22% | not looked at instruction by instruction yet; on `loops`, variants/opti.md found a call's entry and exit (the value stack's slots zeroed, every register spilled around a call) |
| `List.fold_right` | 21% | the same, and not a tail call |
| `ml_alloc` | 21% | an allocation is a call of C, and that C is 7c's `-O0` |
| `ml_curry2_0`, `ml_curry2_1` | 19% | `f a b` with `f` unknown: one argument at a time, a closure allocated in between |
| the closure's body | 12% | |
| the collector | 0.2% | |

**What the existing switches buy on the kernel** (each built whole, the
stdlib too, and measured by `numbers.sh`):

| build | to `ls` | session |
|---|---:|---:|
| ix's tools | 8.3 s | 88.4 s |
| the heap 32 MB from the start (`-DHEAPSTART`), not 2 MB doubling | 7.7 | 84.2 |
| and `mini-ml -O` | 7.7 | 84.2 |
| and `mini-ml -O -ssa` | 7.6 | 83.5 |
| and `mini-cc -simple -O` for the C (the runtime, the library) | 7.7 | 77.6 |

Little: `-O`'s passes (self tail calls, integer equality) and `-ssa`'s
registers do not touch what the table above shows. The collector is not
the problem either (5% with sixteen times fewer collections).

**Not explained yet**: the 8.3 s to the prompt. The bss is 75 MB (the
heap's two halves, the value stacks) and the start clears it; the whole
stdlib is initialized; the rest is the code. To measure (step 1).

## Principles

The author's, from the earlier phases (variants/opti.md, and the
memory of this project):

1. **Measured first.** A pass exists because a profile asked for it,
   and its entry says what it bought, in instructions (`count.sh`) and
   in the kernel's seconds (`numbers.sh`).
2. **The simple path stays.** An optimization is beside it, switchable
   (`-O...`), the code before kept (`(* old: *)`), "optional and not
   polluting the existing simple code path". The mkfiles choose which
   are on.
3. **Lines are the budget.** m-ix is 80,767 lines, `opti/` and `ssa/`
   are counted apart (1,554). A pass's lines are in its entry, with what
   they bought; a rewrite of ix's own code that removes the cost for
   both compilers (the scheduler's list) is weighed against a pass.
4. **Correct before fast**: every test with the pass on, live against
   ocamlopt, and with `ML_HEAP=64` (a collection at almost every
   allocation) when the collector's roots are concerned; the kernel's
   six checks; the fixed point.
5. The notes go to `~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`
   (the symptom in the profile, why, the fix, what it bought) and to
   `docs/notes_performance.md`.

## Candidates, by what the profile says

| | what | where | aims at | lines (guess) |
|---|---|---|---|---:|
| A | **Allocation inline**: the heap's pointer bumped and compared in the generated code, C called only when the half is full (ocamlopt's way; needs the pointer and the limit where ML's code reaches them) | `Gen`, the runtime | `ml_alloc`'s 21% | 40 |
| B | **`f a b` in one call**: an unknown function applied to n arguments calls its code directly when its arity is n (ocamlopt's `caml_applyN`: the arity in the closure, tested), the curried way otherwise | `Lower`, `Gen` | `ml_curry`'s 19%, and its allocations | 60 |
| C | **A call's entry**: only the slots a collection can see uninitialized are zeroed (liveness), registers spilled only when live after the call | `Gen` (or `ssa/`, which has the liveness) | part of the 43% of `to_list` and `fold_right` | 80 |
| D | **Known functions**: a call of a function known at compile time across units (the stdlib's `List.iter`) direct, without its closure; small ones inlined | `Scope`, `Lower` | the rest of it | 100+ |
| E | **The C faster**: `mini-cc -simple -O` in the mkfiles (measured: the session 84.2 to 77.6); then what 7c's own optimizer does that `opti/` lacks | the mkfiles, `languages/c/opti` | the runtime, the C library, the kernel's C | 0, then ? |
| F | **The kernel's memory**: the heap's halves outside the bss (nothing reads a half before it is written), the stdlib's units linked only when named (as `tests/run.sh` does) | the runtime, `mkkernel` | the boot, the image's 922 KB | 30 |
| G | **A generational collector**, beside Cheney's, switchable (plan_ml.md, decision 5) | the runtime | after A: an allocation's cost is then the collector's | 150 |
| H | **ix's own code**: `Proc.all` without a list at each pass; mini-ld's `t.progs` appended to (quadratic) | `kernel/xv6`, `linker` | both builds; the links | -5 |
| I | **The parsers' tables** compacted (plan_lex_yacc.md) | `generators/yacc` | the programs' size | 100 |

Order proposed: A, B (the two that the profile names, both local),
then measure again; E's switch (free); F (the boot); C with `ssa/`'s
liveness; D; G only if the profile then asks.

## Steps

1. **The meters.** `count.sh` and `bench/sched.ml` (done), `numbers.sh`
   (done), `pcprof.py` on a listing (done). To add: the guest's
   instructions to a point, counted by mini-qemu (a count at exit, or
   at a marker), so that the boot and the session are numbers of
   instructions and not seconds of a host; the same three programs of
   `bench/` and `sched` as one table, kept in this file after each
   step.
2. **A and B**, each behind its switch, measured on `sched` then on
   the kernel.
3. **The mkfiles' switches**: which of `-O`, `-ssa`, `-simple -O` and
   the new ones are on for ix built by ix and for the kernels; the
   fixed point and the checks with them.
4. **F**: the boot explained and shortened.
5. **C, D**, by what the profile then says.
6. The same table for **ix built by ix** (the second build's minutes,
   mini-ld's link of mini-cc), and H's linker part.

## Open questions

1. **Where the switches live.** `-O` is all of `opti/`'s passes; A and
   B change `Lower`'s and `Gen`'s output, not an IR-to-IR pass. A flag
   each (`-Oalloc`, `-Oapply`) read by the simple back end, with the
   plain path kept beside? Or in `ssa/`, the optimizing back end, only?
2. **The contract.** With `-O` on in the mkfiles, a program built by
   ix's tools is no longer the simple path's: the fixed point then
   checks the optimizers. Both, in two builds?
3. **H**: is rewriting `Proc.all` (the kernel's own code, for both
   builds) inside this plan, or does the plan keep the kernel as the
   fixed benchmark it was measured with?
4. **The stack a call takes** (32 bytes, ocamlopt's 16: bugs/ix.md) is
   a limit, not time: here or apart?
