# Plan: annotations that check what mini-ml makes of a hot path

The author (2026-10-29), on OCaml's `[@@noalloc]`: "I like this
[@@noalloc] annotation to help the compiler optimize things. I was
actually thinking to have a [@@tailrec] that ensure the function is
compiled in a tail recursive manner (I think Scala has such a thing),
and I was wondering if we could have also an [@@inline] to check the
function will be inlined because small and would satisfy the mini-ml
inlining criteria, maybe a [@@register] or something. We could invent
more annotations. [...] ML of course is a high level language, and we
usually want to go far away from the machine, but sometimes for
critical code path, we don't want to switch to C or assembly but
still have some control on the generated code and have assumptions
validated about its performance", then "yes let's write a plan
document for it".

## The idea: assertions, not hints

A hint asks the compiler for something it may not do (GCC's
`always_inline`, Rust's `#[inline(always)]`, GHC's `INLINE`). A
checked annotation states what the code must compile to, and the
compiler refuses the program when it does not: the meaning is the
same, the program faster or not built, and the day a change breaks a
hot loop (a call no longer in tail position, a tuple allocated per
turn) the build says so, with the line. That is what is wanted here:
the performance of a critical path written down as something checked.

What other languages have:

| | language | kind |
|---|---|---|
| `@tailrec` | Scala | checked: an error if a recursive call is not a tail call |
| `tailrec fun` | Kotlin | checked |
| `[@tailcall]` on an application | OCaml (4.03) | warning 51 if the call is not a tail call |
| `[[clang::musttail]]` | Clang | checked: the call a tail call, or an error |
| `[@inline]`, `[@inlined]` | OCaml (flambda) | hints, warning 55 when inlining is impossible |
| `[@@noalloc]` on an external | OCaml | a promise to the compiler (no allocation, no raise): its C call without caml_c_call's bookkeeping; not checked |
| `[@zero_alloc]` | Jane Street's OCaml (flambda-backend) | checked statically: the function, after inlining, allocates nothing |
| `INLINE`, `SPECIALIZE`, `UNPACK` | Haskell (GHC) | hints |
| `#[inline(always)]`, `#[cold]` | Rust | hints |
| `always_inline`, `hot`, `cold`, `pure` | GCC | hints (an error for some) |
| `@inbounds`, `@simd` | Julia | hints, unsafe |

## Where mini-ml is

Its lexer reads `[@@deriving]`, `[@@class]` and `[@@instance]` (mlpp's)
and skips every other attribute (Lexer.mll's `attribute`); ix's code
already has OCaml's own for ocamlopt (mini-5i's `let[@inline]`,
machine/). OCaml 4.14 ignores an attribute it does not know, so new
ones cost nothing to ix's other compiler (ix compiles with both); one
that OCaml knows keeps OCaml's meaning (`[@tailcall]`, `[@inline]`),
so that both compilers mean the same.

What mini-ml already decides, which the checks read:
- tail calls: Lower's `tail` (a call in tail position, the stack
  machine's tail call and ssa/'s `Tail`);
- inlining: Lower's `inline_candidate`, a body within `inline_most`
  (24 at -O3 since 2026-10-29, 16 before);
- allocation: ssa/'s `Alloc` instructions, a closure's, a float boxed
  (Unbox's `Box`), a call of the runtime that allocates (Alloc's
  safepoints);
- doubles unboxed: Unbox's.

## The annotations, in order

1. **`[@tailcall]` on an application, `[@@tailrec]` on a `let rec`.**
   The first OCaml's: this call is a tail call. The second Scala's:
   every call of the function in its own body is a tail call. Checked
   in Lower; the error names the call and why ("not a tail call: in a
   `try`", "an argument computed after"). Protects the loops written
   as recursion (mini-ml's own passes, the games' loops).
2. **`[@zero_alloc]` on a function.** Its body, after inlining,
   makes no block, no closure, boxes no float and calls nothing that
   may allocate; a raise allowed (its exception made beforehand), and
   a call of a function itself `[@zero_alloc]`. Checked on ssa/'s form
   (-O3; at -O0 an error says it needs -O3). The one for the games'
   inner loops, where the collector's work per frame is what is
   measured. Jane Street's name and meaning, so that their papers and
   ours read alike.
3. **`[@inline]` checked.** On a function: it is inlined at each call
   of it (mini-ml's criteria: its size within `inline_most`, no
   recursion); an error says its size against the bound. OCaml's
   flambda reads the same attribute as a hint.
4. **A double kept unboxed: `[@unboxed]` on a `let` or a `ref` of a
   float.** The value never boxed (Unbox's decision): in a register
   or in a double's slot. An error names what boxes it (passed to a
   function, stored in a block).

Each a commit, with tests/annotations/: for each annotation a program
where it holds (compiled, run, its output) and one where it does not
(the error, its text checked), as tests/refused's.

## Not now

- **`[@register]`.** Whether a value gets a register depends on the
  machine (arm's 5 for mini-ml's values, arm64's 18) and on the whole
  function: an assertion that holds on one machine and fails on the
  other. A loop's values, when it matters, are better seen in
  `-S`.
- **`[@@noalloc]` on an external.** In OCaml it lets ocamlopt skip
  caml_c_call's bookkeeping, gcc's C saving the register its young
  pointer lives in. Under Plan 9's convention, nothing saved by the
  one called, it could skip only the store to `ml_vsp`, not taking
  the value stack's top back (plan_extern_register.md's design C);
  and unchecked, it is a promise, not an assertion. Later, if the C
  calls' cost is measured worth it.
- **Hints** (`[@cold]`, an unroll): mini-ml has no use for them yet;
  checked ones first.
- **No `ml_vsp` handoff around the C that makes nothing** (proposed
  2026-10-29, after step 2): Zero_alloc's six runtime functions run
  no collection and push no value, so a call of one could skip the
  store of the value stack's top before and its load after, part of
  design C's 3.4% back (plan_extern_register.md). Not done, the
  author: "seems fragile and could lead to bad surprise if some
  invariant change": a C function that one day allocates, or raises
  by a way that reads `ml_vsp` (ml_string_get's bound error already
  raises), would break the ML code's value stack with no check
  failing. If done one day, the list checked against the C (the
  functions' bodies, by mini-cc), not written by hand.

## Step 1 done (2026-10-29): [@tailcall] and [@@tailrec]

The author: "let's start 2". languages/ml/Annotations (the tables,
by span), the lexer's TAILCALL and TAILREC, the parser's places, and
Lower's checks (`check_tail`, in `value` and `tail`; bind_rec makes a
[@@tailrec] function the target while its body is compiled):

- `[@tailcall]` where OCaml reads it, on the function of an
  application: `(f [@tailcall]) x`; on `f x [@tailcall]` OCaml warns
  it misplaced (53) and mini-ml refuses it (a syntax error), both
  saying it is not a call's annotation there. A parenthesized
  expression keeps its mark (the parser's new span).
- `[@@tailrec]` after a `let rec` binding, at the top or before
  `in`: each call of the function in its own body made a jump. A call
  of it from a closure inside it is compiled in that closure's frame,
  not checked (Scala's @tailrec refuses it): a gap, said in Lower.
- The messages: "line 3: count [@@tailrec]: its call of itself is
  not in tail position", "line 4: this call [@tailcall] is not in
  tail position", or "is not a tail call (a primitive, or given more
  or fewer arguments than it takes)".

Tests: languages/ml/tests/annotations.sh (a make test job):
annotations/holds.ml (a loop of a million turns, two functions calling
each other, a local loop) by OCaml and by mini-ml -O3, against
holds.out; annotations/refused/'s three (a call an operand of +, a
call inside a try, a [@tailcall] call added to), each refused by
mini-ml with its .err and compiled by OCaml. Unannotated code the same
bytes (lib_core's units and five of mini-ml's own, -O3, arm and arm64:
112 objects).

Used in ix (the author: "let's add a few of those annots in IX, do
dogfood"): `[@@tailrec]` on nine of lib_core's List loops (length's,
rev_append, iter, fold_left, for_all, exists, mem, assoc, find), where
a list of any length must not grow the stack, and on CLI's two loops
over a whole file (named_units, over its tokens; named_words, over its
characters). mini-ml compiles them, arm and arm64, -O0 and -O3; a copy
with exists's call made the left operand of `or` is refused ("line
103: exists [@@tailrec]: its call of itself is not in tail
position"). So the right operand of `&` and `or` is a tail position
for mini-ml, as for OCaml.

## Step 2 done (2026-10-29): [@@zero_alloc]

The author: "let's do it". `let f x = ... [@@zero_alloc]` (Jane
Street's spelling as a binding's attribute; several after one binding,
`[@@tailrec] [@@zero_alloc]`). The parser marks the function, under
its type if it has one (anything else after the annotation a syntax
error); Lower keeps the marked functions' code labels
(Lower.zero_allocs); ssa/Zero_alloc reads each marked function's SSA
form once Unbox, Untag, Licm and Cse are done (Emit.unit_), so after
inlining and with its floats unboxed.

- Refused: a block made, a closure, a float boxed, an int32's block, a
  polymorphic comparison (compare, in C), a call of a function not
  itself marked in this unit, a call of C but six of the runtime's
  that make nothing (a string's length and bytes, = and <> on strings,
  a float array's length).
- A block of code that ends in a raise not counted: mini-ml makes the
  exception's block at each raise, Not_found's too (Jane Street's
  check leaves those paths out, unless "strict").
- Two changes from the plan above: without -ssa (at -O0, and -gas) the
  annotation is not looked at rather than an error, so that code with
  it builds at every level, nothing being promised of simple's code;
  and the error names the function's line, SSA's values having none.
- Seen at once: a local loop that captures a variable of its function
  makes a closure at each call of that function (holds.ml's
  first_digit, which gives the string to its loop instead; refused/'s
  closure.ml, which does not).

Tests: holds.ml (loops over an int array, a float array whose sum stays
a double, a string's bytes, a loop calling a marked function and
raising Not_found, both annotations on one function), run against
OCaml at -O3; refused/'s tuple, closure, boxed (a float returned) and
call (a recursive function not marked, so not inlined). Unannotated
code the same bytes (112 objects).

Not done: externals marked `[@@noalloc]` (OCaml's attribute), which
would let a marked function call C of its own; another unit's marked
functions (Summary would carry the mark); the instruction's line.
Later perhaps (the author: "we could potentially have a [@@noraise]
at some point"): `[@@noraise]`, a function that raises nothing,
checked as this one is (no Raise, no call of what may raise); with
`[@@zero_alloc]`, a C call's `ml_vsp` handoff could then be skipped.

## [@@zero_alloc] on the games' inner loops (2026-10-29)

The author: "let's do 1" (the games' loops). Marked where it holds
after the change, each game built for arm (mini-mk O=5, -O3):

- mini-doom: View.draw_column (R_DrawColumn, the walls' and sprites'
  pixels) allocated nothing already. map_plane (R_MapPlane) and
  Sprites.draw_masked_column were refused, their pixel loops clean but
  their setup boxing floats for calls of another unit's small
  functions (View.fcos, fsin, iceil: not inlined, over -O3's 16 nodes
  with what they call; iceil at 17), once a span or a post. Split
  out, map_plane's loop as id's R_DrawSpan, it held, but the call a
  span cost 0.52% of a frame: not kept, the two left unmarked.
- mini-quake: Spans.draw_spans (D_DrawSpans8) made a tuple of four
  every 8 pixels (snext, tnext, sstep, tstep): each a value of its
  own now, marked, 5.2% fewer instructions in the function, 0.35%
  fewer over a run of 61 frames, the same pixels. draw_zspans held
  as it was. turbulent (the liquids) boxed three floats and made two
  pairs every 16 pixels; rewritten without them it held, but ran 29%
  more instructions, its pixel loop's registers allocated worse
  (Alloc: about 18 instructions a pixel more): kept as it was,
  unmarked, a case for the allocator; Alloc's density since (below),
  rewritten and marked.
- Measured whole runs by mini-5i -prof and mini-prof: a frame's cost
  as the difference of two runs (31 and 61 frames) moved with where a
  collection fell (0.68% "more" for the version 0.17% fewer over the
  run).

### A story: Quake's span loop

The author: "still this quake loop is a great example of the
usefulness of this annotation! great story to record in the plan".

D_DrawSpans8 is Quake's hottest loop: each textured surface's spans,
the perspective-correct s and t computed exactly every 8 pixels (one
division), stepped linearly between. mini-quake's port read well:

    let snext, tnext, sstep, tstep =
      if !count > 0 then begin ... (snext, tnext, (snext - !s) asr 3, ...) end
      else begin ... end
    in

Nothing in it looks like an allocation, and in OCaml nothing in it
is one to the eye: a tuple returned by an if and taken apart at once.
But mini-ml, as ocamlopt without flambda, makes the block: four
fields, every 8 pixels, the whole screen's surfaces a frame. No test
saw it (the pixels were right), no profile named it (the cost spread
over ml_alloc, the minor collections and the loop itself). Marked
[@@zero_alloc], the build said, on the first try:

    render/Spans.ml: line 144: draw_spans [@@zero_alloc]: it makes a
    block (a tuple, a record, a constructor's)

The fix is the code a C programmer would have written, each of the
four a value of its own (the old one kept beside it, old:), and the
mark stays: the loop 5.2% fewer instructions, the same pixels, and
the day someone writes a tuple there again the build refuses it.
That is the annotation's point: not finding the allocation once,
which a profile might have, but the hot loop's property written in
the code and checked at each build, where a comment ("no allocation
here") would have gone stale unseen.

What it says of mini-ml: a short-lived block costs little (a bump of
the pointer, the minor collection copying nothing dead), so what an
allocation's removal gains is mostly the code around it; the call of
another unit's small float function, boxing its argument, is the
cost that recurs.

## Step 3 done (2026-10-29): [@inline]

The author: "let's do 4 and 5". `let[@inline] f x = ...` (OCaml's
place, the lexer's LETINLINE; the first binding of the let marked) or
`let f x = ... [@@inline]`.

Changed from the plan above, by what ix's code showed: ix had four
`let[@inline]` already, written for ocamlopt (machine/'s Arm32.phys and
set, Arm64.phys; lib_graphics's Jpeg.clamp, "a float crossing a call
that isn't is boxed"). Checked against -O3's 16 nodes, three were
refused: set 39 nodes, phys 28, clamp over too. mini-ml had been
calling them all along, the attribute skipped. So [@inline] has
OCaml's meaning, a function inlined whatever its size (Lower's
inline_candidate: forced_most for it, not inline_most), and the check
is what cannot be: refused when recursive ("it is recursive") or
holding a function, a try or an assertion, whose code is not copied.
Across units: a summary's entry says it is forced (Summary's magic 3),
imported whatever its size. Without -ssa (inlining off) not looked at,
as [@@zero_alloc].

The four now inlined by mini-ml at -O3, as by ocamlopt. Tests:
holds.ml's twice (let[@inline]) and mix ([@@inline], over 16 nodes; no
call of it left in its -dssa); refused/'s inline_rec and inline_try.
Unannotated code the same bytes (112 objects).

## The allocator's density, and turbulent marked (2026-10-29)

The author: "what are turbulent registers?", then "let's do 1 and 2
and 3". turbulent without its pairs had its pixel loop's every
temporary stored and loaded (MOVW R3, 24(R13); MOVW 24(R13), R1),
the five registers its loop values', which Alloc took first by their
weight, uses times 8 per loop level: a temporary used once weighed
less than a value carried around the loop, though it holds a register
an instruction or two and the other the whole loop. Now each weight is
over the points the value is live at (Alloc's density, Chaitin's spill
cost over the interference; mini-ml -by-uses the old). Measured at one
commit, both built for arm by ix (tests/inline_limit.sh's OVERLAY),
against the old: mini-doom 0.12% fewer instructions over 61 frames,
mini-quake 0.07% more, mini-ml compiling 0.11% fewer, the benchmarks
the same within 0.2%: no change on the code as it was. But turbulent
rewritten without its st and pairs: 24.7 million instructions with
the old weights, 16.6 with the density, 13% fewer than HEAD's 19.1
(with st's calls), the run 0.16% fewer, the same pixels. So it is
marked [@@zero_alloc], the rewrite kept (old: beside it).

## mini-doom's angles inlined (2026-10-29)

The author: "I think doom was famous for using lots of precomputed
table instead of computation". id's code reads its tables (finesine,
finetangent: tables.c) by a shift of an integer angle, a turn 2^32,
which wraps by itself. mini-doom's angles are floats, its tables
id's, read through View's norm (into [0, 2 pi), a floor), fine (the
index), fsin and fcos: norm alone 2.3% of 61 frames, 624,183 calls
of 42 instructions, most of it the call, its float argument and
result boxed; over -O3's 24 nodes, never inlined, and fsin and fcos
with it. Marked let[@inline], the four: 1.55% fewer instructions over
the run, the same pixels, the program 0.21% larger. Integer angles as
id's would take the floats out too, but touch every angle of the game
and its rounding: not done.

## Step 4 done (2026-10-29): [@@unboxed_float]

The author: "let's do 1 and 2 and 3", then on 3: "we might also want
to have unboxed for integers too at some point? or Int32.t ?".

`let x = e [@@unboxed_float]` or `let r = ref e [@@unboxed_float]`, a
function's local float. Named so, not the plan's [@unboxed]: ix uses
OCaml's [@@unboxed] on types (database/'s type reg = R of int
[@@unboxed]), another meaning, which a token would have had to take
too. Lower records the binding's slot by its function's label
(Lower.unboxed_floats); Ssa_build each slot's values, written and its
phis (Ssa.func's slots); Unbox.check, after every pass, refuses one
boxed (passed to a function, stored in a block or a global, returned,
raised, compared by compare), a phi of it not a double (a block around
the loop), or a call's result (a block). A first value only read (a
literal, a parameter, a field) is unboxed once, a load: allowed. In a
function with a handler Unbox does nothing, so refused there. Tests:
holds.ml's mean; refused/'s unboxed_returned and unboxed_passed.
Unannotated code the same bytes (with -by-uses: 112 objects).

Integers: an int is no block already (31 bits and a tag), and Untag
takes the tag off where its bits are known; an [@@untagged] would
check that one, a smaller gain. Int32.t is a block on both machines
(Lower.ints_in_place makes its operations the processor's, the result
in a new block): an Int32 kept in a register needs a pass as Unbox
for it first (lib_crypto's hashes, the arm emulator's words), then
[@@unboxed_int32] its check. Neither done.

## Status

2026-10-29: steps 1 to 4 done ([@tailcall], [@@tailrec],
[@@zero_alloc], [@inline], [@@unboxed_float]), used in mini-doom and
mini-quake; Alloc's density. Next, if wanted: Int32 unboxed (a pass,
then its annotation), integer angles in mini-doom.
