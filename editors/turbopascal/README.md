# editors/turbopascal: mini-turbopascal

Turbo Pascal 7's IDE in small, on mini-pascal (`languages/pascal/`):
the blue editor, the menus, F9 compiles, Control-F9 runs, an error with
the cursor on it, the P-code of the cursor's line, and the debugger
(trace into, step over, breakpoints, watches, the call stack). The
author's playground's TinyTurboPascal (`~/playground`). The plan:
[`plan_pascal.md`](../../docs/plans/plan_pascal.md).

The IDE (`editor/`) is a `Tui` program of `lib_terminal`'s: a model, a
key, a screen of cells; it knows no screen and no keyboard. A host
gives it both:

- `tty/`: the terminal one types in (`Tty_unix`), Linux's:
  `bin/mini-turbopascal-tty`, by dune and by mini-mk.
- a window with Plan 9's font, in mini-rio's and on Linux: not written
  (the plan's "The window").

`Keys` is the IDE with no host: `-keys 'A-c =p'`, the screen those keys
leave, as text. `tests/keys.sh` compares the playground's five
sessions' screens (`keys.expected`) by dune's build and by mini-ml's.

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh editors/turbopascal`'s, against
the playground at `028d8abf` (2026-10-06).

## What was copied

`appkits/editor`'s `Tui_turbo` and its five `Turbo_*`, with
`Turbo_model.mli` (types alone): 13 files, 1,250 lines there and 1,255
here.

## What changed

25 lines are not the playground's:

- `Turbo_view`: `attrs`'s bold and `frame`'s double and title are said,
  where they were optional; `frame`'s corner is a pair (it had eight
  parameters: mini-ml's most for arm is seven).
- `Turbo_update`, `Turbo_edit`: `Vt.key`'s alt is said, three
  `Option.value` written out.

## What is ix's own

`Keys`, `tty/Main` (the playground's `apps/devtools/tty/TinyTurboPascal.ml`
is one line, here with `-keys` and `-h`), `tests/keys.sh`, the mkfile.

## What remains in the playground

- `apps/devtools/TinyTurboPascal.ml`, the IDE as a picture by the
  playground's Textmode way and its font of strokes: not wanted here
  (the plan).
- The rest of `appkits/editor`: vi and Emacs (`Tui_vi`, `Tui_emacs`,
  `Emacs_*`, `Gap_buffer`).
