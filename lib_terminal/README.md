# lib_terminal: a terminal as data

The author's playground's `libs/terminal` (`~/playground`): `Vt` (a
VT100's screen: the bytes a program writes made cells, a key made the
bytes a program reads), `Line_discipline` (a line typed and edited
before the program has it) and `Talk` (a program that asks for a line
and waits, as a value stepped by who runs it): what mini-pascal's
machine is written with (`languages/pascal/`, its `readln`). And a
full-screen program's two: `Curses` (a screen of cells as a value, and
the bytes that make a terminal showing one show another) and `Tui` (a
model, a key or a tick, a screen), with `unix/Tty_unix`, the host that
is the terminal one types in: what mini-turbopascal's IDE is written
with (`editors/turbopascal/`). The plan:
[`plan_pascal.md`](../docs/plans/plan_pascal.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh lib_terminal`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

6 modules, 12 files, 1,546 lines there and 1,563 here.

## What changed

Optional arguments are said, mini-ml having none; 36 lines are not the
playground's:

- `Vt`: `key`'s `alt` (it was false).
- `Talk`: `run`'s seed and `start`'s baud (1; None: at once).
- `Curses`: `put`'s and `box`'s attrs (they were `Vt.plain`); and
  `cursor_at`, where the cursor is, for a host that draws the cells
  itself.

And `Tui` has an event more, `Resize`: the host's screen has another
size, its rows and columns (a window made larger has more rows, not
larger letters).

`Line_discipline` and `Tty_unix` are the playground's but for their
header.

## What remains in the playground

Its tests (10 files).
