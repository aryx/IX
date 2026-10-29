# Plan: mini-cc's registers, an `ssa/` for C (`languages/c/ssa/`)

The author (2026-10-28), once mini-ml's collector was found spending a
quarter of a compile in C that mini-cc compiles with every variable in
memory: "maybe we can do 1 and 2. Let's start with 1 indeed" (1: the
scan in assembly, `plan_ml_speed.md`'s 2026-10-28; 2: a registerizer in
mini-cc), "maybe we can also have an ssa/ in languages/c/ ?", then
"hopefully tomorrow we have a good gc written partly in assembly and a
good registerizer for mini-cc that could have almost generated the
fast assembly from the generic gc C code that was before".

The goal, measurable: **gc.c's C scan, compiled by mini-cc, close to
`scan_arm.s`**, so that the assembly could go; and with it the rest of
the runtime (compare, ml_modify, ml_alloc, the strings' functions,
some 45% of mini-ml's compile is C), libc and every C program of ix.

## Where mini-cc is (2026-10-29)

Two back ends (`done/plan_cc.md`): compat, 5c's code byte for byte
without 5c's registerizer (`reg.c`, 2,700 lines a machine), every
variable a load or a store, the default; and `-simple`, a stack machine
(`simple/Ir`) whose `-O` passes (`opti/Opti`) include `regs`, variables
in registers chosen by uses weighted by loop depth, saved around calls
(Plan 9's caller saves). On arm64 regs had R19-R25; on arm none, the
stack machine's depth k is Rk, R1-R7.

Done first, the small step (2026-10-29):

- arm's variables in the stack's registers from R7 down, those above
  the function's deepest stack (Opti's `deepest`, Gen's `vregs
  ~depth`): gc.c's copy loop keeps q, p and e in R7, R6, R5;
- a division by a power of 2 a shift (`imm`): unsigned the bits out,
  signed rounded toward 0 by a bias of its sign, an unsigned
  remainder a mask; arm has no divide, a pointer difference was a
  call of `_div` (2.2 million in a compile by mini-ml).

Checked: `languages/c/tests/simple.sh` with `SIMPLE_FLAGS=-O` on arm
and arm64 (TinyC_tests, the same as before: sort's reference prints
garbage either way; 120 programs of TinyC_fuzz.py, arm 103 the same
with and without -O, the same 16 failing, arm64 117 of 117), a test of
the divisions against 5c's and 7c's (negatives, both machines).

Measured, mini-ml compiling its three units on arm (mini-5i -s):

| the runtime by | gc.c's scan | instructions | |
|---|---|---:|---:|
| compat (HEAD) | C | 6,100.0 million | 1 |
| compat | C, rewritten for compat's code | 6,023.5 | 0.987 |
| -simple -O (before: 1.058 of compat) | C | 5,928.2 | 0.972 |
| compat | scan_arm.s | 5,200.9 | 0.853 |
| -simple -O | scan_arm.s | 5,309.5 | 0.870 |

So regs with arm's leftover registers closes a sixth of what the
assembly does; and outside the scan, -simple -O's code is still a
little worse than compat's. What is left in the copy loop (12
instructions a word, the assembly's 4): moves between the stack's
registers and the variables', `MOVW R7,R1; ADD $4,R7,R2; MOVW R2,R7`
for `*q++`, which an allocator over values, not a stack, does not make,
and which ARM's post-indexed load and store do in one.

## The plan: `languages/c/ssa/`, mini-ml's design for C

mini-ml went the same way: a stack machine first (simple/), then
`ssa/` (Ssa_build, Alloc, Emit; `languages/ml/ssa/`), its values in
registers by SSA's coloring. For C:

1. **SSA from simple's IR** after Opti's forms (places, imm, branch),
   Braun's construction as mini-ml's Ssa_build: a variable regs may
   hold (`Opti.variables`: never its address taken) is an SSA
   variable, a stack slot at a block's edge another; a value has its
   `ty` (size, sign, float). Checked as mini-ml's: every use dominated
   by its definition. `mini-cc -simple -ssa -dssa`.
2. **Alloc**: liveness, then the values colored in the dominator
   tree's order (Hack, Grund and Goos), the registers each machine's
   C may use (arm R1-R8 and R14 in a leaf; arm64 R0-R15, R19-R25),
   floats apart; a value live across a call in memory (Plan 9 saves
   nothing), as mini-ml's.
3. **Emit**: the instructions by value, Gen's encodings; an address
   advanced after its load or store one post-indexed access (`*q++`).
4. Measured at each step against compat and scan_arm.s; the target,
   the C scan within 1.2 times the assembly's instructions. Then the
   runtime and libc by it (lib_core's mkfile), compat staying the
   byte-identical reference of goken (fuzz.sh).

Size: mini-ml's ssa/ is about 2,200 lines with its Unbox and Untag,
which C does not need; C's types (sizes, signs, conversions) add.
Whether parts can be shared with mini-ml's (the construction, the
dominators, the coloring) is decided once its IR is written: the
two Irs differ in their instructions, not their control flow.

## Step 1 to 3, written (2026-10-29)

The author: "let's commit and start ssa/ for C without sharing code at
first; we can try to factorize later if ssa/ turned out to be good opti
for C too". `languages/c/ssa/`, behind `mini-cc -simple -O -ssa`
(`-dssa` prints the form), the default unchanged:

- Ssa (the types), Ssa_build (Braun's construction, mini-ml's, with
  C's variables: Opti.variables's, and those read as another integer
  of their size, gc.c's value read as a uvalue, by a conversion;
  simplify; offsets: a load or store through b + k at k(b); sink: q + 4
  after q's last use), Alloc (mini-ml's coloring; a value live across
  calls in a register saved at each call when its uses outweigh them,
  else in a slot; a phi and its operands each trying the others'
  register), Ssa_gen (Gen's instructions by value; phis as parallel
  copies on the edges; a load or store then q + k one post-indexed
  access, MOVW.P). 1,471 lines with the interfaces' comments.
- gc.c's C copy loop comes out as scan_arm.s's: `CMP; BHS; MOVW.P
  4(R2),R4; MOVW.P R4,4(R3); B`.

Measured, mini-ml compiling its three units on arm (mini-5i -s), the
runtime's other C by the same back end as its scan:

| the runtime by | gc.c's scan | instructions | |
|---|---|---:|---:|
| compat (HEAD) | scan_arm.s | 5,200.9 million | 0.853 of 6,100.0 |
| -simple -O -ssa | C | 5,396.3 | 0.885 |
| -simple -O -ssa | scan_arm.s | 5,115.5 | 0.839 |

So the C scan by ssa/ is 1.055 of the assembly's whole compile (the
target was 1.2): what is left is copy's call for each field the
assembly inlines, and e, live across that call, in a slot. And the rest
of the runtime by ssa/ is 0.984 of compat's.

Checked: languages/c/tests/simple.sh with SIMPLE_FLAGS="-O -ssa" on arm
and arm64 (TinyC_tests, TinyC_fuzz.py's 120 and a test of post-indexed
accesses of every type: arm64 129 of 129; arm the same 17 failing as
without -ssa, sort's reference garbage and 16 fuzz programs); the
runtime suite with RUNTIME_FLAGS="-simple -O -ssa" (tests/run.sh's new
variable), arm and arm64 at -O3, as compat's (costs needs arguments,
marshalling's timing line); mini-cc built by mini-ml writes the same
-S as dune's (the runtime and 43 libc files, both machines).

## Status

2026-10-29: steps 1 to 3 written; not done: the runtime
and libc built by -ssa (lib_core's mkfile), and step 4's adoption; a
first argument's store and reload into R0 at a call; ZR for a stored 0
on arm64.
