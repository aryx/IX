# apps/kits: what programs of a kind share

The author's playground's `appkits/` (`~/playground`), the part the
7GUIs of `examples/` asked: `Undo` (a history of states, undone and
redone), `Sheet` (a spreadsheet's cells, each recomputed when what it
reads changes; its formulas are `languages/formula`'s) and
`Sheet_view` (how one is drawn, in `lib_gui`'s paint). The plan:
[`plan_gui.md`](../../docs/plans/plan_gui.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh apps/kits`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

3 modules, 6 files, 764 lines there and 767 here, three of the
playground's folders made one:

| module | there |
|---|---|
| `Undo` | `appkits/document` |
| `Sheet` | `appkits/sheet` |
| `Sheet_view` | `appkits/sheet_view` |

## What changed

24 lines are not the playground's:

- `Sheet`: its cells are `lib_core`'s `Map_`, where they were a
  `Map.Make` (mini-ml has no functor).
- `Undo`: `start`'s limit and `record`'s name are said, where they
  were optional (100, none).
- `Sheet_view`: `draw`'s selection is said (None: none).

## What remains in the playground

The rest of `appkits/`, 197 files:

- `document/`'s `Clipboard`, `Document`, `Saved`.
- The other kits: `astronomy`, `blocks`, `browser`, `cad`, `diagram`,
  `draw`, `editor`, `indexed`, `modeler`, `money`, `nls`, `paint`,
  `pim`, `pushpull`, `richtext`, `sketch`, `slides`, `teletype`, `tui`,
  `typeset`.
- Its tests (52 files).
