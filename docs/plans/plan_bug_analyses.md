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

**Status: A6's first half, A1, A3 and A2's primitives done (2026-11-03), the rest planned.**
`mini-analyze -bugs` runs `bugs/physeq.dl` (`==` or `!=` with a side
made in the comparison), `bugs/stack.dl` (a loop through a `try`, a
frame a list's element) and `bugs/swallowed.dl` (an error of the
system silenced). Each reports its bugs on the code before the fix and
not after (`analyzers/tests/bugs/`: eb5378a5, 021c562b, f46346db,
c5086383, 4f00134c). On today's ix, `physeq` finds nothing; `stack`
gives 145 reports on the 44 programs and 9 on the kernel, `swallowed`
12 on the programs (`lib_code/datalog/tests/bugs_ix.txt`), read in A1
and A3 below. A7 turned out to be
`-dead`'s already (below).
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
| `bugs/pointers.dl` (C) | `free` given what is not the heap's, a returned local's address, a call through a pointer that is never set | Andersen's `pts` |
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

### A1. Deep recursion (`bugs/stack.dl`)

**Done** (2026-11-03), as `stack` in `-bugs`. It re-finds 021c562b,
both overruns: `wait` calling itself in a handler, and `Hashtbl.remove`
going down a bucket a call a binding (lib_core's `remove_bucket`, still
so, and `replace_bucket`, `insert_bucket`: reported on lib_core's own
`Hashtbl.ml` by `-library`). It also re-finds f46346db
(`Css_syntax.components`, a call a token).

**The facts** (`Closure_facts`, about 45 lines):
- `tail(I)`: call I is a tail call *as mini-ml compiles it*: its result
  is the function's, with no `try` around it (mini-ml compiles a `try`
  as a function of its own, so neither its body nor its handler makes a
  tail call).
- `tail_but_try(I)`: I would be a tail call if not for a `try` around it.
- `in_handler(I, T)`: like `in_try`, but for the handler.
- `list_like(T)`: a variant one of whose constructors holds one value
  of the type itself and none two: a list of its own (Hashtbl's
  `bucketlist`), not a tree.
- `&&` and `||` are no longer an external's two arguments: the right
  operand's value is the result, so a call there is a tail call
  (mini-ml's `Lower` since 2fe7e116).

The plan's `rec_over` (a string or an array walked by an index) was
not written: in the history that shape was the compiler's bug (2fe7e116),
not the program's.

**The rules** (`bugs/stack.dl`, 20 lines). A call I in F is `recursive` if
its target is F, or a function of F's unit that calls back to F (the
closure of the calls is per unit: small, but a recursion through two
units is not found), and F is reached. Two reports:
- `in_try_rec`: the call is `tail_but_try`, in a try's body or handler.
  It is a loop as written, through a try. Requiring that the call's
  result is the function's own leaves out an interpreter walking its
  tree through a try (awk's `exec`), which is as deep as the tree.
- `on_list`: the call is no tail call, F (or an earlier stage of F,
  `let rec f l x`) takes a list or a `list_like`, and *no* call of F
  back to F is a tail call. That last condition tells f46346db's bug
  from its fix: the fixed `go` loops by a tail call along a level and
  calls back only for a bracket's inside, as deep as the nesting.

**On ix** (the sweep of the 44 programs, 1 min; the kernel by hand from
`kernels/9pi/mkfile`'s `KML`, 4 s): 145 reports in the programs, 9 in
the kernel, all in `lib_code/datalog/tests/bugs_ix.txt`.
- **In a try, 8.** `machine/CLI.ml`'s `go` calls itself in a handler
  at each breakpoint (a frame each, mini-5i built by mini-ml), and `run`
  calls itself at each `exec`. git's `dial` loops over the few addresses
  of a host. The kernel's `Kchan.step` loops over a union's members.
  These are bounded and harmless. awk's `exec` and `loop_body` are its
  tree. acid's `exited` is a closure the analysis merges with others: a
  false report.
- **Over a list, 137.** These are the f46346db shape: a frame for each
  element. mini-cc's peephole passes (`languages/c/opti/Opti.ml`'s
  `imm`, `incs`, `puts`, `branch`: an instruction each, as long as a C
  function), mini-ml's `Opti`, the IL emitters, git's `Diff.take` (a
  line of a file each), `Texts.split`. Whether a list can be long
  enough is not known from the code. None is a known crash; they are
  where to look when a long input dies. Not triaged one by one.

**Not done:**
- The check of the compiler against the facts, which would have found
  2fe7e116: mini-ml's own tail calls (`Ir.Call`'s flag, `Ssa.Tail`)
  against `tail(I)`, as `-dflow` compares liveness. It needs a call's
  line in the SSA's facts.
- Recursion through two units.
- A string or an array walked by an index.

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

**Done with A3** (2026-11-03): the primitives that raise `Sys_error`,
a raise at their call. Each external says it where it is declared,
`external remove : string -> unit = "sys_remove" [@@raise Sys_error]`
(mini-ml's parser keeps it in `Annotations.raises`; OCaml ignores it),
11 in lib_core's Pervasives, Sys, Filename: the rest of A2's
primitives (`Invalid_argument`, `Division_by_zero`) are more
attributes, no list in the analysis. `-exn` sees
them too: 12 programs' toplevels may now let `Sys_error` escape, a
lib_core exception that `exn_ix.txt` leaves out; nothing else changed.

**The annotations checked against the C** (2026-11-03; the author: "it
would be interesting to check those @@raise annotations are correct
via an analyzer itself since we can also analyze the C code"):
`bugs/raises.dl`, run by `mini-analyze -bugs` given C files and ML
ones, the facts of both front ends in one program. The names meet
without a table: a primitive's C function is its name (`sys_open`), and
the exception the C raises is the global the ML facts already name it
by (`caml_exn_Sys_error`). A C raise is a call of `raise_with` or
`raise_const` (or of a wrapper passing its argument on), with
`failwith`'s `Failure` and the callers' following by the call graph;
`ml_raise_c(bound_exn)` is a one-line model. Two reports:
`undeclared` (the C may raise E, the external does not say it) and
`overdeclared` (it says E, the C never raises it). 15 lines of rules,
10 of facts, 25 of report. Test: `analyzers/tests/raises/prims/` (said
right, through `failwith`, not said, through a wrapper, said wrong).
On the runtime and lib_core, 0.6 s (`lib_code/datalog/tests/raises.sh`,
a make test job, against `raises_ix.txt`): the 11 `[@@raise
Sys_error]` all backed by the C, none wrong; 25 externals that do not
say what their C raises, what -exn has never seen: `int_of_string`,
`float_of_string` and the `of_string`s' `Failure`, `Sys.getenv`'s
`Not_found`, `compare`'s `Invalid_argument` (a functional value),
`Int32`/`Int64` `div`/`rem`'s `Division_by_zero`, `Array.make`'s and
`Bytes.create`'s `Invalid_argument`, `input_binary_int`'s and
`Digest.channel`'s `End_of_file`, `Thread.thread_new`'s `Failure`.
Some are the call graph's only: `Sys.readdir`'s `Invalid_argument` is
an allocation's of a size that cannot be negative there. Not yet
added: adding them is the rest of A2, and changes `-exn`'s answers.

**The primitives' exceptions said** (2026-11-03, the rest of A2's
primitives): the 23 others annotated where they are declared, 39 lines
of lib_core (a `.ml`'s and its `.mli`'s). `raises_ix.txt` now 2, the
call graph's false ones: `Sys.get_argv` and `Sys.readdir` call
`make_vect` with `argc` and a count checked `>= 0`, a size never
negative; not annotated, a wrong `[@@raise]` would be a lie to `-exn`.
The sweeps of the 44 programs, before and after: `-bugs` the same;
`-exn` the same for each program's own exceptions (`exn_ix.txt`
unchanged), more toplevels and sites for lib_core's: `Invalid_argument`
118 lines to 165 (`compare`, `String.make`, `Hashtbl.create`, ...),
`Failure` 73 to 79, `Division_by_zero` 2 to 8, `End_of_file` 1 to 2.

**Cost:** about 20 lines of facts and 5 of rules. The `Invalid_argument`
ones will be many. Report them only on paths where the index comes from
the outside, which needs A4, or leave them behind a switch.

### A3. Errors swallowed (`bugs/swallowed.dl`)

**Done** (2026-11-03), as `swallowed` in `-bugs`, not in `-exn` (the
one switch). It re-finds c5086383 (`try f () with _ -> 1` in rc's
forked child, a pipe's open failing) and 4f00134c (`with Unix_error _
-> ()` around a write to /env). 7f7ce094 (a fork's `Unix_error` in the
same child) is the same try, found by the same report.

**The facts** (`Closure_facts`, about 30 lines):
- `silent(T, E)`, `silent_all(T)`: a case of T (no guard) that catches
  E, or everything, and answers `()` or a number: nothing of what it
  caught is used, so the pattern needs no look. `None`, `false`, `[]`
  are left out: `try Some (stat f) with Unix_error _ -> None` asks a
  question, the answer the caller's (24 of the first sweep's 45). A
  case that names what the exception holds (`Unix_error (EINTR, _,
  _)`) is a choice, not silent.
- The runtime's primitives that raise `Sys_error` (`sys_open`,
  `sys_remove`, ...: `raise_with` in `languages/ml/runtime/`), their
  externals marked `[@@raise Sys_error]` (A2 above), are a
  raise at their call (`raise_of`, and `primitive(I, P)` naming it).
  That is A2's primitives, the part A3 needed: without it no
  `Sys_error` arrives anywhere, `open_in` failing in C. `Unix_error`
  needs nothing: lib_core's `Unix` raises it in ML.

**The rules** (`bugs/swallowed.dl`, 30 lines): `swallowed(T, E)` when
E is an error of the system (`Unix_error`, `Sys_error`), E may come to
T from its body (`exceptions.dl`'s `at`, through the try's own calls
and the tries in it), and a silent case catches it. A call whose
failure is told by what follows or does not matter is not a cause
(`release`): a close, a remove, a kill (best effort), an exec (it comes
back only when it failed, the next line saying so). That list came
from reading the first sweep's reports (12 of its 45). `Failure`, `Invalid_argument`
and `Not_found` are left out: `with Not_found -> None` and
`int_of_string`'s `with Failure _ -> 0` are how ix asks a question.
`-bugs` now runs `exceptions.dl` over `insensitive.dl` (`-context`
chooses another).

**On ix** (the sweep, 1 min, the longest program 74 s; the kernel 6 s):
12 reports, in `lib_code/datalog/tests/bugs_ix.txt`, the kernel none
(its errors its own `Error`). Read one by one:
- **Worth a look, 3.** rio's `mount_files` writes `/env/wsys` and says
  nothing when it cannot: 4f00134c's shape, the window's rc without
  `$wsys`. rc's `finish` runs `sigexit` and drops its `Unix_error` and
  `Sys_error`. git's `mkdir_p` drops every error of `mkdir`, not only
  `EEXIST`: a directory not made shows only at the next write.
- **A read error as the end, 3.** acid's console, usbd's and fdisk's
  reads answer 0 on an error: the input ends early, in silence.
- **Best effort, 6.** ed's save on hangup and its and hoc's `recover`
  (an `lseek` after an interrupt), the highlighter's `Names_ml`, rio's
  `chdir` of a window (its comment says why), rio's note to a process.
None was fixed: the author decides.

**Not done:** `Failure` and the program's own exceptions; a case that
says something but drops the error (`with _ -> prerr_endline "?"`);
the `Invalid_argument` of an index out of bounds (`%array_safe_get`).

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

### A6. Physical equality (`bugs/physeq.dl`)

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
bugs/pointers.dl's "use after free needs the order", and Engler's checkers'
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
existing `bugs/pointers.dl` stays as it is. Taint is the next step for C, after
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
| 3 | A1 deep recursion | `tail`, `tail_but_try`, `in_handler`, `list_like` | 65 | 3 | done |
| 4 | A3 errors swallowed | `silent`, `silent_all`, `primitive` | 60 | 3 | done |
| 5 | A2 roots and primitives | `root_of`, primitive `raise_of` | 25 | ~5 | A8 uses its roots |
| 6 | A4 31 bits, step 1 | `int_lit`, `shift`, `wide_unit`, `wide_only` | 55 | ~12 | |
| 7 | A5 output order | sinks file | 30 | ~10 | the fixed points |
| 8 | A10 init and link order | `link` | 15 | ~3 | |
| 9 | A8 races | `while` | 25 | ~3 | |
| 10 | A9 pairs on every path | `call_at`, exception edges | 70 | ~5 | flow facts |
| 11 | A4 step 2, intervals | `range` (ML) | 200 | ~5 | after numbers in Datalog |
| 12 | A11 layout, evaluation order | columns, purity | 40+ | ~3 | |
| 13 | A7 unused parameters (fields: `-dead`'s) | SSA `use` joined | 20 | ~2 | |

These estimates come from reading the existing rule files (`bugs/pointers.dl` is
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
