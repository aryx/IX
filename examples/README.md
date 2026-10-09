# examples: small programs that each show one thing

From the author's playground's `examples/` (`~/playground`), those
about a GUI and about How to Design Programs' worlds:

- the 7GUIs, a toolkit's benchmark of seven tasks: `Gui7Counter`,
  `Gui7Temperature`, `Gui7Flight`, `Gui7Timer`, `Gui7Crud`,
  `Gui7Circles`, `Gui7Cells`;
- `gui4/`: five of the tasks written four ways (immediate, retained,
  MVC, MVU), which `GuiFourWays` shows side by side;
- `GuiWidgets`: each widget of `lib_gui`'s;
- `BigBangRocket`, `BigBangWorm`: `big-bang` programs
  (`lib_playground/ways`'s `Bigbang`).

On `lib_playground/`, `lib_gui/`, `apps/kits/` (`Undo`) and
`apps/office/` (Gui7Cells' sheet and its formulas). On Linux a program is built by dune with the
platform that writes a frame to a file (`tests/frames.sh`); on mini-9pi
by the `mkfile`. The plan: [`plan_gui.md`](../docs/plans/done/plan_gui.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh examples`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

27 files, 2,418 lines there and 2,457 here: 11 programs, `gui4/`
whole (6 modules) and its test. A program's text is the playground's:
what it leaves unused stays.

## What changed

117 lines are not the playground's:

- Each program's last line is ix's, `Playground_platform.run_app` given
  the flags and the capabilities (`lib_playground`'s
  `Playground_platform.mli` says why).
- What was an optional argument of `lib_gui`'s is said (a gap, a
  button's `enabled`, a grid's spans).
- `gui4/`: the MVU way's messages are a type (`msg`), where they were
  polymorphic variants; `Gui4`'s `retained` takes its `before`.
- `BigBangRocket`, `BigBangWorm`: the handlers are `Bigbang`'s record.

## What is ix's own

`tests/frames.sh` and `frames.expected` (each program's frame, its
sum), `mkfile`.

## What remains in the playground

87 files, 10,500 lines, each about a part of the playground ix has
not, or has not asked yet: `Physics*` (15), `Ai*` (13), `Povray*`
(7), `Audio*` (6), `Image*`, `Raytracing*`, `Logo*`, `Juice*`,
`PuzzleScript*`, `Universe*`, `Karel`, `Textmode`, `Teletype`,
`Typeset`, `Http`...
