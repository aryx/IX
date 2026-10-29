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

2026-10-29: steps 1 to 3 written; mini-cc -O3 for all of it (-simple -O
-ssa; the author: "maybe we could add a -O3 like for mini-ml"; 5c's -O3
is its registerizer, its -O0 compat's code, the default); the runtime
built by -O3 (lib_core's mkfile), gc.c's scan in C with copy's work in its loop, as fast as the
assembly it replaces (plan_ml_speed.md's 2026-10-29: 1.0003), which is
gone. Not done: libc by -ssa (it stays compat's, fuzz.sh's reference);
more registers on arm (R1-R7: the scan's lo and hi in slots); a first
argument's store and reload into R0 at a call; ZR for a stored 0 on
arm64.

## 2026-10-29, the libc and the kernels' C by -O3

The author: "why libc is not compiled by -O3? [...] same for the
kernels' runtime, let's use -O3 there too, if it turns out -O3 generate
faster code". lib_core's mkfile compiles the libc's C by -O3 (its
memmove and memset are assembly already), the kernels' mkkernel their
C (the ML runtime, lib_machine's runtime.c, machine.c, usb.c, shim.c;
COPT= for compat's). mini-9pi's pixels are OCaml (lib_memdraw), not C:
-O3 reaches a game's frame by the runtime and the libc only.

languages/c/tests/bench/ (the author: "feel free to add those test
benchmark under languages/c/tests/bench/ [...] like we did for
mini-ml"), by tests/bench.sh, each program and the libc by CC_FLAGS,
arm (mini-5i -s):

| | compat | -O3 | |
|---|---:|---:|---:|
| fmt: snprint, strcpy, strlen, memcmp | 4,206.0 million | 3,075.5 | 26.9% fewer |
| copy: *q++ = *p++, a walk | 51.5 | 22.1 | 57.1% fewer |
| sorts: a quicksort by hand, then qsort | 36.3 | 31.2 | 14.0% fewer |

Found by sorts: (lo + hi) / 2 in v[...] is Div of an unsigned, an
index's type, which imm left to arm's _div (Opti's imm now: a shift,
signed when the type fills the register, else unsigned). Left: libc's
qsorts 10% more under -O3 than compat's (13.8 million to 12.4), its
calls of the comparison function among its loops.

Checked: simple.sh with -O -ssa (the benchmarks among the programs);
the divisions against 5c's and 7c's with -O and -O -ssa; make test
(mini-9pi's kernel by -O3 boots and builds on its card in the smoke
test, which now compiles pow.c by -O3 there, as lib_core's mkfile).
Not run: the kernels' long checks (mini-mk check) under mini-qemu.

## 2026-10-29, the two ssa/'s shared algorithms in lib_code/

The author: "yes let's commit and then factorize the SSA code in
lib_code/" ("(not lib_core)"). lib_code's Dominators (idoms, children,
loop depths), Braun (the construction's reads and seals, the trivial
phis), Liveness (in SSA form, and after each instruction) and Coloring
(points, choose, the walk with hints), from mini-ml's ssa/, which both
Ssa_build's and Alloc's call; each mkfile compiles them (lib_code has
none). mini-ml's output the same bytes (lib_core's units and its own
five, -O3, arm and arm64); mini-cc's 42 of 426 compiles differ, a
block's incomplete phis now given their operands newest first, as
mini-ml's (mini-cc's own copy had them oldest first). The ssa/'s 230
lines less, lib_code 248 more (and 193 of interfaces).

## 2026-10-29, libc's qsort slower by -O3 than compat's: four fixes

The author: "let's investigate the 10% slowdown. -O3 should be faster
than compat!". qsorts (goken's port/qsort.c) by -O3 12.4 to 13.7
million instructions in the sorts benchmark, its loops a call through
a function pointer at each turn. Under mini-prof -a, a turn of
`do pi += es; while(pi < pn && p->cmp(pi, a) < 0)` was compat's 18
instructions and -O3's 20:

- the first argument stored to the outgoing area, then loaded into R0:
  now the call's operand (Ssa_build), put in R0 at the call (5c's
  convention: the callee stores R0 itself);
- a value stored to its slot and loaded at once: the register it was
  stored from, when no instruction is between (Ssa_gen);
- pi not SSA's: `pi = pivot(...)` is the call, then lea pi; swap; put,
  which places did not fold (its address seen taken); now PutAt
  (Opti's places, -O's too);
- a value live across calls stored at each call: once, where it is
  made, an SSA value never changing (Alloc's spill), the cost a load a
  call; and R0's store at the entry left out when nothing reads the
  parameter's slot (cmp, the comparison: 8 instructions a call to 7).

Arm, mini-5i, the benchmarks by -O3, compat's beside:

| | compat | -O3 before | -O3 now |
|---|---:|---:|---:|
| fmt | 4,206.0 million | 3,075.5 | 2,948.5 (29.9% fewer than compat's) |
| copy | 51.5 | 22.1 | 22.1 (57.1% fewer) |
| sorts | 36.3 | 31.2 | 29.3 (19.3% fewer) |
| its qsorts | 12.4 | 13.7 | 12.2 (1.8% fewer) |

sorts.c's own sort 7.4 to 7.7 million: a value live across its
recursive call now stored at each turn, where only one path calls.

## 2026-10-29, R8 the allocator's on arm

The author: "how can we use more registers for ssa/ on arm? I like
the simplicity in Plan 9 toolchain where a few registers are reserved
for a clear useful purpose". 5c's registers are R0-R8 (R9 and R10 the
external ones, R11 the linker's, R12 SB, R13 SP, R14 the link, R15 the
PC); ssa/ kept R0 and R8 as scratch. Now R0 is the only one, R1-R8 the
allocator's, a second operand loaded into R0 when the first is in a
register; a function with an instruction that still needs a second
scratch (two operands in memory, a cycle of phis' moves) is emitted
again with R1-R7 (Ssa_gen.func, its instructions taken back). The roles
explained in docs/manuals/m-ix.md's section 8.

Arm, mini-5i: mini-ml compiling its three units, the runtime and the
libc by -O3, 5,107.9 million instructions to 5,087.4 (0.4% fewer;
gc.c's scan keeps its end in a register, lo and hi still in slots:
ten values live in its copy loop); the benchmarks: sorts 0.4% fewer,
fmt and copy the same.

