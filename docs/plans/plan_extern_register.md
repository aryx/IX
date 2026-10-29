# Plan: `extern register`, and mini-ml's value stack in R10 by declaration

The author (2026-10-29), once ssa/'s registers on arm were written
down (docs/manuals/m-ix.md, section 8): "seems bad to leave this R10
implicit instead of enforced. Maybe we should use extern register for
ml_vsp? and put things in the right order like in principia's kernel
so we can then comment and assume it's in R10 and R9?", then "yes
let's first write the plan".

## Where things are (2026-10-29)

mini-ml's code keeps its value stack's top in a register for a
program's whole run: R10 on arm, R26 on arm64 (mini-ml's `vsp`, in
ssa/'s Emit and simple's Gen). Before each call of C it stores it to
`ml_vsp(SB)`, the runtime's global (runtime.c), for the collector and
the C that pushes values; it never loads it back after, counting on
the C leaving R10 alone. Nothing declares that: it holds because 5c,
and mini-cc after it, never allocate R9 and R10, Plan 9's two extern
registers, reserved in every file whether one is declared or not
(5c's `ginit`). mini-ml's R9 is its temporary. Said in comments since
977e730c (mini-ml's Emit, simple's Gen, runtime.c, mini-cc's Ssa_gen,
m-ix.md); the kernels' `swtch` (kernels/lib_machine/pi1/l.s) keeps
R10 across a switch.

Plan 9's way, principia's kernel/core/arm/dat.h:

    extern register Cpu* cpu;   /* R10 */
    extern register Proc* up;   /* R9 */

5c gives extern registers in the order they are declared, from
`REGEXT` down: R10 then R9 on arm (5.out.h's `REGEXT = 10`), at most
two (5c's `exreg`: integers and pointers; floats from `FREGEXT`); on
arm64 7c's R27 then R26 (7.out.h's `REGEXT = 27`). A use of such a
variable is the register itself, no load or store.

mini-cc parses `extern register` but refuses a use of one ("extern
register is not in the subset", Check.ml): compat's reserved lists
have R9 and R10 (Arm.ml), R26 and R27 (Arm64.ml), and nothing gives
them to a variable.

## The steps

1. **mini-cc: `extern register`, as 5c's and 7c's.** The front end
   gives a declared one its register, in order, from R10 (R27) down,
   at most two, as `exreg`; a use is that register (Tree's name with
   the register, the classes 5c's: `Cexreg`).
   - compat: 5c's code byte for byte (its listing and object), the
     corpus's test of it (languages/c/tests/listing.sh) and a new
     file of declarations and uses, read, written, taken in
     expressions, beside a call.
   - simple and ssa/: a read and a write of the register (an Ir
     instruction of its own, or GetReg/SetReg's with a fixed
     register); never an SSA variable's, never across a call saved (no
     callee or caller touches it).
   - If principia's kernel files that use `cpu` and `up` compile, they
     are the larger check (compat against 5c).
   - mini-cc's twin: 5c had it, principia's kernel needs it.
2. **The runtime declares it; mini-ml stops storing it.** runtime.c,
   first among its globals, principia's order:

       extern register value *ml_vsp;   /* R10 (arm64: R27) */

   R9 left to 5c's rule (reserved in every file), said beside it as
   mini-ml's temporary, or a second declaration if a name is wanted.
   mini-ml's back ends (ssa/'s Emit, simple's Gen) no longer store
   `vsp` to `ml_vsp(SB)` before a call of C, and `ml_callback` no
   longer loads it: the C reads and writes the register.
   - arm64: mini-ml's `vsp` from R26 to R27, 7c's first extern
     register (or `ml_vsp` declared second; the first keeps the two
     machines alike).
   - The gcc route (mini-ml `-gas`, the runtime by gcc, run.sh's
     GAS=1): GNU's `register value *ml_vsp asm("r10");` under
     `__GNUC__`, or `ml_vsp` kept a memory global there and mini-ml
     `-gas` keeping its store; the simpler of the two.
   - The kernels: their runtime (kernels/lib_machine/runtime.c, and
     languages/ml/runtime/runtime.c compiled with -DHEAP) by the same
     declaration; `swtch` keeps R10 as now.

## What to check, each step

- mini-cc: listing.sh and fuzz.sh as before (compat byte for byte),
  simple.sh at -O and -O3 on arm and arm64, the new file against 5c
  and 7c by behavior.
- mini-ml: its runtime suite (tests/run.sh) at -O3 on arm and arm64,
  the threads' tests among them, and GAS=1 on arm; make test (m-ix
  built in mini-9pi, the smoke test's card); mini-ml's output for the
  calls of C one instruction shorter, nothing else.
- Measured: mini-ml compiling its three units on arm (mini-5i), one
  store fewer at each call of C (millions in a compile; under 1%
  expected).

## Risks

- gc.c's threads assign `ml_vsp` (`ml_vsp = stack_top[i]`, the
  switch): a write of R10 itself then, where today it is memory the
  ML code does not read back. Read and checked by the threads' tests
  before step 2 is committed.
- arrays.c's `top = ml_vsp; ... ml_vsp = top` and every C that pushes
  ML values (callbacks, ml_push): the register, now, read and written
  in place; the same values.
- compat's byte-identity: 5c's code for an extern register's use is
  its OREGISTER, which compat must make as Cgen does a register; the
  corpus has no such file today, so the new test is its only check.

## Decision: another design first (2026-10-29)

The author: "is there a better design? We don't have to follow
necessarily Plan 9 every time", "especially if there is a clear better
one", then "ok let's do C and postpone extern register. What I want is
clearer code, less hidden assumptions about register". Design C: the
ML code hands its value stack's top to C in `ml_vsp` before each call
of C and loads it back after (ocamlopt's way, caml_c_call), so nothing
assumes the C leaves R10 alone, and mini-cc's -O3 gives R9 and R10 to
its allocator (R26 and R27 on arm64). The conventions, numbered:
mini-ml's ssa/Emit.ml; docs/manuals/m-ix.md's section 8.

Measured on arm (mini-5i), against HEAD at one commit, the same
pixels:

| | design C against HEAD |
|---|---|
| mini-doom, a frame | 0.01% more instructions |
| mini-quake, cameltry | 0.19%, 0.34% more |
| mini-ml's benchmarks (tests/bench.sh) | 0% to 2.7% more (pixels 2.7%, sha 2.1%; limbs, fib, tak, matrix the same) |
| mini-ml compiling Ssa_build.ml | 1.3% more |
| mini-ml compiling its three units | 3.4% more (5,328.3 to 5,508.1 million) |
| mini-cc's benchmarks (C alone) | the same (sorts 0.3% fewer) |

Where the cost is: a load after each call of C, some ten million in
a compile (the runtime's length, string_alloc, blit_string, ml_alloc),
and mini-ml's output that much bigger (2% more instructions for
Ssa_build.ml), which mini-ml itself then makes; the gain, gc.c's scan
keeping lo and hi in R9 and R10's room (scan_copies 3.8% fewer
instructions a call), too little to pay it back. Committed all the
same (the author: "let's commit design C and with it the slightly
negative result but still arguments for it"): one convention said in
one place, nothing assumed of the C, ocamlopt's own way
(caml_c_call). To win it back without the assumption: the runtime's
smallest functions open-coded in mini-ml's code (length at 14
instructions a call, 1.9 million calls in a compile), their calls and
reloads gone.

`extern register` stays a gap in mini-cc as 5c's twin (step 1 above),
for whenever principia's kernel C is compiled by it; nothing of ix
needs it.

## Status

2026-10-29: plan written; postponed for design C, which is done.
