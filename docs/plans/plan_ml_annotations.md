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
  (16 at -O3);
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

## Status

2026-10-29: plan written; nothing done.
