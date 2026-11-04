# Plan: mini-analyze on 100,000 lines (`analyzers/`, summaries first)

The author (2026-11-04): "I like your plan to improve the speed for 100
000 LOC", then "ok let's start the 100 000 lines scaling project with
summaries". plan_analysis_summaries.md's step 3 is this plan ("lib_core's
summaries stored"); its steps 1 and 2, summaries for precision computed in
the run, are done there.

**Status: step 1 done (2026-11-04); step 2 tried and not kept (below);
step 3 next.**

## Step 1: where the time and the memory go (measured)

`analysis_scale/measure.sh -dead|-exn out` runs the sweep of the 44
programs with each run timed and its facts counted, the program's own
units', lib_core's, the primitives'; `analysis_scale/dead.txt` and
`exn.txt` are its tables (aarch64, 8 runs at once).

| | lines | facts own | lib_core | `-dead` | `-exn` |
|---|---:|---:|---:|---|---|
| mini-ed | 952 | 33,035 | 82,856 | 1.2 s, 67 MB | 1.9 s, 113 MB |
| mini-rc | 1,662 | 55,666 | 82,737 | 1.6 s, 96 MB | 3.0 s, 221 MB |
| mini-dotnet | 9,232 | 396,846 | 103,045 | 10.2 s, 770 MB | 30.9 s, 2.5 GB |
| mini-cc | 13,973 | 470,010 | 101,061 | 15.9 s, 1.3 GB | 67.9 s, 3.4 GB |
| mini-ml | 18,129 | 674,057 | 117,140 | 13.3 s, 1.0 GB | 75.5 s, 5.7 GB |

What they say:

- **lib_core is a fixed cost in every program**: 80,000 to 117,000 facts
  (about 37,000 for the kernel's, which has its own system), whatever the
  program uses. Under 2,000 lines it is 70% to 99% of the facts, most of
  the 1 to 3 s and 70 to 220 MB of a run; the sweep pays it 44 times.
- **A program's own code: about 37 facts a line.** `-dead` grows about
  with them (mini-ml 13.9 s: the facts made 3.7 s, 107 MB; mini-datalog's
  run 11.2 s, 1 GB, 3.6 million tuples, about 250 bytes a tuple, the
  6- and 7-column relations the most: `flow/6` 710,000, `pt/6` 489,000,
  `read/7` 334,000; the rules' time spread over contexts.dl's). `-exn`
  grows faster: mini-ml has 1.7 times mini-dotnet's facts, 2.4 times its
  time, 2.3 times its memory.
- **100,000 lines** (about 3.7 million facts of its own): `-dead` about
  80 s and 6 GB if linear; `-exn` at least 7 minutes and 30 GB, more at
  its growth. lib_core's summaries do not reach that: they are a fixed
  cost taken away, the program's own code is the rest.
- **What a program reaches of lib_core**: mini-ml 777 of its 1,552
  functions, mini-ed 545 of 1,353; the facts of the functions it does
  not reach, 4% of mini-ml's, 18% of mini-ed's. The rest of lib_core's
  are its units' toplevels (run at the start, whatever is used) and the
  types.

## Step 2: lib_core's functions no one names, left out

A function of lib_core that no code of the program names, directly or
through what it names, nor a unit's toplevel, contributes no fact the
analyses read: its facts dropped before mini-datalog. A summary of the
plainest kind: lib_core's call graph by name, computed once (a unit
names, a function names), the closure taken from the program's own
units and every unit's toplevel. Sound by construction (a function is
reached only by a name, Closure_facts' `assign_address`); checked by
make check: the six recordings unchanged. Expected: 18% of a small
program's facts, 4% of mini-ml's.

road-not-taken (tried 2026-11-04, not kept): a pass between the facts and
mini-datalog (a `-prune`, Analyze holding Closure_facts' facts, a module
Prune: functions and globals the nodes, a fact's context its owner or the
global it defines, a toplevel's closure variable a node of its own, else
every toplevel names every function of its unit). On mini-ed it kept
120,814 of 123,589 facts, 2.3% out where 18% are unreached: a name is a
far weaker reason than a call from the start, almost every lib_core
function named by another one named. The run no faster (the pass costs
what it saves), and -exn's answer changed (more raise sites through
Models' calls): not sound as built. What reaches less must be the
analysis's own reach, which needs the facts: the summaries' job.

## Step 3: lib_core's summaries, derived (Models' way)

Each lib_core function's effect said in terms of its arguments, as
`analyzers/ml/Models` writes List's and Hashtbl's by hand: what its
result may point to (an argument, an argument's field, an object it
makes), what it stores where (an argument's field), which argument it
calls and with what, what it may raise. Derived once by the points-to
rules themselves, on lib_core alone, each parameter given an object of
its own (`param(F, i)`, a symbol): the summary is what reaches the
result, the fields, the calls, in those symbols; stored as facts, a file
beside lib_core's objects. A program's run then has, for each call of a
summarized function, the summary instantiated at the call (Models'
`model_call` and `model_new`), not the body.

Its hard parts, why it is a step of its own:

- **Soundness on the heap**: arguments that alias (a summary computed
  with each parameter its own object says nothing of two that are the
  same); a field written through one and read through the other. First
  the functions where it cannot matter: no field written, or written
  only in objects the function made (List's, String's, Buffer's
  creation).
- **Globals and toplevels**: a function reading a global (a ref of its
  unit) depends on every writer; those stay bodies.
- **Callbacks**: `List.iter f l` calls its argument: the summary says so
  (`calls_param(F, i, args)`), the caller's analysis makes the call.
- **Checked against the hand models**: List's and Hashtbl's derived
  summaries against Models' (`-no-models` and the models test of
  analyzers/tests/run.sh), then make check's six unchanged, then the
  measurement again.

### 3.1: the derivation, List first (against Models' List)

A summary in Models' own vocabulary (`Models.op`: `New`, `Load`, `Store`,
`Assign`, `Scalar`, `Call`, `Raise`), so Closure_facts writes it at each
call unchanged; one op more, `Global (v, sym)`, v holding what a
global holds (List.hd raises by calling `Pervasives.failwith`: the call
kept, to its real code or its own summary). Made from lib_core's facts
with no models (`-no-models`), a function's tree at a time: its curried
stages and its local functions, each of its variables a `Tmp`, each
parameter first copied (`Assign (Tmp p, Arg i)`), the last stage's
result `Ret`:

    List.iter's facts                      its summary
    f/241 = iter:arg                       Assign (T1, Arg 1)     f
    a = iter':arg.hd, l = iter':arg.tl     Assign (T2, Arg 2)     the list
    f a                                    Load (T3, T2, hd)  Load (T4, T2, tl)
    iter f l: iter/240 holds List.iter     Call (T5, T1, T3)
      (a call in the tree: its             Assign (T1, T1)        (iter f: f)
       parameters, its result)             Assign (T2, T4)        (_ l: c = c.tl)

A call whose target is a closure of the tree is its parameters and its
result (Andersen's, inside); one through anything else, a `Call`; a
global read, `Global`; `raise_of`, `Raise`. Not summarized, the body
kept: a `try` in the tree, a global written, a primitive called through
a variable. Compared with Models' List (the ops of iter, map, hd, find,
rev side by side, then the models test, then the measure).

**First results** (2026-11-04): `analyzers/summaries/` (Summaries, the
derivation and the summaries' text; Derive.exe, `facts unit... [-models]
[-o file]`), mini-analyze `-summaries file` (a derived summary first,
Models' own for the rest: List derived, Hashtbl Models'). A call of a
summarized function given all its arguments is its summary written in
(List.rev's rev_append: rev's cells its call's own, as Models' rev).
List's functions, 52 written to the file, every one summarized:

- iter, map, find as Models' (a few copies more); hd more faithful (it
  calls Pervasives.failwith, Models raises Failure itself);
- the models test's probe: the same 83 answers as the code as written
  and as Models';
- make check's six: -caps the same on both, -dead the same on the 44
  (tiny/ one gone), -bugs tiny/ one gone and 8 new on the 44 (evalorder
  in mini-cc's generated parser, order in mini-ml's Typing): conventions
  of Models' that bugs/ reads, `walked` made of a model's shape (an
  `Assign (Tmp j, Arg)` then `Load (Tmp j, Tmp j, tl)`) that a derived
  summary has not;
- the measure, the 44 programs' total: -dead 124 s to 115, -exn 341 s
  to 314 (8% faster than Models' List), the memory the same.

Then (2026-11-04, uncommitted): every call chain of a summarized
function written in, a global's variable serving several (stable_sort's
four of rev_append; no List function called through a global left: the
shared body had made sort_uniq's callers write each other's cells, six
evalorder reports, gone); `walked` the loop wherever its ops are and
through copies (a local function's parameter, rev_map's rmap_f), the
hand models' answers the same; the sorts Models' own even with
-summaries (`Models.meant`: a sort's result a list of its own, what
bugs/order.dl needs, the code saying only cells, some its input's).
Left: two order reports in mini-ml's Typing (places, min_max_globals:
a table's contents sorted, then marshalled; false), TinyVCS.lca one
output place of two, and TinyBrowserTokens.wanted no longer dead: which
derived function carries the order is to find, through order.dl's taint.

Next: those three; then Hashtbl derived (its closures over the buckets, the
case Models was written for); then the rest of lib_core, the fixed cost
of step 1 (List's code about 2,400 of the 80,000 to 117,000 facts of
lib_core in a program: mini-cat's count).

Expected: a small program's run near its own code's, a few tenths of a
second; the sweep several times faster. `Models.ml` stays: "a good
baseline to compare too, for correctness and performance", and "it also
has teaching value" (the author): a flag chooses, the hand models (today's
default), the derived summaries, or neither (`-no-models`, which exists);
the default the summaries once they give Models' answers (the models
test) at its speed or better (this plan's measure).

## Step 4 and after: the program's own code (100,000 lines)

What step 1 says is the rest: summaries of a program's own modules,
bottom-up over the units' order (each unit's from its dependencies',
as a compiler compiles), with the same three hard parts; the engine's
memory (a tuple's 250 bytes: the contexts packed in one column, the
intermediates like `passed` dropped once their consumers ran);
mini-datalog's `-j` on OCaml 5. Planned when step 3's numbers are in.
