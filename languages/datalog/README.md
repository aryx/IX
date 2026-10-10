# languages/datalog: mini-datalog

Datalog, written here: a Prolog text without compound terms (read by
`languages/prolog`'s reader), its rules run bottom up until nothing is
new. For program analyses: a dataflow analysis is a fixpoint of rules
over facts, which is what this computes. The plan:
[`plan_prolog.md`](../../docs/plans/plan_prolog.md), "Datalog".

| module | what |
|---|---|
| `Datalog` | relations (sets of tuples of symbols), rules, queries; a text loaded and checked (a rule must be safe) |
| `Datalog_eval` | the strata (a relation is whole before another negates it), the fixpoint (semi-naive, or naive), a body joined by indexes made on demand |
| `CLI`, `Main` | the command: files, `-q query`, `-all`, `-naive`, `-s` |

`mini-datalog -h` says how, by an example.

## Why not mini-prolog

A rule whose head is in its own body (`path(X, Y) :- path(X, Z),
edge(Z, Y).`) never ends in Prolog, which searches down from the
question; and an answer found by two ways is given twice. Here the
facts come first and every rule is applied until no tuple is new: it
always ends, each tuple is there once, and the order of the rules or
of a body's atoms changes the time only.

## What it runs

The author's pointer analysis of 2014, as it is: `analyses/pointer.dl`
(pfff's `h_program-lang/datalog_code.dl`, copied; 15 rules: Andersen's analysis of C,
the calls through pointers found by the analysis and fed back to it),
its `point_to(A,B)?` included, on pfff's test's facts
(its `tests/mini/datalog/pointer.dl`, by hand: not a test here) and on `tests/pointer_facts.dl`
here (a call through a pointer).

`tests/liveness.dl` and `tests/dominators.dl` are the two dataflow
examples of the plan's table, on graphs written by hand.

And a C file's own facts, `mini-cc -facts` (`languages/c/facts/`: the
17 relations of those rules, made from mini-cc's tree before its
typing). `languages/c/facts/tests/pointers.c` is each way a pointer is
made, moved and called through; the analysis finds a call through a
table of functions reaching both of its functions, one through a
structure's member, one through a parameter. On ix's own C
(2026-10-09, OCaml's build):

| program | lines of C | facts | `point_to` found | the analysis |
|---|---:|---:|---:|---:|
| mini-ml's runtime (`languages/ml/runtime/runtime.c` and what it includes) | 2,458 | 2,726 | 1,505 | 0.14 s |
| lib_core's libc (60 files, each its facts, together) | 3,636 | 2,950 | 5,155 | 0.41 s |

Neither has a call through a pointer that the program itself gives a
target (libc's two, `atexitrun`'s and `_vasop`'s, are given theirs by
a program that links it).

## Control flow and liveness, checked against the compilers

A function as facts of its control flow and of what each instruction
reads and writes, by each compiler, and the rules in `analyses/`:

| | facts | rules | checked against |
|---|---|---|---|
| mini-ml | `mini-ml -flow` (`languages/ml/facts/Ssa_facts`): the SSA form's blocks, points, definitions, uses, phis | `liveness_ssa.dl` (a phi's operand is live at its predecessor's end), `dominators.dl` (and the loops' back edges) | `Alloc`'s liveness and `Ssa_build`'s dominators |
| mini-cc | `mini-cc -flow` (`languages/c/facts/Ir_facts`): the stack code's instructions, the variables a register may hold | `liveness.dl` (the textbook's three rules, and what is live across a call) | `Opti`'s liveness (its `regs` pass) |

Each compiler prints its own answer as facts of other names (`-dflow`:
`own_live_in`, `own_idom`...), and a file of rules beside the tests
(`check.dl`, `flow_check.dl`) asks for each tuple one has and the
other has not: the comparison is a Datalog question, and its answer
must be empty. Each test also takes a rule out and expects
differences, so that an empty answer says something. On ix's own
programs (2026-10-10, OCaml's builds; `languages/ml/facts/tests/ix.sh`
and `languages/c/facts/tests/ix.sh`), no tuple differs:

| program | files | functions | blocks (C: instructions) | facts | tuples found | differ | mini-datalog |
|---|---:|---:|---:|---:|---:|---:|---:|
| `languages/prolog` | 8 | 328 | 3,052 | 51,505 | 243,080 | 0 | 1.2 s |
| `languages/datalog` | 4 | 94 | 836 | 15,438 | 57,580 | 0 | 0.3 s |
| `languages/ml` | 22 | 1,188 | 17,422 | 292,171 | 4,229,680 | 0 | 16.8 s |
| `languages/c` | 26 | 894 | 12,610 | 201,133 | 2,238,679 | 0 | 8.7 s |
| `languages/scheme` | 12 | 373 | 3,609 | 63,545 | 376,989 | 0 | 1.6 s |
| `assembler` | 7 | 97 | 1,663 | 25,150 | 199,009 | 0 | 0.8 s |
| `linker` | 9 | 485 | 6,609 | 106,911 | 1,073,311 | 0 | 4.5 s |
| mini-ml's runtime (C) | 1 | 209 | 6,486 | 14,371 | 18,903 | 0 | 0.2 s |
| lib_core's libc (C, arm64's files) | 59 | 186 | 8,811 | 20,065 | 48,990 | 0 | 0.9 s |

mini-ml makes a file's facts in a tenth of the time the rules then
take (2.3 s for `languages/ml`); the compiler's own liveness of those
1,188 functions is a part of the 2.3 s. The rules for dominators are
in the square of a function's blocks.

## ML's closures, and what a program never calls

`mini-ml -facts` (`languages/ml/facts/Closure_facts`) says an ML unit
in the relations of the author's pointer analysis of C, and
`analyses/pointer.dl` runs on them unchanged: a function written is a
place, a variable points to the functions it may be, a call is a call
through a pointer, `f x y` two of them. What a block holds is by its
field's name, as the rules have it for C (`'fld:run'`, `'con:Some.0'`,
`'tuple:2.1'`). The units' facts put together are a program's, and
`analyses/calls.dl` (11 rules) asks: who calls whom, what is never
called, what no unit's toplevel reaches, what is given one argument
and never its next.

`languages/ml/facts/tests/program.sh dir...` is the report for a
program with lib_core (2026-10-10, OCaml's builds):

| program | units, with lib_core's 69 | functions | calls | targets found | `point_to` | mini-datalog | its own functions unreached |
|---|---:|---:|---:|---:|---:|---:|---:|
| mini-prolog | 77 | 2,676 | 13,548 | 22,506 | 479,189 | 4.1 s | 0 |
| mini-datalog (with `Prolog`, `Prolog_read`) | 75 | 2,381 | 11,901 | 20,759 | 415,250 | 3.5 s | 14 |
| mini-asm | 76 | 2,247 | 11,909 | 21,464 | 401,315 | 3.4 s | 11 |
| mini-ld (with `Asm`, `Show_asm`) | 80 | 2,838 | 16,800 | 30,407 | 565,368 | 5.3 s | 2 |
| mini-scheme | 81 | 2,633 | 13,695 | 45,710 | 1,191,444 | 10.3 s | 11 |
| mini-cc (with assembler/) | 102 | 3,822 | 26,049 | 152,364 | 5,710,249 | 67 s | 51 |
| mini-ml (with the assembler's four units) | 98 | 4,356 | 29,839 | 517,653 | 7,039,841 | 146 s | 62 |

What it finds, each kind looked at: a unit's functions that this
program does not use and another does (mini-datalog's 14 are
`Prolog`'s `copy`, `variables`, `text_of`..., mini-prolog's own;
mini-scheme's `Scheme_eval.call` and `resume` are mini-drscheme's;
every `Highlight_*` is mini-emacs's; mini-cc's 51 are mostly the
assembler's lexer and parser, which it does not call); the `show`
functions a compiler without deriving leaves as stubs (`Ast`'s 26);
and functions no program of ix names, found by a search of the tree
after: `Scheme.kind`, `Scheme_eval.defined`, `Asm.cond_bits`.
mini-prolog's call of a built-in (`Prolog_machine`'s table) reaches
its 61 built-ins.

It errs on the side of "reached": a function is reached if any call
that the facts say may reach it is in reached code, and every unit
given is a root, its toplevel run. Where it could miss a call: a
function passed through an array or a C function comes back out of
one place for all of them (`ext`), so it is not lost; a call that
reaches nothing in code that runs is printed (`-holes`: 13 to 17 a
program, all read for mini-prolog: each is a parameter of a function
that this program never calls, in a `fun () -> ...` handed to
`Fun.protect`, which is called).

## What is not there

Reaching definitions; a call's context (every call of a function is seen together: mini-ml's 17 targets a call are that); values in a lattice (constants, intervals); aggregates
(count, min); a fact file's own fast format (a fact is read by
Prolog's reader); a join's order chosen (it is the order written, the
new tuples' atom first).

## Tests

`tests/run.sh`: on dune's build and on mini-ml's (`-5`: arm under
mini-5i, seven seconds), each program's tuples against its `.out`, and
the semi-naive way against the naive one; what is refused, each with
its line. The `.out` files were read, not made by another Datalog.

## Its speed

`tests/bench.sh` (arm64, 2026-10-09):

| program | tuples | OCaml's build | mini-ml's |
|---|---:|---:|---:|
| the paths of a chain of 1,000, recursion on the left | 500,500 | 0.96 s, 49 MB | 6.8 s, 190 MB |
| the same, recursion on the right | 500,500 | 1.4 s, 72 MB | 13.1 s, 263 MB |
| a chain of 200, semi-naive | 20,100 | 0.04 s | 0.11 s |
| a chain of 200, naive | 20,100 | 1.7 s | 10.2 s |
| the pointer analysis on 1,000 random assignments | 35,003 | 3.9 s | 33.7 s |

The last is the analysis's worst case, not a program's: among random
assignments every variable comes to point to every address, and the
rules for `*p = q` and `p = *q` join two such sets (8.8 million
firings for 35,003 tuples; with 3,000 assignments, 218 million and 108
seconds). Some 2 million firings a second by OCaml's build, a seventh
of it by mini-ml's.
