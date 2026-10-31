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

The rules mini-datalog runs (the engine stays in `languages/datalog/`;
the author, 2026-10-31: "move the datalog analyses", "not the engine,
just the .dl"), toward what `plan_datalog.md` is for: static analysis
of ix's C and ML that finds its bugs, sophisticated and small, ML and
Datalog each for what it is best at, and read by students.

| | |
|---|---|
| `pointer.dl` | the author's, pfff's of 2014: Andersen's, field-based |
| `calls.dl`, `bugs.dl` | who calls whom, what is never called; three C bugs, over `pointer.dl`'s answers |
| `dead.dl` | dead functions, globals, fields, constructors and statements, by `points_to/`'s call graph (`mini-analyze -dead`) |
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

Every program with a mkfile's `SRC`, by its own units and `-I`'s: 23 of 44
read whole. A report is only of those: a unit not read makes what it calls
look dead, so the others say `NOT READ`, and `-dead` fails on them. Not read:
mini-ml and mini-cc (past 180 s), mini-emacs, mini-tiger and mini-csc (past
180 s or 12 GB), and programs whose units share a name with another's (`Ast`,
`Symbols`), or need files `sweep.sh` does not find; mini-oberon and mini-squeak
compute their `SRC`.

| found in those 23 | |
|---|---:|
| dead functions, in the program that was read | 236 |
| of them, a name no other file writes, nor its own past its definition (`tests/dead_ix.txt`) | 40 |
| named by another file of the same program, though "nothing names it": false by that test | 0 |
| dead globals, fields, constructors, in the program | 12, 37, 26 |

Dead in a program is not dead in ix: a library's function another program uses
is dead in this one, so 196 of the 236 are to be read, not deleted. Fields are
noisier: what a program writes by `Marshal` (`Asm`'s `s_items`) another reads.
`dead_ix.txt` is a list to read, not to delete by: its grep sees no `open`, and
tests and other programs not read may use what it lists.

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
