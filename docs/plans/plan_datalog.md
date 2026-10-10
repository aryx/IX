# Plan: Datalog for program analysis of ix's own C and OCaml, as Soufflé and Doop do it (`languages/datalog/`)

The author (2026-10-10), mini-prolog done: "our main focus is datalog
for program analysis", "maybe start a plan_datalog if we didn't have
yet, to be used for advanced program analysis of C and OCaml, a la
Souffle and DOOP framework pointer analysis". Before it
(2026-10-09, plan_prolog.md): "a datalog engine and use it especially
for fixpoint program analysis, like pointer and controlflow and
dataflow analysis, of OCaml and C", "so it can be used on the code of
ix itself". And of what it is to reach (2026-10-10): "I hope we can
do far more complex context sensitive, type sensitive, pointer and
dataflow analysis, interprocedural, taint analysis, etc."

The short answer: **the three parts exist, small, and each is what
limits the next. The engine (464 lines) is a tenth of what Soufflé
is asked for here and takes 146 s on mini-ml's own code; the facts
say a program without its allocation sites and without its types; and
the one pointer analysis is the author's of 2014, field-based and
without contexts. The plan is those three made Doop's shape, in that
order of need: first measure where the time goes, then facts by
allocation site, then the analyses with contexts, then what they are
for.** Nothing of this plan is written; its numbers are the README's
(`languages/datalog/README.md`, measured 2026-10-09 and -10) or are
said to be estimates.

**Status: plan written and its first questions answered, nothing
done** (2026-10-10; see Status at the end).

## What there is

From [`plan_prolog.md`](done/plan_prolog.md)'s stages 7 to 10 (done):

| part | where | lines | what |
|---|---|---:|---|
| the engine | `languages/datalog/` (`Datalog`, `Datalog_eval`) | 464 | relations of tuples of symbols; rules checked safe; strata for negation; semi-naive, or naive to check it; a body joined in the order written, by hash indexes made on demand; a fact read by Prolog's reader |
| C's facts | `languages/c/facts/Facts` (`mini-cc -facts`) | 293 | the 17 relations of the author's rules, from the tree before its typing |
| C's flow | `languages/c/facts/Ir_facts` (`-flow`) | 52 | the stack code's points, successors, definitions, uses |
| ML's facts | `languages/ml/facts/Closure_facts` (`mini-ml -facts`) | 241 | a unit in those same 17 relations: a function is a place, a call is a call through a pointer |
| ML's flow | `languages/ml/facts/Ssa_facts` (`-flow`) | 72 | the SSA form's blocks, definitions, uses, phis |
| the rules | `languages/datalog/analyses/` | 248 | `pointer.dl` (pfff's, 2014: Andersen's, field-based, the calls found as it goes), `calls.dl`, `liveness.dl`, `liveness_ssa.dl`, `dominators.dl` |

What it does today: liveness and dominators the same as the
compilers' own on 3,459 ML functions and 395 C ones, no tuple
differing; the call graph of an ML program with lib_core, and what it
never calls (three functions of ix found unused).

Where it stops:

| | measured | why |
|---|---|---|
| mini-ml analysed by `pointer.dl` | 146 s, 7,039,841 `point_to`, 517,653 targets for 29,839 calls (17 a call) | no context: every call of `List.map` is one; field-based: every `.name` of every record is one place; what goes through an array or C is one place (`ext`) |
| mini-cc | 67 s, 5.7 million `point_to` | the same |
| the engine | some 2 million firings a second (OCaml's build), a seventh by mini-ml's | a tuple is a list of strings hashed again at each lookup (not measured: stage 1 says) |
| ix whole | not tried | m-ix is 83,987 lines of OCaml and 4,079 of C (`make loc`); mini-ml with lib_core is a tenth of it |

## What Soufflé and Doop are

**Soufflé** (Scholz, Jordan, Subotić, Westmann, "On Fast Large-Scale
Program Analysis in Datalog", 2016) is an engine: Datalog with typed
relations declared, facts read from files of tab-separated columns,
numbers and arithmetic in a body, aggregates, records, stratified
negation. Its speed is from three things: a rule is translated to a
program of loops over indexes (its relational algebra machine, RAM)
and that program compiled to C++; the indexes a program needs are
chosen from its rules, the fewest that cover every lookup; and the
relations are B-trees. It has an interpreter of the RAM too, a
profiler (the time and the tuples of each rule), and provenance: the
proof of a tuple, asked after the run.

**Doop** (Bravenboer and Smaragdakis, "Strictly Declarative
Specification of Sophisticated Points-to Analyses", 2009) is a
framework over such an engine, for Java: a program's facts made once
by a front end and kept as files; then some thousand rules, where an
analysis is chosen by what a *context* is. Its points are: the heap
is abstracted by allocation site; fields are by object and field
(field-sensitive); the call graph is found by the analysis as it
goes; and context sensitivity is two functions, what a call's context
is (`Merge`) and what an allocation's is (`Record`): with the last k
call sites it is k-CFA, with the receiver's allocation site it is
object sensitivity, with nothing it is Andersen's. The same rules for
all. cclyzer is the same group's for LLVM's code, hence C: a field by
its offset in a typed object, and a `malloc`'s type found from where
its result goes. The book to follow is Smaragdakis and Balatsouras,
"Pointer Analysis" (2015): its rules are a page.

For a language of functions the same is control-flow analysis
(Shivers's k-CFA, 1988): `mini-ml -facts` already says a closure as a
place and a call as a call through a pointer, which is 0-CFA.

| | Soufflé, Doop | here |
|---|---|---|
| a relation's columns | declared, typed (`symbol`, `number`) | not declared: a name misspelled is an empty relation |
| facts | files of columns, read and written | Prolog's clauses, read by its reader |
| a tuple | integers; symbols in a table | a list of strings |
| indexes | chosen from the rules; B-trees | a hash table for each use, made when first asked |
| a body's order | planned, or given (`.plan`) | as written |
| numbers, `<`, `+` in a body | yes | no |
| aggregates (`count`, `min`) | yes | no |
| why a tuple is there | provenance (`explain`) | no |
| which rule costs | a profiler | `-s`: the totals only |
| the heap | allocation sites | variables' addresses and functions; ML's blocks by their field's name only |
| fields | by object | by name, whatever the object |
| contexts | call sites, objects, types; chosen | none |
| the analyses | a library, the clients over it | five files |

## Decisions (1, 2 and 4 to 8 proposed; 3 and 9 the author's)

1. **Measure before the engine is changed.** Stage 1 is a profiler
   (each rule's firings, new tuples and time) and the profile of
   mini-ml's 146 s. The table above guesses that tuples of strings and
   one place for all are the cost; the engine's next form depends on
   which.
2. **The engine stays an interpreter, of a plan.** A rule becomes a
   small program of scans, lookups in an index, filters and one
   insertion (Soufflé's RAM, as a type), which is run; `-plan` prints
   it, as `-S` prints the WAM's code. No C++ and no OCaml written out
   and compiled: mini-datalog must run where mini-ml's programs run.
   Tuples become arrays of integers, the symbols in a table.
3. **The syntax stays Prolog's, with declarations added** (the
   author: "we can keep Prolog syntax"). A declaration is a directive,
   `:- decl point_to(var, object).`; with one, a relation's arity and
   its columns' kinds are checked, and a relation used and never
   declared or given is said. Soufflé's own syntax (`.decl`, `!` for
   not) would let its and Doop's files be read; none could run without
   the rest of Soufflé (components, records), so it buys little.
4. **Facts are files of columns**, one a relation
   (`point_to.facts`), tab-separated, as Soufflé's and Doop's: `-F
   dir` reads every relation that has no rule, `-D dir` writes those
   asked. A program's facts are made once and kept; an analysis is run
   again without the compiler. `mini-cc -facts` and `mini-ml -facts`
   write a directory.
5. **A context is columns, not a term.** Datalog has no compound term
   and this one gets none: a context of depth k is k columns, and the
   rules are written for a k (1 and 2). What makes a context, Doop's
   `Merge` and `Record`, is a small file of rules to swap. If a depth
   in a variable is wanted later, records come then.
6. **One set of relations for C and ML, Doop's shape, in place of
   pfff's.** The 17 relations and `pointer.dl` are where this started
   and are retired (decision 9) once stage 7's analysis is checked
   against them. The new facts are by instruction: an allocation (its site, its type), a
   move, a load and a store of a field of an object, a call (its site,
   its arguments), a return; and the types' own (a structure's fields,
   a constructor's arguments). Both compilers write them, C from its
   typed tree, ML from `Scope` with the types the checker gave. The
   rules that are the same for both (the heap, the calls) are one
   file; what is a language's own (C's address-of and arithmetic on
   pointers, ML's partial application and exceptions) is another.
7. **An analysis is checked by what it must contain and by what it
   costs.** No Soufflé and no Doop here to compare with. So: (a) small
   programs with the answer written by hand; (b) a more precise
   analysis's answer is inside a less precise one's (`check.dl`'s way:
   the tuples one has and the other has not, the question a Datalog
   one); (c) the calls a program makes when it is run are in the call
   graph found (a trace of mini-ml's tests under mini-7i or by a
   counting build: an analysis that misses one is wrong); (d) Doop's
   table for each analysis on each program: the time, the mean size of
   a variable's set, the call edges, the calls with more than one
   target, the functions reached.
8. **The clients are ix's.** What the analyses are for, in the order
   of their use here: what is never called (there); the calls with one
   target, for mini-ml to call them directly (stage 8, and the one
   place where a compiler reads an answer); which exceptions leave a
   function; what a function may write (purity); and the
   capabilities: that every way to an operating system's call goes
   through a function that was handed its capability, which is what
   `Cap` promises and no tool checks.

9. **What the author wrote before is a starting point, not a thing
   to keep** ("pointer.dl and whatever I wrote before can be retired;
   it's just a starting point"). `pointer.dl`, `calls.dl` over it and
   the two `-facts` of today stay as tests until stage 7 contains
   their answers, then go; `Facts` and `Closure_facts` are rewritten
   for decision 6's relations, not kept beside them.
10. **The compilers read the answers, in `opti/` only** (the author,
    first: "we can probably delay when things get more concrete";
    then, told what it meant: "oh I like using mini-datalog analysis
    result to improve the speed of mini-ml! doing whole-program
    analysis and injecting back the results for further
    optinisations! but the original mini-ml (and mini-cc) code must
    remain simple; this would go in an opti/ directory or
    something"). Both compilers have that directory and its switches
    already (`languages/ml/opti/`, `languages/c/opti/`: `-Oname`, a
    pass each, none on by default). So: a program is compiled once to
    its facts, mini-datalog writes the answers as files of columns
    (decision 4), and a second compilation reads them through one
    more pass of `opti/`, asked by a switch. Nothing outside `opti/`
    knows of it; without the switch the compiler is the one of today,
    and ix's bootstrap does not need mini-datalog. Stage 13.

## The stages (each checked before the next)

The engine:

1. **A profiler, and the profile.** `-profile`: for each rule its
   firings, lookups, new tuples, and the time. Check: the totals are
   `-s`'s; mini-prolog's and mini-ml's analyses profiled, the table in
   the README, and from it what stage 2 must be.
2. **Tuples of integers, a rule as a plan.** The symbols in a table;
   a relation's tuples arrays; a rule translated once to scans and
   index lookups; `-plan`. Check: every test's tuples the same,
   semi-naive against naive still; `bench.sh` before and after; the
   146 s.
3. **Declarations, facts in files, numbers.** `:- decl`, `-F` and
   `-D`, integers as a kind of column, `<`, `=<`, `=:=`, `\=` and `is`
   in a body (after what binds their variables), `count` and `min`
   over a relation that is whole (a stratum, as negation). Check: a
   misspelled relation refused; a directory of facts written and read
   back gives the same tuples; Doop's table (decision 7d) is a file
   of rules.
4. **Why.** `-why 'point_to(a, b)'`: one proof of a tuple, the rule
   and the tuples it used, down to the facts (each tuple keeps the
   rule and the round that first made it). Check: by hand on the small
   tests; on ix, the proof that a function thought reached is.

The facts:

5. **C by instruction and by type.** From the typed tree: each
   `malloc` (and the kernels' allocators, named in a file) a site
   with the type its result is first used as; a structure's fields; a
   local whose address is taken; the address of a field, of an
   element. Check: `tests/pointers.c` by hand; mini-ml's runtime and
   mini-xv6's kernel, the counts in a table.
6. **ML by allocation site.** Each closure, each constructor applied,
   each tuple, record, `ref` and array made is a site with its type; a
   field read or written is of an object; a partial application is an
   object that holds its arguments; `raise` and `try` are moves to and
   from a function's exceptional return; an external is a call of the
   C function of that name, so the runtime's facts join the program's.
   Check: `tests/closures/` by hand; the answers contain the calls
   made when mini-ml's tests are run (decision 7c).

The analyses:

7. **Andersen's by allocation site, fields by object, no context**,
   for both languages, in Doop's rules. Check: its call graph inside
   `pointer.dl`'s (decision 7b); the table; mini-ml's targets a call,
   17 today.
8. **Contexts**: one call site; two call sites and one for the heap;
   for ML the closure's own site as the context (object sensitivity's
   kin), which is what tells one `List.map` from another; and the type
   in place of the site (type sensitivity, Smaragdakis, Bravenboer and
   Lhoták, 2011: nearly an object's precision for much less, the
   context being the type that holds the allocation, here the module
   or the structure). Check: each inside the one before; the table, each
   analysis a row; where it does not end in the time given, said, and
   which functions are to be left without context (Smaragdakis's
   introspective analysis, 2014) only then.
9. **Dataflow across functions, over the pointer analysis.** The
   `-flow` facts (a function's points, definitions, uses) joined to
   stage 8's call graph and its contexts: a value followed from where
   it is made through calls, returns, fields and the heap. Reaching
   definitions and def-use chains across calls first; a function's
   summary (what of its arguments reaches its result and what it
   stores) so that a callee is not followed again for each caller
   (the tabulation of Reps, Horwitz and Sagiv, 1995, which in Datalog
   is two relations). Check: by hand on small programs of two and
   three functions; within a function, the same as the compilers' own
   liveness still.
10. **Taint.** Sources, sinks and sanitizers named in a file of facts,
    and the rules over stage 9 that say which source reaches which
    sink unchecked, with the path (`-why`). For ix: in the C kernel
    (mini-xv6), an address a user program gave used before it is
    checked (`argptr`, `fetchint` and `copyin` the sanitizers); in the
    OCaml kernel and the servers, a length or an offset read from a 9P
    message, a FAT entry or a network packet that reaches
    `Bytes.blit`, an array or an allocation's size; in mini-rc, text
    read that reaches `exec`. Check: a bug put in on purpose in each
    is found; each report on ix as it is read, and the false ones
    counted.
11. **The other clients** (decision 8), each a file of rules and a
    report on ix: the calls with one target; exceptions; purity;
    capabilities. Check: each kind of answer looked at, as "never
    called" was.
12. **ix whole.** Every unit of m-ix's programs and the C under
    them, facts kept in `_build`, the reports by `make analyze`.
    Check: the time and the memory; the reports read.

13. **The answers back in the compilers** (decision 10): a pass in
    each `opti/` that reads a directory of answers. For mini-ml, in
    the order of what each is expected to buy (estimates, to measure):
    a call whose one target is known made a direct call, with no
    closure fetched and no arity checked (and then open to the
    inlining `opti/` has); a function no unit reaches left out of the
    program; a closure, a tuple or a `ref` that does not leave its
    function kept in registers; a function that is pure, its call
    with the same arguments made once. For mini-cc: the same first
    two, a call through a pointer with one target and the functions
    never reached. Each is its own switch (`-Oknown-calls`...), the
    answers' directory another (`-answers dir`), and a unit whose
    answers are missing or older than its source is compiled without
    them. Check: every test of the compiler the same with and without
    each; the fixpoint of ix built by ix still reached; and
    plan_mini_toolchain_optimization.md's numbers (mini-xv6's, the
    benchmarks'), each switch a row: what it bought, and what it
    cost to build twice.

Not in this plan: the pointer analysis itself made flow-sensitive (a
variable's set by program point: stage 9 follows values along the
control flow over a pointer analysis that is not); values in
a lattice (constants, intervals: Flix's Datalog, another engine);
Soufflé's components and records; a parallel engine; an analysis
that is kept up as the program changes; Java.

## Open questions

- **Soufflé installed here once**, to compare answers and times on
  the same rules (it would need the rules in its syntax: a translator
  of some 50 lines)?
- **How far is "advanced"?** Doop's reflection, its exceptions by
  type, its strings, are Java's; cclyzer's type back-propagation is
  C's and is stage 5. Named here so that what is left out is chosen.
- **Which C?** mini-ml's runtime and lib_core's libc are analysed
  today; mini-xv6's kernel is the C that has pointers to functions
  and locks. mini-9pi's kernel is OCaml.
- **The cost on ix whole is not known**: 0-CFA on mini-ml is 146 s by
  an engine that stage 2 changes and with facts that stage 6 changes.
  To measure at stage 7 before stages 8 and 10 are promised.
- **On mini-9pi's card?** mini-datalog and the facts of a program, to
  analyse ix on ix. It builds by mini-ml; not asked yet.

## Status

2026-10-10: plan written, after plan_prolog.md was moved to `done/`.
Read for it: `languages/datalog/README.md` (its tables are the
numbers above), `analyses/pointer.dl`'s head and `calls.dl`,
`mini-datalog -s`'s output, `make loc`'s first lines. The same day
the author answered its first three questions (decisions 3, 9 and
10) and said how far it is to go: contexts and types, dataflow across
functions, taint (stages 8 to 10, written then). And then decision
10 turned: the compilers are to read the answers, in `opti/` (stage
13). Soufflé's and
Doop's descriptions are from memory of the papers named, not from
their sources: neither is on this machine. Nothing run for this plan;
nothing written but it.
