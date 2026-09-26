# A C compiler, from scratch: a tutorial for `languages/c/`

How a C file becomes the instructions that mini-ld links, on arm and
arm64, the Plan 9 way: a front end that reads C into a typed tree, and
one code generator that walks the tree and writes Plan 9's
instructions, asking a record of the machine only what the machine
decides. It is written for **a reader of mini-cc's code, not a
user of a C compiler**, and explains the ideas in the order the code
needs them.

It is the specification of the program planned in
[`plan_cc.md`](../plans/plan_cc.md), written before the code, to be
checked against it, as the other tutorials were; it was checked on
2026-09-24, and where the two differed the text now says what the code
does. The listings marked "checked" are goken's `5c -O0 -S` and `7c
-O0 -S`, on 2026-09-23.
Companions:
[`notes_cc_related_work.md`](../related-work/notes_cc_related_work.md),
[`notes_asm.md`](notes_asm.md) (the toolchain's first half, which this
one writes for), and the twins: the Principia book `compilers/`,
goken's 5c and 7c, and xix's `compiler/`.

## 0. Where the code is, and a reading order

| module | what | section |
|---|---|---|
| `languages/c/Tree` | the types, the tree, the symbols | §3, §4 |
| `languages/c/Pre` | the preprocessor | §3 |
| `languages/c/Lexer`, `Parser` (ocamlyacc) | C into a tree | §3 |
| `languages/c/Declare` | declarations, scopes, frames, initializers | §3, §7 |
| `languages/c/Check` | types, and the tree made explicit | §4 |
| `languages/c/Machines` | the types' sizes, the calling convention, per machine | §8 |
| `languages/c/compat/Acom` | 5c's arithmetic rewrites | §4 |
| `languages/c/compat/Gen` | code from the tree | §4, §5, §6, §7 |
| `languages/c/compat/Multiply` | a multiplication by a constant | §5 |
| `languages/c/compat/Arm`, `Arm64` | what each machine decides | §8 |
| `languages/c/compat/Regs` | 5c's registers, the frame's areas | §4, §7 |
| `languages/c/Emit`, `Com64`, `CLI` | the instructions, `-S`, the objects; arm's vlong calls; `mini-cc` | §8, §9 |
| `languages/c/simple/Lower`, `Gen` | `-simple`: a stack machine, for both machines | §10 |
| `languages/c/opti/Opti` | `-simple -O`: passes on the stack machine's code | §10 |

Each module's `.mli` says what it does and where it departs from 5c
and 7c, with the papers it follows; read Tree's first, then in the
order of the table. `languages/c/` is the language, shared;
`compat/` is the back end whose listings are 5c's and 7c's, byte for
byte; `simple/` (`mini-cc -simple`) the one whose contract is only the
behavior, a stack machine in 500 lines (plan_cc.md, decision 8).

## 1. From a `.c` to a running program

A function, and what 5c makes of it at `-O0` (checked):

```
   int                             TEXT  sum+0(SB),0,$8        a frame of 8 bytes: i and s
   sum(int *a, int n)              MOVW  R0,a+0(FP)            the first argument came in R0
   {                               MOVW  $0,R2
       int i, s;                   MOVW  R2,s-8(SP)            s = 0
                                   MOVW  $0,R3
       s = 0;                      MOVW  R3,i-4(SP)            i = 0
       for(i = 0; i < n; i++)      B     6(PC)                 to the test
           s += a[i];              B     2(PC)                 (continue: to the increment)
       return s;                   B     17(PC)                (break: after the loop)
   }                               MOVW  i-4(SP),R4            i++
                                   ADD   $1,R4
                                   MOVW  R4,i-4(SP)
                                   MOVW  i-4(SP),R2            the test: i < n, or leave
                                   MOVW  n+4(FP),R4
                                   CMP   R4,R2
                                   BGE   -7(PC)
                                   MOVW  i-4(SP),R1            s += a[i]
                                   SLL   $2,R1
                                   MOVW  a+0(FP),R5
                                   ADD   R5,R1
                                   MOVW  0(R1),R1
                                   MOVW  s-8(SP),R3
                                   ADD   R1,R3
                                   MOVW  R3,s-8(SP)
                                   B     -17(PC)               again
                                   MOVW  s-8(SP),R0            the result in R0
                                   RET
```

and the trip:

```
   mini-cc     preprocesses, parses, types the tree, makes it explicit,
              generates the instructions above, writes sum.5 (mini-asm's object)
   mini-ld     lays out and encodes (the frame's prologue, RET's epilogue,
              the branches), writes the executable
```

What stands out: every variable lives in its stack slot, and each
statement loads what it needs and stores what it made (this is `-O0`;
5c's registerizer would keep `i` and `s` in registers). The compiler
never computes an address or a frame: `s-8(SP)`, `n+4(FP)` and `6(PC)`
are for the linker. And the dead branches at the loop's top (`B
2(PC)`, `B 17(PC)`) are the targets that `continue` and `break` jump
to; the linker's `follow` removes what never runs.

## 2. Plan 9's C

The corpus is C89 with Plan 9's habits (the plan counts them):

- **`u.h`'s types**: `uchar`, `ushort`, `uint`, `ulong`, `vlong`
  (`long long`), `uvlong`, defined per machine; `nil` for a null
  pointer; `USED(x)` to say a variable is used.
- **Headers without guards**, included once by convention, `u.h` first,
  then `libc.h`.
- **No `#if`**: `#ifdef`, `#ifndef`, `#else`, `#endif` only; macros
  with arguments (152 of them), `#pragma varargck` for `print`'s
  formats (which mini-cc reads and ignores).
- **No bitfields, no designated initializers**; Plan 9's unnamed
  structure members, at most once.

## 3. The front end: characters, tokens, a tree

**The preprocessor** replaces `#include` by the file (from `-I` for
`<...>`, and the including file's directory for `"..."`), and a macro
by its body, its arguments substituted and the result rescanned.

**The lexer** needs one thing from the parser, C's famous one: whether
a name is a typedef. `T * x;` declares `x` when `T` is a type, and
multiplies otherwise; so the lexer looks the name up in the symbol
table, which the parser fills as it declares, and hands back a
type-name token for a typedef's.

**The parser** reads declarations with C's declarators, the part of C
where the syntax is inside out: `int (*f[4])(char*)` is an array of four
pointers to functions from `char*` to `int`, read from the name
outwards. It makes trees, OCaml variants (`Tree`): an expression is
its kind (`Binary (Add, l, r)`, `Unary (Ind, p)` for `*p`, `Assign`,
`Call (f, args)`, `Elem (x, m)` for `x.m`...) with its type and what
the code generator will learn of it; statements (`If`, `For`,
`Switch`, `Case`...), declarators (`Dptr`, `Dfunc`, `Darray` around a
`Dname`) and initializers have their own types. 5c's are one kind of
node, an operator with a left and a right, for all four; the passes
here return new trees where 5c's rewrite them in place.

## 4. Types, and the tree made explicit

**Typechecking** gives every node a type, and makes C's implicit rules
explicit nodes: the conversions (`char` to `int` in arithmetic, `int`
to `long`, a pointer and an integer), a pointer plus an integer scaled
by the pointee's size, an array into a pointer to its first element.
Constant expressions are folded.

**Two numbers per node**, which the code generator lives by (5c's
`sgen.c`):

- **addable**: how the node can be an operand as it is: a constant, a
  name (`x(SB)`), a stack slot (`x-8(SP)`), an address in a register
  plus an offset. A node that is addable needs no instruction to be
  used. It is a variant (`Aconst`, `Aname`, `Areg`, `Aindreg`...),
  where 5c's is a number (20, 10, 11, 12...).
- **complex**: how many registers the node needs to be computed
  (Sethi and Ullman's number): 0 for addable, and for `a op b` the
  larger of the two sides', plus one when they are equal. The code
  generator computes the more complex side first, so that the other
  never holds a register while it waits.

**64-bit arithmetic on arm** is rewritten as the tree is labelled
(Gen's `xcom`, with 5c's `com64.c`): arm
has 32-bit registers, so a `vlong` sum is a call (checked):

```
   vlong add(vlong a, vlong b)      5c: TEXT add(SB),$20
   { return a + b; }                    MOVW R0,.ret+0(FP)     the result: through a pointer
                                        ... a and b copied to the outgoing slots
                                        BL   _addv(SB)         libc's vlrt.c
                                    7c: MOV  a+0(FP),R0
                                        MOV  b+8(FP),R4
                                        ADD  R4,R0             one instruction
```

## 5. Code from a tree

**`cgen(n, dest)`** generates code that leaves the value of `n` in
`dest` (a register or an addressable node), or nowhere for a statement.
Registers are taken with `regalloc` and given back with `regfree`, per
expression: at `-O0` nothing survives a statement in a register. The
shape, for `l op r`:

```
   if r is more complex than l:      r into a register first, then l
   if r is a constant or addable:    l into dest, then  op r, dest
   else:                             l into dest, r into a register, op reg, dest
```

**Conditions** (`boolgen`) generate jumps, not values: `a < b && c`
branches away on the first false part, and `if` and `while` use the
jumps directly; a condition's value is made only when it is stored.

**Structures** are copied by `sugen`: on arm with `MOVM` (a load and a
store multiple), on arm64 word by word (checked, `mid` in §8). A
function that returns a structure gets a hidden pointer, in R0, where
it writes the result (`.ret+0(FP)`).

## 6. Statements, and switches

**`gen(stmt)`** (5c's `pgen.c`): a statement is code with a place to
go on `break` and `continue`, the loop's layout being §1's. `goto` and
labels are the same branches, patched when the label is seen.

**A switch** (5c's `swt.c`) is one of three shapes, by its cases
(checked):

- at least 3 cases whose range is less than twice their number: **a
  table**, `CASE` and one `BCASE` per value, bounds checked first (on
  arm `CASE.LS`, conditional; on arm64 `BHI` to the default, then
  `CASE`);
- fewer than 5 cases: **a chain** of comparisons;
- otherwise **a binary search**, halving the sorted cases.

## 7. Calls and frames

The first argument is passed in R0 (the callee stores it in its slot,
`MOVW R0,a+0(FP)`), the others on the stack, where the caller writes
them into its outgoing area (`MOVW R1,8(R13)`), and the result comes
back in R0. The frame (`TEXT f(SB),$8`) is the locals' size: the
compiler adds up the locals and the largest outgoing area, and the
linker writes the prologue and the epilogue from it (notes_asm.md
§5).

## 8. The two machines: one generator, two records

The same functions from 7c (checked), against §1's and §4's:

```
   sum (7c)                          what the record said
   MOV   R0,a+0(FP)                  a pointer is 8 bytes: MOV, and n is at +8
   MOVW  $0,s-8(SP)                  a zero is stored from the zero register
   ...
   MOVW  i-4(SP),R4
   SXTW  R4,R4                       an int index widened to a pointer's size
   LSL   $2,R4
   MOV   a+0(FP),R5
   ADDW  R4,R3,R4                    32-bit arithmetic is the W form
   RETURN                            7l's pseudo-return

   mid (a structure returned)
   5c:  MOVM.U 0(R5),[R1,R2]         7c:  MOVW 0(R1),R2
        MOVM.U [R1,R2],0(R3)              MOVW 4(R1),R3
                                          MOVW R2,0(R4)
                                          MOVW R3,4(R4)
```

What the record holds, then (goken's `txt.c` and `gc.h` per machine):

- the sizes of the types, and the pointer's; the alignment;
- the registers: which may hold a value, which is the result's (R0),
  the zero register if any;
- **the instruction for an operator on a type** (5c's `gopcode`: `ADD`
  on arm; `ADD` or `ADDW` on arm64, by width) and **for a move between
  two types** (`gmove`: the widenings and narrowings, `SXTW`, `MOVBU`,
  the float conversions);
- how a structure is copied, and how a switch's table is entered;
- what is a call rather than an instruction: `vlong` arithmetic on
  arm.

The code generator has none of these decisions, and that is the claim
the second machine checks (plan_cc.md, decision 1).

## 9. The objects

The compiler writes mini-asm's objects (`Asm.obj`): the instructions,
the `TEXT`s, and the data as `DATA` and `GLOBL` (a string literal is a
static `.string<>` symbol, 8 bytes per `DATA`, as §1's listings show).
`-S` prints the same instructions in Plan 9's syntax, which mini-asm
reads back into the same object. So mini-ld links a compiled file and
an assembled one alike, and a `.s` written by hand (libc's `rt0.s`)
sits beside the compiled ones.

## 10. The other back end: a stack machine (`-simple`)

Everything so far is **compat**, the back end whose listing is 5c's,
instruction for instruction: its Sethi-Ullman order, its
addressability, its arithmetic rewrites (`acom`), its register
allocator, its three shapes of switch, its multiplications by shifts
are all there because 5c has them. `mini-cc -simple` is the other
answer to "what makes a C compiler": the same front end, the same
objects and calling convention, and a back end whose only contract is
that the program *behaves* as 5c's does (plan_cc.md, decision 8). It
is two modules, `Lower` and `Gen`, 561 lines of code for both machines
(with `-dir`'s listing, and the forms `Opti` makes) against compat's
1,622.

**Lower** turns the typed tree into code for a stack machine: every
operation takes its operands from the top of a stack and pushes its
result. A value is an integer of 1, 2, 4 or 8 bytes, signed or not, or
a float; a structure's value is its address, and assigning one copies
its bytes. `mini-cc -simple -dir` prints it; `s += a[i]` in §1's `sum`
(on arm, where an int is 4 bytes, `i4`, and a pointer unsigned, `u4`):

```
   lea s-8(SP)        s's address
   dup                kept for the store
   load i4            s
   cvt i4 i4          x op= y is computed in the operation's type: here s's, no code
   lea i-4(SP)
   load u4            i, as the index's type
   int 4 u4
   op mul u4          i*4: the front end scaled the index
   lea a+0(FP)
   load u4            a
   swap               a + i*4: the deeper operand came first (below)
   op add u4
   load i4            a[i]
   op add i4          s + a[i]
   cvt i4 i4          back to s's type, no code
   store i4           into s, the value left on the stack
   cvt i4 i4          the expression's value, in its type, no code
   drop               a statement's value, thrown away
```

**Gen** keeps the stack in registers: the slot at depth *i* is R*i*, or
F*i* when it holds a float (R1 to R7 and F1 to F6 on arm, R1 to R15
and F1 to F15 on arm64). So the code writes itself, one or two
instructions per operation (checked, `mini-cc -simple -m 5 -S`):

```
   MOVW  $s-8(SP),R1          lea         depth 1
   MOVW  R1,R2                dup         depth 2
   MOVW  0(R2),R2             load i4
   MOVW  $i-4(SP),R3          lea         depth 3
   MOVW  0(R3),R3             load u4
   MOVW  $4,R4                int 4       depth 4
   MUL   R4,R3,R3             op mul      back to 3
   ...
   ADD   R3,R2,R2             op add i4   s + a[i] in R2
   MOVW  R2,0(R1)             store i4
```

The whole of `sum` is 52 instructions against compat's 30: no
immediate operands (`MOVW $4,R4` then `MUL`, where 5c shifts), every
variable's address computed before its load, a comparison made into
0 or 1 before it is tested. That is the price of a back end that
knows no instruction's forms beyond one per operation, and what
opti/, planned beside it, is for.

**Calls.** Every register is the caller's to save, in Plan 9's
convention, so a call spills the live slots to the frame, below the
locals, and reloads them after. The arguments go straight to the
outgoing area at their offsets (the first also in R0 when it is a
word), and an argument that itself calls is computed first into a
temporary, since that inner call would overwrite the area. A
structure's result goes to a temporary whose address is the hidden
first argument. That is 7c's convention, so what `-simple` compiles
calls libc, and libc compiled by `-simple` is called by it: the test is
all of goken's libc through it.

**Three things the tests found**, each a lesson about stack machines
(notes_fuzzing_techniques.md tells how they were found):

- *The stack's depth at a label.* A label is reached with the depth of
  the jumps to it. In `x || 255` the constant side never jumps to the
  "false" label, so there was no jump to take the depth from, and the
  code after it took it from the dead code before; now a label no jump
  reaches after dead code is a statement's, where the stack is empty.
- *Nothing live across `setjmp`.* In `switch(setjmp(b))` the switch's
  temporary address was pushed before the call, spilled across it, and
  reloaded after; when `longjmp` returns there, the spill slot has
  been reused by a later call. 5c never has this problem, because
  Sethi-Ullman's order computes a call first. So `-simple` computes a
  call's value before the address it is stored to.
- *Seven registers are few.* `x ^= (a % b) != (c - (x | a[i & 7]))`
  needs 8 slots in left-to-right order. The cure is Sethi-Ullman's
  idea without its machinery: Ershov's number, the slots a subtree
  needs, and the deeper operand of a binary operator first, then a
  `swap` (as `a + i*4` above). A random program has not been refused
  since.

**vlong on arm** is 5c's structure: a vlong's value is its address,
like a structure's, and its operations are libc's calls (`_addv`,
`_sl2v`), which the front end's `Com64` makes for both back ends.

**opti**: `-simple -O` runs `Opti`'s passes on the stack machine's
code before `Gen`, each a rewrite of the list (`-dir` shows the
result). Measured first (`mini-5i -s` counts a program's instructions,
`-t` traces them), -simple's excess over compat was moves, addresses
and 1-or-0 comparisons, and the passes remove them: `lea m; load` is
one load from `m`, a constant operand an immediate, `op lt; jz` one
compare-and-branch, a stored value that is dropped never moved. `sum`
becomes, on arm, 24 instructions to 5c's 30:

```
   loadat i-4(SP) i4          MOVW  i-4(SP),R1
   loadat n+4(FP) i4          MOVW  n+4(FP),R2
   brnot lt i4 L3             CMP   R2,R1
                              BGE   ...
   ...
   loadat i-4(SP) i4          MOVW  i-4(SP),R1          i++
   opimm add i4 1             ADD   $1,R1
   putat i-4(SP) i4           MOVW  R1,i-4(SP)
```

Two more follow 5c's optimizer's ideas, not its code: **regs** keeps
a function's variables whose address is never taken in registers,
chosen by their uses weighted by loop depth, a liveness dataflow
saying which calls they are live across (Plan 9 saves no register
across a call); **peep** works on the instructions `Gen` wrote: copy
propagation, 5c's `subprop`, and dead code by the registers'
liveness, a dead instruction made a NOP that mini-ld drops. `sum`'s
loop is then 10 instructions on arm64, its variables in R19-R22.
Whole programs, libc included, run 1.13 to 1.34 times compat's
instructions, against 2.4 for -simple (plan_cc.md's opti section has
the tables, `languages/c/tests/count.sh` the measure).

## 11. Compared with goken and xix

| | goken (C) | xix (OCaml) | mini-cc |
|---|---|---|---|
| front end | yacc, 7,900 lines | ocamlyacc, typechecker complete | ocamlyacc; the preprocessor and lexer by hand |
| back ends | one per machine, 3,600 to 3,900 lines each, plus 2,700 of optimizer | one, arm, mostly unwritten | one, with a record per machine |
| objects | Plan 9's | xix's | mini-asm's |
| optimizer | registers, peephole | none | compat: none (`-O0`); `-simple -O`: `Opti`'s passes (§10) |
| lines | about 22,000 (16,700 without the optimizers) | 5,553 | 5,253 (the target was 3,500); the front end and `-simple`, 3,487 lines of code |

## 12. How it is tested

- **The listings**, function by function against `5c -O0 -S` and `7c
  -O0 -S`, over the corpus.
- **The executables**: goken's libc and programs, compiled and linked
  by ix only, against goken's, byte for byte, and run.
- **A fuzzer**: random C of the subset through both compilers.
- **The corners** the corpus may not reach (`languages/c/tests/c/`):
  declaration words, the lexer, structure copies, initializers,
  vlongs.
- **`-simple`, by behavior** (`languages/c/tests/simple.sh`): goken's
  libc and the programs compiled by it, run, their output compared
  with 5c's and 7c's; and the fuzzer's random programs.

## 13. Exercises

- **Registers**: 5c's `reg.c`, variables into registers by a dataflow
  analysis, at last `-O2`; and its peephole.
- **Bitfields**, and `#if`.
- **A third machine** (riscv64): a third record, and mini-ld's third
  module.
- **An intermediate language**, the other answer to the plan's
  question: `-simple`'s stack machine (§10), and the one-file
  variant's.
- **A pass on the stack machine**, measured as `Opti`'s were (§10):
  a result extended then stored narrower (`sxtw` before a 32-bit
  store) needs no extension; `*p` and `a[i]` could fold a constant
  offset into the load, as 5c's `fold_offset` does.

## 14. In ix

mini-cc finishes ix's toolchain: C to objects, objects to
executables, all in OCaml, byte for byte with goken's. The kernel and
the emulator come next; the compiler builds their C parts.

## Glossary

- **addable, complex**: a node's two numbers (§4).
- **Sethi-Ullman number**: registers needed to compute an expression
  (§4).
- **boolgen**: generating a condition as jumps (§5).
- **the record**: what a machine decides for the code generator (§8).
- **stack machine**: code whose operations take their operands from a
  stack and push their result (§10).
- **spill**: a register's value saved to memory across a call (§10).
- **Ershov number**: the stack slots, or registers, a subtree needs
  (§10).

## References

- Ken Thompson, "Plan 9 C Compilers", 1990; and "A New C Compiler",
  1990.
- Brian Kernighan and Dennis Ritchie, *The C Programming Language*,
  2nd edition, 1988.
- Ravi Sethi and Jeffrey Ullman, "The Generation of Optimal Code for
  Arithmetic Expressions", *JACM*, 1970.
- Christopher Fraser and David Hanson, *A Retargetable C Compiler:
  Design and Implementation* (lcc), 1995.
- The Principia Softwarica book `compilers/` (5c).
