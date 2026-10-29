# Plan: one low-level IR under mini-cc and mini-ml (`languages/cmm/`), C--'s ideas without qc--, and mini-tiger its first new client

The author (2026-10-29): "I'm thinking of adding a mini-tiger and
mini-c-- in IX (see ~/github/tiger and ~/github/c--), and possibly to
add a c-- backend to mini-c and mini-ml. [...] we also have a plan for
a mini-dotnet so this might interact with c--. Also maybe we could
take good ideas not just from c-- but also llvm, mlrisc, VPO, etc. to
rethink the toolchain backend"; then, after the analysis: "let's
write this plan document for now".

The short answer: **not a twin of qc--, but its two ideas that ix
lacks**: one low-level SSA IR with a syntax of its own, which both
compilers lower to and one back end compiles (C--'s language, QBE's
size), and later the runtime interface, the collector's roots found
by tables rather than mini-ml's value stack (C--'s spans, Go's
FUNCDATA). **mini-tiger**, Appel's language, is the IR's first
client that is neither C nor ML: plan_dotnet.md's program (decision
10 there), its front end shared, compiled both ways, to IL there and
to cmm here (the author, 2026-10-29: "we can target both cmm and
dotnet for tiger"). mini-dotnet's JIT is a later client.

**Status: plan written, nothing built.**

## Where ix is (2026-10-29)

Two compilers, two SSAs, two emitters; the algorithms shared since
today (lib_code/README.md):

```
mini-cc: Tree -> simple/Ir (a stack) -> opti/ -> c/ssa/Ssa   -> Ssa_gen   458 lines
mini-ml: Ast  -> simple/Ir (a stack)          -> ml/ssa/Ssa  -> Emit    1,251 lines
                 lib_code: Braun, Dominators, Liveness, Coloring (299 lines)
both:    -> mini-asm's objects (Plan 9's assembly) -> mini-ld selects and encodes
                                                      (Arm 808 lines, Arm64 867)
```

- **C's `Ssa.ins` is at C--'s level already**: `Load`, `Store`,
  `Op`, `Cvt`, `Call` over a `ty` (size, sign, float).
- **ML's is higher**: `Field`, `Alloc`, `Tag`, `Box`, `Caught`,
  `Try`; Unbox and Untag are ML's passes over it. Below them, a field
  is a load at an offset, an allocation a bump of the heap's pointer
  or a call, a tag an addition and a shift: C's instructions.
- So the two emitters each answer the same questions their own way:
  which registers (plan_cc_ssa.md's R1-R8 on arm, design C of
  plan_extern_register.md), what lives across a call, the phis'
  parallel copies, post-indexed accesses (C's only).
- **What makes a port cheap is already there**: Plan 9's assembly is
  one syntax for every machine, and mini-ld turns an instruction into
  what the machine can do (done/plan_cc.md, "an intermediate target,
  or Plan 9's?"). A C--, LLVM or VPO layer would not make riscv64
  (plan_riscv.md) much cheaper: its cost stays in mini-ld and compat.

## Why not a mini-c-- twin of qc--

The author's fork `~/c--` (counted 2026-10-29, `.ml`, `.mly`, `.mll`):

| part | lines |
|---|---:|
| parsing, ast, elab, fenv | 5,105 |
| cfg | 3,953 |
| middle (expand, layout, opti, proc, translate) | 7,030 |
| rtl, target, backend (asm, regalloc) | 6,582 |
| driver, libs | 6,154 |
| all but the machines | 28,824 |
| a machine (arm 3,095, arm64 3,273, riscv64 2,944, x86 9,975) | ~3,000 |

- Its size is mini-cc's and mini-ml's together, before a machine;
  done/plan_cc.md turned it down for that reason already.
- It cannot be a twin: qc-- writes GNU's assembly for a dozen
  machines; ix writes Plan 9's objects for mini-ld. No output can be
  the same bytes.
- Its heart, RTLs and expanders from λ-RTL's machine descriptions
  (Davidson and Fraser's, VPO's), is the job mini-ld does late,
  Plan 9's way.

The contract that would hold is the **language**: the C-- that
fork-tiger's `tigerc` writes, run by ix's back end with the output
qc-- gives on arm. A differential check for test-all only (it needs
`~/c--` and `~/tiger`: gate-no-external-references).

## What is taken, and from where

| idea | from | for ix |
|---|---|---|
| one low-level SSA IR, printed, parsed, verified | C-- (its syntax: `bits32[p]`, `foreign "C"`), LLVM (an IR that reads back what it prints, a verifier, the passes named on the command line), QBE (the size: ~10,000 lines of C, SSA, arm64 and riscv64) | one allocator and one emitter for both compilers; tests written in the IR; a target for a new front end |
| the collector's roots by tables | C--'s spans and runtime interface; MLRISC (the client says which values are pointers, kept through the allocation); Go (FUNCDATA and PCDATA, added to Plan 9's assembly for its stack maps) | mini-ml's live pointers no longer stored to the value stack (R10, R26); the tables beside plan_debugger.md's, read by the same walk (`Frames`) |
| exceptions as `cut to` | C-- | one model for ML's `Try`/`Raise`, Tiger's exceptions (fork-tiger has `cut to` and unwinding), .NET's two passes later |
| a register convention inside the IR | Go's ABIInternal (2021), AAPCS | variants/modern.md's conventions, 1: inside code by the IR, Plan 9's at the boundary with libc and compat |
| lowering by rules, generic to a machine's | Go's `*.rules`, LLVM's TableGen, lcc's lburg | not now: worth it with a third machine (riscv64), if the emitters grow |

Not taken: Cranelift's e-graphs and ISLE, LLVM's passes beyond the
few ix has (CSE, LICM, both mini-ml's), VPO's optimizer over RTLs:
much code for little at ix's size.

ocamlopt's own IR between its lambda code and its Mach is called
Cmm, after C--: a Cmm level in mini-ml is its original's design, not
a departure (mini-ml twins ocaml-light, whose ocamlopt has it). Hence
the name proposed, `cmm`.

## Decisions (proposed, for the author)

1. **No qc-- twin.** The IR is ix's, C--'s syntax where it says the
   same thing; the program that reads it (`mini-cmm`, or a flag of
   the library's test driver) is not called mini-c--, as mini-xxx is
   a twin (ix-twin-programs).
2. **The IR is C's `Ssa` grown, not ML's shrunk**: values with a
   `ty`, loads and stores at an offset, ops, conversions, calls
   (Plan 9's convention), phis, `Jmp`, `Br`, `Switch`, `Ret`; then
   what ML needs below its own SSA: a raise and a handler (`cut to`'s
   shape), the heap's pointer, a call of C (design C's). ML's Field,
   Alloc, Tag, Box are lowered to it after Unbox and Untag; mini-ml's
   ssa/ keeps its passes.
3. **A syntax, an ocamlyacc grammar** (parser-technology), the
   printer its inverse: `-dcmm` in both compilers prints what the
   reader reads back, the same bytes (the round trip a test). A
   verifier: every use dominated by its definition, the types of an
   op's operands agreeing, a phi's operands one by predecessor.
4. **Where**: `languages/cmm/`, a library both compilers link (its
   instructions, the builder, the reader, the printer, the verifier,
   Alloc, the emitter), over lib_code's algorithms; lib_code stays
   what is not a back end (lib-code-program-analysis).
5. **The contract of each port: the same bytes.** mini-cc -O3's
   assembly, then mini-ml -O3's, unchanged by going through the IR
   (lib_core's units and mini-ml's own, the runtime and libc, arm and
   arm64), as for lib_code's factoring. Where a difference is a gain,
   it is a step of its own, measured.
6. **The emitter writes mini-asm's instructions as values**, not
   text, and mini-ld's encoders are callable as a library: the JIT of
   plan_dotnet.md ("After it") encodes in memory, with no file.
7. **The roots by tables is a plan of its own** (stage 4), decided by
   measures (mini-doom's frame, mini-ml compiling its three units, on
   arm under mini-5i): its gain is a guess until then.

## The stages (each checked before the next)

1. **The IR, its reader, printer and verifier.** Hand-written `.cmm`
   files: the round trip, the verifier's refusals (a use before its
   definition, a phi missing a predecessor). No back end yet.
2. **mini-cc through it.** c/ssa/Ssa becomes cmm's; Ssa_gen the
   emitter. Check: decision 5's bytes; `languages/c/tests/simple.sh`
   with -O -ssa, arm and arm64; mini-cc built by mini-ml writes the
   same -S.
3. **mini-ml through it.** ML's SSA lowered after Unbox and Untag;
   Emit's machine half moved to cmm's emitter, its ML half (the value
   stack, the handlers' frames) the lowering. Check: decision 5's
   bytes; tests/bench.sh's numbers the same; make test. Measured: the
   two emitters' 1,709 lines against cmm's.
4. **The roots by tables** (its own plan, decision 7): the stack maps
   at each call, the collector walking frames by them, the value
   stack gone where the tables say all.
5. **mini-tiger's second back end** (below), to cmm's text, once
   plan_dotnet.md's stage 5 has its front end and the IL back end.
6. **mini-dotnet's JIT** on the same IR, when plan_dotnet.md's stage
   4 is done: a method's IL to cmm, then the emitter and mini-ld's
   encoders in memory (decision 6).

Stage 5 can come before 3 or 4: it needs only stage 1 and 2's
emitter, and the front end of plan_dotnet.md's stage 5. Its GC asks
the runtime question of stage 4, which a value stack answers as
mini-ml's does today.

## mini-tiger's two back ends (`languages/tiger/`)

Tiger, the language of Andrew Appel's *Modern Compiler Implementation
in ML* (1998), the textbook of a compiler course; the author's
`~/tiger` (fork-tiger) its front end to C--, qc-- its back end.
mini-tiger is plan_dotnet.md's (its decision 10: written anew, the
lexer, grammar, tree, names and types, fork-tiger's tests); this plan
adds the second back end:

```
                                     +-> IL: frames as classes     plan_dotnet.md
 .tig -> lexer, grammar, types, escapes
                                     +-> cmm: frames in the stack  this plan
```

- **One front end, typed**: the IL wants typed locals and fields
  (plan_dotnet.md's decision 10), and cmm reads what it needs of the
  same tree (a word or a pointer, for the collector). Appel's escape
  analysis serves both.
- **The two back ends are the lesson**, the same program put on two
  machines: an escaping local is a field of a frame's class on the
  heap for IL, a slot in the stack frame for cmm, the static link a
  pointer to it; the others IL's locals, cmm's SSA values. A record
  is a class for IL, words at offsets for cmm; an exception the
  machine's own for IL, `cut to` for cmm; the collector the VM's for
  IL, the runtime's by the roots for cmm.
- **What it asks of cmm that C and ML do not, together**: static
  links, records and arrays collected, exceptions, strings by the
  runtime. The proof that cmm is not "mini-cc's SSA" under another
  name.
- **The same tests both ways**: fork-tiger's 14 programs and their
  outputs, as plan_dotnet.md takes them, run by Microsoft's `dotnet`
  and mini-dotnet on one side, natively on arm and arm64 on the
  other. The differential check with qc-- (above) in test-all.
- **Its runtime on cmm**: an allocator and a copying collector in C,
  as fork-tiger's (`runtime/`, 511 lines with stdlib's 203), or
  mini-ml's own collector if its roots can be said the same way:
  decided at stage 5. Tiger's library the same functions as the
  class `Tiger` the IL back end writes.
- **Size** (estimates): the back end to cmm, the frames and the
  lowering, 500; its runtime 300: about **800**, beside
  plan_dotnet.md's 1,600 for mini-tiger with its IL. fork-tiger is
  2,376 lines (parsing 786, frontend 1,385, backend 85, main 120).
- A one-file TinyTiger.ml is not proposed: tiny/ has TinyC and TinyML
  for the compiled languages.

## How it meets mini-dotnet

Two levels, not two answers to one question: CIL is a virtual
machine's IR (a typed stack, objects, generics; the collector the
machine's), C-- a machine's (the front end's collector, through the
runtime interface). They meet:

- in the **JIT** (stage 6): IL, its stack's types known by the
  verifier (plan_dotnet.md's stage 6), to cmm's values; then the
  emitter;
- in **mini-tiger**: one front end, two back ends, IL there and cmm
  here (above).

## Sizes (estimates, not measured)

| part | lines |
|---|---:|
| cmm: the instructions, the builder | 200 |
| the grammar (ocamlyacc), the lexer, the printer | 550 |
| the verifier | 150 |
| Alloc and the emitter, the two emitters made one | 900 to 1,100 |
| mini-ml's lowering from its SSA | 300 |
| cmm, all | 2,100 to 2,300, against the 1,709 of the emitters it retires |
| mini-tiger's back end to cmm, its runtime | 800 (the front end plan_dotnet.md's) |

## Open questions

- The name: `cmm` (ocamlopt's), or another?
- Stage 2's IR: C's Ssa moved into cmm as is, or written anew with
  ML's needs, then C ported?
- C--'s syntax for the text, as far as it goes, or a syntax of ix's
  own closer to `-dssa`'s print?
- mini-tiger's cmm back end before or after stage 3 (mini-ml
  through cmm)? And before or after its IL back end (plan_dotnet.md
  proposes IL first)?
- mini-tiger's runtime on cmm: fork-tiger's shape, or mini-ml's
  collector?
- The roots by tables (stage 4): in this plan, or one of its own as
  proposed?

## Status

2026-10-29: plan written, after the analysis (qc--'s and fork-tiger's
sizes counted from `~/c--` and `~/tiger`, ix's by `wc`; the rest
estimates). Nothing built. Related: done/plan_cc.md (C-- turned down
as mini-cc's target), variants/modern.md (conventions 1 and 2),
plan_cc_ssa.md, plan_extern_register.md, plan_debugger.md,
plan_dotnet.md, plan_riscv.md,
docs/related-work/notes_cc_related_work.md.
