# Plan: analyses that would have found ix's past bugs (`lib_code/datalog/`, `analyzers/`)

The author (2026-11-03): "we recently added some analyzers/ to find bugs
in C or ML. Can you study the git history of this repo and your own
memory to study the bugs we had in the past in this repo, and the
bugfixes, and maybe design analysis (using datalog and the ml and cc
frontend in analyzers/) that would have found those bugs, and so can
then be used to find possibly other similar bugs."

The short answer: **ix's past bugs fall in a dozen classes. Five of
them are worth an analysis now: deep recursion, swallowed errors,
integers wider than arm's 31 bits, output that depends on a hash
table's order, and physical equality with a fresh value. They hold
about 60 of the bugs, and each needs at most one or two new facts. The
other classes are either cheap extensions of what `-dead` and `-exn`
already do (unread fields, more roots), or need what the engine does
not have yet (numbers, the order of statements), or were only ever
findable by running the code (hardware, timing).** Each analysis is
checked the same way: it must report the bug on the code as it was
before the fix (`git show FIX^:path`) and stay quiet on the fixed code.
Then it runs over ix through the sweep, as `-dead`, `-caps` and `-exn` do.

**Status: A6's first half done (2026-11-03), the rest planned.**
`mini-analyze -bugs` and `physeq.dl`: `==` or `!=` with a side made in
the comparison. It reports eb5378a5's bug on the code before the fix
(`analyzers/tests/bugs/eb5378a5/`) and nothing in today's ix (the sweep
of the 44 programs, 13 s; a grep of the whole tree, apps and browsers
too, finds no other case). A7 turned out to be `-dead`'s already (below).
The evidence is in
[`bugs/history/`](bugs/history/): `from_git.md` has 73 bug fixes found in
`git log`, with their commits, about 25 of them read diff by diff.
`from_docs.md` has about 280 rows read from `bugs/*.md`. Both were made
by two subagents and are not checked row by row. Ten of the commits they
cite were checked against `git log`, and the bugs this plan relies on
were read in their diffs: 021c562b, e92ae1ec, eb5378a5, 62d811be,
c5086383, d22c56e4.

## What there is

| | finds | over |
|---|---|---|
| `-dead` (`dead.dl`) | functions no run reaches, dead code after a jump, fields stored and never read (`dead_field`) | the call graph from `points_to/` |
| `-caps` (`capabilities.dl`) | a function reaching a system call without the capability | the same, plus `takes_cap`, `declares`, `holds_field` |
| `-exn` (`exceptions.dl`) | the exceptions a toplevel may let escape | the same, plus `raise_*`, `catches*`, `in_try` |
| `bugs.dl` (C) | `free` given what is not the heap's, a returned local's address, a call through a pointer that is never set | Andersen's `pts` |
| `-flow` | liveness, dominators | one function's SSA (ML) or stack code (C) |

The real bugs these analyses have found so far: one, awk's `Next_file`,
uncaught in END (89e79b5e), from the `-exn` sweep. `-caps` found gaps
(`Fs.branch`, `Eval.redirect`), but none of them led to a fix. The
analyses were built to answer questions about the code (what is dead,
which capability, which exception), not from the bugs ix actually had.
This plan starts from the bugs.

## The bugs, by class

Counted in `bugs/history/` (the two files overlap; a bug may be in two
classes):

| class | git | docs | examples | findable by |
|---|---:|---:|---|---|
| deep recursion: a non-tail call over input, a call in a `try`, small stacks | 10 | 17 | 021c562b `Devmnt.rpc`'s `wait` in a handler; f46346db `Css_syntax.components`; 2fe7e116 `&&`; `Hashtbl.remove` down a bucket | call graph plus a tail-call fact (**A1**) |
| exceptions uncaught, or swallowed by `with _ ->` | 9 | 21 | 89e79b5e; c5086383 rc's child `with _ -> 1`; 4f00134c `with Unix_error _ -> ()` on /env; the kernel's fault handler to `guard` | `-exn` plus roots (**A2**), a trivial handler plus what `arrives` (**A3**) |
| ints wider than 31 bits on arm, sign, overflow | 11 | 19 | e92ae1ec Sha1's `0xffffffff`; d47f0829 `land 0x7fffffff` then `mod`, a negative `List.nth`; 7f15c58f a guard that wraps | literals and shifts per target, then intervals (**A4**) |
| output that depends on `Hashtbl`'s order or on `Marshal`'s sharing | 7 | 9 | d22c56e4 Unbox; 410d04a2; ca664887 `Asm.save` | taint to an output, `List.sort` cleans it (**A5**) |
| `==` and `!=` against a fresh value, identity of what is mutated | 6 | 5 | eb5378a5 `!drawn != Some !model` | points-to (**A6**) |
| an encoder or a back end dropping a field | | 14 | mini-asm's register index never read by `Arm64.aclass`; `sys_open` ignoring its flags | `dead_field` for ML too (**A7**) |
| races: signal handlers, threads, forked jobs | 9 | 13 | TinyMachine's ^C lost; `Event.sync`'s one `Condition.wait` | handler and thread roots, shared writes (**A8**) |
| resources and counts not given back on some path | 6 | 8 | 62d811be dup's `o != c`; 15f1a021, f7b1aef0, 35a236d8 | needs the order: SSA facts with calls (**A9**) |
| initialization and link order, two units of one name | 4 | 8 | Poly1305 reading `Bignum.base_bits` first; two `Collide` linked | toplevel reads plus link order (**A10**) |
| layout and evaluation order | 4 | 6 | b9fea684 `else a; match`; 56934c32 `f a @ concat_map f l` | the tree with columns, purity (**A11**) |
| quadratic algorithms | 6 | 22 | `List.assoc` in a loop, `^` accumulating | a lint; not a correctness bug, not here |
| differences from OCaml/C, hardware, emulator, timing, plain logic | ~22 | ~90 | the compiler's own bugs; device registers | differential tests, `tests/modern/`, the boards: not static |

About half the bugs are in the last two rows. No analysis here would
have found them, and none is proposed.

## The analyses

Each one lists: the bugs it re-finds, the facts it reads (existing or
new), the rules, the false reports to expect, and the cost in lines.
The order is by bugs re-found per line of code.

### A1. Deep recursion (`stack.dl`)

**Re-finds:** 021c562b, both overruns: `wait` calling itself inside a
handler, and `Hashtbl.remove` reached from kernel code. Also f46346db,
`Lexer_asm.preprocess`, `Datalog.questions` (non-tail recursion over
the lines or tokens of a file), and 2fe7e116 (see the check below).

**New facts** (`Closure_facts`, about 30 lines):
- `tail(I)`: call I is in tail position *as mini-ml compiles it*, so not
  inside a `try`'s body or its handler (mini-ml compiles a `try` as a
  function of its own).
- `in_handler(I, T)`: like `in_try`, but for the handler.
- `rec_over(F, P)`: F's parameter P has a list, string or array type
  (from `vtype`).

**Rules** (about 25 lines): a function's strongly connected component,
from `reach`; a call inside the component that is not `tail` gives
`deep(F, I)`. These are ranked: first a call in a handler (no tail call
by mini-ml, and OCaml programmers do not expect that), then recursion
over a parameter found in `rec_over`. For the kernel, a second root
set: what `kernels/9pi` reaches from its system calls and its traps.
There, a call of a library function known to recurse once per element
(a file of facts, `deep_lib('List.map')`, `deep_lib('Hashtbl.remove')`,
since ocaml-light's `Hashtbl` is recursive in a bucket's length) is
reported too, because the stack is only 16 KB.

**Check:** `analyzers/tests/bugs/021c562b/`, with Devmnt's `rpc`
before 021c562b and after it. The compiler's own tail calls are
compared with `tail(I)`, as `-dflow` compares liveness: with the old
`Lower.app`, `&&`'s right operand would have been `tail` in the facts
and not in mini-ml's code. That is the 2fe7e116 bug, found by checking
the compiler against the facts rather than by checking the program.

**False reports:** recursion over a tree (an AST's depth is small), and
over lists that are short by construction. The ranking puts handlers
and the kernel first. A `[@tail_ok]`-style comment is not proposed;
read the list first.

### A2. Exceptions: more roots, the primitives' (`exceptions.dl`)

**Re-finds:** the fault handler's out-of-memory reaching `guard` (it
panics); 2ec2c2a1's `Failure "usage"` from 21 mains (only partly,
since `-exn` already looks at toplevels); d47f0829's `List.nth` (with
A4).

**New:** roots besides the toplevels. These are the kernel's `guard`
(an exception arriving there is a panic), the functions given to
`Thread.create`, and the handlers given to `Sys.signal`. `Closure_facts`
already sends what `thread_new` and `ml_signal` keep to `ext`; it would
also say `root_of(F, thread)`. The exceptions of the primitives
(`Invalid_argument` from `%array_safe_get`, `String.sub`, `List.nth`)
go in as `raise_of` facts at the call (`prim_body` is where). This is
what exceptions.dl's header lists as "not here".

**Cost:** about 20 lines of facts and 5 of rules. The `Invalid_argument`
ones will be many. Report them only on paths where the index comes from
the outside, which needs A4, or leave them behind a switch.

### A3. Errors swallowed (`swallowed.dl`, in `-exn`)

**Re-finds:** c5086383 (`try f () with _ -> 1` in rc's forked child),
4f00134c (`with Unix_error _ -> ()` around a write to /env), and
7f7ce094 (a fork's `Unix_error` swallowed by the former).

**New fact:** `trivial_handler(T)`: a case of T that does not name what
it caught and returns a constant (`()`, `1`, `None`, `[]`). Around
10 lines in `Closure_facts`, where `catches_all` is said.

**Rule**, which is why this goes beyond grep: a grep for
`with _ -> ()` finds 973 lines in ix. The rule joins
`trivial_handler(T)` with `exceptions.dl`'s `arrives(T, _, _, E)` and
reports only when what may arrive is an error of the system or of the
program (`Unix_error`, `Sys_error`, `Failure`, `Invalid_argument`,
`Not_found` from somewhere other than the try's own body's first call).
An `End_of_file` or `Exit` arriving at a `with _ -> ()` is the usual
way to stop a loop and is not reported.

**Cost:** about 15 lines of rules. It reuses `-exn`'s whole fixpoint.

### A4. Ints on 31 bits (`intwidth.dl`)

**Re-finds:** e92ae1ec (Sha1's `let mask = 0xffffffff`, seen in the
diff's parent); Zlib's CRC and Adler; Chacha20; 6a649689, 7a8c6af7,
cc6eb618 (`lsl 16 lor`, `0x80000000`); 7f15c58f (`2*n+1 < 256`
wrapping); d47f0829 (a mask keeping the sign bit, then `mod`, then
`List.nth`).

**Two steps:**
1. **Syntactic, now.** The facts `int_lit(V, Big)` for a literal above
   `max_int` on 31 bits, and `shift(V, X, K)` for `lsl` by a constant,
   both with their unit. Every unit is taken to run on the Pi 1 too
   (Decisions, below), but those named in a file as 64-bit only,
   `wide_unit(U)` (`kernels/lib_machine/pi4/`, `raspberry/`,
   `machine/`). Report a big literal
   or a shift past bit 30 in any other unit. Two hits of today
   show what must be excused:
   - `Poly1305.mac_limbs`: 32-bit masks and `f lsr 32`, but `mac` calls
     it only when `Sys.int_size >= 63`. A call guarded by that test is a
     fact, `wide_only(F)`, and such a function is not reported.
   - `Delta`'s gear hash: a table of 32-bit constants, but the hash is
     only tested by `land 0xff`, and the low bits are the same on
     31 bits. A value whose only use is a mask below 2^30 is not
     reported. This needs SSA's `use`, so it comes in step 2.

   One to check by hand: `Dbm.key_of`'s `n land 0xffffffff`, which on 31
   bits keeps a negative key negative where chidb's cast makes it
   unsigned.
2. **Intervals, later.** A value's range over the SSA of `-flow`, by
   abstract interpretation in ML (`Ssa_facts` writing `range(V, Lo, Hi)`).
   Datalog cannot compute this until plan_datalog.md's stage 3 gives it
   numbers. It finds the sign that d47f0829's `mod` kept and the guard
   that 7f15c58f wrapped.

**Cost:** step 1 is about 40 lines of facts (the literal, the shift,
the file of 64-bit units) and 15 of rules. Step 2 is some 200 lines
of ML.

### A5. Output in a hash table's order (`order.dl`)

**Re-finds:** d22c56e4 (the Unbox pass's boxes in `Hashtbl` order),
410d04a2, 423d5e76, `ssa/Alloc`, mini-cc `-O`, `Typing.places`, tiny-ml's
interfaces; ca664887 (`Marshal` without `No_sharing` in `Asm.save`).
Each broke ix's fixed points: the same input gave different bytes
depending on which compiler built the tool.

**Rules:** taint over Andersen's `pts`, which no rule does yet:
- **Sources:** what a closure given to `Hashtbl.iter` or `fold` stores
  or returns. These are its `return` and its stores, found through
  `argument` at a call to those functions.
- **Propagation:** `copy`, `load`, `store`, and an accumulator's list
  cells.
- **Cleaned:** the objects `List.sort` (and `sort_uniq`, `Array.sort`)
  makes or reorders.
- **Sinks:** `output_string`, `Buffer.add_*` reached by the program's
  writers, `Marshal.to_*`.

**False reports:** an order that does not matter (a sum, a set rebuilt).
The sinks are limited to the tools whose output ix compares
(the toolchain, tiny-ml, typesetting), named in a file.

**Cost:** about 30 lines of rules. `Marshal` without `No_sharing` is one
fact on the call's arguments.

### A6. Physical equality (`physeq.dl`)

**Re-finds:** eb5378a5, both halves: `!drawn != Some !model` is always
true, since `Some` makes a new block; and mini-emacs's model, changed in
place, so a cache comparing it by `!=` never saw it change. Also
fbfc0317 and 282b689b.

**Done, the first half** (2026-11-03). The facts: `phys_compare(I, F, Op)`
for each `==` and `!=` and the function it is in, and
`fresh_operand(I, What)` for a side made there (a constructor applied, a
tuple, a record, an array, a string or a float written there). What is
fresh is read off the tree by `Closure_facts.fresh`, not by `pts`: a
temporary that a block is made into cannot be told from a `let`'s
variable in the facts, and `let x = Some 1 in x == x` is no bug. The
rule, `always(I, F, Op, What)`, is a join of the two; 25 lines of facts,
one rule, 25 lines of report (`Bugs_report`). Test:
`analyzers/tests/bugs/eb5378a5/`, Before.ml reported, After.ml not, nor
`l == []`, `o != None`. Today's ix: nothing.

**Not done, the second half:** `identity_key(I, S)`: X may point to S,
and S is changed in place somewhere (a field set, not a block's
initialization, which the facts do not tell apart yet: a fact
`mutates(V, Fld)` for `<-`, `:=` and `.() <-`). Comparing by identity
then misses the change: mini-emacs's model behind a cache. This needs
`pts`, so `-bugs` would then run the pointer analysis (its cost, as
`-dead`'s).

### A7. A field that nothing reads, for ML too (`dead.dl`)

**Meant to re-find:** `from_docs.md`'s class 8. mini-asm parsed a
register index into a field that `Arm64.aclass` never read. `sys_open`
ignored its flags. mini-ld kept no line for a reference, so it reported
line 0.

**Found when starting it (2026-11-03): this is `-dead`'s already.**
`dead.dl`'s `dead_field` is over `store` and `load` of both languages,
and `Dead_report` says ML's fields (`dead field: x stored in F`). And
it could not have found the register index: a field is by its name,
whatever the program, and `index` is read by the arm 32 encoder
(`linker/Arm.ml`'s `aclass`, a `Mem { index = Some _ }`), only not by
arm64's. The bug is a field one consumer of two ignores, which needs
the consumers named (`Arm64.aclass` against `Arm.aclass`): not a rule
for now. What is left is `unused_param(F, N)`, a parameter nothing reads
in a function reached; but the facts say no read of a value used only
by arithmetic (`n + 1` writes nothing of `n`), so it needs the
`-flow` facts' `use`, whose names are SSA's, not `Closure_facts`'. Put
after the others.

### A8. Races with handlers and threads (`races.dl`)

**Re-finds:** TinyMachine's console queue, changed by the signal handler
while the main loop replaced it; `Event.sync` waiting once, not in a
`while`; mini-mk's jobs sharing `/env` (only partly: that one was a
system call's flag).

**Rules:** A2's roots, read as threads. A global's object written from
one root and read or written from another, in a function that takes no
`Mutex.lock` (a coarse lockset: Eraser's, Savage and others, 1997, made
static). And `Condition.wait` not inside a `while` (a check of the
tree). Today all of ix's `Condition.wait` calls are inside a `while`
(Map_worker, Js_coroutine, Tab_worker), so this rule would report
nothing now and only prevents regressions.

**Cost:** about 20 lines of rules, and 5 of facts for `while`.

### A9. Resources and counts on every path (`pairs.dl`, flow)

**Re-finds:** 62d811be (`dup(1, 1)`: a reference taken, then the old
chan closed only `if o != c`, one count too many, and the pipe never
closed), 15f1a021, f7b1aef0, 35a236d8.

**This needs the order of statements:** `-flow`'s SSA facts with the
callee of each call (`call_at(P, F)`, which `Ssa_facts` does not say
today) and the edges of an exception. Then a typestate check: from an
`acquire` (`open_in`, `incref`, `Mutex.lock`: pairs named in a file of
facts), every path to the function's exit goes through its `release`,
or returns the thing. 62d811be's bug is path-sensitive: the release
depends on `o != c`. The rule reports the path where it is skipped, and
someone has to judge whether that path is legitimate. This is
bugs.dl's "use after free needs the order", and Engler's checkers'
shape.

**Cost:** about 40 lines of facts and 30 of rules. Later than A1 to A7.

### A10. Toplevel initialization and link order (`init.dl`)

**Re-finds:** Poly1305's toplevel reading `Bignum.base_bits` before
`Bignum` was initialized (the program looped); two units named `Collide`
linked into one program (a segmentation fault); tiny-ml exporting the
first of two toplevel definitions of the same name.

**Facts:** `global_def(G, 'M:init')` exists. Reads by a toplevel's code
come from `var_in`. The link order, `link(Prog, Unit, N)`, comes from the
mkfiles or the linker's command.

**Rule:** M's init reaches a read of a global defined by N's init, and N
comes after M. Two units of one name in one `link`.

**Cost:** about 15 lines, plus reading the link lines.

### A11. Layout and evaluation order (a lint over the tree)

b9fea684 (`if ... then (...) else a; match ...`, which ran the program
twice) needs the columns. That is a check of mini-ml's parsed tree in
ML, not Datalog: a `;` after an `else` branch whose next line is
indented as the branch. 56934c32 (`f a @ concat_map f l` evaluates its
right side first) needs to know what writes: purity, plan_datalog.md's
stage 11, as `writes(F, Object)`. Then it is an operator whose two
sides both call something that writes.

**Cost:** about 40 lines of ML for the layout check. Purity is a stage
of its own.

## C

The C bugs are mostly hardware (device registers, the boards, the
emulator's differences) and goken's, which is outside ix. For ix's own
C (mini-ml's runtime, the kernels' C, lib_core's libc), the classes that
apply are A1 (the runtime's statics corrupted by f46346db's depth: a
guard page, not an analysis), A9 (counts and locks), and unchecked
lengths (plan_datalog.md's stage 10, taint: `argptr`, `copyin`). The
existing `bugs.dl` stays as it is. Taint is the next step for C, after
A9's flow facts exist for both languages.

## The method: each analysis against its history

`analyzers/tests/bugs/<commit>/` holds two units, `Before.ml` and
`After.ml`, the smallest extract of the code before the fix and after
it, with the commit named in its first comment. Each is cut down until
it parses alone, and the two are read as one program by `-bugs`.
`analyzers/tests/run.sh` compares the report with `expected.out`, which
has `Before.ml`'s lines and none of `After.ml`'s (a look-alike that must
stay quiet goes in `After.ml` too). A false report
that a later change removes is a regression too. This is the test of a
rule and also its documentation: a student reads the bug, the rule, and
the commit.

Then the sweep (`tests/sweep.sh FLAG=-bugs`) over the 44 programs
gives one list, `bugs_ix.txt`, each line naming its analysis, triaged
like `dead_ix.txt`.
Each report is read and marked real, harmless, or false. A false report
is a test to add, and a real one goes in `bugs/ix.md` with its
reproduction.

## Order

| # | analysis | new facts | lines (est.) | bugs re-found | first |
|---|---|---|---:|---:|---|
| 1 | A6 physical equality, a side made there | `phys_compare`, `fresh_operand` | 50 | 1 | done |
| 2 | A6, identity of what is changed in place | `mutates` | 20 | ~3 | `-bugs` then runs `pts` |
| 3 | A1 deep recursion | `tail`, `in_handler`, `rec_over` | 55 | ~15 | the kernel's 16 KB |
| 4 | A3 errors swallowed | `trivial_handler` | 25 | ~8 | over `-exn` |
| 5 | A2 roots and primitives | `root_of`, primitive `raise_of` | 25 | ~5 | A8 uses its roots |
| 6 | A4 31 bits, step 1 | `int_lit`, `shift`, `wide_unit`, `wide_only` | 55 | ~12 | |
| 7 | A5 output order | sinks file | 30 | ~10 | the fixed points |
| 8 | A10 init and link order | `link` | 15 | ~3 | |
| 9 | A8 races | `while` | 25 | ~3 | |
| 10 | A9 pairs on every path | `call_at`, exception edges | 70 | ~5 | flow facts |
| 11 | A4 step 2, intervals | `range` (ML) | 200 | ~5 | after numbers in Datalog |
| 12 | A11 layout, evaluation order | columns, purity | 40+ | ~3 | |
| 13 | A7 unused parameters (fields: `-dead`'s) | SSA `use` joined | 20 | ~2 | |

These estimates come from reading the existing rule files (`bugs.dl` is
53 lines and `exceptions.dl` 100) and are not measured. The counts of
bugs re-found are the history files' and are checked by the history
tests as each analysis is written.

## Decisions

- **One switch, `mini-analyze -bugs`** (the author, 2026-11-03: "a
  single -bugs would be more practical for the user for now"). It runs
  every analysis written so far over one `points_to/` fixpoint, which
  is the cost, and each report line names its analysis
  (`bug? Devmnt.ml:78: deep: wait calls itself in a handler`). The
  existing `-dead`, `-caps` and `-exn` stay as they are.
- **The catalogues stay as they are** for now (the author: "the
  catalogue can stay like this for now").

- **A4's code is all of ix, on 31 bits** (the author: "assume all of it
  should run both on pi1 and pi4. what is in lib_machine/pi4 is meant
  only for pi4 I think"). No mkfile is read: every unit is taken to run
  on the Pi 1 too, except those named in a file of the units meant for
  64 bits only: `kernels/lib_machine/pi4/`, and for now `raspberry/`
  (mini-qemu) and `machine/` (mini-5i, mini-7i), which run on the
  author's arm64 machine (the author: "let's skip raspberry/ too then
  and machine/ for now since yes we are mostly running this code from
  this machine (an arm64)"). So `raspberry/boards/Pi4.ml`'s 29 literals
  are not reported.

## Open questions

- **Tests from history and the 80 columns**: an extract keeps the code
  as it was, long lines included.
