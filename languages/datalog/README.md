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

## What is not there

Facts from an ML program, and a program's control flow as facts (the
plan's stages 9 and 10); values in a lattice (constants, intervals); aggregates
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
