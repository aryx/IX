# apps/kits: what programs of a kind share

The author's playground's `appkits/` (`~/playground`), the part two
programs here ask: `Undo` (a history of states, undone and redone),
Gui7Circles' (`examples/`) and mini-office's (`apps/office/`). The
plan: [`plan_gui.md`](../../docs/plans/plan_gui.md).

`Sheet` and `Sheet_view` were here until 2026-10-09: they are
`apps/office/sheet/`'s, with the formulas they are written in
(`apps/office/formula/`) and the other kits mini-office stands on
(the author: "let's move the Sheet to apps/office/sheet").

The copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). To check:
`scripts/playground_copies.sh apps/kits` (against the playground at
`028d8abf`, 2026-10-06).

- **Copied**: `Undo.ml` and `Undo.mli`, 130 lines there and 131 here.
- **Changed**: `start`'s limit and `record`'s name are said, where
  they were optional (100, none).
- **Remains in the playground**: the rest of `appkits/` (what
  `apps/office/` has of it is said there).
