# languages/scheme: mini-scheme

A small Scheme and How to Design Programs' Beginning Student, after
the author's playground's `languages/scheme` and `languages/sexpr`
(`~/playground`), here in one directory: `Sexpr`, `Sexpr_read`
(s-expressions read, each part with its place in the text), `Scheme`
(the values, the code, printing), `Scheme_image` (2htdp/image's images
as data), `Scheme_syntax` (the special forms checked, the derived ones
rewritten), `Scheme_prims` (the built-ins), `Scheme_prelude` (map,
filter, sort... in Scheme), `Scheme_eval` (the CESK machine: call/cc,
tail calls, fuel) and `Scheme_step` (Beginning Student's stepper).
mini-drscheme (`editors/drscheme/`) is its window. The plan:
[`plan_scheme.md`](../../docs/plans/done/plan_scheme.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh languages/scheme`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

The two directories whole but `sexpr`'s tests: 9 modules and
`scheme`'s tests, 24 files, 2,206 lines there and 2,220 here.

## What changed

62 lines are not the playground's:

- `Scheme_eval`: its two maps are `lib_core`'s `Map_` (mini-ml has no
  functor), and the fuel is said, where it was optional.
- `Scheme_step`: the most steps is said.
- `Scheme_prims`: `Scheme_image`'s names said in full, and a string's
  characters taken without a `Seq`.
- `tests/Unit_scheme`, `tests/Unit_scheme_step`: the fuel and the most
  steps said.

The six others are the playground's but for their header (`tests/Test`'s
is ix's two lines), and the interfaces its bytes but `Scheme_eval`'s
and `Scheme_step`'s.

## What is ix's own

- `CLI`, `Main`: the command `mini-scheme`, a prompt.
- `tests/differential.sh` and `tests/queens.scm`: the same program by
  OCaml's mini-scheme and by mini-ml's.

## What remains in the playground

`languages/sexpr/tests` (`Unit_sexpr`, 4 files).
