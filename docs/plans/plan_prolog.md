# Plan: Prolog in ix, and after it a Datalog engine for program analysis (`languages/prolog/`, `languages/datalog/`)

The author (2026-10-09), told that of the paradigms `languages/` has
not, logic programming is the first to add: "let's write a plan
document for Prolog; note that at some point I would love to also make
a datalog engine and use it especially for fixpoint program analysis,
like pointer and controlflow and dataflow analysis, of OCaml and C".

The short answer: **Prolog is new code, about 1,300 lines of .ml (an
estimate), with nothing to copy: the playground has no Prolog.
Datalog is a second engine, about 500 lines (an estimate), that shares
Prolog's reader and nothing of its machine; and its first program is
already written, by the author, in 2014.**

- **mini-prolog**: Edinburgh's Prolog, the core of the ISO standard.
  A reader with operators, a machine whose continuation is data (as
  Scheme's is), the built-ins, a prelude in Prolog. Run on Linux and
  on mini-9pi's console, as mini-scheme.
- **mini-datalog**: rules without function symbols, evaluated bottom
  up to their fixpoint. Prolog's machine cannot do it: the author's
  own pointer analysis has `point_to` in the body of `point_to`, and
  goes round for ever under Prolog's search.
- **The analyses**: facts made from mini-cc's and mini-ml's trees,
  rules in files. pfff's `datalog_code.dl` (171 lines, 15 rules, a
  pointer analysis of C with the calls through pointers) and
  `datalog_c.ml` (671 lines, the facts from C) are the start; pfff ran
  them on bddbddb, a Java program, and on a toy in Lua.

Its numbers are `scripts/stats/prolog_survey.sh`'s (run 2026-10-09,
against pfff at `ec21095a`, 2017-02-07). The lines of what is to
write are estimates, from the sizes of ix's other languages
(mini-scheme 1,686 lines of .ml, mini-pascal 1,917).

**Status: mini-prolog, mini-datalog and `mini-cc -facts` written, on
Linux** (2026-10-09: stages 1 to 3, 7 and 8; see Status at the end).
Not done: mini-9pi's card (4), the WAM (5), the highlighter (6),
control flow and dataflow from the compilers' trees (9), ML (10).

## What there is

Nothing in ix, nothing in the playground (its `languages/` has basic,
hypertalk, lisp, postscript, scheme, smalltalk and others, no prolog);
principia's old tree has a `languages/prolog/` directory of 2014,
empty. No Prolog and no Datalog on this machine (`swipl`, `gprolog`,
`yap`, `souffle`: none), so nothing to compare an answer with today.

What the author wrote before, in pfff, all of it read by SWI-Prolog or
bddbddb then:

| file | lines | what |
|---|---:|---|
| `h_program-lang/datalog_code.dl` | 171 | the rules: `point_to`, `assign`, `call_edge`; 15 rules, no negation |
| `h_program-lang/datalog_code.ml` | 357 | the facts as a type (17 constructors), written for bddbddb and for the toy |
| `lang_c/analyze/datalog_c.ml` | 671 | C to facts, over `ast_cil` (an expression made instructions) |
| `mini/datalog_minic.ml` | 347 | the same for a small C, the first version |
| `tests/mini/datalog/pointer.dl` | 45 | a test: five assignments, three rules, a query |
| `tests/c/datalog/` | 6 files | C files to make facts of |
| `h_program-lang/prolog_code.pl` | 407 | codequery: 50 clauses over a code base's facts (`children`, `calls`...) |
| `h_program-lang/prolog_code.ml`, `graph_code/graph_code_prolog.ml` | 175, 206 | those facts, from codegraph's graph (still in `semgrep-pfff-langs`) |

`datalog_code.dl` says, of its last rule (`call_edge(I, F) :-
call_indirect(I, V), point_to(V, F).`): "power of mutually recursive
analysis! dataflow -> controlflow -> dataflow", and of the whole: "I
always wanted (but was never able to write ...) an interprocedural
(dataflow) analysis. With Datalog I did it in one day!". That file is
the plan's second half in one page.

`prolog_code.pl` asks little of a Prolog: three `op` directives, two
`discontiguous`, `findall` (3 times), `not` (7), `writeln` (2),
`length` (1). mini-prolog as planned below would read it.

In ix, what a fact would be made from:

- C: `languages/c/Tree.ml` (173 lines; the typed trees after `Check`)
  and `languages/c/simple/Ir.ml` (66; a function as stack code with
  labels and jumps).
- ML: `languages/ml/Ast.ml` (168), `languages/ml/simple/Ir.ml` (84)
  and `languages/ml/ssa/Ssa.ml` (50): a function as blocks, each with
  its predecessors, its phis, its instructions numbered. The
  control-flow graph is there already.
- Three passes compute a liveness by hand today, each a backward
  dataflow to its fixpoint: `languages/c/opti` (`Opti`, `Peep`) and
  `languages/ml/ssa/Alloc`. They are what a Datalog's answer can be
  checked against.

## Prolog: what to write

```
  text ──Prolog_read──▶ terms ──Prolog_db──▶ clauses
            │ (operators)                       │
            ▼                                   ▼
        a query ───────────────────────▶ Prolog_machine ──▶ answers, one at a time
                                          goals, choice points, trail
                                                │
                                          Prolog_builtins, Prolog_prelude (in Prolog)
```

| module | what | lines (estimate) |
|---|---|---:|
| `Prolog` | a term (an atom, an integer, a variable, a compound); a variable a reference bound or not; printing (`write`, `writeq`, operators and lists back as written) | 200 |
| `Prolog_read` | the tokens, and a term read by the operators' priorities; the table of operators, which `op/3` changes | 300 |
| `Prolog_db` | the clauses of a predicate by name and arity, a clause renamed for a call; `assert`, `retract` | 100 |
| `Prolog_machine` | unification and the trail; the goals to prove, the choice points; the cut; `catch` and `throw`; a budget of steps | 300 |
| `Prolog_builtins` | `is` and comparison, the type tests, `functor`, `arg`, `=..`, `copy_term`, `findall`, the atoms' (`atom_codes`, `atom_length`...), `write`, `nl`, `read`, `consult`, `halt` | 300 |
| `Prolog_prelude` | `append`, `member`, `reverse`, `length`, `between`, `not`, `forall`... and the translation of `-->`, written in Prolog | 100 (of Prolog) |
| `CLI`, `Main` | files consulted, `-g goal`, a prompt (`?-`), `;` for the next answer | 120 |

About 1,300 lines of .ml in all, and the .mli. A highlighter for
mini-emacs (`languages/prolog/highlight/`, as each language has) is
some 60 more.

What it is not: no modules, no strings beside atoms and lists of
codes, no occurs check (as every Prolog by default), no constraint
solver, no garbage collector of its own (OCaml's), no tabling (that is
what Datalog is for here). Floats: an open question.

## Prolog: decisions (proposed, for the author)

1. **Written from scratch**, by the books: Clocksin and Mellish for
   the language, the ISO standard's core for what a built-in answers,
   Warren's 1983 report and Aït-Kaci's tutorial for the machine. No
   file imported.
2. **The machine: goals and choice points as data first, the WAM
   after, as a switch.** The first machine keeps clauses as terms: a
   call renames a clause and unifies its head; the goals to prove are
   a list, the choice points a stack, each with the trail's height
   and the goals of that moment. It is Scheme's CESK machine's
   cousin: the continuation is data, so a budget of steps, a break,
   and a tracer cost nothing. Some 300 lines.
   The WAM (clauses compiled to `get`, `put`, `unify`, `call`, `try`,
   `retry`, `trust`; the first argument indexed) is the machine the
   language is known by, as P-code is Pascal's and the bytecode
   Smalltalk's; it is some 700 lines more (an estimate), and faster by
   a factor not known here. It comes as a second machine under a flag
   (`-wam`), the first one kept, the same tests on both, the speed in
   a table: the author's way for an optimization.
   The other first machine, a solver of some 150 lines by OCaml's own
   closures (a success and a failure continuation), is shorter and was
   not chosen: the cut is awkward in it, and nothing of it can be
   stopped, stepped or shown.
3. **The reader is written by hand**, not ocamlyacc's (which is the
   default for a real grammar here). The reason is `op/3`: a program
   declares its operators while it is read (`:- op(42, xfx, calls).`,
   the author's own in `prolog_code.pl`), so the grammar is not known
   when a table would be made. A reader by priorities (Pratt's) is
   some 150 lines of the 300.
4. **`languages/prolog/`, flat, the program mini-prolog**, in the
   README's second table ("the languages that are run"). On mini-9pi's
   card: `prolog`. The name as mini-scheme's: no twin of a Plan 9
   program, Plan 9 has no Prolog.
5. **What a built-in answers is ISO's**, where ISO says; errors are
   thrown as terms and an uncaught one is said with its clause's file
   and line. The integers are OCaml's (63 bits, 31 on a Pi1 by
   mini-ml's arm: said, not hidden).
6. **The tracer is the four ports** (Byrd's box: call, exit, redo,
   fail), `-trace`: what the stepper is to mini-scheme. Each port a
   line, by the first machine only.
7. **The tests are by text**: a directory of `.pl` files and what each
   prints (`languages/prolog/tests/`), compared by dune's build and by
   mini-ml's, on arm64 and on arm under mini-5i; in `make test-lite`.
   The expected output is checked once against SWI-Prolog if the
   author installs it (none here), else by reading. The programs: the
   classical ones (the ancestors, `append` run backwards, the eight
   queens as `queens.scm` so the two machines are compared, naive
   reverse of 30 elements for the inferences a second, the zebra
   puzzle, Warren's derivative, a grammar by `-->`, the interpreter of
   Prolog in three clauses) and the author's `prolog_code.pl` over a
   small `facts.pl`.

## Datalog: what it is, and why not Prolog's machine

A Datalog program is a Prolog text with no compound term: facts
(`assign('w', 'p').`) and rules (`point_to(P, L) :- assign(P, Q),
point_to(Q, L).`). The reader is Prolog's. The evaluation is the
other way round:

- Prolog starts from the question and searches down, depth first. A
  rule whose body names its own head first does not end; and an answer
  found twice is given twice.
- Datalog starts from the facts and applies every rule until nothing
  new comes: the least fixpoint. It always ends (no function symbol,
  so the tuples are finite), each tuple is there once, and the order
  of the rules and of a body's atoms changes nothing but the time.
  That is a dataflow analysis's own definition, which is why the
  author's rules read as the textbook's.

The engine:

| module | what | lines (estimate) |
|---|---|---:|
| `Datalog` | a program: relations, rules, atoms; checked (a head's variable is in its body, a negated atom's variables are bound, the arities agree) | 100 |
| `Datalog_relation` | a relation: a set of tuples of integers (a symbol is its number), with an index for each set of columns a rule looks it up by | 120 |
| `Datalog_eval` | the strata (a relation negated is computed before); in a stratum, the rules to their fixpoint: naive, and semi-naive (a rule run with one body atom taken from the last round's new tuples) | 200 |
| `CLI`, `Main` | rule files, fact files, a query (`point_to(A, B)?`, the syntax of the author's files), a relation written as lines | 100 |

About 500 lines. Naive first and semi-naive as the switch, both kept;
then the indexes; the join's order as written first.

**Negation, stratified**, is in from the start though the pointer
analysis has none: liveness needs it (`live(V, P) :- succ(P, Q),
live(V, Q), not def(V, P).`), and dominators too.

## The analyses

Each is a file of rules and a maker of facts. The makers belong to
their compiler (a `facts/` folder in `languages/c/` and in
`languages/ml/`, as `highlight/` and `simple/` are), the rules to
`languages/datalog/analyses/`.

| analysis | of | facts from | rules |
|---|---|---|---|
| pointer analysis (Andersen's, by inclusion), and the call graph with the calls through pointers | C | `Tree`, after `Check`; pfff's 17 relations | `datalog_code.dl`, the author's, as it is if it can be |
| reachability, dominators | C, ML | `Ssa`'s blocks and predecessors; C's `Ir` labels and jumps | new, a few lines each |
| liveness, reaching definitions | C, ML | the same, with each instruction's uses and definitions | new; checked against `Alloc`'s and `Opti`'s own |
| which closures reach a call (0-CFA), and the call graph | ML | mini-ml's resolved tree | new; the same shape as the pointer analysis (`call_indirect`) |
| what is never called | ix itself | the two call graphs | a line; a report, and lines to remove |

An analysis is a tool first (a report on a program, on ix). Whether a
compiler's pass then reads its answer (a call made direct when one
closure reaches it, in mini-ml) is a later question, and
[`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md)'s.

Not in a plain Datalog: constant propagation and intervals, whose
values are a lattice's and not a set's (Flix's and Soufflé's
extensions). Left out; an open question below.

## The stages (each checked before the next)

Prolog:

1. **Terms, the reader, the printer.** Check: a text read and written
   back is the same, operators and lists included; `op/3`.
2. **The machine, the built-ins, the prelude, the command: mini-prolog
   on Linux.** Built by dune and by mini-mk; mini-ml compiles it (no
   optional argument, no functor, at most seven parameters: written
   that way from the first line). Check: the `.pl` files' output, the
   same by both builds, arm64 and arm under mini-5i.
3. **The rest of the language**: `assert` and `retract`, `findall`,
   `catch` and `throw`, `-->`, `-trace`. Check: the grammar, the
   three-clause interpreter, `prolog_code.pl` on a `facts.pl`.
4. **On mini-9pi's console**: `/bin/prolog` and a file in
   `/lib/prolog/`. Check: a recorded session, as `check-scheme`.
5. **The WAM**, `-wam` (decision 2). Check: the same outputs; naive
   reverse's inferences a second by each machine, each build.
6. The highlighter, for mini-emacs.

Datalog (after stage 3; it needs the reader only):

7. **The engine**: `mini-datalog`. Check: pfff's `pointer.dl` gives
   its `point_to`; the same tuples naive and semi-naive; a rule that
   negates through its own recursion refused, and said.
8. **C's facts and the pointer analysis.** Check: pfff's six C files
   and one of ix's own (`tiny/TinyLib/c/`, or mini-xv6), a function
   called through a pointer found; the time and the tuples, in a
   table.
9. **Control flow and dataflow**, from `Ssa` and from C's `Ir`.
   Check: the liveness the same as `Alloc`'s, function by function,
   on ix's own files.
10. **ML's closures and ix's call graph.** Check: by hand on small
    files; then the report on ix, each "never called" looked at.

Not in this plan: a window (a DrProlog); Prolog compiled to the
machine by mini-asm; constraints; tabling in Prolog; an analysis's
answer read by a compiler; pfff's codequery as a program of ix's (its
file is a test only).

## Open questions

- **Floats in Prolog**: integers only at first (the classical programs
  need none), or `is` over floats from stage 2? mini-scheme has them.
- **The WAM (stage 5): wanted, or the first machine is enough?** It is
  the largest stage, and the reason to do it is the machine itself,
  not a need of speed that has been measured.
- **The pointer analysis's facts: pfff's relations as they are** (so
  `datalog_code.dl` runs unchanged), or named again here? And pfff's
  `datalog_c.ml` is the author's own file: imported and adapted to
  `Tree`, or written anew over `Tree` with it as the model? (ix's
  programs are written from scratch unless the author names a file.)
- **Facts from which tree?** C's `Tree` keeps the fields and the
  types (the pointer analysis wants them); `Ir` and `Ssa` have the
  control flow but have lost the names. Two makers a language, as the
  table above says, or one tree made to carry both?
- **The engine's speed on ix itself** is not known: how many tuples
  ix's ML makes, how long 0-CFA's fixpoint takes by an interpreter in
  OCaml. bddbddb used BDDs and Soufflé compiles its rules to C++;
  this one has hash indexes. To measure at stage 8 before stage 10 is
  promised.
- **Lattices** (constants, intervals): a later extension of the
  engine, or those analyses stay written by hand in the compilers?
- **SWI-Prolog installed here**, for the expected outputs once
  (decision 7)?
- **Does Datalog count in `make loc`'s m-ix?** The languages that are
  run are set apart; an engine the compilers come to use would not be.

## Status

2026-10-09: plan written. Read for it: pfff's files in the table (the
rules whole; `prolog_code.pl`, `datalog_code.ml` and `datalog_c.ml`
their first sixty to hundred lines only), the head of ix's `Tree`, C's
`Ir` and `Ssa`,
mini-scheme's command; `scripts/stats/prolog_survey.sh` run. Not done:
anything written or built; no line of the estimates tried; pfff's
rules not run by any engine here; `prolog_code.pl`'s clauses not
checked one by one for what they ask of a Prolog beyond the calls the
survey counts.

2026-10-09, **stages 1 to 3 done: Prolog is a program of ix's, on
Linux, mini-prolog** (the author: "ok let's commit the prolog plan and
do it", then "I'll review next morning, so move forward as much as you
can on the plan"). `languages/prolog/`: 8 units, **2,081 lines of .ml**
(160 of them the prelude, which is Prolog) and 300 of .mli, where the
plan said about 1,300: the built-ins are 602 lines for the 300
estimated, the machine 475 for 300. Built by dune and by mini-mk (in
the top mkfile's list); mini-ml compiles the 8.

Checked, `languages/prolog/tests/run.sh`, **the same by dune's build,
by mini-ml's on arm64 and by mini-ml's for arm under mini-5i** (six
minutes there): the classical programs of decision 7 (`classics.pl`:
the family, the eight queens, six queens' 4 boards, naive reverse,
Warren's derivative, the zebra, a grammar's value, Prolog in three
clauses, Hanoi's 1,023 moves by a counter); 197 checks of the language
(`language.pl`, each a goal that must hold: unification, the order,
arithmetic, errors' terms, the cut in each place, catch, assert, bagof
and setof, the lists', the atoms', the reader, the printer, grammars,
a recursion of 20,000); the four ports; goals typed at the prompt; a
file with mistakes. And 6 unit tests (Testo, dune). In `make test` and
`test-lite`.

**The author's `prolog_code.pl` (codequery) is read whole and
answers** (`mini-prolog facts.pl prolog_code.pl -g "children(X,'A'),
writeln(X), fail"`: B, C), from pfff's directory; not a test here.

What the plan had not:

- **mini-ml has no array pattern** (`[| a; b |]`: a syntax error): a
  compound term's arguments are a list, not an array.
- **The trail**: with every binding on it, naive reverse 2,000 times
  was 159 MB; a variable younger than the last choice point is not
  trailed (the WAM's test), and it is 6 MB.
- `discontiguous` declares its predicate (a call with no clause
  fails): `prolog_code.pl` needs it.
- mini-5i has no `gettimeofday`: `statistics/2` takes it as no clock.
- The answers' variables print as `_G` and a number, which changes
  with the prelude: `trace.out` and `prompt.out` have such numbers.

**Its speed**: naive reverse of 30 elements 2,000 times (992,000
inferences) 0.85 s by OCaml's build, 2.9 s by mini-ml's (arm64).

Decided on the way, for the author to confirm: integers only (no
float); `/` is `//`; a file consulted again replaces its predicates;
`-g goal` runs once and a prompt comes only with no `-g`.

Stage 4, **built and not put on the card**: `mini-mk O=5 OS=plan9` in
`languages/prolog` gives an 802 KB program for mini-9pi. Not added to
`kernels/9pi/Makefile`: another session was changing it, and a
program more on the card makes its recorded sessions stale. Not run
under mini-9pi.

2026-10-09, **stage 7 done: mini-datalog** (`languages/datalog/`, 4
units over mini-prolog's `Prolog` and `Prolog_read`, 554 lines of .ml
and 106 of .mli, where the plan said about 500). Strata, semi-naive
and naive (`-naive`), negation, comparisons, indexes made on demand.

Checked, `languages/datalog/tests/run.sh`, the same by the three
builds: paths with a cycle, liveness, dominators (three strata), what
is refused; each program's tuples the semi-naive way and the naive
one, the same (that comparison found a bug of the first: a relation
with two rules was turned twice a round). **The author's
`datalog_code.dl` runs as it is** (copied since as
`languages/datalog/analyses/pointer.dl`, see below), its `point_to(A,B)?` included: on
pfff's `pointer.dl` it gives the seven `point_to` expected, and on
`tests/pointer_facts.dl` the call through a pointer
(`call_edge(main_line5,id)`).

**Its speed** (`tests/bench.sh`): a chain of 1,000's 500,500 paths in
1 s by OCaml's build and 7 s by mini-ml's; the pointer analysis on
1,000 random assignments 3.9 s and 34 s, on 3,000, 108 s by OCaml's
build: its worst case (`languages/datalog/README.md`). On a real
program's facts: not known, there are none yet.

Found on the way, in `docs/plans/bugs/ix.md`: lib_core's
`Hashtbl.replace` never grew its table (mini-datalog by mini-ml was
10 s for 90,000 tuples; it uses `add`), fixed the next day, see
below; mini-5i's `gettimeofday`, not fixed.

2026-10-09, **stage 8 done: `mini-cc -facts`, a C file as the facts
of the author's pointer analysis** (`languages/c/facts/Facts.ml`, 293
lines, written anew over `Tree` with pfff's `datalog_c.ml` as its
model for the names: `f__x`, `ret_f`, `_fld__m`, a parameter's number
from 1; `CLI.ml`: a third back end that makes no code, 20 lines). The
tree before the typing: a member has its name there, and after it is
an offset.

Checked, `languages/c/facts/tests/run.sh` (in `make test` and
`test-lite`): `pointers.c`'s 89 facts, and what pfff's rules then find
by mini-datalog: `swap(&p, &q)` leaves each of p and q pointing to x
and y; a call through a table of functions reaches both; `l->visit(l)`
reaches `show`; `f(l)` in `walk` reaches `hide`. The same by mini-cc
and mini-datalog built by mini-mk in a copy of the tree. pfff's own
six C files: `methodcall.c`'s `x->f(2)` reaches `test`; four have
nothing a pointer points to; `globalcall.c` includes `stdlib.h`.

**On ix's own C**: mini-ml's runtime (2,458 lines) is 2,726 facts,
made in 0.04 s, and the analysis 0.14 s (1,505 `point_to`); lib_core's
libc (60 files, 3,636 lines) 2,950 facts and 0.41 s (5,155). So the
open question of the engine's speed has a first answer for C of this
size: no problem. For ix's ML (some 100,000 lines), still not known.

What it asked: loading a file of facts was in the square of its size
(a clause's line counted from the text's start: 1.8 s for the
runtime's facts, 0.14 after); a global's initializer comes typed, its
`&` gone (a name there is an address).

Not said by the facts: a structure's initializer's members (a table
of structures with a function in each: the call through the member is
not found); a static's file (two files' statics of one name are one);
`_init`'s temporaries are numbered per file.

Not done: stage 4's card and session; stage 5 (the WAM); stage 6 (the
highlighter: it is editors/emacs's mkfiles too); stages 9 and 10;
floats; the long `run.sh -5` of mini-prolog is not in `test-lite`.

2026-10-10 (the author: "let's not depend on pfff so yes copy the
analysis in languages/datalog/analyses/", "let's fix bugs in Hashtbl
if there are", "and let's commit"). **The rules are here**:
`languages/datalog/analyses/pointer.dl`, pfff's `datalog_code.dl` with
a first line saying where it is from; the tests read it and skip
nothing, pfff need not be on the machine. **lib_core's `Hashtbl`**:
`replace` grows the table as `add` does, and `find`, `find_all` and
`remove` compare a key by `compare` as `mem` and `replace` did (a nan
put was never found); `languages/ml/tests/modern/hashtables.ml`, which
the Hashtbl of before fails. Checked: `make test-lite`, 62 jobs, 0
failure, 51 s (it builds ix by ix on the new `Hashtbl` and runs
mini-prolog's and mini-datalog's tests on those builds). Not run:
`run.sh -5` (arm under mini-5i) again, `make test` whole,
`mkfiles/check.sh`. Committed, 9fb243b.

2026-10-10 (the author: "ok let's commit and move forward"), **stage 9
done: control flow and liveness as facts, by both compilers, and the
rules' answers the compilers' own.**

- **mini-ml `-flow`** (`languages/ml/facts/Ssa_facts.ml`, 72 lines): a
  function's SSA form as facts (blocks, successors, each instruction a
  point, definitions, uses, phis and their operands by predecessor).
  `analyses/liveness_ssa.dl` (8 rules) and `analyses/dominators.dl` (7
  rules, by negation: three strata). `-dflow` prints `Alloc`'s
  liveness and `Ssa_build`'s dominators as facts; for it the liveness
  is a function of its own in `Alloc` (`Alloc.liveness`, the same
  code moved: `-ssa`'s assembly of four files the same before and
  after, and test-lite's ix built by ix).
- **mini-cc `-flow`** (`languages/c/facts/Ir_facts.ml`, 52 lines): the
  stack code after `Opti`'s passes but `regs`, an instruction a point,
  the variables `regs` considers. `analyses/liveness.dl` (the
  textbook's three rules, and `across_call`). `-dflow` prints `Opti`'s
  liveness; `Opti.mli` gives `variables`, `successors` and `liveness`
  for it.
- **The check is a Datalog question**: `differs(...)`, each tuple the
  rules have and the compiler has not, or the reverse
  (`languages/ml/facts/tests/check.dl`, `languages/c/facts/tests/flow_check.dl`).
  On ix's own files, function by function (`tests/ix.sh` in each):
  **88 ML files of 7 directories, 3,459 functions, 45,801 blocks,
  8.4 million tuples found, none differs** (liveness at each block's
  two edges and each block's immediate dominator), 34 s of mini-datalog
  in all, 17 for `languages/ml`; mini-ml's runtime and libc's 59 files
  of C, 395 functions, none differs, 1.1 s. The table is in
  `languages/datalog/README.md`.
- The tests (`languages/ml/facts/tests/run.sh`, and
  `languages/c/facts/tests/run.sh` extended; both in `make test` and
  `test-lite`, and on the programs ix builds of itself): a file's
  facts, what the rules find, no difference, and a rule taken out
  gives differences (the check is not empty by itself).

The engine's speed on ix's ML, the open question: liveness and
dominators of a directory of 10,000 lines are 10 to 20 s, which is
slow for a compiler's pass and fine for a report. Seen on the way: in
`s = s + twice(i)`, mini-cc's `places` leaves a `lea s` (the store
after a call), so `regs` gives `s` no register; not looked at further.

Checked: `make test-lite`, 63 jobs, 0 failure, 54 s. Not run: the two
`ix.sh` on mini-ml's builds or on arm; `make test` whole. Not done:
reaching definitions (the table's row has liveness only); `Peep`'s
liveness (C, on the assembly); stage 10; stages 4 to 6; floats.
Committed, 0ee3682.

2026-10-10, **stage 10 done: ML's closures by the author's pointer
rules, and what a program of ix never calls.**

- **mini-ml `-facts`** (`languages/ml/facts/Closure_facts.ml`, 241
  lines, over `Scope`'s tree after the typing): a unit in
  `pointer.dl`'s relations, so that **the rules of 2014 run unchanged
  on ML**. A function written is a place (`assign_address`), a call
  is `call_indirect` with one `argument`, `f x y` two calls and
  `let f x y` two functions (`'M.f'`, `'M.f''`): a partial
  application is nothing special. Fields by name (the rules'
  field-based): a record's label, a constructor's argument, a tuple's
  position. An external is a function too: a C function's arguments
  go to one place (`ext`) and its result comes from it, with the
  arrays' elements and what a handler catches; those the compiler
  writes in place move nothing, or what they are known to (`ref`,
  `!`, `:=`, `fst`, `snd`, the identity).
- **`analyses/calls.dl`** (11 rules): `calls`, `never_called`,
  `unreached` (from the units' toplevels), `half_called`, `hole` (a
  call in reached code that reaches nothing).
- **The report**, `languages/ml/facts/tests/program.sh dir...`: a
  program's units with lib_core's 69, its grammar and lexer made by
  mini-yacc and mini-lex as the mkfiles do. Seven programs, the table
  in `languages/datalog/README.md`: mini-prolog (2,676 functions,
  13,548 calls) in 4 s, mini-ml (4,356 and 29,839) in 146 s.
- **Each "unreached" looked at**, by kind: another program's part of
  a shared unit (mini-datalog does not use `Prolog.copy`; mini-drscheme
  uses `Scheme_eval.call`), mini-emacs's `Highlight_*`, the `show`
  stubs, and three that a search of the tree then finds no use of:
  `Scheme.kind`, `Scheme_eval.defined`, `Asm.cond_bits`. Not removed:
  the author's to decide. None found that is in fact called.
- The test (`languages/ml/facts/tests/run.sh`): two units where each
  function is reached another way (a list of records, a ref, an
  exception's argument, a partial application, a function called only
  by a dead one), by hand.

What it is not: sensitive to a call's context (mini-ml's 29,839 calls
have 517,653 targets, 17 each: its tables of functions and its
records of closures seen together), nor to types; the whole of ix as
one program (a report per program, each with all of lib_core); a
pass of the compiler (a call made direct when one function reaches
it: `plan_mini_toolchain_optimization.md`'s).

Not done: the same for C and ML together (the runtime's calls of ML);
`program.sh` on mini-ml's builds; stages 4 to 6; floats; reaching
definitions; `docs/loc.md`.
Committed, 825a310.

2026-10-10, **stage 6 done: Prolog's colors in mini-emacs**
(`languages/prolog/highlight/Highlight_prolog.ml`, 97 lines, as
Scheme's and Pascal's: a pass over the text, no parser).
`editors/emacs/modes/Prolog_mode` for `.pl`, `.pro` and Datalog's
`.dl`: the colors, the matching parenthesis, TAB. A clause's head is
what it defines (a clause starts after a full stop), `:-` `-->` `?-`
keywords, `!` `;` `->` `\+` control, a declaration's word after `:-`
(`dynamic`...), variables, numbers (`0'c`), quoted atoms and strings,
`%` and `/* */` comments. Checked: `editors/emacs/tests/keys.sh`, a
session added (131, the 130 others unchanged), by dune's build and by
mini-ml's (mini-mk in `editors/emacs/tty` and `draw`, in a copy of the
tree); `make test-lite`, 63 jobs, 0 failure. Not run: mini-emacs on
mini-9pi with a `.pl` file.

Left of the plan: stage 4 (mini-prolog on mini-9pi's card, its
recorded session: `kernels/9pi/Makefile` and minutes under the
emulators), stage 5 (the WAM: the author's to say if it is wanted),
floats.
