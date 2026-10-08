# editors/drscheme: TinyDrScheme

DrScheme in small: a program's text above, a prompt below, Run, and
Beginning Student's stepper. The author's playground's
`apps/devtools/TinyDrScheme.ml` (`~/playground`), on mini-scheme
(`languages/scheme/`), `lib_gui/` and `lib_playground/`. On Linux it is
built by dune with the platform that writes a frame to a file
(`tests/frames.sh`); on mini-9pi by the `mkfile`, in a window of
mini-rio's or on the bare screen. The plan:
[`plan_scheme.md`](../../docs/plans/done/plan_scheme.md).

The numbers below are `scripts/playground_copies.sh editors/drscheme`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

One file, `TinyDrScheme.ml`: 783 lines there, 797 here. Its text is
the playground's: what it leaves unused stays.

## What changed

26 lines are not the playground's (the file's `ix:` line says them):

- its last line is ix's, `Playground_platform.run_app` given the flags
  and the capabilities;
- the machine's fuel and the stepper's limit are said, where they were
  optional;
- a string's characters are taken without a `Seq`, an `Option.value` is
  written out, `text_view`'s x and y are a pair;
- Enter at the prompt takes the frame's typed text with it.

## What is ix's own

`tests/frames.sh` and `frames.expected`: its frames' sums and, where
the playground is there, its golden frame pixel by pixel. `mkfile`.

## What remains in the playground

The other programs of `apps/devtools`: `TinyTurboPascal` (mini-pascal's
window, [`plan_pascal.md`](../../docs/plans/plan_pascal.md)), `TinyBasic`,
`TinyEmacs`, `TinyVi`, `TinyScratch`, `TinySnap`, `TinySmalltalk80`
and `TinySqueak` (whose start is `languages/smalltalk`'s `Squeak`).
