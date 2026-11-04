# Plan: analyses that would have found ix's past bugs (`analyzers/datalog/`, `analyzers/`)

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

**Status: A6's first half, A1, A3 and A2 done (2026-11-03), A4's first
step, A5, A10 and A8's handlers (2026-11-04), the rest planned.**
`mini-analyze -bugs` runs `bugs/physeq.dl` (`==` or `!=` with a side
made in the comparison), `bugs/stack.dl` (a loop through a `try`, a
frame a list's element), `bugs/swallowed.dl` (an error of the
system silenced), `bugs/intwidth.dl` (an int past the Pi 1's 31
bits), `bugs/order.dl` (a table's order given to an output) and
`bugs/init.dl` (a start reading a later unit's global), `bugs/races.dl`
(a field a signal's handler and the program both write, a wait not in
a `while`). Each
reports its bugs on the code before the fix and not after
(`analyzers/tests/bugs/`: eb5378a5, 021c562b, f46346db, c5086383,
4f00134c, 4436f60d, e92ae1ec, d22c56e4, 410d04a2, 70b6b2bf,
6264d271, 11c5d5f0, ddb60eef). On today's ix,
`physeq` finds nothing; `stack` gives 145 reports on the 44 programs
and 9 on the kernel, `swallowed` 12 on the programs, `int31` 29,
`order` 2, `race` 1 (`analyzers/datalog/tests/bugs_ix.txt`), read in
A1, A3, A4, A5 and A8 below. A7 turned out to be
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
the kernel, all in `analyzers/datalog/tests/bugs_ix.txt`.
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
On the runtime and lib_core, 0.6 s (`analyzers/datalog/tests/raises.sh`,
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
`-exn` the same for each program's own exceptions, more toplevels and
sites for lib_core's: `Invalid_argument` 118 lines to 165 (`compare`,
`String.make`, `Hashtbl.create`, ...), `Failure` 73 to 79,
`Division_by_zero` 2 to 8, `End_of_file` 1 to 2. (Wrong then:
`exn_ix.txt` keeps `Division_by_zero`, bc's and dc's; the 6 new ones,
`Int32`/`Int64` `div` and `rem`, are recorded with the roots below.)

**The roots** (2026-11-03): what C calls was an entry for `-dead` only
(`dead.dl`'s `escaped`); now `contexts.dl`'s `callback(F)`, for every
analysis: a function in `ext` (`Callback.register`, `Sys.signal`, a
thread's), one given to a C function with no body (`c_callback`), and
one made an `Obj.t` (ocamlyacc's actions, mini-dotnet's JIT call-outs,
called back by `Obj.magic` or their address). The kernel's `trap`,
`irq`, `fault`, `process_start`, `Proc.scheduler` are read at last.
`exceptions.dl`: `from_c(F, E)`, E leaving a function C calls (`-exn`:
"Main.trap, called from C, may let Failure escape"); `ends_in(T, E)`,
E reaching a try that catches all and raises from its handler, not
what it caught (`guard`, whose `Machine.panic` ends in `failwith`):
`-exn`'s "the try in Main.guard, its handler raising, may be reached
by", and `-bugs`' `crash` for a program's own exception. A handler
raising `Invalid_argument` (by `^`) is not one; one giving what it
caught to a raise, there or in another function (git's `proto_die`),
neither. Found on the way: a `with e ->`'s caught object had no frame
(no `var_in`), so it never pointed anywhere and exceptions.dl's rule
for "kept and raised again" had never run; it is in its function now,
typed `exn`. And `raised(E, R)` scanned every raise for each tuple of
`leaves`: 187 s of mini-ml's `-bugs`, reordered, 248 s to 66 (75 at
HEAD). Test `analyzers/tests/bugs/4436f60d/`: Before.ml, the fault's
refused page reaching `guard`, reported; After.ml, its fix, a cleanup
raising `e` again, a handler answering, a `proto_die`, not. The sweeps
of the 44, HEAD and after: `-dead`, `-caps` the same; `-bugs` 1 more,
rio's `Terminal.take` (a callback's); `-exn` git's `Proto.Error` and
`Serve.Fatal` (passed on by `proto_die`), no program's "called from C"
line. The kernel: 3 more, `Devenv.replace` and `Usermem.go` (a page
at a time, bounded) for `stack`, and the crash: `Errors.Error` may
reach `guard` (and `Queue.Empty`, lib_core's), a panic, not triaged:
`Syscall.syscall` catches it, so it comes another way (an interrupt's
device, a note, a kernel process) or the analysis merges too much.
`bugs_ix.txt`, `exn_ix.txt` recorded. Not done: a thread's function
(`Thread.make` catches all already) and a signal's handler as roots of
their own, with their own report.

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
12 reports, in `analyzers/datalog/tests/bugs_ix.txt`, the kernel none
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

### A4. Ints on 31 bits (`bugs/intwidth.dl`)

**Step 1 done** (2026-11-04), as `int31` in `-bugs`. It re-finds
e92ae1ec (Sha1's `let mask = 0xffffffff` and its constants), the
gigabyte bound of cc6eb618's note (`0x40000000`, min_int on the Pi 1),
and a word read from four bytes, the last `lsl 24`
(`analyzers/tests/bugs/e92ae1ec/`). Its fix (Int32's words) is quiet,
and so are a function only called under `if Sys.int_size >= 63`
(Poly1305's `mac_limbs`), `0x3fffffff`, a char's code `lsl 16`, and
`x lsl 30` of a value of no known width.

**The facts** (`Closure_facts`, 60 lines; `Analyze`, 25):
- `wide_int(S, U, F, W)`: a literal past `0x3fffffff` (or below
  `-0x40000000`); a shift by 31 or more; `x lsl k` when x says its
  width (a constant, a mask `land m`, a char's code, an `lsr` of one)
  and k takes it past bit 30. Only the primitive: `linker/Arm.ml`'s own
  `lsl`, Int32's, is not one.
- `wide_site(I)`: a call in the branch of an `if Sys.int_size >= 63`
  (or `< 63`'s else), where no `wide_int` is said either.
- `unit_dir(U, D)`: each directory of a unit's file from the top of the
  tree, lib_core's parent (`-L`): `kernels/lib_machine/pi4` whether
  mini-analyze runs from the top or from `kernels/9pi`.

**The rules** (`bugs/intwidth.dl`, 10 lines): `narrow(F)`, what the
entries and callbacks reach by calls not in a wide branch; `int31` a
`wide_int` in a narrow function of a unit not in a `wide_dir`
(`kernels/lib_machine/pi4`, `raspberry`, `machine`: Decisions). The
report is a line a function, its first values and how many more: a
table of constants is one line.

**On ix** (the sweep, 2 min; the kernel), 29 lines in `bugs_ix.txt`,
read one by one. None was fixed: the author decides.
- **Worth a look, 7.**
  - mini-git's pack index (`Pack.ml:215`, `Pack.offset`): on 31 bits
    `1 lsl 31` is 0 and `0x80000000` is 0. So every offset is written
    to the 64-bit table, and what is read back is the table's index,
    taken as the offset.
  - `Query.probe`: `land 0xffffffff` is `land -1`, so after `mod` the
    slot may be negative: d47f0829's shape.
  - Scheme's `random` (`Scheme_eval`, `Scheme_secd`): `mod 2147483647`
    is `mod -1`, always 0.
  - mini-dotnet's `ILogB` (`Library.ml:357`): Int32's minimum written as
    an int, 0 on the Pi 1.
  - `Dbm.key_of`, the plan's one to check: a negative key stays
    negative where chidb's cast makes it unsigned.
- **The same bits on both sides, 12.**
  - A magic number compared with a word read the same way (`Image.read`'s
    BSJB).
  - A header's fields below 2^30 (`Symbols.be32`, `Exec.be32`,
    `Syscall.trace`'s user addresses, Etherusb's registers, the PE's
    `0x60000020`, its low 31 bits right).
  - A mask that is `land -1` on small values (`Record.get4`, Schema's
    root, Dbm's cursor).
  - Delta's gear hash (two lines, 191 constants): split by
    `land 0xff`, the low bits the same.
  - Packer's murmurhash2, a sort key for deltas, not a name: another
    pack, not a wrong one.
- **Host only, 10.** acid's Frame64 (an arm64 program's prologue), Gas
  (GNU as, compat/), the linker's Mach-O (`Exe.macho`, `CLI.link`'s
  `1 lsl 32`), mini-ml's .NET ids (`Il_exprs.var`, distinct still).

**Step 2, not done: intervals.** A value's range over the SSA of
`-flow`, by abstract interpretation in ML (`Ssa_facts` writing
`range(V, Lo, Hi)`). Datalog cannot compute this until plan_datalog.md's
stage 3 gives it numbers. It would find:
- Adler's `(b lsl 16) lor a` (7a8c6af7), b below 65521: no width said,
  so step 1 is quiet;
- the sign that d47f0829's `mod` kept;
- the guard that 7f15c58f wrapped (`2 * n + 1 < 256`);
- and it would excuse Delta's hash, a value used only through a small
  mask.

### A5. Output in a hash table's order (`bugs/order.dl`)

**Done** (2026-11-04), as `order` and `sharing` in `-bugs`. Re-found:
- **d22c56e4**, the Unbox pass's boxes in `Hashtbl` order
  (`analyzers/tests/bugs/d22c56e4/`). Also on the whole of mini-ml with
  Unbox.ml as it was before the fix: its `Hashtbl.iter` (line 129) is
  reported, its order reaching the objects' `Marshal` (`Asm.ml:214`,
  `232`) and the summaries' (`Summary.ml:112`).
- **410d04a2**, Typing's places, a `Hashtbl.fold` marshalled in X.inline
  without `No_sharing` (`analyzers/tests/bugs/410d04a2/`, both reports).
- **ca664887**'s class, `Marshal` without `No_sharing`: `sharing`.

The fixes are quiet: the list sorted first, `No_sharing`. So are the
look-alikes in `After.ml`: a sum over a table, a table filled from
another, a message to stderr, a string built in a Buffer of its own.

**The facts** (`Closure_facts`, 36 lines), at each model's call
(`analyzers/ml/Models`):
- `walked(S, M, V)`: the model of M walks V in order, a table's
  bindings or a list's cells;
- `walk_call(I, S)`: the calls of the closure it was given;
- `model_new(S, H)`: the blocks it makes;
- `shares(S, F)`: `Marshal.to_string`, `to_bytes` or `to_channel`
  whose flags do not say `No_sharing`.

**The rules** (`bugs/order.dl`, 43 lines): a taint of the objects whose
source is the table's walk.
- In the walk's order: a list cell that a walk's closure makes and that
  accumulates (its tail a cell of its own site: `k :: acc`,
  `l := x :: !l`; not a list literal, Prolog's `$ops` terms); the list
  a model makes from a list in that order (`List.map`, `rev`, `@`); and
  what a walk of such a list makes.
- `List.sort`, `sort_uniq`: a list of their own, in no table's order.
- Output: a walk in that order whose closure writes (`output_string`,
  `print_*`, `Console.print`, `printf`, `FS.write`, or an add to a
  global Buffer, through the program's own functions); or `Marshal`
  given what holds such a list.
- A Buffer given around is not one. Every `Buffer.create`'s object is
  one object here, and most build a string (Show_ast's `to_string`,
  Prolog's `atom_text`: their walks were the first sweep's false ones).
  So a string built in a walk's order and written later is not found,
  nor a walk written by hand (`let rec go = function x :: r -> ...`).

**On ix** (the sweep: no time added; the kernel): 2 lines in
`bugs_ix.txt`. Both are a table's order shown to the user: acid's
`whatis` lists the variables in it, mini-5i's profile writes its counts
in it (machine/CLI.ml:50). Not among the 44 programs: mini-ar's
`Link.write_library` (`sharing`, run by hand: the libraries' bytes
are the compiler's, as Asm.save's were before ca664887), and office's
`Saved.to_string` (a document, not compared). None was fixed: the
author decides.

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

**Done for handlers** (2026-11-04): `bugs/races.dl`, two kinds of
`-bugs` line. `race`: a field written by what a signal's handler runs
and by the program, of an object the program made. The roots are what
`Sys.signal` is given in `Signal_handle` and what `Thread.make` is
given (not C callbacks: Pervasives keeps the handlers and runs them
where the program waits, `run_signals`); the program's code is what
the entries and C's callbacks run, not through a root. Not reported: a
bool (a flag, the fix's), an object the handler makes, a handler that
ends the program (`exit`: ed's hangup saving the buffer). `wait`: a
`Condition.wait` neither in a `while` nor in a function calling itself.
New facts: `store_in(O, Fld, W, F)`, a field written once its block is
made, in which function (`assign_store_field` did not say it of a
global), and `loop_site(I)`. 30 lines of rules, 25 of facts, 70 of
report. Tests `analyzers/tests/bugs/11c5d5f0/` (TinyMachine's handler
typing the ^C into the queue console_poll replaces: reported; the flag:
not) and `ddb60eef/` (basic_sync's one wait: reported; in a `while`,
and in a recursive retry: not).

On ix: the kernel, nothing (no signals, no threads); the 44 programs,
one `race`, mini-5i's `Linux.raise_signal` appending to `pending`
while `deliver` filters it (`pending := List.filter ... !pending`).
Under ix's runtime a handler runs only at a system call, none between
that read and that write: harmless. Under OCaml 4.14 a signal is
handled at an allocation too, `List.filter`'s: a signal arriving there
is lost, in OCaml's build of mini-5i (not reproduced;
`docs/plans/bugs/ix.md`).

**Not done: threads.** The first sweep gave 406 lines, 88 once a
model's new cells and an object the root makes were left out; 75 of
those were threads, mini-emacs's and lib_graphics' `Display`, none
seen a race: ix's threads switch only where one yields or waits, and
every thread of `Source`'s is one root. They need the switch points
and the lockset (a function calling `Mutex.lock` as holding it) before
they are reported.

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

### A10. Toplevel initialization and link order (`bugs/init.dl`)

**Done** (2026-11-04), as `init` and `link` in `-bugs`. Re-found:
- **70b6b2bf's Poly1305**, its toplevel reading Bignum before Bignum
  started: `analyzers/tests/bugs/70b6b2bf/`. Also on the real files:
  Poly1305.ml and Bignum.ml as of 70b6b2bf, with `-start "Poly1305
  Bignum"`, give "Poly1305's start reads Bignum.modulus and 4 more";
  with the fixed order, nothing.
- **6264d271's two `Collide`**, mini-doom's beside lib_physics's:
  `analyzers/tests/bugs/6264d271/`.
- Not done: tiny-ml exporting the first of two toplevel definitions of
  one name, a check of tiny-ml's own rule, not the link's.

**The facts** (mini-analyze, 65 lines; none from Closure_facts):
- `starts_before(I, J)`: the order of the units' starts, by a new
  option, `-start "units"`, the list mini-ml -start is given.
  `mk_units.sh`'s `start_of` makes it from a mkfile as mkprog does:
  STD, COMMONS, each `LIBDIRS` library's `UNITS`, `LIBUNITS`, `SRC`.
  The sweep passes it. Without it, only "the library's units before the
  files'" is known.
- `unit_start(U, I)`: a unit's start.
- `unit_file(U, F)`: each file of a unit's name in a directory whose
  units name it. A file of the name in an `-I` that only gives
  interfaces, or whose units do not name it, is not linked: the first
  sweep's 24 false reports (`Main`, `CLI` beside the programs they read
  from).

**The rules** (`bugs/init.dl`, 6 lines):
- `early(I, G, F, J)`: what a start runs (its code and what it calls,
  through `target`) names a global that a later start makes.
- A function of a unit that starts later is not counted. It could run
  there only as a value its own start registered, later: the
  flow-insensitive call graph does not order that (Oberon's tasks, the
  first sweep's 40 false reports). A call of it from the earlier code
  is reported where it is named.
- `twice(U, F1, F2)`: two such files.

**On ix** (the sweep with `-start`: no time added; the kernel with its
`KML` as the order): nothing. The order bug was fixed by 70b6b2bf, and
no two linked units share a name.

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
| 6 | A4 31 bits, step 1 | `wide_int`, `wide_site`, `unit_dir` | 95 | 3 | done |
| 7 | A5 output order | `walked`, `walk_call`, `model_new`, `shares` | 80 | 3 | done |
| 8 | A10 init and link order | `starts_before`, `unit_start`, `unit_file` | 70 | 2 | done |
| 9 | A8 races | `store_in`, `loop_site` | 125 | 2 | handlers done; threads need the switch points |
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
