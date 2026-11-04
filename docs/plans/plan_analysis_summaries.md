# Plan: a function by its effect, not its body (`analyzers/datalog/`)

The author (2026-11-04), of plan_bug_analyses.md's A9 left undone:
"The A9 and summary per function seems interesting though to pursue. I
know another session was also mentioning using summaries to scale to
100 000 LOC; I dunno how much those 2 overlap", then "ok let's start
them with the short plan you mentioned".

**Status: steps 1 and 2 done (2026-11-04), step 3 planned.**

## Two kinds of summary

A summary says what a function does to its arguments and its result, so
that a caller's analysis reads that instead of the body. ix has one
kind already, written by hand: `analyzers/ml/Models`, List's, Hashtbl's
and `@`'s functions as a few operations at each call, 3 to 5 times
faster on mini-cc and mini-ml (`andersen.dl`'s design note).

| | for precision (this plan's step 1) | for speed (step 3, the other session's) |
|---|---|---|
| what | a few booleans: "returns a resource it takes", "gives back its argument" | the whole effect: what the result may point to in terms of the arguments, what it raises, what it calls back |
| when | computed in the run, more rules | lib_core's computed once, stored, loaded by each program's run |
| hard part | "on every path": a universal, which stratified negation computes one level at a time | staying sound on the heap: arguments that alias, fields |

The other session's proposal (2026-11-04 07:33, prompt-history.md):
mini-analyze on 100,000 lines, by measuring the growth, summarizing
lib_core's units, and mini-datalog's `-j`; approved ("I like your plan
to improve the speed for 100 000 LOC"), not written yet.

## Step 1: A9's resources across a call

`bugs/pairs.dl` pairs a take and its give-back in one function. Two
summaries carry them across a call:

- `gives_arg_back(F)`: the stage F gives back the resource of its
  argument on every path to its end: a helper that closes (`read_all ic`).
- `returns_taken(F)`: F returns a resource it took (`open_log f =
  open_out f`).

A call of one is then a give-back or a take in its caller, and
`pairs.dl`'s paths do the rest: a raise between `open_in` and a call of
a closing helper is a leak, missed before; and one between a call of an
opening helper and its close. One level: a summary is made of a
function's own calls of `close_in` and of the openers, not of other
summaries, since "on every path" is a negation and the strata forbid
one through its own recursion (what a greatest fixpoint, or a
summary's iteration in ML, would allow).

**Done** (2026-11-04): `bugs/pairs.dl`'s `gives_arg_back(F)` (no path
of the SSA from its function's entry to an end avoids a give-back of
the variable its argument binds) and `returns_taken(F)` (its result
points to what a take of its own made); `took` and `gave` a call of
one too; and `leak_in(F, C, R, E)`, a raise in such an F before it
gives back (SSA's paths have no edge for a raise: the callee's leak,
reported there). Test `analyzers/tests/bugs/summaries/` (a read between
an open and the closing helper, one between the opening helper and its
close, a raise in the closing helper: reported; a helper closing on one
path only, no raise between: not). Found on the way: `gives_back`
was exceptions.dl's already (a try's caught object raised again), the
two one relation, -exn's crash changed until renamed: a name of the
rules is the program's, every file's. On ix: nothing new, the 44
programs and the kernel as `bugs_ix.txt` (mini-mk has one summary of
each, Recipe's closing helper and `CapStdlib.open_in`: no raise between
there). 25 lines of rules, 12 of report.

Not in step 1: a channel made of a descriptor (ed's `read` opens a
descriptor, `read_file` closes the channel `in_channel_of_descr` made of
it: one more fact, the channel holds it), counts (62d811be's dup).

## Step 2: summaries for the other analyses

What A8's races and the exceptions' crash could read the same way: a
function's writes (`writes(F, Field)`, the purity A11's evaluation
order needs), what it may raise already being `exceptions.dl`'s.

**Done** (2026-11-04), for A11's evaluation order: `bugs/evalorder.dl`'s
`wrote(F, O)`, the objects a program's function writes, or what it
calls, but those the callee made (a list or a table filled and returned
is no effect for the caller), and `io` for order.dl's outputs and
stdin's reads; `effectful(F)`; then `unordered(N, A, B)`, two operands
of an application, a tuple, a constructor, a record, an array, both
with an effect (Tree_facts' `tree_site`, an application by the key of
`site_key`; Closure_facts' `store_site`, a write's site). Every level:
the summary is a least fixpoint, its negations over facts only. The
library's own writes not followed: the insensitive heap has one object
for every `Buffer.create`, `Printf.sprintf` wrote all of them, 849
reports on the 44 programs; by the program's functions and order.dl's
table, 183. Test `analyzers/tests/bugs/56934c32/` (lib_core's `f a @
concat_map f l`: reported; its `let`, `&&`, a lambda, pure operands:
not).

Found on the way: 56934c32 was not two compilers apart. OCaml and
native mini-ml both evaluate right to left; OCaml's own List binds
`f a` first, lib_core's did not. mini-ml -dotnet evaluates left to
right, and stays so (the author: "better .NET evaluate left to right,
and not necessarily follow what OCaml does, since anyway programs
should not rely on such order"): the 183 are code whose output may
differ between ix's native and .NET builds. Their kinds: caches
(machine/'s `Memory`, its last segment: benign), tables filled in
order (the .NET `Writer`'s string heap, `Il_types`' `sys c`: an
entry's index), fresh counters (`Resolve`, `Ssa_build`). None fixed
(the author decides). `writes` was order.dl's already: `effectful`.

## Step 3: lib_core's summaries stored (for 100,000 lines)

The other session's: each relation of a library unit computed once and
loaded, Models' way but derived. Step 1's relations are keyed by
function name so that they can be stored with the others.
