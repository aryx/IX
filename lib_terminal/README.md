# lib_terminal: a terminal as data

The author's playground's `libs/terminal` (`~/playground`): `Vt` (a
VT100's screen: the bytes a program writes made cells, a key made the
bytes a program reads), `Line_discipline` (a line typed and edited
before the program has it) and `Talk` (a program that asks for a line
and waits, as a value stepped by who runs it). What mini-pascal's
machine is written with (`languages/pascal/`, its `readln`). The plan:
[`plan_pascal.md`](../docs/plans/plan_pascal.md).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The lists and
the numbers below are `scripts/playground_copies.sh lib_terminal`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

3 modules, 6 files, 1,196 lines there and 1,203 here.

## What changed

Optional arguments are said, mini-ml having none; 18 lines are not the
playground's:

- `Vt`: `key`'s `alt` (it was false).
- `Talk`: `run`'s seed and `start`'s baud (1; None: at once).

`Line_discipline` is the playground's but for its header.

## What remains in the playground

- `Curses`, `Tui`: a screen of characters drawn by a program.
- `unix/Tty_unix`: the host's terminal made raw.
- Its tests (10 files).
