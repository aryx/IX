# Program analysis, from scratch: a tutorial for `analyzers/`

What a static analysis is, and the ideas the field built one on another
since the 1970s, each on a toy program small enough to follow by hand:
dataflow in a function, pointer analysis (Andersen's, Steensgaard's),
flow, context and path sensitivity, types as an analysis, summaries,
taint. Each idea is then found in mini-analyze's code, where it is
there, and said not to be there where it is not. It is written for **a
reader of `analyzers/`, a graduate student who knows a compiler but
not this field**, and explains the ideas in the order the code needs
them.

The listings marked "checked" are what ix's programs answer:
`analyzers/datalog/tests/tutorial/` holds this tutorial's own toys and
`run.sh` runs them against `expected.out`; the others are from the
tests of `analyzers/datalog/tests/` and `analyzers/tests/`, which `make
test` runs. A listing marked "sketch" is not run by anything.
Companions:
[`notes_analysis_related_work.md`](../related-work/notes_analysis_related_work.md)
(where mini-analyze sits among the real analyzers, and the papers),
[`plan_datalog.md`](../plans/plan_datalog.md) (the engine and the
pointer analyses), [`plan_bug_analyses.md`](../plans/done/plan_bug_analyses.md)
(the bugs), [`plan_analysis_summaries.md`](../plans/plan_analysis_summaries.md)
and [`plan_analysis_scale.md`](../plans/plan_analysis_scale.md) (the
summaries), and [`FACTS.md`](../../analyzers/datalog/FACTS.md), the
facts' vocabulary.

## 0. Where the code is, and a reading order

```
 a.c, B.ml --> mini-analyze --> facts --> mini-datalog + rules --> answers --> report
               front ends                  languages/datalog/       analyzers/report/
               analyzers/c/, ml/           analyzers/datalog/*.dl
```

| where | what | section |
|---|---|---|
| `analyzers/c/Facts`, `analyzers/ml/Closure_facts` | a program as facts: what points where (`-facts`) | §2 |
| `analyzers/c/Ir_facts`, `analyzers/ml/Ssa_facts` | one function's flow: points, successors, SSA (`-flow`) | §3, §5 |
| `languages/datalog/` | the engine: semi-naive, stratified negation | §2 |
| `analyzers/datalog/liveness.dl`, `dominators.dl` | dataflow in a function | §3 |
| `points_to/instructions.dl` | the four instructions every pointer analysis reads | §4 |
| `points_to/steensgaard.dl`, `andersen.dl` | the two classic pointer analyses | §4 |
| `points_to/contexts.dl` + a context file | Doop's frame: call site, object, type, hybrid, selective | §6 |
| `bugs/pairs.dl` | paths over the SSA: a resource held when a call raises | §7 |
| `andersen.dl`'s types, `capabilities_types.dl` | OCaml's types used by the analysis | §8 |
| `analyzers/ml/Models`, `analyzers/summaries/` | a function by its effect: hand models, derived summaries | §9 |
| `dead.dl`, `exceptions.dl`, `capabilities.dl`, `bugs/*.dl` | the clients: what is reported on ix | §11 |
| `analyzers/Analyze`, `analyzers/report/` | the command: which rules, which report | §11 |

Read §1 and §2 first, then §4: every other analysis here sits on the
pointer analysis's call graph.

## 1. What an analysis is: a question and an approximation

A static analysis answers a question about every run of a program
without running it: can this function be called, can this pointer be
null here, can this exception reach the toplevel. Rice's theorem (1953)
says that every such question about what a program does, as opposed to
how it is written, is undecidable. An analysis answers anyway, by
answering a slightly different question that it can decide, and the
difference is the whole craft.

Two directions to be wrong in:

```
                     what the program really does
     +-------------------------------------------------------+
     |                                                       |
     |    under: a must, or a bug-finder's       over: a may,|
     |    "these I am sure of"                   what is said|
     |         +-------+                     to be possible  |
     |         |       |  real              +----------------+--+
     |         +-------+  behaviours        |                |  |
     |                                      +----------------+--+
     +-------------------------------------------------------+
```

- An **over-approximation** (a *may* analysis) says every behaviour the
  program has, and some it has not: "`p` may point to `a` or `b`". It is
  **sound** for a question when nothing real is left out. Its mistakes
  are false alarms.
- An **under-approximation** (a *must*, or a bug finder's report) says
  only what is sure. Its mistakes are missed bugs.

Every analysis in `analyzers/` is a may analysis with deliberate holes,
what Livshits and others called *soundiness* (2015): sound for the
language minus the parts it chooses not to follow (Obj.magic, C called
from ML, a function a pointer reaches from assembly), each such choice
said in its file's header. And a reported bug must be believed, or no
one reads the reports: `dead.dl`'s design note says it, "what cannot be
seen is taken as alive". A may-analysis is used both ways: for the
questions "is it dead" and "is there no path" its *absence* of a fact is
the sure answer.

The other axis is **precision against cost**. A more precise analysis
says fewer impossible things and costs more; all of §4 to §7 is points
along that line, and the field's main finding is that where precision
pays depends on the language and the question (§6's table).

## 2. Programs as facts, analyses as rules

An analysis here has two halves. A front end says the program as
**facts**, relations of symbols, nothing computed: mini-analyze reads C
by mini-cc's front end and ML by mini-ml's, and says what each
statement does to memory. The rules, in **Datalog**, say what follows,
and mini-datalog computes every consequence. From `FACTS.md` (checked
by `facts_doc.sh`), C's `p = &y; pp = &p; *pp = id(&x); p = *pp;`:

```
assign_address('main__t1', 'main__y').
assign('main__p', 'main__t1').
assign_address('main__t2', 'main__p').
assign('main__pp', 'main__t2').
assign_deref('main__pp', 'main__t4').
assign_content('main__t5', 'main__pp').
assign('main__p', 'main__t5').
```

Each expression becomes a sequence of instructions over variables, a
temporary for each value in between, so that a rule never sees a nested
expression. Then `points_to/instructions.dl` brings C's and ML's 17
relations to the four of Doop's normal form, and the rest is about
memory, not about a language:

```
alloc(V, H)      V = new H       H an abstract object: a malloc, a block, a closure, &x
copy(P, Q)       P = Q
load(P, X, F)    P = X.F         F a field, or star for *X and X[i]
store(X, F, V)   X.F = V
```

**Why Datalog.** A Datalog program is facts and Horn clauses with no
function symbols: every relation is finite, so evaluation ends, and the
order of the rules does not change the answer. Its semantics is the
least fixpoint, the smallest set of facts closed under the rules,
which is exactly the least solution of an analysis's equations (§3). The
evaluation is someone else's problem: semi-naive evaluation (a rule
re-run only on what the previous round added), joins by indexes, the
order of a body's atoms chosen by the engine (`languages/datalog/`).
Negation, `\+ p(X)`, is allowed when *stratified*: `p` is computed
whole before any rule that negates it, so a negation never goes through
its own recursion. That restriction comes back in §9: "on every path"
is a negation.

Reps (1994) observed that dataflow equations are Datalog; Whaley and
Lam's bddbddb (2004) ran a context-sensitive pointer analysis of Java
as Datalog on BDDs; Doop (2009) and Soufflé (2016) made it the way
precise analyses are written. The appeal for ix is size: `andersen.dl`
is 27 lines of rules.

## 3. Dataflow in one function: Kildall's framework

Kildall (1973): attach a fact to each point of a function's control-flow
graph, say how each instruction transforms it and how facts meet where
paths join, and iterate until nothing changes. **Liveness** is the
backward instance: a variable is live before an instruction that reads
it, or before one it is live after and that does not write it.
`liveness.dl`'s three rules are the textbook's equations:

```
live_in(V, P) :- use(V, P).
live_in(V, P) :- live_out(V, P), \+ def(V, P).
live_out(V, P) :- succ(P, Q), live_in(V, Q).
across_call(V, P) :- call(P), live_out(V, P).
```

On a toy (`tutorial/liveness.facts`, checked):

```
p1: x = 1;         live_in(x, p2).     x is read at p2
p2: y = x + 1;     live_in(y, p3).     y waits across the call: in a
p3: f();           live_in(y, p4).       callee-saved register, or spilled
p4: print(y);      live_in(x, p6).     the x of p5, not of p1: p5 kills
p5: x = 2;         across_call(y, p3).
p6: print(x);
```

The same rules on mini-cc's stack code and mini-ml's SSA give the same
sets as the compilers' own register allocators, on 3,459 ML functions
and 395 C ones (plan_datalog.md): an analysis checked against an
independent implementation, the method of §12.

**Lattices.** Kam and Ullman (1977) gave the framework's conditions: the
facts form a lattice of finite height, each transfer function is
monotone, and the iteration then reaches the least fixpoint; distributive
transfer functions make it the *meet over all paths*, the most precise
answer. Datalog's sets are such a lattice when the facts are sets
(liveness, reaching definitions, available expressions): this is why
they are rules here. Where the lattice is not a powerset of finite things
(a variable's constant value, its interval of integers), Datalog alone
cannot say it: Flix (2016) adds lattices to Datalog, and mini-datalog
has not. That is why `bugs/intwidth.dl` (an `int` past arm's 31 bits)
tracks only where a large constant flows, and plan_bug_analyses.md's
A4 step 2, intervals, was not done.

**Abstract interpretation** (Cousot and Cousot, 1977) is the theory of
all of this: a program's concrete semantics, an abstract domain related
to it by a Galois connection, and the abstract semantics then provably
an over-approximation. For an infinite domain (intervals), *widening*
forces termination by jumping to a limit. A sketch, not in ix:

```
x = 0;                        intervals:   x in [0, 0]
while (x < 100) x = x + 1;    iteration:   [0,1], [0,2], ... never ends
                              widening:    [0, +inf], then the exit
                              test gives   x in [100, +inf]; narrowing
                              brings it to [100, 100]
```

**Dominators**, the other classic of one function: X dominates N when
every path from the entry to N goes through X. `dominators.dl` writes
the definition, by what it is not, and checks the compiler's Cooper,
Harvey and Kennedy algorithm against it:

```
avoiding(X, N) :- entry(N), block(N, F), block(X, F), X \= N.
avoiding(X, N) :- avoiding(X, M), succ(M, N), N \= X.
dom(X, N) :- block(X, F), block(N, F), \+ avoiding(X, N).
```

## 4. Pointer analysis: Andersen's and Steensgaard's

Almost every interesting question across functions needs to know what a
pointer may point to: which function a call through a variable reaches,
whether a store through `p` can change what `q` reads. In ML every call
of a function value is such a call, so the call graph itself is a
pointer analysis's answer.

**The abstract heap.** A program makes unboundedly many objects; the
analysis needs finitely many names. The classic choice is the
**allocation site**: every object made by one `malloc` (or one record
expression, one closure) is one abstract object, named by where it is
made. `FACTS.md`: `_malloc_in_cons_line_32`, `Toy:block1@10`, a
closure named by its function.

**Andersen's analysis** (his thesis, 1994): each assignment is an
*inclusion*. `p = q` says that what `q` points to, `p` points to too.
`andersen.dl`'s core, without the C extras:

```
flow(V, H) :- alloc(V, H).
flow(P, H) :- copy(P, Q), pt(Q, H).
fpt(O, F, L) :- store(X, F, V), pt(X, O), pt(V, L).
flow(P, L) :- load(P, X, F), pt(X, O), fpt(O, F, L).
call_edge(I, F) :- call_indirect(I, V), pt(V, F), function(F).
flow(P, L) :- call_edge(I, F), parameter(F, Z, P), argument(I, Z, A), pt(A, L).
flow(R, L) :- call_edge(I, F), return(F, V), call_ret(I, R), pt(V, L).
```

(`pt` is `flow` filtered by the types: §8.) Three things to see. The
heap is by object and field, `fpt(O, F, L)`: `x.f` and `y.f` are
different places when `x` and `y` point to different objects
(*field-sensitive*; the author's `pointer.dl` of 2014 was *field-based*,
one place `*.f` for every record). The call graph is found as the
analysis goes, *on the fly*: a call through `V` reaches what `V` points
to, which may need what the call returns. And nothing says in which
order the statements run (§5).

**Steensgaard's analysis** (1996) makes each assignment an *equality*:
`p = q` unifies what both point to, so every pointer has one target
class, kept in a union-find. It is almost linear where Andersen's is
cubic, and it ran on millions of lines on 1996's machines.
`steensgaard.dl` says the difference in rules: make `same` symmetric
and transitive, and inclusion becomes unification:

```
same(P, Q) :- copy(P, Q).
same(Q, P) :- same(P, Q).
same(A, C) :- same(A, B), same(B, C).
same(H, K) :- pt(V, H), pt(V, K).     two things one pointer may point to merge
```

The same toy by both (`tutorial/unify.facts`, checked):

```
p = &a;            Andersen's:        Steensgaard's:
q = &b;              pt(p, a)           pt(p, a)   pt(q, a)
p = q;               pt(p, b)           pt(p, b)   pt(q, b)
                     pt(q, b)
```

`p = q` made `q` point to `a` too, which no run does. (The rules are
the definition, not the algorithm: `same` writes every pair of a class,
quadratic, where a union-find has one node. `steensgaard.dl` is here
for what it teaches, not for speed.) Das's One Level Flow (2000) found
the middle: unify below the first level, include at it, and get most of
Andersen's precision on C at Steensgaard's speed.

**For a language of functions** the same analysis is *control-flow
analysis*: which lambdas may reach which call (Shivers's 0-CFA, 1988).
`mini-ml -facts` says a closure as an object and every call as a call
through a variable, so `andersen.dl` is 0-CFA on ML with no rule of its
own. A curried `let add a b` is two functions, `add` and `add'`
(`FACTS.md`).

Andersen's on `analyzers/datalog/tests/contexts.c` (checked,
`contexts_c.out`) shows what it does and does not separate:

```
int* id(int *a) { return a; }       p1 = id(&x); p2 = id(&y);
                                    p1: x y          one a for both calls
own1.v = &x;  own2.v = &y;          n1 = own1.v;
                                    n1: x            by object: andersen
                                    n1: u w x y      by unification: steensgaard
```

`p1` points to `y` because `id`'s parameter is one variable for all its
callers: that is the next refinement but one (§6). First, the order of
statements.

## 5. Flow sensitivity

A **flow-insensitive** analysis has one answer per variable for the
whole program: the facts are a set, and a set has no order. A
**flow-sensitive** one has an answer per variable *per program point*,
and a write may replace what was there (a *strong update*). The toy
(`tutorial/flow_*.facts`, checked by `andersen.dl`):

```
p = &a;           one p:          pt(q, a)  pt(q, b)
q = p;
p = &b;           p1, p2 (SSA):   pt(q, a)
```

**SSA gives it for free, for what is written once.** Rename each write
of a variable (`p1`, `p2`) and a flow-insensitive analysis of the names
is as sharp as a flow-sensitive one of the variables: the order was in
which write a read sees, and the names now say it. ML's let-bound
variables are written once already (Appel, "SSA is functional
programming", 1998), so `Closure_facts`' variables are SSA's, and
`points_to/` is flow-sensitive for them at no cost (`Ssa_facts.mli`'s
design note). What stays insensitive is what is written more than once:
a `ref`'s contents, a mutable field, an array's element, C's locals. That
is the heap, where a strong update needs to know the object is one
concrete object, which an allocation site is not.

Hardekopf and Lin's sparse flow-sensitive analysis (2011) and SVF (Sui
and Xue, 2016) make C's pointer analysis flow-sensitive at scale by
running a flow-insensitive one first and following only the def-use
chains it gives. Not in ix: `bugs/pointers.dl`'s header says what it
would add (a `free(p); p = &x` no longer one `p`).

## 6. Context sensitivity

The `id` of §4 is the problem: a function analysed once for all its
callers mixes what each gives it, and returns the mix to each. Sharir
and Pnueli (1981) gave the two cures, and the field has used both
since:

- **The call-string approach**: analyse a function once per *context*,
  a finite abstraction of how it was called. With the last k call sites
  it is k-CFA (Shivers, 1988), *k-call-site sensitivity*.
- **The functional approach**: compute what a function does in terms
  of its inputs, a *summary*, and apply it at each call (§9).

`contexts.dl` is Doop's way (Bravenboer and Smaragdakis, 2009): one set
of rules for every analysis, and a file of a few lines that says what a
context is. Its two choices are Doop's *Merge* (the context a call runs
in) and *Record* (the context an object made there is known by). The
context is two columns, not a term (Datalog has none), `none` where it
is shorter:

```
call1.dl          callee(I, C1, C2, F, I, none) :- fresh(I, C1, C2, F, _, _).
                  flow(V, C1, C2, H, none, none) :- new_site(V, H, C1, C2).
                  a call runs in the context of where it is called from

call1_heap1.dl    the same, an object known by its caller's context too:
                  a wrapper of malloc makes one object per caller

object1.dl        a call runs once per object its first argument may be:
                  Milanova, Rountev and Ryder's receiver (2002)

type2_heap1.dl    the object's place of making, not the object
                  (Smaragdakis, Bravenboer, Lhoták, 2011)

hybrid.dl         objects, and call sites where there is no object (2013)

selective.dl      2-call-site only where Andersen's shows it worth it:
                  a function given two objects, or handing out its own
                  (introspective analysis, 2014; Zipper, 2018)
```

What each tells apart, on `contexts.c` (checked, `contexts_c.out`, a
question per variable; the full table has all eleven analyses):

```
                     p1     q1      r1         o1          f1
                     id     id2     newbox     set3        run(fone)
                     1 lvl  2 lvls  a wrapper  3 levels    a pointer
steensgaard          x y    x y     u w x y    u w x y     x y
andersen             x y    x y     u w x y    u w x y     x y
call1                x      x y     u w x y    u w x y     x
call1_heap1          x      x y     x          u w         x
call2_heap1          x      x       x          u w         x
```

Read it as the lesson Doop's papers drew for Java: one call site
separates one level of wrapping and no more (`id2` needs two); a
*heap context* (`_heap1`) matters as much as a longer call string,
because without it the wrapper `newbox` makes one object for all its
callers; and three levels (`set3`) defeat both, where one object all
the way down (`object2_heap1`) does not. The ML version,
`contexts.ml`, asks the same of closures, records and lists:

```ocaml
let id x = x
let a = id inc
let b = id dec          (* which function is a?  andersen: dec inc
                                                 call1:    inc *)
```

**What it costs**, on real programs (`analyzers/datalog/README.md`,
2026-10-31, one core): on mini-datalog's 101,863 facts Andersen's takes
22 s, 1-call-site 46 s, 1-call-site+1-heap 58 s, and the object, type,
hybrid and selective files do not end in 150 s. Van Horn and Mairson
(2008) proved k-CFA EXPTIME-complete for k ≥ 1 on a higher-order
language: a closure's captured variables multiply the contexts. Might,
Smaragdakis and Van Horn's m-CFA (2010) flattens them, and
`contexts.dl` makes the same choice: a variable a closure captures has
no context (`global(V)`).

**The lesson ix's numbers taught.** On ML the calls with several
targets hardly move with contexts (154 to 152 on mini-datalog): what
merged values was not the lack of a context but three other things,
each fixed otherwise. An external (`Obj.magic`, `Array.get`) was one
function for the whole program, so every caller's `'a` result was every
other's: `Closure_facts` makes a copy per call, which is
1-call-site-sensitivity for externals alone, at no cost elsewhere
(mini-cc's `-dead` out of memory at 12 GB, then 16 s and 1.2 GB). List's
functions and Hashtbl's buckets were one set of cells for the program:
models at each call (§9). And OCaml's types (§8). The contexts were the
textbook's answer; the facts' merges were the real one.

## 7. Path sensitivity

A **path-sensitive** analysis keeps apart facts that hold on different
paths, instead of joining them where paths meet. The classic false alarm
of a path-insensitive analysis, a toy in `tutorial/paths.dl` (checked):

```
n1: if (c)                         path-insensitive: at n4, "p may be 0",
n2:   p = 0;                       so the deref at n7 is reported:
n3: else p = &x;                     bug(n7).
n4: ...                            path-sensitive: the fact carries what
n5: if (!c)                        is known of c on the way, and an edge
n7:   *p = 1;                      that contradicts it is no path:
                                     null2_in(n4, c). null2_in(n5, c).
                                   and nothing at n7
```

The fact `null2_in(N, C)` has one more column, the condition known on
the way, and `meet` has no row for `c` and `notc`, so the edge to n7
is not taken. The cost is the number of conditions: in general one per
path, exponential. The field's answers:

- **Property simulation** (Das, Lerner and Seigle's ESP, 2002): keep a
  path apart only while it differs in the property tracked (the null
  state), join otherwise. Nearly linear, enough for Windows's file
  handles.
- **Predicate abstraction and refinement** (SLAM, Ball and Rajamani,
  2001; BLAST, 2002): the conditions are predicates chosen from the
  program, added when a reported path is found infeasible
  (counterexample-guided).
- **Symbolic execution** (King, 1976; DART 2005, KLEE 2008): follow
  paths one at a time with a solver; precise, an under-approximation,
  a bug finder.

In ix, `bugs/pairs.dl` follows paths but not conditions: over mini-ml's
SSA (`ssa_succ`, `ssa_next`), `held(A, P)` is a path from the take `A`
to `P` that avoids the give-back, and a call that may raise on such a
path is a leak:

```ocaml
let ic = open_in file in                   (* f7b1aef0^, builder/CLI.ml *)
let s = really_input_string ic (in_channel_length ic) in
close_in ic;                               (* a raise above: the channel left open *)
```

Its header names what it misses for want of conditions: 62d811be's
`dup`, a count given back only `when o != c`. Paths are cheap here
because one function's SSA is small and the question is one resource
at a time.

## 8. Types as an analysis

A type checker is a static analysis that is sound by construction and
that the programmer agrees to help. Hindley-Milner inference (Milner,
1978) solves equality constraints by **unification**: the same
algorithm as Steensgaard's (§4), and Steensgaard presented his analysis
as type inference over a type of locations. Andersen's inclusion is to
Steensgaard's what subtyping is to equality.

**Let-polymorphism is context sensitivity for types.** In

```ocaml
let id x = x
let a = id inc          (* int -> int *)
let b = id dec          (* int -> int, a separate instance of 'a -> 'a *)
```

the type checker gives each use of `id` a fresh instance of its type
scheme: each call is analysed in its own context, at any depth,
because the scheme is a summary (§9) of `id`. Mossin's thesis (1997)
and Rehof and Fähndrich (2001) made it exact: a flow analysis read off
polymorphic types is context-sensitive the way CFL-reachability is
(§9), matched calls and returns. Palsberg and O'Keefe (1995) showed
0-CFA equivalent to a type system with subtyping.

**ix uses OCaml's types three ways:**

1. **As a filter on the pointer analysis.** `andersen.dl`'s `pt` keeps a
   flow only if the variable's type and the object's agree, the head
   first (`list`, `Hashtbl.t`, `->`), then the whole type when neither
   has a variable. Without it, mini-tiger's facts did not end in 200 s
   and 8.5 GB: `List.rev_append`'s parameter held every list of the
   program, and a boxed `int64` reached 1,900 variables. "OCaml's types
   are a static analysis already done" (its design note); Doop filters
   by Java's declared types for the same reason.
2. **As the thing checked: row polymorphism for capabilities.** A
   function's type `< Cap.stdout; .. >` says what it may do; OCaml checks
   that a caller holds what a callee asks for, the `..` making it a
   subset test. `capabilities_types.dl` writes that check again over the
   call graph, not to find bugs (OCaml found them) but to find the
   analysis's own: a mismatch on code OCaml accepted is the analysis
   wrong. The method is translation validation's (§12).
3. **As what the type checker cannot say.** OCaml checks a function
   against what its callees ask; nothing checks that what a function asks
   for is what its body does. `capabilities.dl` computes what a function
   does, a fixpoint over the call graph, and compares it with its type:
   an *effect system* (Lucassen and Gifford, 1988) computed, not
   declared. Checked, `analyzers/tests/caps/ml/`:

```
let log s = print_string s
    Use.log: no capability, needs Cap.stdout (Pervasives.print_string)
let wrong (_ : < Cap.stdout; .. >) f = Unix.openfile f [ Unix.O_RDONLY ] 0
    Use.wrong: has < Cap.stdout >, needs Cap.open_in|Cap.open_out
    (Unix.openfile); may not need Cap.stdout
```

Exceptions are the same story: Leroy and Pessaux's ocamlexc (2000)
inferred the exceptions a function may raise in its type, with row
variables; `exceptions.dl` computes them over the call graph instead,
the transitive closure minus what each `try` catches, "ten lines".

## 9. Summaries: a function by its effect

Sharir and Pnueli's second approach: describe what a function does as a
relation between its inputs and outputs, once, and apply it at each
call. The call's result then depends only on its own arguments, which is
full context sensitivity for what the summary says, at the cost of one
analysis per function.

**IFDS** (Reps, Horwitz and Sagiv, 1995) made it exact and polynomial for
the dataflow problems whose facts are a finite set and whose transfer
functions distribute over union (the problems of §3, across functions):
the analysis becomes reachability in an "exploded supergraph", and a
callee's summary is the set of (fact at entry, fact at exit) pairs it
connects. Only paths whose calls and returns match are followed, which
is CFL-reachability (Reps, 1998): the language of balanced parentheses,
one pair per call site. In Datalog it is two relations, a path inside a
function and a summary edge across a call.

**A toy of taint with summaries** (`tutorial/taint.dl`, checked; §10
says what taint is):

```ocaml
let read_input () = Sys.argv.(1)     (* a source *)
let id x = x
let quote s = Filename.quote s       (* a sanitizer *)
let run cmd = Sys.command cmd        (* a sink *)
let shell c = run c

let a = id (read_input ())
let b = id "ls"
let () = run b                       (* c3: fine *)
let () = run (quote a)               (* c5: fine *)
let () = run a                       (* c6: the bug *)
let () = shell a                     (* c7: the bug, a call down *)
```

The context-insensitive rules bind each argument to the callee's
parameter, one variable for all calls:

```
tainted(P) :- call(S, F), \+ sanitizer(F), arg(S, I, A), tainted(A), param(F, I, P).
tainted(R) :- call(S, F), ret(S, R), return(F, V), tainted(V).
    leak(c3). leak(c6). leak(c8).
```

`c3` is false (id's `x` held `a` and `"ls"` both), and `c8` is reported
inside `shell`, where every caller of `shell` is blamed at once. With
two summaries, `passes(F, I)` (argument I reaches the result) and
`sinks(F, I)` (argument I reaches a sink, through calls too), the
parameters are never bound:

```
passes(F, I) :- param(F, I, P), return(F, P).
sinks(F, I) :- param(F, I, P), in_fun(S, F), call(S, G), arg(S, J, P), sinks(G, J).
tainted2(R) :- call(S, F), \+ sanitizer(F), passes(F, I), arg(S, I, A),
               tainted2(A), ret(S, R).
    leak2(c6). leak2(c7).
```

The call that is the bug is reported, at the caller that made it.

**ix has three kinds of summary**, of increasing ambition:

- **Hand-written models** (`analyzers/ml/Models`): List's, Hashtbl's
  and `@`'s functions as a few operations at each call, in a small
  vocabulary (`New`, `Load`, `Store`, `Assign`, `Call`, `Raise`). A list
  written in ML is one set of cells for the whole program: every list of
  mini-cc had 949 elements. A model at each call made `-dead` on
  mini-cc 36 s to 12 s, `-exn` 247 s and 12 GB to 46 s and 3.8 GB.
  Infer, Pulse, Soot and WALA model their libraries the same way.
- **Derived summaries** (`analyzers/summaries/`, plan_analysis_scale.md
  step 3): the same vocabulary made from the library's own facts. A
  function's tree (its curried stages, its local functions) becomes
  ops over `Arg i`, `Ret` and temporaries; a call inside the tree is
  assignments to its parameters, so a loop over a list becomes
  `c = l; c = c.tl` and the objects are the caller's. List.iter's:

```
Assign (T1, Arg 1)      f
Assign (T2, Arg 2)      the list
Load (T3, T2, hd)       a = l.hd
Load (T4, T2, tl)
Call (T5, T1, T3)       f a: the caller's analysis makes the call
Assign (T2, T4)         the recursive call: l = l.tl
```

  The hard parts are the plan's: arguments that alias (a summary
  computed with each parameter its own object says nothing of two that
  are the same), globals (a function reading one depends on all its
  writers: those keep their body), and callbacks (`Call` on a
  parameter, made by the caller).
- **Boolean summaries for precision** (`bugs/pairs.dl`, plan_analysis_
  summaries.md): `gives_arg_back(F)`, F gives back its argument's
  resource on every path to its end, and `returns_taken(F)`, F returns a
  resource it took. A call of one is then a give-back or a take in its
  caller. One level only: "on every path" is a negation, and
  stratification forbids one through its own recursion, so a summary
  is made of a function's own calls, not of other summaries. A greatest
  fixpoint, or the summary's iteration written in ML, would lift it.
  And `bugs/evalorder.dl`'s `wrote(F, O)`, the objects a function or its
  callees write, but those the callee made: a least fixpoint, every
  level.

Summaries are also how analyses scale: compute each module's once,
bottom-up, as a compiler compiles. Facebook's Infer analyses each
procedure once (bi-abduction, Calcagno and others, 2009) and so runs on
a diff. In ix, lib_core's 80,000 to 117,000 facts are a fixed cost in
every program's run (plan_analysis_scale.md, step 1): their summaries,
stored once, are the plan.

## 10. Taint: does what comes in reach what must not

**Taint analysis** asks whether data from a **source** (a user's input,
a network packet, a file's length field) can reach a **sink** (`exec`,
an SQL query, an allocation's size, an array index) without going
through a **sanitizer** (a check, an escape). It is the security
analyses' workhorse, from Perl's taint mode (dynamic) to FlowDroid
(Android, 2014), CodeQL, Pysa and Semgrep's taint mode (static). It is a
reachability over a value-flow graph, so everything above applies:
pointers (a tainted value stored in a field and read back elsewhere),
contexts (§9's `c3`), and summaries. The theory behind it is
information flow (Denning, 1976): a lattice of security levels, and a
type system for it (Volpano, Smith and Irvine, 1996) that also sees
*implicit* flows, a secret's value told by which branch ran, which taint
analyses usually leave out.

Not built in ix yet. plan_datalog.md's stage 10 names its sources and
sinks: in mini-xv6's C kernel an address a user program gave used
before `argptr`, `fetchint` or `copyin` checked it; in the OCaml kernel
and servers, a length read from a 9P message, a FAT entry or a packet
reaching `Bytes.blit`, an array or an allocation's size; in mini-rc,
text reaching `exec`. `tutorial/taint.dl` is the shape it would take,
over `points_to/`'s `pt` and `target` in place of its hand-written
`call` and `arg`.

## 11. The clients: what mini-analyze reports on ix

An analysis is worth what its reports find. mini-analyze's switches,
each a set of rules over the same call graph and a report in
`analyzers/report/`:

| switch | rules | question |
|---|---|---|
| `-dead` | `dead.dl` | what no run can reach, from the roots |
| `-exn` | `exceptions.dl` (call1_rec.dl's contexts) | the exceptions a toplevel may let escape |
| `-caps` | `capabilities.dl` | does a function hold the capabilities its body needs, and no more |
| `-bugs` | `bugs/*.dl` | ix's past bugs as classes: deep recursion, swallowed errors, 31-bit ints, a table's order in an output, `==` on a fresh value, leaks, races with handlers, evaluation order |
| `-facts`, `-flow` | none | the facts, for one's own rules |

**Dead code** from the roots, not from each function's callers: two dead
functions calling each other would keep each other alive, as reference
counting keeps a cycle. A grep and a call graph differ both ways,
`dead.dl`'s header:

```c
void show(Node *n) { ... }       void (*visit)(Node*) = show;
void hide(Node *n) { ... }       main() { visit(&root); }
void unused(void) { hide(0); }
    show: alive, through_pointer: no line of the program calls it by name
    unused: dead, never_named
    hide: dead, named_in_dead: only unused calls it
```

**Exceptions**, checked (`analyzers/tests/exn/toplevel/`):

```ocaml
let first (l : int list) : int = match l with x :: _ -> x | [] -> raise Empty
let guarded (b : bool) : int = try first [] with Empty when b -> 0
let later () : unit -> unit = try fun () -> raise Late with Late -> fun () -> ()
    the toplevel may let Main.Empty escape, raised at Main.ml:12 (Main.first)
    the toplevel may let Main.Late escape, raised at Main.ml:26
```

a guard catches nothing for sure, and a function made inside a `try`
runs outside it.

**Bugs.** Each `bugs/*.dl` was written from a class of ix's past bugs
(plan_bug_analyses.md) and is tested on the code before the fix and
after it (`analyzers/tests/bugs/<commit>/`): reported on `Before.ml`,
quiet on `After.ml`. `bugs/swallowed.dl` joins a `try` whose case
answers a constant with what may arrive there, which is what a grep for
`with _ -> ()` (970 lines in ix) cannot:

```ocaml
let code = try f () with _ -> 1 in       (* c5086383^: a fork's failure, silent *)
```

## 12. How an analysis is checked

No Soufflé or Doop here to compare with, so (plan_datalog.md, decision 7):

- **Answers written by hand** on toys, each question saying which
  analysis should tell it apart: `contexts.c`, `contexts.ml`, this
  tutorial's `tutorial/`, `analyzers/tests/*/expected.out`.
- **Containment**: a more precise analysis's answers are inside a less
  precise one's; `tests/run.sh` counts the tuples outside, each count
  must be 0.
- **Against real runs**: a function that ran and that the call graph
  does not reach is the analysis's mistake (`tests/dynamic.sh`: mini-5i's
  profile of five programs' tests, 0 missed). The dynamic run is an
  under-approximation, the static one an over: the first must be inside
  the second.
- **Against an independent implementation**: liveness and dominators
  against the compilers' own; the capabilities against OCaml's type
  checker (`capabilities_types.dl`). A checker of a result is simpler
  than what made it, translation validation's idea (Pnueli, 1998).
- **Against history**: each bug analysis on a fix's code before and
  after.
- **Recordings**: the reports on ix (`bugs_ix.txt`, `dead_ix.txt`,
  `caps_ix.txt`) are kept, and a change to the rules shows as their diff.

## 13. What is not here

Named so that what is left out is chosen:

- **Numeric domains** (intervals, octagons, polyhedra) and widening: the
  engine has no lattices (§3). Astrée, Frama-C's EVA, IKOS, Goblint.
- **Shape analysis**: whether a structure stays a list or a tree.
  Sagiv, Reps and Wilhelm's three-valued logic (TVLA, 2002); separation
  logic (Reynolds, O'Hearn, 2001-02) and its bi-abduction, Infer's.
- **A flow-sensitive heap**, strong updates (§5).
- **Path conditions** beyond the toy, and symbolic execution (§7).
- **Demand-driven and incremental analysis**: one variable's answer
  without all (Heintze and Tardieu, 2001; Sridharan and Bodík, 2006);
  an answer kept up as the program changes (DRed, differential
  dataflow; `Datalog_eval.mli` names them).
- **Concurrency**: `bugs/races.dl` sees signal handlers, not threads'
  interleavings; lock sets (Eraser, 2000) and RacerD (2018) are the
  references.
- **Taint** (§10), and **IFDS** in general, are the next stages of
  plan_datalog.md (9 and 10).

## 14. Exercises

For a reader who wants to change the rules (run them with
`bin/mini-datalog`; `analyzers/datalog/tests/tutorial/run.sh` checks the
toys):

1. In `steensgaard.dl`, remove the rule `same(Q, P) :- same(P, Q)`:
   `unify.facts` then says Andersen's answer. Write a toy where it still
   does not, and say which rule left is to blame.
2. Give `paths.dl` a third branch on a second condition `d`. How many
   rows does `null2_in` grow to, and what does that say of path
   sensitivity's cost?
3. In `taint.dl`, make `id` call `quote` on its argument. Which leaks
   remain by each set of rules, and is `passes(id, 1)` still right?
4. `tests/contexts.ml`'s question 6 (`second box f`): why does
   `object1` fail on it and `call1` not? Write the question where the
   opposite holds.
5. Write `reaching.dl`, reaching definitions in §3's style over
   `liveness.facts`' relations, and say which `x` reaches `p6`.
6. (Harder) `pairs.dl`'s `gives_arg_back` is one level. Write it for two
   levels by hand, a helper calling a helper, and say which negation
   stratification would refuse if it were written recursively.
