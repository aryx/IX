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
[`plan_pascal.md`](../docs/plans/done/plan_pascal.md).

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

`Line_discipline` is the playground's but for its header; `Tty_unix`
has `run_sized`, which asks the terminal its rows and columns. `Vt`'s
colours have `Rgb`, any colour by its red, green and blue, which
`Curses` sends; `Curses` gives a wide character two cells and puts a
combining one with the character before it (`Utf8.width`).

## What is ix's own

`hosts/`: a `Tui` program in a window, where `unix/` is the terminal.
`Cells` (what changed between two screens painted on a surface, a cell
a character of Plan 9's default font; the PC's box characters; a key
and a click as the bytes a terminal sends), `Picture` (a surface in
memory: SDL's, and a file's), `sdl/Window_sdl` (a window on Linux:
dune's alone) and `draw/Window_draw` (one of mini-rio's, under
mini-9pi). Written for mini-turbopascal (`plan_pascal.md`, "The
window"), here since mini-emacs has the same hosts
([`plan_emacs.md`](../docs/plans/plan_emacs.md), stage 6): with
`mouse`, a host says a click and the wheel as xterm's bytes for them.

## What remains in the playground

Its tests (10 files).
