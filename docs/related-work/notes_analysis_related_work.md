# mini-analyze vs. the rest of the program analyzers

Where a small analyzer of C and ML in Datalog sits among the real ones:
the foundations (dataflow, abstract interpretation), the pointer
analyses and their solvers, Datalog as the language of analyses (Doop,
Soufflé, CodeQL), the analyses of functional languages and of types,
the compositional analyzers that run at Facebook and Google, the bug
finders, and taint. What they do that ix won't, and which of their
ideas fit in an analyzer small enough to read. Companions:
[`notes_analysis.md`](../tutorials/notes_analysis.md) (how it works,
on toys) and [`plan_datalog.md`](../plans/plan_datalog.md) (what gets
built). The dates and venues below are from memory unless a file of
ix's is named, and are to be checked before relying on them for
teaching; the `cs-history:` and `References:` notes of
`analyzers/datalog/*.dl` were written the same way.

## The one-line version

| | What it optimizes for | How |
|---|---|---|
| Kildall's dataflow (1973), Kam and Ullman (1977) | an optimizer's facts, in one function | a lattice, transfer functions, iteration to a fixpoint |
| Abstract interpretation (Cousot and Cousot, 1977) | soundness, proved | a concrete semantics abstracted by a Galois connection; widening |
| Andersen (1994), Steensgaard (1996) | what a C pointer may point to | inclusion constraints, cubic; unification, almost linear |
| k-CFA (Shivers, 1988) | which lambda a Scheme call reaches | 0-CFA is Andersen's on closures; k call sites as context |
| IFDS (Reps, Horwitz, Sagiv, 1995) | exact interprocedural dataflow, polynomial | summaries; reachability over matched calls and returns |
| bddbddb (2004), Doop (2009), Soufflé (2016) | precise pointer analysis written as rules | Datalog; BDDs, then compiled C++ |
| CodeQL (Semmle, 2007-) | queries over a codebase, for security | a Datalog with objects (QL) over a database of the program |
| Infer (Facebook, 2013-) | analysing a diff in minutes, on millions of lines | compositional: a summary per procedure, bi-abduction |
| Astrée (2003-) | no run-time error in avionics C, proved | abstract interpretation, domains made for the code |
| Coverity (Engler's metacompilation, 2000-) | bugs programmers believe, few false ones | unsound by choice: checkers of rules, statistics of deviance |
| Semgrep (r2c, 2020-; sgrep in pfff before) | rules a programmer writes in their language's syntax | patterns over a generic AST; taint and constants, intraprocedural first |
| ocamlexc (Leroy, Pessaux, 2000) | OCaml's uncaught exceptions | type inference with row variables |
| `analyzers/` (mini-analyze) | reading how an analyzer works, on ix's own code | facts by mini-cc's and mini-ml's front ends; Doop's rules in mini-datalog |

## Part 1: foundations

- **Rice's theorem** (Henry Rice, 1953): every non-trivial property of
  what a program computes is undecidable; every analysis approximates.
  For pointers in particular: Landi (1992) and Ramalingam (1994) proved
  may-alias undecidable with recursion and the heap; Horwitz (1997)
  proved even flow-insensitive precise may-alias NP-hard; Reps (2000),
  context-sensitive data dependence undecidable.
- **Frances Allen**, "Control flow analysis" (1970), and Allen and
  Cocke (1976): basic blocks, intervals, the optimizer's graph. Reese
  Prosser (1959) named dominance; `dominators.dl`'s header has its
  history.
- **Gary Kildall**, "A unified approach to global program optimization"
  (POPL 1973): the dataflow framework, a lattice per point. John Kam and
  Jeffrey Ullman, "Monotone data flow analysis frameworks" (1977): when
  iteration reaches the least fixpoint and when that is the meet over
  all paths. `liveness.dl` is its backward instance.
- **Patrick and Radhia Cousot**, "Abstract interpretation: a unified
  lattice model" (POPL 1977), and "Systematic design of program
  analysis frameworks" (POPL 1979): every analysis as an abstraction of
  the semantics, widening for infinite domains. The theory ix's
  analyses are instances of without saying it; ix has no numeric domain
  (the engine has no lattices).
- **Static single assignment**: Ron Cytron and others, "Efficiently
  computing static single assignment form and the control dependence
  graph" (TOPLAS 1991); Mark Wegman and Kenneth Zadeck's sparse
  conditional constant propagation (TOPLAS 1991), the first analysis
  made better by it. Andrew Appel, "SSA is functional programming"
  (1998): why ML's lets need no renaming (`Ssa_facts.mli`).
- **Slicing**: Mark Weiser, "Program slicing" (ICSE 1981); the program
  dependence graph (Ferrante, Ottenstein, Warren, 1987); interprocedural
  slicing (Horwitz, Reps, Binkley, 1990).
- The books: Flemming Nielson, Hanne Riis Nielson and Chris Hankin,
  *Principles of Program Analysis* (1999), the theory in one volume;
  Anders Møller and Michael Schwartzbach, *Static Program Analysis*
  (lecture notes, Aarhus, 2008-), free and the closest to this tutorial's
  order; Yannis Smaragdakis and George Balatsouras, *Pointer Analysis*
  (Foundations and Trends, 2015), whose chapter 2 rules `points_to/`
  follows; Xavier Rival and Kwangkeun Yi, *Introduction to Static
  Analysis: an abstract interpretation perspective* (2020).

## Part 2: pointer analysis

- **Lars Ole Andersen**, "Program analysis and specialization for the C
  programming language" (thesis, DIKU, 1994): inclusion constraints,
  cubic. `andersen.dl`.
- **Bjarne Steensgaard**, "Points-to analysis in almost linear time"
  (POPL 1996): unification, presented as type inference over location
  types. `steensgaard.dl`. **Manuvir Das**, "Unification-based pointer
  analysis with directional assignments" (PLDI 2000, One Level Flow):
  include at the first level, unify below.
- **Making Andersen's fast**: online cycle elimination (Manuel
  Fähndrich, Jeffrey Foster, Zhendong Su, Alexander Aiken, PLDI 1998);
  BDDs (Marc Berndl, Ondřej Lhoták and others, PLDI 2003); wave and deep
  propagation (Pereira and Berlin, 2009); lazy and hybrid cycle detection
  (Ben Hardekopf and Calvin Lin, "The ant and the grasshopper", PLDI
  2007), a million lines of C in seconds. Each is a solver's trick a
  rule file cannot do; `andersen.dl`'s road-not-taken says so.
- **Context sensitivity**: Micha Sharir and Amir Pnueli, "Two approaches
  to interprocedural data flow analysis" (1981), call strings and the
  functional approach; Ana Milanova, Atanas Rountev and Barbara Ryder,
  object sensitivity (ISSTA 2002, TOSEM 2005); Smaragdakis, Bravenboer
  and Lhoták, "Pick your contexts well" (POPL 2011), type sensitivity;
  George Kastrinis and Smaragdakis, hybrid (PLDI 2013); introspective
  analysis (PLDI 2014); Yue Li, Tian Tan, Anders Møller and Smaragdakis,
  Zipper (OOPSLA 2018) and Scaler (FSE 2018): a cheap pass picks where
  contexts pay. Every one of them has its file in `points_to/`, with
  the caveats `contexts.dl` names (no receiver in C or ML: the first
  argument; no types in the facts for type sensitivity's place).
- **Flow-sensitive at scale**: Hardekopf and Lin, "Flow-sensitive
  pointer analysis for millions of lines of code" (CGO 2011, sparse,
  staged); **SVF** (Yulei Sui and Jingling Xue, CC 2016), LLVM's value
  flow framework, the reference for C today. Not in ix.
- **Demand-driven and refinement**: Nevin Heintze and Olivier Tardieu
  (PLDI 2001); Manu Sridharan and Rastislav Bodík, refinement-based
  context-sensitive analysis for Java (PLDI 2006), as CFL-reachability.
- **For Java**: Ondřej Lhoták and Laurie Hendren's Spark (CC 2003) and
  Paddle in **Soot** (Raja Vallée-Rai and others, 1999); IBM's **WALA**;
  **Doop** (below); **Tai-e** (Tian Tan and Yue Li, 2023), a teaching
  framework from Nanjing with its course, the nearest in spirit to this
  directory.
- **For C, structures**: George Balatsouras and Smaragdakis,
  "Structure-sensitive points-to analysis for C and C++" (SAS 2016),
  cclyzer: a field by its offset in a typed object, a `malloc`'s type
  from where its result goes. ix's C facts are field-by-name per object,
  no offsets.

## Part 3: Datalog as the language of analyses

- **Thomas Reps**, "Solving demand versus exhaustive dataflow analyses
  using magic sets" (1994): dataflow is Datalog, demand is magic sets.
- **John Whaley and Monica Lam**, "Cloning-based context-sensitive
  pointer alias analysis using binary decision diagrams" (PLDI 2004),
  and bddbddb: Java's context-sensitive analysis as Datalog, each
  context a clone, the relations BDDs.
- **Doop** (Martin Bravenboer and Yannis Smaragdakis, "Strictly
  declarative specification of sophisticated points-to analyses",
  OOPSLA 2009): Java's points-to in some thousand rules, a context as
  the choice of Merge and Record, on LogicBlox, later on Soufflé
  (Antoniadis and others, 2017). `contexts.dl` is its shape, a few
  hundred lines because ix's facts have no classes, reflection or
  strings.
- **Soufflé** (Bernhard Scholz, Herbert Jordan, Pavle Subotić, Till
  Westmann, "On fast large-scale program analysis in Datalog", CC 2016):
  a Datalog compiled to parallel C++, its indexes chosen from the rules,
  provenance (why a tuple holds). mini-datalog borrowed its plan of a
  rule (scans, lookups, an insertion) and its flat tuples, interpreted
  (plan_datalog.md, stage 2).
- **CodeQL** (Semmle, from Oege de Moor's group at Oxford; Avgustinov
  and others, "QL: object-oriented queries on relational data", ECOOP
  2016): a program as a database, analyses as queries in a Datalog with
  classes, a library per language; GitHub's since 2019. Its taint
  libraries are the industrial version of §10.
- **Flix** (Magnus Madsen, Ming-Ho Yee, Ondřej Lhoták, "From Datalog to
  Flix", PLDI 2016): Datalog with lattices, so constant propagation and
  intervals are rules. **Formulog** (Bembenek, Greenberg, Chong, OOPSLA
  2020): Datalog with ML-like functions and an SMT solver. **IncA**
  (Szabó and others, 2016-) and **DDlog** (Ryzhyk and Budiu, 2019):
  incremental, an answer kept up as the program changes.
- **Rust's Polonius** (Niko Matsakis, 2018-): the borrow checker's
  flow-sensitive loans written as Datalog (datafrog): a type system's
  check as rules, as `capabilities_types.dl` is here.
- **pfff** (the author's): a C front end that wrote facts
  for a Datalog engine; its `pointer.dl` (Andersen's, field-based, the
  call graph on the fly) is where `analyzers/datalog/` started, kept as
  a test (plan_datalog.md, decision 9).

## Part 4: functional languages, and types as analyses

- **Olin Shivers**, "Control-flow analysis in Scheme" (PLDI 1988), and
  his thesis (CMU, 1991): k-CFA. David Van Horn and Harry Mairson,
  "Deciding kCFA is complete for EXPTIME" (ICFP 2008); Matthew Might,
  Smaragdakis and Van Horn, "Resolving and exploiting the k-CFA paradox"
  (PLDI 2010), m-CFA, whose flattening of closures `contexts.dl` takes.
  Might and Van Horn's "Abstracting abstract machines" (ICFP 2010):
  analyses derived from an abstract machine, step by step.
- **Robin Milner**, "A theory of type polymorphism in programming"
  (1978), and Luis Damas and Milner (POPL 1982): inference as
  unification, generalization at `let`. mini-ml's `Typing` (`notes_ml.md`
  §6).
- **Types and flow**: Jens Palsberg and Patrick O'Keefe, "A type system
  equivalent to flow analysis" (POPL 1995); Nevin Heintze, "Control-flow
  analysis and type systems" (SAS 1995); Christian Mossin, "Flow analysis
  of typed higher-order programs" (thesis, DIKU, 1997); Jakob Rehof and
  Manuel Fähndrich, "Type-based flow analysis: from polymorphic subtyping
  to CFL-reachability" (POPL 2001); Fähndrich, Rehof and Das, "Scalable
  context-sensitive flow analysis using instantiation constraints" (PLDI
  2000). Polymorphism is context sensitivity; tutorial §8.
- **Effect systems**: John Lucassen and David Gifford, "Polymorphic
  effect systems" (POPL 1988); Jean-Pierre Talpin and Pierre Jouvelot
  (1992); Tofte and Talpin's regions (1994-97). `capabilities.dl`
  computes the effect a type would declare.
- **Exceptions**: Kwangkeun Yi's analysis of SML (1994, abstract
  interpretation); Xavier Leroy and François Pessaux, "Type-based
  analysis of uncaught exceptions" (TOPLAS 2000), ocamlexc. CLU (1975)
  and Java declare them instead. `exceptions.dl` is the call graph's
  version.
- **Success typings**: Tobias Lindahl and Konstantinos Sagonas (PPDP
  2006), Erlang's Dialyzer: types inferred to find only sure errors, an
  under-approximation, the bug finder's choice in a type system.
- **Refinement types**: Liquid Types (Patrick Rondon, Ming Kawaguchi,
  Ranjit Jhala, PLDI 2008): predicates in types, inferred by
  abstract interpretation over a set of qualifiers.

## Part 5: summaries and compositional analysis

- **IFDS** (Thomas Reps, Susan Horwitz, Mooly Sagiv, "Precise
  interprocedural dataflow analysis via graph reachability", POPL
  1995) and **IDE** (Sagiv, Reps, Horwitz, 1996, environments, so
  constant propagation). Reps, "Program analysis via graph
  reachability" (1998), CFL-reachability as the common frame. Java's
  Heros and Soot's, and **PhASAR** (Schubert, Hermann, Bodden, TACAS
  2019) for LLVM.
- **Saturn** (Yichen Xie and Alex Aiken, 2005-07): C's whole Linux
  analysed function by function, each summarized, by SAT: compositional
  and path-sensitive within a function.
- **Infer** (Cristiano Calcagno, Dino Distefano, Peter O'Hearn, Hongseok
  Yang, "Compositional shape analysis by means of bi-abduction", POPL
  2009; Facebook's from 2013, open in 2015): separation logic, a
  procedure's pre- and postcondition inferred once, so a diff is
  analysed alone. Its later Pulse and RacerD; Distefano and others,
  "Scaling static analyses at Facebook" (CACM 2019). Why ix's
  summaries (plan_analysis_scale.md) are the road to 100,000 lines.
- **Library models**: Infer, WALA and Soot hand-write the library's;
  Doop reads the JDK as written and pays for it. `analyzers/ml/Models`
  hand-writes List's and Hashtbl's, `analyzers/summaries/` derives
  them from lib_core's code: both, compared (plan_analysis_scale.md).

## Part 6: path sensitivity, model checking, symbolic execution

- **ESP** (Manuvir Das, Sorin Lerner, Mark Seigle, "Path-sensitive
  program verification in polynomial time", PLDI 2002): property
  simulation, paths apart only where the property differs.
- **SLAM** (Thomas Ball and Sriram Rajamani, 2001-02) and **BLAST**
  (Thomas Henzinger, Ranjit Jhala, Rupak Majumdar, Grégoire Sutre, "Lazy
  abstraction", POPL 2002): predicate abstraction refined by
  counterexamples; Windows's driver verifier.
- **Symbolic execution**: James King, "Symbolic execution and program
  testing" (CACM 1976); DART (Godefroid, Klarlund, Sen, PLDI 2005) and
  concolic testing; **KLEE** (Cadar, Dunbar, Engler, OSDI 2008); SAGE at
  Microsoft. Under-approximations: every bug real, not every bug found.
- **Shape analysis**: Mooly Sagiv, Thomas Reps, Reinhard Wilhelm,
  "Parametric shape analysis via 3-valued logic" (TOPLAS 2002), TVLA;
  separation logic (John Reynolds, LICS 2002; O'Hearn, Reynolds, Yang,
  2001).

## Part 7: bug finders in industry, and what they learnt

- **Metacompilation** (Dawson Engler and others, "Checking system rules
  using system-specific, programmer-written compiler extensions", OSDI
  2000; "Bugs as deviant behavior", SOSP 2001): a lock taken and not
  released, as a state machine over paths; rules inferred from what most
  of the code does. It became **Coverity**; Al Bessey and others, "A few
  billion lines of code later" (CACM 2010), the lessons: a false report
  costs more than a missed bug, a report must be explainable, the build
  must be understood. `dead.dl`'s "what is flagged must be believed" is
  that lesson, and `bugs/pairs.dl` is metacompilation's lock checker
  over SSA.
- **Google**: Caitlin Sadowski and others, "Tricorder" (ICSE 2015) and
  "Lessons from building static analysis tools at Google" (CACM 2018):
  analyses at code review, an effective false positive rate under 10%,
  a fix suggested with each report.
- **Astrée** (Bruno Blanchet, Patrick Cousot and others, PLDI 2003): no
  false alarm on Airbus's flight control C, by domains designed for that
  code; **Frama-C** (CEA), **IKOS** (NASA), **Goblint** (Munich and
  Tartu), **Mopsa** (Paris): abstract interpretation's open tools.
- **Lint** (Stephen Johnson, Bell Labs, 1978), the first: what C's
  compiler would not say. **Splint**, **FindBugs** (David Hovemeyer and
  William Pugh, 2004: bug patterns, simple and effective), **Error Prone**.
- **Semgrep** (r2c, 2020-, from the author's sgrep in pfff):
  patterns in the language's own syntax over a generic AST, then
  constant propagation and taint. xix checks its capabilities by a
  Semgrep rule; `capabilities.dl` asks what a rule cannot, through
  wrappers and only for code that runs (its `others:` note).
- **Soundiness** (Benjamin Livshits, Manu Sridharan, Yannis Smaragdakis
  and others, "In defense of soundiness: a manifesto", CACM 2015): every
  practical analyzer is unsound somewhere; say where. Each `.dl`'s header
  here says its holes.

## Part 8: taint and information flow

- **Dorothy Denning**, "A lattice model of secure information flow"
  (CACM 1976); Dennis Volpano, Geoffrey Smith and Cynthia Irvine, "A
  sound type system for secure flow analysis" (1996); Andrew Myers, JFlow
  (POPL 1999), Jif: information flow as types, implicit flows included.
- **Taint as static analysis**: Umesh Shankar and others, format string
  bugs by type qualifiers (cqual, USENIX Security 2001); Benjamin
  Livshits and Monica Lam (USENIX Security 2005), Java web applications
  by bddbddb; TAJ (Omer Tripp and others, PLDI 2009); **FlowDroid**
  (Steven Arzt and others, PLDI 2014), Android, IFDS with aliases on
  demand; Facebook's Zoncolan (Hack) and **Pysa** (Python, 2020), by
  summaries; CodeQL's and Semgrep's taint modes.
- **Dynamic taint**: Perl's taint mode; TaintCheck (James Newsome and
  Dawn Song, NDSS 2005), on binaries. plan_datalog.md's stage 10 is
  static, over `points_to/`.

## What mini-analyze takes, and leaves

Takes: Doop's normal form and its frame of contexts, every classic
context file a few lines (Bravenboer and Smaragdakis); allocation sites
and fields by object (Andersen's, as modern analyzers do); the call graph
on the fly; 0-CFA for ML's closures with m-CFA's captured variables
(Shivers; Might, Smaragdakis, Van Horn); the types as a filter (Doop's
declared types, OCaml's inferred ones); SSA for flow sensitivity where
variables are written once (Appel); library models (Infer, WALA) and
summaries derived from the library's code (Infer's compositionality, one
level at a time); the checks of a result against an independent one
(translation validation), against runs, against containment;
Coverity's and Google's lesson that a report must be believed; Soufflé's
plans, interpreted.

Leaves: numeric domains and widening (Astrée, Flix's lattices); shape
analysis and separation logic (TVLA, Infer); a flow-sensitive heap
(SVF); path conditions and solvers (ESP, SLAM, KLEE, Saturn); IFDS in
general, and taint (plan_datalog.md stages 9 and 10); demand-driven and
incremental evaluation (Heintze and Tardieu, DDlog); threads' races
(RacerD); and a hand-written solver's tricks (cycle collapsing, BDDs):
the rules stay the analysis, the engine the speed.

## Postscript: the numbers

From `analyzers/datalog/README.md` and plan_analysis_scale.md, measured
by ix (2026-10-31 to 11-04), not compared with any tool above, none
being on this machine:

| | |
|---|---|
| rules | `analyzers/datalog/`: 2,620 lines of Datalog, comments included, `points_to/` 14 files |
| Andersen's on mini-datalog's 101,863 facts | 22 s, 1.2 million (variable, object) pairs |
| `-dead` on the 44 programs of ix | 124 s in all; mini-ml 13 s and 1 GB |
| `-exn` on the 44 | 341 s; mini-ml 75 s and 5.7 GB |
| calls the static call graph missed, against 94 runs | 0 |
| a program's own code | about 37 facts a line |
