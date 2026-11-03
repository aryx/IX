# lib_code: code as what a program reads

The author's playground's `libs/code/highlight` (`~/playground`):
`Highlight_code`, the categories a highlighter gives a file's tokens
(a keyword, a comment, a function where it is defined, a type) and a
file as lines of spans, the same for every language. A language's
highlighter is beside the language, and gives these:

| | the playground's | here |
|---|---|---|
| OCaml | `languages/ocaml` | `languages/ml/highlight/` |
| C | `languages/c` | `languages/c/highlight/` |
| assembly | `languages/asm` | `assembler/highlight/` |
| Smalltalk | `languages/smalltalk/Highlight_st` | `languages/smalltalk/highlight/` |
| Scheme, Pascal, Prolog | none | `languages/scheme/highlight/`, `languages/pascal/highlight/`, `languages/prolog/highlight/`: written for ix |

What draws them is mini-emacs (`editors/emacs/`): a mode a language,
its colors `Highlight`'s. The plan:
[`plan_emacs.md`](../docs/plans/done/plan_emacs.md).

Each copied file says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh lib_code languages/ml/highlight
languages/c/highlight assembler/highlight languages/smalltalk`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

`Highlight_code` (2 files: 282 lines there, 110 here) and four
highlighters (16 files: 1,996 lines there, 1,412 here).

## What changed

- **An editor's colors, not a code map's.** `Highlight_code` has the
  categories, a span and `lines`. Gone: the colors (codemap's, as
  red, green and blue: an editor has its own, a terminal's eight), a
  category's name and its size seen from afar, and what a map of
  several files asks of each (the occurrences of a name, the
  definitions, the references: `analysis`). So each highlighter has
  `lines`, and no `analyze`.
- **The tokens, not the tree.** The playground's OCaml and C
  highlighters make two passes: a guess from each token and its
  neighbours, then, over it, what a parse of the file says of each
  name (its scope: a parameter, a local, a field). Here the first
  pass only: `Parse_ml` and `Ast_ml` (1,338 lines) and `Parse_c` and
  `Ast_c` (1,013) are not copied. For OCaml the second pass is ix's
  own, `Names_ml` (123 lines): mini-ml's parser is asked, an item of
  the program at a time, and its tree says where a parameter, a local
  and a field are; an item that does not parse (the one being typed)
  keeps the guess. C's highlighter says a keyword, a type's keyword,
  a number, a string, a comment, a constant in capitals, and no more
  of a name.
- **What mini-ml and mini-lex have not**: the two lexers' polymorphic
  variants are a type (`lexed`), and `Highlight_ml`'s (`binder`); a
  comment of `Lexer_ml.mll` that quoted a comment's end says it in
  words.
- `Highlight_asm` still colors an operand that is one of the file's
  labels; `Highlight_st` still follows the bindings it followed.

## What remains in the playground

The two parsers and their trees (above); each highlighter's tests
(`Unit_highlight_ml`, `Unit_lexer_ml`, `Unit_highlight_c`, `Test_asm`,
`Unit_highlight_st`: 412 lines): here mini-emacs's sessions show each
language's colors (`editors/emacs/tests/keys.sh`).

## SSA's algorithms (ix's own)

The author, on factoring mini-ml's and mini-cc's `ssa/` (2026-10-29):
"maybe in lib_code/ ?", "which could be the basis for more program
analysis code reused by different tools (e.g., a linter in the futur,
a semgrep-like program, some phases before datalog, etc.)". Each
module works on numbers, the blocks 0 to n - 1 and the values, and
takes what a language's instructions are as functions:

| | what | used by |
|---|---|---|
| `Dominators` | the dominator tree (Cooper, Harvey and Kennedy), its children, the loops' depths | both `Ssa_build`s (the check), both `Alloc`s |
| `Braun` | SSA's construction: reads, writes, phis, sealing; the trivial phis out | both `Ssa_build`s |
| `Liveness` | liveness in SSA form, a phi's operand at its predecessor's end | both `Alloc`s |
| `Coloring` | the values chosen for registers by weight, the coloring walk in the dominator tree's order, with hints | both `Alloc`s |

What stays in each compiler: its instructions, what must live in
memory (mini-ml's collector, C's calls), what a use weighs, the code
emitted.

## Analyses in Datalog (`datalog/`)

What each rule file reads, every fact the compilers say, on toy programs:
[`datalog/FACTS.md`](datalog/FACTS.md).

The rules mini-datalog runs (the engine stays in `languages/datalog/`;
the author, 2026-10-31: "move the datalog analyses", "not the engine,
just the .dl"), toward what `plan_datalog.md` is for: static analysis
of ix's C and ML that finds its bugs, sophisticated and small, ML and
Datalog each for what it is best at, and read by students.

| | |
|---|---|
| `pointer.dl` | the author's, pfff's of 2014: Andersen's, field-based |
| `calls.dl` | who calls whom, what is never called, over `call_edge`: `andersen.dl`'s in mini-analyze, `pointer.dl`'s in `analyzers/ml/tests` |
| `bugs/pointers.dl` | three C bugs, over `points_to/`'s answers |
| `bugs/physeq.dl` | ML's `==` or `!=` with a side made in the comparison (`mini-analyze -bugs`; the first of `plan_bug_analyses.md`'s, each checked on a fix's code before and after it, `analyzers/tests/bugs/`) |
| `bugs/stack.dl` | ML's recursions the stack may not hold: a loop through a `try`, a frame a list's element (`-bugs`) |
| `bugs/raises.dl` | an ML external's `[@@raise E]` against what its primitive's C raises: C's facts and ML's in one program (`-bugs`, `tests/raises.sh`) |
| `bugs/swallowed.dl` | ML's errors of the system arriving at a `try` whose case answers a constant (`-bugs`, over `exceptions.dl`) |
| `dead.dl` | dead functions, globals, fields, constructors and statements, by `points_to/`'s call graph (`mini-analyze -dead`) |
| `capabilities_types.dl` | OCaml's check of the capabilities again: a test of the analysis, and a teaching one |
| `capabilities.dl` | whether ML's functions hold the capabilities they need, and no others (`mini-analyze -caps`) |
| `liveness.dl`, `liveness_ssa.dl`, `dominators.dl` | one function's dataflow, checked against the compilers' own |
| `points_to/` | the pointer analyses below, each file's header its history |

`points_to/` reads the same facts in a normal form
(`instructions.dl`), with a few more from the compilers: which function
names which variable, ML's blocks by site, what is a scalar
(`Facts.mli`, `Closure_facts.mli`):

| analysis | files | tells apart |
|---|---|---|
| Steensgaard's (1996) | `steensgaard.dl` | little: a copy unifies both sides |
| Andersen's (1994), by allocation site, fields by object | `andersen.dl` | `x.f` from `y.f`; the pre-analysis of the others |
| Doop's frame (2009): one set of rules, a context file | `contexts.dl` + one of: | |
| no context | `insensitive.dl` | Andersen's on what is reached |
| 1-call-site, 1-call-site+1-heap, 2-call-site+1-heap | `call1.dl`, `call1_heap1.dl`, `call2_heap1.dl` | callers of a function, through wrappers; a wrapper of `malloc` |
| 1-object, 2-object+1-heap (first argument's object) | `object1.dl`, `object2_heap1.dl` | what a function works on, at any depth |
| 2-type+1-heap (Smaragdakis, 2011) | `type2_heap1.dl` | objects by where they are made; no types in the facts yet, so C's function, ML's unit |
| hybrid (Kastrinis, 2013) | `hybrid.dl` | objects, and call sites where no object is |
| selective (introspective 2014, Zipper 2018) | `selective.dl` | 2-call-site only where Andersen's shows a function given two objects or handing out its own |

`datalog/tests/contexts.c` and `contexts.ml` ask, a question each,
what separates them; `contexts_c.out`, `contexts_ml.out` the answers,
read; `contained.out` that each answer is inside the coarser one's
(`run.sh`, in `make test`). `table.sh` is Doop's table for a program,
`real.sh` runs it on ix's.

What the facts force, each in `contexts.dl`'s header: a variable a
closure captures and a C variable whose address is taken have no
context (m-CFA's choice, not k-CFA's); an ML function of several
arguments is one frame; object sensitivity's receiver is the first
argument. Every value has an object (`scalar` at the least), so an empty
first argument means no run gets there; `tests/dynamic.sh -c` holds it to
that on `tests/hole.c`. What remains, in C: a call given what is read from a
global or a field never written, 0, is not followed by the object, type and
hybrid files.

### What they cost and give (`tests/real.sh`, 2026-10-31)

One core, by OCaml 4.14's build. `pt`: (variable, object) pairs, contexts
forgotten; `several`: calls with more than one target. `>150`: stopped.

| | mini-datalog, 101,863 facts | | | | rc (C), 15,026 facts | | |
|---|---:|---:|---:|---:|---:|---:|---:|
| | s | `pt` | edges | `several` | s | `pt` | edges |
| `andersen` | 22.4 | 1,223,579 | 13,124 | 200 | 0.3 | 26,077 | 1,270 |
| `insensitive` | 26.0 | 492,834 | 8,531 | 154 | 0.6 | 25,368 | 1,256 |
| `call1` | 45.9 | 441,334 | 8,041 | 154 | 3.9 | 25,354 | 1,256 |
| `call1_heap1` | 57.6 | 318,220 | 7,763 | 152 | 16.1 | 16,074 | 1,256 |
| `call2_heap1` | >150 | | | | >100 | | |
| `object1` | >150 | | | | 2.0 | 25,349 | 1,256 |
| `object2_heap1` | >150 | | | | 72.4 | 25,040 | 1,256 |
| `type2_heap1` | >150 | | | | 27.2 | 25,040 | 1,256 |
| `hybrid` | >150 | | | | 51.4 | 16,074 | 1,256 |
| `selective` | >150 | | | | 30.0 | 16,074 | 1,256 |

Read: reachability removes 60% of Andersen's pairs on ML, because it
leaves out what the program does not run; a heap context is what
removes the next quarter (rc: `call1_heap1` 37% fewer pairs than `call1`,
`hybrid` as many, `object2_heap1` not). The calls with several
targets hardly move (154 to 152): what they go through is not told
apart by a context (`ext`, the one place of arrays, exceptions and C;
a captured variable), so that, not longer contexts, is what to refine
next for ML. And on mini-datalog the richer files do not end in 150 s:
`-j`, or fewer contexts for scalars, is not tried. On a ten-line program
using `lib_core`, `object2_heap1` and `hybrid` take over 60 s where the
others take 2 s.

### Dead code (`mini-analyze -dead`, `dead.dl`)

The author: "flag dead functions (and dead code); some func might not be
called directly but called via pointer, but some are not called by anything
and should be flagged". From `main` and the toplevels, by `insensitive.dl`
without Andersen's first pass: 8 s on mini-datalog, its report read against
the sources:

| program | dead functions | through a pointer only | others |
|---|---:|---:|---|
| rc (goken's) | 1, `Xrdfn`: its comment says so, a stub a table names | 55 | the fields `changed`, `fnchanged`, written and read only by `plan9.c`, not in this build |
| mini-datalog | 14, 6 checked by grep; most of Prolog's and Prolog_read's API, which mini-prolog uses and this program does not | - | `Local`, matched and not built here |
| mini-forth | 0 | - | nothing |

A function is reported by why: nothing names it; only dead code does; or
live code takes its address and no call goes through it, which a grep would
have called used. What cannot be seen counts as alive: given to a C function
with no body, in ML's `ext`, or named by `-root` (`dead.dl`'s header).
`analyzers/tests/dead/` says each kind, and each thing that only looks dead.

### The sweep (`tests/sweep.sh`, `tests/triage.sh`, 2026-10-31)

Every program with a mkfile's `SRC`, by its own units and `-I`'s (`mk_units.sh`:
LIBI's, INCLUDES', LIBDIRS', a library's DIRS, the units made first): all 44
read whole (2026-11-03, mini-ml the longest, 71 s; 42 on 11-02 by the types'
heads, 35 before them, 23 on 10-31). A report is only of what is read: a unit
not read makes what it calls look dead, so `-dead` says `NOT READ` and fails on
a program partly read, as on a unit with no file (mini-squeak read without two:
415 dead functions; whole, 61).

| found in those 44 | |
|---|---:|
| dead functions, in the program that was read | 1,145 |
| of them, a name no other file writes (as `Unit.f` or by an alias, `module W = Unit`'s `W.f`), nor its own past its definition (`tests/dead_ix.txt`) | 43 |
| of them, a printer of `[@@deriving show]` no one calls (`Ast.pp_expr`): not written by hand, not in the list | 60 |
| named by another file of the same program, though "nothing names it": false by that test | 6, a type's name, a string's or a comment's (`Vt.cell`, `Index.first`, `Arm32.take`) |
| dead globals, fields, constructors, in the program | 106, 130, 108 |

Dead in a program is not dead in ix: a library's function another program uses
is dead in this one, so most of the 1,145 are to be read, not deleted (mini-emacs's
two builds and mini-csc's alone 480, by the libraries they share). Fields are
noisier: what a program writes by `Marshal` (`Asm`'s `s_items`) another reads.
`dead_ix.txt` is a list to read, not to delete by: its grep sees no `open`, and
tests and other programs not read may use what it lists. The aliases, since
2026-11-02, took out four (`St_interp.resume`, which `St_debug` calls as `I.resume`).

### Against real runs (`tests/dynamic.sh`, 2026-10-31)

Plan_datalog.md's decision 7c. A function that ran and that the call graph does
not reach is the analysis's mistake. `mini-5i -prof` says the addresses that ran,
the link's map their functions, `mini-where` (a link with `-g`) each one's unit
and first line, which is a `closure(F, Unit, Line)`. No emulator change.

| program, by mini-ml | runs (its own tests) | functions ran | reached by `insensitive.dl` | missed |
|---|---:|---:|---:|---:|
| mini-forth | 5 | 223 | 815 | 0 |
| mini-datalog | 12 | 351 | 1,253 | 0 |
| mini-rc | 45 | 362 | 1,202 | 0 |
| mini-prolog | 6 | 216 | 1,457 | 0 |
| mini-dc | 26 | 156 | 744 | 0 |

The check can fail: with calls through a local variable followed only for curried
stages (`RULES=` a broken copy), mini-forth's 223 give 212 missed. For C, by `-c`
on toy programs under every context file: `hole.c` missed `sink` and `target` under
object1, object2_heap1, type2_heap1 and hybrid, until the facts said what a constant
holds; now none. It is a one-way test: what ran is a part of what can run, so
reached and not run says nothing, and it speaks only for those workloads and for
the context file run (ML: `insensitive.dl`, the one `-dead` uses; the object files
do not end on these programs). A source edited after its object gives lines that
name another function: the script says so; run it on a clean copy of a tree others edit.

### The bugs on sharper answers (`bugs/pointers.dl`, `mini-analyze -context`, 2026-10-31)

mini-analyze's C report now reads `points_to/`, `call1_heap1.dl` unless told. On
`analyzers/tests/c/bugs/bugs.c`, 5 real bugs and two look-alikes, a string in the
same field of another object and a string given to a function that another caller
gives the heap:

| rules | reports | false |
|---|---:|---:|
| `pointer.dl` | 7 | 2 |
| `insensitive.dl`: fields by object | 6 | 1 |
| `call1_heap1.dl`: and a call site | 5 | 0 |

On real code it has changed nothing yet. rc's one report, `efree` given strings and
code arrays, stays under every context file, and is not a matter of contexts:
`codefree` frees only when `--cp[0].i` reaches 0, and a static table's count does
not. What keeps it safe is a value; a points-to set has none. Read with `-library`
(without it, what `main` does not reach is not looked at, and mini-ml's runtime is
called from ML): the runtime, libc's port and Linux files, singularity's, squeak's:
0 reports, of these three checks only. `kernels/lib_machine`, `kernels/9pi`'s C and
`debuggers/acid`'s stop on includes; they were not read.

### The right capabilities (`mini-analyze -caps`, `capabilities.dl`, 2026-11-01)

`Cap.mli`: a signature tells what a function may do "only if the code does not go
around it [...] That part is a convention", which xix checks with a Semgrep rule.
OCaml checks that a function holds what the functions it calls ask for; nothing
checks that what it asks for is what its body does. Here that is two sets: what it
holds, from its type (`< Cap.stdout; caps; .. >`, by `Resolve.capabilities`, aliases
and groups expanded, all objects still one type to `Typing`), and what it reaches,
a fixpoint over the call graph, with `requires(S, C)`, the table of what needs what.

```
editors/ed/CLI.ml:27: CLI.main: has < Cap.argv; ...; Cap.wait >, needs Cap.signal (Sys.set_signal), Cap.stdin (Unix.stdin)
utilities/calc/dc/Dc.ml:610: Dc.flush_out: has < Cap.exec; ...; Cap.wait >, may not need Cap.exec, Cap.fork, Cap.open_in, Cap.stdin, Cap.wait
shell/Eval.ml:31: Eval.print: no capability, needs Cap.stdout (Pervasives.print_string, Pervasives.stdout)
```

A function a line: what it holds, what is missing and by what, what it may hold for
nothing; the last line says which capabilities are missing most. A function answers
for what it names, called or passed on, not for what it calls through a parameter:
`List.iter print_int l` is its writer's, no other caller of `List.iter`'s. A
descriptor is a capability, so `Unix.read` is nothing here, `Unix.openfile` is.
`Cap.draw`, `keyboard`, `mouse` allow `Unix.openfile`, a device being a file.

`sweep.sh` with `FLAG=-caps`, on the 44 programs: 151 functions
(`tests/caps_ix.txt`; 172 before a record's capabilities were held, 149 on the
35 read on 11-02, 40 on the 23 before them).

| | functions | |
|---|---:|---|
| no capability | 50 | `Eval.print`, version_control's commands 11, `Tty_unix` 6; test programs' prints |
| holds some, not the one | 30 | `Sys.set_signal` in mini-rc's, mini-ed's, mini-mk's, mini-5i's mains; `Host.dir_of`'s `Unix.opendir` with no `Cap.readdir`; by a record's: version_control's `Fs.branch`, `Walk` (no `Cap.readdir`), mini-rc's `Eval.redirect` (no `Cap.stdout`) |
| holds one it may not need | 73 | mini-acid's `Proc` and `CLI` 16, awk's `Io` 7, hoc's `Eval` 6, `Dc` 6; of the 9 programs read since, 23, each given the program's whole `caps` (mini-ml's `CLI` 11, mini-cc's 3, mini-tiger's and mini-csc's `compile`, mini-asm's `data_items`) |

Of the 23 programs read first, those holding some were read at the source, but for
5 of dc's of one kind, of which one was; of the 12 read since, 2 (`Host.dir_of`,
mini-sql's prompt loop), the others not.

A capability in a record's field is held (2026-11-03, the author: "yes a record
field count as held, but in practice we should prefer to store capabilities via
parameters rather than big structures, but sometimes it's hard to do otherwise"):
`holds_field`, the fields' records gone into too. Of the 82 "no capability", 21 went
quiet, 11 became "not the one", the record holding others; "may not need" is not
asked of a record's, given for what else it has. What it does not say:
`Unix.openfile`'s flags are not read, so `Cap.open_in|Cap.open_out`;
the clock, a pipe have no capability in xix's `Cap`; `may not need` is not said of a
function that lets its capability go into a structure or a call through a parameter;
a function that names and never calls is reported.

### OCaml's check again, to test the analysis (`capabilities_types.dl`, `tests/caps_types.sh`, 2026-11-01)

The author: "the capabilities are checked by the OCaml 4.14 type checker, so we
should not redo too much", "it's like a deadcode analyzer [...] a great way to find
bugs in the analysis (call graph, use graph) and find blind spot". OCaml accepts ix,
so on any program a `mismatch` is this analysis's mistake: a test with no expected
output to write, on every program. A function hands on a capability it holds, the
function reached asks for that much or less: one rule, row polymorphism as a subset.

On `tests/caps_wrong/`, a program OCaml refuses and mini-ml takes: its 4 planted
errors, through a closure and a renamed variable, and none of the look-alikes. On
the 23 programs read: 422 calls that hand on a capability, 206 with both sides
known, 0 mismatches.

| found by it | |
|---|---|
| `Regex`'s `caps`, its groups' places, was taken as a capability | the name was the rule; now `Typing`'s type, the name only where the type says nothing |
| `needs` went inside `Thread.create`: `Source.reader` needed `Pervasives.exit` | an authority is said by its name, not gone into |
| `Unix._exit` in a forked child asked `Cap.exit` | `Cap.fork` allows it too |

What it says it cannot see: 216 of the 422, mostly a callee whose type names
nothing (`CapUnix`'s `< .. >`), or a caller whose capability has no written type,
as `Cap.main (fun caps -> ...)`; one in a field; and the calls in code no call
reaches, each counted. Where the callee names nothing, `by_need` asks what it needs
by `requires`: 21 reports, not mistakes of the analysis but wrappers doing more than
they say (`Source.reader`'s `Unix.kill`, `Procs.spawn`'s `Pervasives.stderr`): OCaml
does not see these, so this is not a count that must be 0.

### The big programs: types, not `ext` (2026-11-02)

Of the 9 programs too big or too slow, 7 now read, most in seconds: mini-emacs's two
(9 s, 8 s), mini-tiger 3 s, mini-dotnet 41 s, mini-csc 4 s, mini-datalog 4 s, mini-man
14 s; 42 of 44. mini-cc's `-dead` ends past the sweep's 180 s (217 s, 6.5 GB by
mini-datalog), mini-ml's past 900 s and 10.8 GB.

What it was, measured on mini-tiger's 118,832 facts (Andersen's, by mini-datalog):

| | s | GB | `pt` |
|---|---:|---:|---:|
| before | >200 | 8.8 | |
| `ext`'s 1,652 facts taken out | 36 | 1.3 | 1,445,401 |
| arrays as objects, `exn`, C's results their own (`Closure_facts`) | >200 | 8.5 | |
| and the types' heads (`vtype`, `htype`) | 5.9 | 0.25 | 559,338 |

Not `ext` but the polymorphic library: `List.rev_append`'s parameter, one for every
caller, held every list of the program (783 objects), and every caller's result
them all; a boxed `int64` was in 1,900 variables. `ext` taken out had only cut what
arrays held. A variable now holds an object only if their types' heads are the
same, or one is not known (`andersen.dl`'s design note): OCaml's types, a static
analysis already done, as Doop filters by Java's declared types.

Checked by real runs (`tests/dynamic.sh`): the first filter lost 96 of mini-forth's
223 functions that ran, `Pervasives.ref` written `ref` for `%makemutable`'s object,
so every ref's content was lost; the heads from the external's own type, 0 missed
on all five programs (mini-forth 818 reached, mini-datalog 1,626, mini-rc 1,206,
mini-prolog 1,458, mini-dc 748).

### mini-cc and mini-ml: an external, each call's (2026-11-03)

The two left were not what the types' heads missed. Profiled by mini-datalog
`-profile` on mini-cc's facts (`-dead`'s rules, `insensitive.dl`):

| | s | GB | `dead(F)`, lib_core's too |
|---|---:|---:|---:|
| the types' heads (mini-analyze's whole run; the others, the rules) | 217 | 6.5 | |
| and the whole types, where both have no variable (`vfull`, `hfull`) | 135 | 4.7 | 474 |
| contexts instead: `call1_heap1`, `call1_rec` | 403 | 14.8 | 474 |
| an external given as a value typed `->` (`(-.)` had no head: it was a list's cell) | 116 | 4.3 | 474 |
| an external given all its arguments, a copy at the call | 14.6 | 1.1 | 474 |
| a type compared only if it is known (below; the whole run) | 47 | 3.8 | 474 |

An external was one function for the whole program: `Obj.magic`'s and
`Array.get`'s `'a` result all that any caller had given, 306 of mini-cc's
functions returning the same 2,014 objects, and one `ref` object for all the
program's refs. No context helps a function that C or the compiler writes; a
copy at each call does it all, its objects that call's, of the type there (an
`int ref`, not `'a ref`). mini-ml 68 s and 3.8 GB, out of memory past 860 s
before.

Found by the sweep, not by `dynamic.sh` (whose five programs are not it): whole
types by name are wrong for a type abstract in an `.mli` and an abbreviation
inside (`Tui_turbo.mli`'s `type model`, `Turbo_model.model` inside), its two
names keeping apart one record, 183 of mini-turbopascal's functions called dead.
A type is compared now only if it has constructors, fields or a built-in name
(`analyzers/tests/dead/abstract`). And a value made an `Obj.t` (`Obj.repr f`)
goes to `raw`, where `dead.dl` takes a function as escaped: mini-dotnet's JIT
calls its call-outs by their address, reached before only by the one
`Obj.magic`. `dynamic.sh`: 0 missed on all five, fewer reached (mini-forth 686,
mini-datalog 1,499, mini-rc 1,048, mini-prolog 1,301, mini-dc 602).

mini-datalog reading a large file of facts overflowed the stack (fixed:
`Datalog.questions`'s `List.map`, `docs/plans/bugs/ix.md`).
