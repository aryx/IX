# languages/pascal: mini-pascal

Pascal (Wirth, 1970) compiled to P-code and run on a P-machine,
Pascal-P's scheme (1973) and UCSD Pascal's, after the author's
playground's `languages/pascal` (`~/playground`): `Pascal_lexer` (the
text to tokens), `Pascal_compile` (one pass of recursive descent that
checks the types and emits the code as it reads, no tree), `Pcode`
(the stack machine's instructions, their listing), `Pmachine` (the
machine: frames, static links; a `Talk` program of `lib_terminal`'s,
so that `readln` waits for a line), `Pdebug` (a paused machine read as
Pascal) and `Pascal_disk` (the classics: the eight queens, the towers
of Hanoi). The plan: [`plan_pascal.md`](../../docs/plans/plan_pascal.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh languages/pascal`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

The directory whole: 6 modules and their test, 16 files, 2,405 lines
there and 2,407 here.

## What changed

41 lines are not the playground's:

- `Pascal_compile`: `check_type`'s place is said, where it was
  optional.
- `Pmachine`: `resume`'s pause is said (it was never:
  `fun _ -> false`).
- `tests/Test.ml`'s header is ix's two lines; `tests/Unit_pascal` keeps
  its own optional arguments: a test is OCaml's, mini-ml does not
  compile it.

`Pascal_lexer`, `Pcode`, `Pdebug` and `Pascal_disk` are the
playground's but for their header, and the interfaces its bytes but
`Pmachine`'s.

## What is ix's own

- `CLI`, `Main`: the command `mini-pascal`.
- `tests/differential.sh` and its six programs (`tests/*.pas`): the
  same program by OCaml's mini-pascal and by mini-ml's.

## What remains in the playground

Nothing of `languages/pascal`. Its IDE is `editors/turbopascal/`.
