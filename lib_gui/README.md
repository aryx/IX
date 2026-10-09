# lib_gui: a GUI toolkit from scratch

The author's playground's `libs/gui` (`~/playground`), for teaching
how a program is built around the person using it: what a widget is
(`Widget`), where its colors and sizes come from (`Theme`), where
widgets go (`Layout`, `Grid`), a text and its editing (`Text`,
`Text_edit`), how they look (`Look`), who has the keyboard (`Focus`),
and four ways to write a program with them: `Immediate`, `Retained`,
`Mvc`, `Mvu`. It speaks rectangles and paint; `lib_playground/apis`'s
`Gui` is its adapter to the playground's shapes. What the 7GUIs of
`examples/` and mini-drscheme (`editors/drscheme/`) are written with.
The plan: [`plan_gui.md`](../docs/plans/done/plan_gui.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh lib_gui`'s, against
the playground at `028d8abf` (2026-10-06).

## What was copied

The library whole: its 12 modules, 24 files, 3,463 lines there and
3,480 here.

## What changed

Optional arguments are said, mini-ml having none; 39 lines are not the
playground's, the 12 header lines among them:

- `Layout`: `row`'s and `column`'s gap (it was 0.).
- `Grid`: an item's `rowspan`, `colspan` and `sticky`, and `make`'s gap
  and weights (1, 1, ""; 0., none).
- `Immediate`, `Mvu`: a button's and a field's `enabled` (true).
- `Immediate`: a context menu's answer is a type (`menu_answer`), where
  it was a polymorphic variant; an `Option.value` is written out.

`Focus`, `Look`, `Mvc`, `Retained`, `Text`, `Text_edit`, `Theme` and
`Widget` are the playground's but for their header, and 8 of the 12
interfaces its bytes.

## What remains in the playground

Its tests (`libs/gui/tests`, 16 files, 1,156 lines). Here the library
is checked by the programs on it: `examples/gui4/tests` (the
playground's own) and the frames of `examples/tests`.
