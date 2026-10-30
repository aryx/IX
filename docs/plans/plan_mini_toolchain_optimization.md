# Plan: the mini toolchain, faster (the target: mini-xv6's numbers)

Companion of [`plan_kernel_mini_ml.md`](done/plan_kernel_mini_ml.md)
(mini-xv6 built by ix's tools, its step 7: the two builds' numbers) and
of [`plan_mkfiles.md`](done/plan_mkfiles.md), whose step 5 this is. The
earlier work on mini-ml's and mini-cc's code is in
[`variants/opti.md`](variants/opti.md) and
[`variants/ssa.md`](variants/ssa.md) (`-O`, `-ssa`: what was tried, what
each bought). The author (2026-10-02): "let's plan for an optimization
phase at some point", then "we can start a plan mini_toolchain
optimization document, with as a good target getting better numbers
for mini-xv6!".

**Status: on hold** (the author, 2026-10-02: "for now let's put the
optimization plan on hold"): a plan with its first measurements, to
review when it is taken up again. Nothing is optimized yet.

## The target

mini-xv6 on the Pi 4 has two builds of the same OCaml and the same C:
the Makefile's (ocaml-light, gcc, GNU's linker) and the mkfile's
(mini-ml, mini-cc, mini-asm, mini-ld). `kernels/xv6/numbers.sh`, under
mini-qemu:

| build | image | to `sh` and an `ls` | the check's session |
|---|---:|---:|---:|
| ocaml-light, gcc | 1,917,608 (an ELF) | 2.8 s | 20.1 s |
| ix's tools | 2,457,808 | 8.3 s | 88.4 s |

The session (ls, cat, mkdir, ln, wc, rm, grep, forktest) is 4.4 times
slower. **The target: that ratio under 2, without making the simple
path longer** (the principles below). A second target, the same code's
other use: ix built by ix. The fixed point's second build takes 3
minutes where the first, by ocamlopt's code, takes 1, and mini-ld by
mini-ml links mini-cc in 18 s (bugs/ix.md).

## Where the time goes

**The kernel is its scheduler.** A profile of each build under mini-qemu
(`-prof`, mapped by `kernels/9pi/tests/perf/pcprof.py`, which now reads
`mini-ld -v`'s listing too) says the same of both: when no process
runs, and between two, the kernel is in `Proc.all ()`:

    let all () = List.fold_right (fun o acc -> match o with Some p -> p :: acc | None -> acc) (Array.to_list procs) []

64 slots made a list, folded by a closure of two arguments, at every
pass. ocaml-light's build: `Array.to_list` 28%, the scheduler's loop
22%, `List.fold_right` 20%, `caml_apply2` 12%. ix's: `to_list` 19%,
`fold_right` 18%, `ml_alloc` 17%, the loop 10%, and 15% in `ml_curry2`,
which ocaml-light's does not have.

**So the scheduler's pass is the benchmark**:
`languages/ml/tests/bench/sched.ml`, the same line 2,000 times, in
user mode, where every instruction can be counted
(`languages/ml/tests/count.sh`, against ocaml-light's ocamlopt):

| | instructions | times ocamlopt's |
|---|---:|---:|
| ocamlopt | 7,889,568 | 1 |
| mini-ml | 36,532,638 | 4.63 |
| mini-ml `-O` | 34,788,691 | 4.41 |
| mini-ml `-O -ssa` | 32,757,342 | 4.15 |

4.63: the session's 4.4. The kernel's ratio is this code's. And
mini-ml's instructions, function by function (`mini-5i -t`, the same
script):

| | share | what it is |
|---|---:|---|
| `Array.to_list`'s loop | 22% | not looked at instruction by instruction yet; on `loops`, variants/opti.md found a call's entry and exit (the value stack's slots zeroed, every register spilled around a call) |
| `List.fold_right` | 21% | the same, and not a tail call |
| `ml_alloc` | 21% | an allocation is a call of C, and that C is 7c's `-O0` |
| `ml_curry2_0`, `ml_curry2_1` | 19% | `f a b` with `f` unknown: one argument at a time, a closure allocated in between |
| the closure's body | 12% | |
| the collector | 0.2% | |

**What the existing switches buy on the kernel** (each built whole, the
stdlib too, and measured by `numbers.sh`):

| build | to `ls` | session |
|---|---:|---:|
| ix's tools | 8.3 s | 88.4 s |
| the heap 32 MB from the start (`-DHEAPSTART`), not 2 MB doubling | 7.7 | 84.2 |
| and `mini-ml -O` | 7.7 | 84.2 |
| and `mini-ml -O -ssa` | 7.6 | 83.5 |
| and `mini-cc -simple -O` for the C (the runtime, the library) | 7.7 | 77.6 |

Little: `-O`'s passes (self tail calls, integer equality) and `-ssa`'s
registers do not touch what the table above shows. The collector is not
the problem either (5% with sixteen times fewer collections).

**Not explained yet**: the 8.3 s to the prompt. The bss is 75 MB (the
heap's two halves, the value stacks) and the start clears it; the whole
stdlib is initialized; the rest is the code. To measure (step 1).

## A second benchmark: mini-smalltalk (2026-10-07)

The author, when [`plan_system_squeak.md`](done/plan_system_squeak.md)'s
stages 1 and 2 found Squeak slow by mini-ml: "it's also a great bench
for future improvements to mini-ml! to compare with ocamlopt and reduce
the gap"; "we had a similar issue before, where another ix kernel or
program could be a great benchmark for mini-ml" (this plan's: mini-xv6
and its scheduler's pass).

mini-smalltalk (`languages/smalltalk/`) is the Blue Book's virtual
machine, 4,800 lines of OCaml of the usual kind, and three things it
does are three kinds of code. `languages/smalltalk/tests/bench/numbers.sh`
(`-all` for the third, 8 minutes) counts each: mini-ml's instructions
under mini-5i (arm64), ocamlopt's by valgrind on this machine (OCaml
4.14, x86-64: another instruction set and a far better compiler than
ocaml-light's, so not `sched.ml`'s ratio):

| | what it is | mini-ml | ocamlopt | ratio |
|---|---|---:|---:|---:|
| the start | the system's text compiled (3,340 lines of Smalltalk): a lexer, a parser, a compiler, hash tables | 269,376,042 | 51,884,894 | 5.2 |
| fib | `20 benchFib`, 229,945 bytecodes: the interpreter's loop, sends, contexts made and dropped | 560,123,294 (2,435 a bytecode) | 74,866,221 (326) | 7.5 |
| the world | Squeak's start and three cycles of its world, 1,026,041 bytecodes: objects, closures, BitBlt, the collector | 6,406,348,276 | 549,554,891 | 11.7 |

- **The switches buy nothing here either**: fib with `-O`, 2,436
  instructions a bytecode; with `-O -ssa`, 2,591 (the program's units
  rebuilt, not the stdlib).
- **ocamlopt's profile of the world is flat** (valgrind's): the
  interpreter's `step` 12%, the object table's accessors (`body`,
  `fields`, `fetch`, `class_of`: a line each) 11%, `caml_modify` 8%,
  `caml_apply2` and `3` 6%, the collector 6%; BitBlt under 1%. So no
  one function to rewrite: what is slow is what every program does,
  small functions called, closures applied, cells allocated and
  written. **mini-ml's own profile of it was not taken** (no sampler in
  mini-5i yet; mini-qemu's `-prof` will do once Squeak is a kernel).
- What it adds to the table of where the time goes, to check there:
  the ratio grows from the compiler's kind of code (5.2) to the
  interpreter's (7.5) to the objects' (11.7), where ocamlopt inlines
  the accessors and allocates in three instructions.

So the targets are three now: mini-xv6's session, ix built by ix, and
**Squeak's first screen**, which decides whether mini-squeak is
pleasant on the Pi 4.

## A third benchmark: lib_crypto (2026-10-11)

The author, once `https://` ran on mini-9pi
([`plan_browser.md`](plan_browser.md), stage 10) and the library alone
had been made faster: "let's add crypto as an additional bench like I
think we already had xv6 and some graphics stuff". A TLS handshake by
mini-ml's code for arm is some 1.5 thousand million instructions, and
what was left after the library's own rewrites (`lib_crypto/README.md`,
"Speed on a small machine") is the code of its loops.

It is a third kind of code. The scheduler's pass is calls and
allocation, Squeak is small functions and objects; this is **loops
over arrays of ints**, with no closure applied and little allocated:
the body of a loop, values kept in registers or not, an index checked
or not, a multiplication. `lib_crypto/tests/numbers.sh` counts each
kind of work of `Speed.ml`, a kilobyte or one operation, the start
taken off: mini-ml's instructions under mini-5i, ocamlopt's by
valgrind on this machine (OCaml 4.14, arm64 too: the same instruction
set, so the ratio is a fair one):

| | what it is | mini-ml, arm64 | ocamlopt | ratio | mini-ml, arm |
|---|---|---:|---:|---:|---:|
| the start | the runtime's and the units' own (AES's tables) | 4,833,984 | 2,516,865 | 1.9 | 6,899,178 |
| aes | a kilobyte: four tables read and xored a byte | 1,769,996 | 678,576 | 2.6 | 1,581,280 |
| ghash | a kilobyte: eight ints shifted and xored, 32 times a block | 2,338,046 | 866,809 | 2.7 | 2,432,209 |
| chacha20 | a kilobyte: additions, xors and rotations of words | 1,327,301 | 311,015 | 4.3 | 2,636,705 |
| poly1305 | a kilobyte: products of limbs, unrolled | 191,718 | 40,124 | 4.8 | 1,309,097 |
| sha256 | a kilobyte: the same kind as chacha20, in `int32` | 5,668,472 | 205,388 | **27.6** | 5,458,490 |
| x25519 | a public key: 3,000 of `Bignum.mont_mul` | 60,889,391 | 17,734,503 | 3.4 | 158,738,772 |
| ecdsa | a P-256 signature checked: 6,000 of them | 125,867,021 | 37,548,403 | 3.4 | 319,387,843 |
| rsa | a 2048-bit modulus and its 17 products | 53,706,647 | 15,172,665 | 3.5 | 112,092,480 |

(The last column is not to be held against ocamlopt's: on arm an int
has 31 bits and the library runs other code for it, limbs of 14 and 13
bits and words in two halves, so more operations for the same work.)

- **A loop's body is 2.6 to 4.8 times ocamlopt's.** `mont_mul`'s inner
  loop, traced on arm (`mini-5i -t`): two multiplications, four array
  accesses and two carries are about 110 instructions. Every value
  goes to its slot of the stack and comes back (`str r1, [sl, #-204]`
  then `ldr r1, [sl, #-204]`), each array access checks its index (six
  instructions), a `ref` that does not escape is a cell of the heap
  read and written through its pointer, and a global (`mask`) is two
  loads.
- **`int32` is boxed: 27.6.** Every `Int32.add` allocates; ocamlopt
  keeps them unboxed inside a function. The hashes (SHA-256, SHA-512
  in `Int64`) are all of it; they are what a handshake's transcript
  and a certificate's check cost.
- **`Array.unsafe_get` changes nothing** (tried in `mont_mul`): it is
  checked all the same.
- The switches were not tried on it (`-O`, `-O -ssa`): to do with the
  first step taken for it.

So the targets are four: mini-xv6's session, ix built by ix, Squeak's
first screen, and **a TLS handshake on a Pi 1** (and under mini-qemu,
where a server gives up before it ends).

## Principles

The author's, from the earlier phases (variants/opti.md, and the
memory of this project):

1. **Measured first.** A pass exists because a profile asked for it,
   and its entry says what it bought, in instructions (`count.sh`) and
   in the kernel's seconds (`numbers.sh`).
2. **The simple path stays.** An optimization is beside it, switchable
   (`-O...`), the code before kept (`(* old: *)`), "optional and not
   polluting the existing simple code path". The mkfiles choose which
   are on.
3. **Lines are the budget.** m-ix is 80,767 lines, `opti/` and `ssa/`
   are counted apart (1,554). A pass's lines are in its entry, with what
   they bought; a rewrite of ix's own code that removes the cost for
   both compilers (the scheduler's list) is weighed against a pass.
4. **Correct before fast**: every test with the pass on, live against
   ocamlopt, and with `ML_HEAP=64` (a collection at almost every
   allocation) when the collector's roots are concerned; the kernel's
   six checks; the fixed point.
5. The notes go to `~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`
   (the symptom in the profile, why, the fix, what it bought) and to
   `docs/notes/notes_performance.md`.

## Candidates, by what the profile says

| | what | where | aims at | lines (guess) |
|---|---|---|---|---:|
| A | **Allocation inline**: the heap's pointer bumped and compared in the generated code, C called only when the half is full (ocamlopt's way; needs the pointer and the limit where ML's code reaches them) | `Gen`, the runtime | `ml_alloc`'s 21% | 40 |
| B | **`f a b` in one call**: an unknown function applied to n arguments calls its code directly when its arity is n (ocamlopt's `caml_applyN`: the arity in the closure, tested), the curried way otherwise | `Lower`, `Gen` | `ml_curry`'s 19%, and its allocations | 60 |
| C | **A call's entry**: only the slots a collection can see uninitialized are zeroed (liveness), registers spilled only when live after the call | `Gen` (or `ssa/`, which has the liveness) | part of the 43% of `to_list` and `fold_right` | 80 |
| D | **Known functions**: a call of a function known at compile time across units (the stdlib's `List.iter`) direct, without its closure; small ones inlined | `Scope`, `Lower` | the rest of it | 100+ |
| E | **The C faster**: `mini-cc -simple -O` in the mkfiles (measured: the session 84.2 to 77.6); then what 7c's own optimizer does that `opti/` lacks | the mkfiles, `languages/c/opti` | the runtime, the C library, the kernel's C | 0, then ? |
| F | **The kernel's memory**: the heap's halves outside the bss (nothing reads a half before it is written), the stdlib's units linked only when named (as `tests/run.sh` does) | the runtime, `mkkernel` | the boot, the image's 922 KB | 30 |
| G | **A generational collector**, beside Cheney's, switchable (plan_ml.md, decision 5) | the runtime | after A: an allocation's cost is then the collector's | 150 |
| H | **ix's own code**: `Proc.all` without a list at each pass; mini-ld's `t.progs` appended to (quadratic) | `kernels/xv6`, `linker` | both builds; the links | -5 |
| I | **The parsers' tables** compacted (plan_lex_yacc.md) | `generators/yacc` | the programs' size | 100 |
| J | **A loop's values in registers**: a temporary used once not stored and loaded back; a `ref` that does not escape a variable, not a cell (ocamlopt's) | `Gen`, or `ssa/`'s allocator | lib_crypto's 2.6 to 4.8 | 150+ |
| K | **An index known in bounds** not checked (a `for` over `0 .. length - 1`), and `Array.unsafe_get` really unchecked | `Lower` | a quarter of `mont_mul`'s loop | 40 |
| L | **`int32` and `int64` unboxed** inside a function: boxed only when stored or passed | `Lower`, `Gen` | sha256's 27.6 | 150 |

Order proposed: A, B (the two that the profile names, both local),
then measure again; E's switch (free); F (the boot); C with `ssa/`'s
liveness; D; G only if the profile then asks.

## Steps

1. **The meters.** `count.sh` and `bench/sched.ml` (done), `numbers.sh`
   (done), `pcprof.py` on a listing (done). To add: the guest's
   instructions to a point, counted by mini-qemu (a count at exit, or
   at a marker), so that the boot and the session are numbers of
   instructions and not seconds of a host; the same three programs of
   `bench/` and `sched` as one table, kept in this file after each
   step.
2. **A and B**, each behind its switch, measured on `sched` then on
   the kernel.
3. **The mkfiles' switches**: which of `-O`, `-ssa`, `-simple -O` and
   the new ones are on for ix built by ix and for the kernels; the
   fixed point and the checks with them.
4. **F**: the boot explained and shortened.
5. **C, D**, by what the profile then says.
6. The same table for **ix built by ix** (the second build's minutes,
   mini-ld's link of mini-cc), and H's linker part.

## Open questions

1. **Where the switches live.** `-O` is all of `opti/`'s passes; A and
   B change `Lower`'s and `Gen`'s output, not an IR-to-IR pass. A flag
   each (`-Oalloc`, `-Oapply`) read by the simple back end, with the
   plain path kept beside? Or in `ssa/`, the optimizing back end, only?
2. **The contract.** With `-O` on in the mkfiles, a program built by
   ix's tools is no longer the simple path's: the fixed point then
   checks the optimizers. Both, in two builds?
3. **H**: is rewriting `Proc.all` (the kernel's own code, for both
   builds) inside this plan, or does the plan keep the kernel as the
   fixed benchmark it was measured with?
4. **The stack a call takes** (32 bytes, ocamlopt's 16: bugs/ix.md) is
   a limit, not time: here or apart?

## Status

2026-10-08, **A and B done, and a float's arithmetic with them**, for
the games on mini-9pi ([`plan_playground_speed.md`](plan_playground_speed.md)'s
Status has the detail and what a frame gained):

| | mini-ml | times ocamlopt's | before |
|---|---:|---:|---:|
| `sched` | 22,148,917 | 2.81 | 36,551,288 (4.63) |
| `maps` | 25,370,134 | 0.80 | 39,813,277 (1.26) |
| `fib` | 6,461,681 | 3.23 | the same |
| `tak` | 3,014,702 | 2.76 | the same |

- A: `Gen.alloc_in_place`: the runtime's `hp` and `limit` are `ml_hp`
  and `ml_limit`, not static; a block is 9 instructions, the runtime
  called when there is no room, the values then in their slots as
  before. Not for more than 16 fields (arm64's small offsets), nor
  with gcc's C (`-gas`).
- B: `Lower.calls_whole`: no arity in the closure; a closure's first
  field is the curry function of its arity, so comparing it with
  `ml_curry<m>_0` says "takes exactly m". For that the curry functions
  are one set, the program's, in the start object (`Lower.curry_funcs`,
  `Gen.startup`), not each unit's. A function given more arguments
  than it takes, or fewer, goes one at a time as before.
- Floats (that plan's M4a): `Ir.Float2`, `Float1`, `FloatOfInt`,
  `IntOfFloat`, and two floats compared in `Poly`'s code after its
  integers.
- `tests/costs.sh` (arm, instructions an operation, both ways). ix
  built by ix with them (`make test-lite`), the kernels' checks
  (`make -C kernels/9pi check-all`). +272 lines in `simple/` and `ssa/`.

**Open question 1, answered for now by what was quickest to measure,
the author's to change**: they are in the simple back end, **on by
default**, and one flag turns them all off (`mini-ml -calls`), the
plain path beside each in the code. Not a flag each, not in `ssa/`
(`Ssa_build` gives them back as the runtime's calls). And so question
2 is open again: ix built by ix is built with them (the fixed point
passes), and no build is the plain path's any more unless a mkfile
says `-calls`.

Beside them, in the runtime: `Gc.get` and `Gc.set`, OCaml's
`space_overhead` (how much more than what is alive the heap may be:
100, twice, is the rule as it was and the default; a game asks 700 and
its collections are a quarter as many: G's cheap half); `blit_string`
and `fill_string` a word at a time (the C library's `memmove` is a
byte a turn: E's concern, done here for strings only). And
`Bytes.length` was a function where `String.length` is the primitive.

What `fib` and `tak` say is left: a call's entry and exit (C), then D.
And two that the games' profile adds: an integer division is 200
instructions (the C library's, the Pi1 having none), and the
collector copies all that is alive (G).

2026-10-11, **lib_crypto added as a third benchmark** (its section
above, `lib_crypto/tests/numbers.sh`), and J, K, L to the candidates.
Nothing of the compiler changed for it yet.

2026-10-23, **four more of the profile's, mini-ml's self-compile 22%
fewer instructions** (the author: "let's continue the work on
improving the code generated by mini-ml ... so doom/quake, and also
mini-ml itself becomes faster so also building m-ix under m-ix is
faster"). mini-prof on mini-ml (built -O3) compiling its Typing.ml on
arm named them: the copying collector 20%, compare's `cmp` 5%,
`obj_block` 4.4%, `ml_string_get` and its `bound` and `length` 6.5%;
and `fib`'s code under -O3 showed the rest.

- **Comparisons typed** (`Lower.immediates`): the type checker records
  each `=`, `<`... with its type, by its place in the text
  (`Typing.immediates`, read once the unit is checked); on ints, chars,
  booleans or `()` it is the integers' `Cmp`, not `Poly` (both
  operands tested, compare called for others). fib's `n < 2`, 11
  instructions on arm, is a CMP and its branch. Nothing else reads a
  type; `-unsafe-types` and `-calls` keep `Poly` everywhere. A place
  seen at two types (an expression copied) is one only if both are.
- **A string's checked byte inline** (`Ir.ByteGet true`, `ByteSet
  true`): `s.[i]`, `Bytes.set`, the index compared with the length
  there (ocamlopt's way), in both back ends; they were calls of
  `ml_string_get` and `ml_string_set`.
- **A big block inline** (ssa's `Emit`): `Lower.block`'s `obj_block`
  for more than 4 fields, its words taken and set to `()` as the
  runtime does, the runtime called when there is no room.
- **ssa's frame**: the stack code's slots are not in it unless a
  handler's function reads them in memory (fib's frame 9 words, 7
  zeroed at each call, now 3); a parameter not live across a call may
  have a register, loaded at the entry.
- The runtime's `cmp`: two strings compared a word at a time while
  they are the same.

Tried, not kept: the collector calling `copy` only for a block of the
space collected (Typing.ml 1% more: the test is copy's own, twice);
no jump to the next block in ssa's `Emit` (mini-ld already drops it:
fib the same count).

The numbers, on arm, every unit of the program (the stdlib too) by
each compiler, mini-5i -s; mini-ml built by mini-mk O=5 in two copies
of the tree (HEAD's compiler, this one), each compiling the same three
units (HEAD's), as `tests/macro.sh` does:

| | before | after | |
|---|---:|---:|---:|
| mini-ml compiling simple/Lower.ml | 3,865,837,842 | 3,016,996,053 | 0.78 |
| Typing.ml | 2,683,401,875 | 2,062,747,401 | 0.77 |
| ssa/Ssa_build.ml | 2,675,370,650 | 2,146,485,922 | 0.80 |
| mini-doom, a frame (`macro.sh`'s) | 33,042,732 | 29,389,721 | 0.89 |
| mini-quake, a frame | 38,642,143 | 35,788,030 | 0.93 |
| cameltry, a frame | 4,528,435 | 4,215,811 | 0.93 |

`tests/bench.sh 5`, -O3: pixels 39.35 million to 37.09 (0.94), limbs
16.01 to 15.96, samples 14.18 to 13.95, fib 5.49 to 3.39 (0.62), tak
2.81 to 1.89 (0.67), maps 22.68 to 20.23 (0.89), sched 16.66 to 14.10
(0.85). Against ocaml-light's arm ocamlopt (`O=5 count.sh`): fib 2.67
to 1.65, tak 2.45 to 1.64, sched 2.05 to 1.74, maps 0.73 to 0.65,
limbs 1.36.

What the profile says is left, Typing.ml compiled by the new mini-ml
(2.08 thousand million): the collector 25% (`copy` 14.6, `collect`
10.7: G, a generational one, is now the largest), `cmp` 8% and
`compare` 1.4% (names compared, by `List.assoc` and `Hashtbl`), arm's
division 3.4% (principia's `div<>`, a bit a turn, 32 turns for a hash
`mod` a table's size; CLZ would start at the divisor's first bit), the
unmarshaller's `byte` and `get_uint16_le` 4% (the interfaces read).
Floats are still boxed (samples).

Checked: tests/tiny and tests/runtime (two new: bounds, compare_strings)
on arm and arm64, -O3 and -O0, each with ML_HEAP=64 (arm's arith and
strings fail as before, 64-bit outputs); facts' tests; compile_ix.sh
(1035 of 1037, the two failures HEAD's); the whole tree built with
mini-mk O=5 by the new compiler, and mini-doom's and mini-quake's 31st
frames the same bytes as HEAD's build's; mini-ml built by mini-ml (arm)
writes the same assembly as by OCaml (seven files, arm and arm64,
Typing.ml among them). Not run: make test-lite, the kernels' checks,
mini-9pi, m-ix built on the card.

2026-10-23, **G: a generational collector** (the author: "let's do the
generational collector! tiny-ml I think anyway has a copying collector
already no? so mini-ml should do better than tiny-ml and has a bigger
budget than tiny-ml"). The runtime's `gc.c`: a young generation
(OCaml's minor heap, 1M words, `MAXHEAP / 16` for a kernel) where every
block is born, `ml_hp` and `ml_limit` its; a minor collection copies
its survivors into the half, after its last block; the halves'
Cheney is the major collection, both generations at once, when the
half is past its size (the growth by `space_overhead` as before). A
block of more than half the young generation is made in the half,
after a minor collection. The roots of a minor collection: the major's
and the remembered old fields. The write barrier: each `SetField` and
`SetIndex` (Gen and ssa's Emit) tests the stored value, an integer
nothing, else calls `ml_modify` (the start object's, `Gen.startup`:
assembly that changes only R0 and the scratch register), which
remembers the field when the value is young and the field old; ssa's
Emit leaves it out for a constant and for a block made since the last
safepoint (fresh: a closure's environment, a big record's fields). The
runtime's C stores with `Store_field` (memory.h: `ml_store`). Off:
`ML_YOUNG=0`, and with gcc's C (`-gas`, no barrier); `old:` kept.

| arm, mini-5i -s | one generation | generations | |
|---|---:|---:|---:|
| mini-doom, a frame | 29,389,721 | 18,939,281 | 0.64 |
| mini-quake, a frame | 35,788,030 | 27,818,178 | 0.78 |
| cameltry, a frame | 4,215,811 | 2,430,548 | 0.58 |
| mini-ml compiling simple/Lower.ml | 3,016,996,053 | 2,892,509,355 | 0.96 |
| Typing.ml | 2,062,747,401 | 2,002,063,112 | 0.97 |
| ssa/Ssa_build.ml | 2,146,485,922 | 2,018,406,147 | 0.94 |

(the frames the same bytes; with `ML_YOUNG=0` the same build's frames
are 0.4 to 1.5% above the first column: the barrier's cost.)
`bench.sh 5`: maps 20.23 million to 13.14 (0.65); limbs 15.96 to
16.95 and pixels 37.09 to 37.86, the inline test of a stored integer;
samples 13.95 to 14.54, its arrays' floats boxed, each new one
remembered; fib, tak, sched the same.

Why so little for the compiler: Typing.ml's compile has 109 minor
collections and 3 major (28 collections before), the copy now 349
million instructions where it was 526, but a compiler keeps most of
what it makes (the trees, the types, the code until the unit is
written): the survivors are many, each copied once anyway, and
ml_modify's 2.7 million calls cost 50 million. A young generation of
256K words (OCaml's) was 2% slower than 1M. Tried, not kept: the scan
calling `copy` only for a young pointer (C's test costs the call).
Next for the barrier, if wanted: the stores the type checker sees as
integers (an `int array`, an `int ref`) without it, as the
comparisons (`Typing.immediates`).

Checked: tests/tiny and tests/runtime on arm and arm64, -O3 and -O0,
with ML_HEAP=64, and with ML_YOUNG=256 (a minor collection every few
allocations: the same, but for gc.ml on arm, out of time: its 200,000
deep recursion's stack scanned at each); lite.sh's "ix built by ix"
job on a copy of the tree (97 programs by the new compiler and
runtime, the games', music's, office's frames and sounds, the
browsers, TLS, the tiny programs, mini-xv6 and a kernel's step booted
under mini-qemu); mini-ml built by mini-ml writes the same assembly as
by OCaml. Not run: mini-9pi (its kernel and programs with the young
generation), the kernels' check-all, m-ix built on the card.

On the Pi 2 (the author, the card built after the generations and
mini-9pi's scaled draw, F5 of plan_playground_framebuffer.md): mini-doom
outside rio, full screen, "I get 24fps often", where it was around 15 on
a large area (d754454d).

2026-10-23, **the types used three times more** (the author: "let's do
the int barrier and string equality"; the float comparisons found on
the way, in mini-doom's profile). `Typing` records, beside each
comparison, the stores of an array, a ref and a field with the type of
what they store (`Typing.places`); Lower then emits:

- **no write barrier** for a stored int, char, bool or `()` (Ir's
  `SetField` and `SetIndex` have a bool: `Typing.immediates`);
- **a string's equality** for `=` and `<>` on strings: the runtime's
  `caml_string_equal`, the words compared (a string's padding is 0),
  not compare's walk; `ml_equal` and `ml_notequal` take the same path
  when both operands are strings (`List.assoc` on names);
- **a float's comparison**, `Ir.FloatCmp`, the processor's (VFP's CMPD,
  arm64's FCMPD, the conditions false of a NaN), in both back ends:
  ssa's Emit called the runtime's compare for two floats, 14% of
  mini-doom's frame (its walls' and planes' tests).

Against the generations' commit, arm, the same frames:

| | before | after | |
|---|---:|---:|---:|
| mini-doom, a frame | 18,939,281 | 15,640,249 | 0.83 |
| mini-quake, a frame | 27,818,178 | 23,216,278 | 0.83 |
| cameltry, a frame | 2,430,548 | 2,195,076 | 0.90 |
| mini-ml compiling simple/Lower.ml | 2,892,509,355 | 2,794,784,608 | 0.97 |
| Typing.ml | 2,002,063,112 | 1,923,369,827 | 0.96 |
| ssa/Ssa_build.ml | 2,018,406,147 | 1,943,874,625 | 0.96 |

`bench.sh 5`: samples 14.54 million to 11.95 (0.82), limbs 16.95 to
16.01, pixels 37.86 to 37.10 (both back to before the barrier). Since
this morning's HEAD: mini-doom's frame 33.0 million to 15.6 (0.47),
mini-quake's 38.6 to 23.2 (0.60), mini-ml compiling 9.22 thousand
million to 6.66 (0.72).

Checked: tests/tiny and tests/runtime (new: string_equal, every way a
string is made; float_compare, NaN and the infinities against the
runtime's answers) on arm and arm64, -O3 and -O0, ML_HEAP=64,
ML_YOUNG=4096; lite.sh's "ix built by ix" job on a copy of the tree;
the frames the same bytes; mini-ml built by mini-ml writes the same
assembly as by OCaml. Not run: mini-9pi, the kernels' check-all.

2026-10-23, **mini-doom's frame, item by item** (the author: "yes. You
can use doom"; another session's measures against OCaml 4.14 on
arm64: doom's frame 2.5 times OCaml's instructions, 3.5 once doom's
min and max are Int's). mini-doom built from HEAD first faulted at its
start (its music rendered whole, a block past the largest: 9f1766f4,
bugs/ix.md). Then mini-prof on a frame (arm, frames 31 to 61), and
what it named, each measured:

| | mini-doom, a frame | |
|---|---:|---|
| HEAD (19b70c51 and 9f1766f4) | 18,303,390 | |
| `land`, `lor`, `lxor` with a small constant an immediate; no jump to the block written next | 17,990,013 | 0.983 |
| `floor` and `ceil` by the processor's conversion within an int's range (the C library's, modf's, 5% of a frame) | | |
| `min` and `max` (Pervasives', Int's, and a unit's `let min = Int.min`) inline on ints or floats | 17,067,865 | (both: 0.949) |
| arm: R14 a sixth value register in a function with no BL but calls | 16,858,292 | 0.988 |
| arm: an unchecked byte at a shifted register offset (`R8->1(R1)`), one instruction for three | | |
| `/` and `mod` by a constant power of two by shifts, not arm's `_div` | 16,428,729 | (both: 0.975) |

The frame the same bytes. 18.30 to 16.43 million, 0.90; mini-ml
compiling Lower.ml, Typing.ml, Ssa_build.ml: 6.52 thousand million to
6.07 (0.93). The span's loop (map_plane, 15% of a frame): 47
instructions a pixel to 39.

Left, by the profile: the span's and the column's loops are still
twice OCaml's, mostly tags (a byte loaded then tagged, then untagged
to index: ARM's shifted operands could fold an add and a tag) and
their invariants reloaded (arm's 6 registers); arm's `_div` 4.8% (the
divisions by a variable: principia's div.s a bit a turn; CLZ would
need the assembler's, the VFP's division the FPU in every C program);
`ml_floor` 1.9% (a call of C, a float allocated); the allocations
(`ml_alloc`, `copy`, `make_vect`: 7%).

Checked: tests/tiny and tests/runtime (new: floor, min_max, div_pow2)
on arm and arm64, -O3 and -O0; lite.sh's "ix built by ix" job on a copy
of the tree; mini-ml built by mini-ml writes the same assembly as by
OCaml. Not run: mini-9pi, the kernels' check-all.

2026-10-26, **arm's division by a variable** (the author: "let's do 1,
2, 3", the third the leftovers above). The C library's `div<>`
(lib_core/libc/arch/arm/div.s), behind `_div`, `_mod`, `_divu`,
`_modu`: 32 turns always, but for the numerator's zero bytes skipped,
7 instructions a turn. Now the denominator is first shifted under the
numerator's highest bit, by a binary search of compares with the
numerator shifted 16, 8, 4, 2, 1 (arm's shifted operand, no CLZ:
neither mini-asm nor mini-ld nor the emulators have it), then a turn
for each bit of the quotient, 6 instructions, the bit by ADC: about
20 + 6(q + 1) for a quotient of q bits, at most 212; the old loop in
comments beside it. Measured in a worktree of HEAD (the shared
tree's mini-ml has another session's work in progress):

| | old | new | |
|---|---:|---:|---|
| mini-ml (arm) compiling Typing.ml, instructions | 1,949,357,378 | 1,904,368,736 | 0.977 |
| mini-doom's frame (frames 1 to 31) | 12,833,918 | 12,795,550 | 0.997 |

The same Typing.5 and the same frame 31, byte for byte. mini-doom's
4.8% of the 23rd was spent since: `_div` is not in its 25 first
functions now (the frame 12.8 million, its divisions by a constant
power of two shifts); the compiler's Hashtbl's `mod` by a variable is
where it still pays. New: lib_core/libc/tests/div_check.c (/ and %,
signed and unsigned, against a long division by shifts: the edges and
a million pairs), in mem_check.sh and lite's libc job. Left of the
23rd's list: `ml_floor`'s call and the allocations, which
plan_ml_floats.md's unboxed floats change (another session's, in
`ssa/` now).
