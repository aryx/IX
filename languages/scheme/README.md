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
- `Scheme_secd` (316 lines): a second machine for the same programs,
  Landin's SECD (1964), the first abstract machine for a language of
  functions and the CESK machine's ancestor. `-secd` runs by it,
  `-secd -trace` prints its four registers (the stack, the
  environment, the control, the dump) before each step, and
  `-landin` takes away the one rule that is not of 1964: a call in
  tail position then saves on the dump as any other, and `-s` says
  how deep a loop took it (a frame a turn; none with the rule). It
  runs `Scheme`'s expressions as they are, an application's parts
  put on the control and then `ap`: Landin's machine, not
  Henderson's compiled one (Lispkit, 1980). The values, the built-ins,
  the prelude and the errors' texts are the first machine's; a
  continuation is the four registers kept. Its state is changed in
  place and its store an array, where the CESK machine's is a value
  and a map: the eight queens' 92 boards take it 0.39 s where the
  first takes 0.88 (OCaml's build), 1.6 s and 4.6 s by mini-ml's
  (arm64, 2026-10-10), and that difference is the store's more than
  the machine's.
- `tests/Unit_scheme_secd`: the two machines on the same programs,
  the dump's depth with and without the rule, a trace's lines.
- `tests/differential.sh` and `tests/queens.scm`: the same program by
  OCaml's mini-scheme and by mini-ml's, and by the two machines.

## What remains in the playground

`languages/sexpr/tests` (`Unit_sexpr`, 4 files).
