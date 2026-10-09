# apps/office/formula: a spreadsheet's formulas

The author's playground's `languages/formula` (`~/playground`): what
is typed in a cell (`=A1+SUM(B1:B3)`) read and computed. `../sheet/`'s
`Sheet` is written with it, for the 7GUIs' Cells (`examples/`) and
mini-office's sheets. It was `languages/formula/` here too until
2026-10-09 (the author: "it is not in the same class than the other
languages/"). The plan: [`plan_gui.md`](../../../docs/plans/done/plan_gui.md).

- **Copied**: the directory whole, `Formula.ml` and `Formula.mli`, 360
  lines.
- **Changed**: nothing but the `.ml`'s header and its line that says
  where it comes from.
- **Remains in the playground**: nothing.

To check: `scripts/playground_copies.sh apps/office/formula` (against
the playground at `028d8abf`, 2026-10-06).
