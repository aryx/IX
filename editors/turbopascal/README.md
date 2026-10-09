# editors/turbopascal: mini-turbopascal

Turbo Pascal 7's IDE in small, on mini-pascal (`languages/pascal/`):
the blue editor, the menus, F9 compiles, Control-F9 runs, an error with
the cursor on it, the P-code of the cursor's line, and the debugger
(trace into, step over, breakpoints, watches, the call stack). The
author's playground's TinyTurboPascal (`~/playground`). The plan:
[`plan_pascal.md`](../../docs/plans/done/plan_pascal.md).

The IDE (`editor/`) is a `Tui` program of `lib_terminal`'s: a model, a
key, a screen of cells; it knows no screen and no keyboard. A host
gives it both:

- `hosts/draw/`: a window of mini-rio's, or the bare screen, under
  mini-9pi: `turbopascal` on the card (`mini-mk O=5 OS=plan9`).
- `hosts/sdl/`: a window on Linux: `bin/mini-turbopascal` (dune's
  alone: SDL).
- `tty/`: the terminal one types in (`Tty_unix`), Linux's:
  `bin/mini-turbopascal-tty`, by dune and by mini-mk.

The two windows show the same picture: a grid of cells, each a
character of Plan 9's default font (9 by 15 pixels) in the PC's 16
colours, the PC's box characters drawn as lines (the font has Latin-1
only). A window made larger has more rows and columns, not larger
letters. The windows themselves are `lib_terminal/hosts/`'s
(`Window_sdl`, `Window_draw`), since mini-emacs has the same; here are
the two programs' mains. `Cells` there is what the windows share: from
the screen shown and the next one, the cells that changed, painted on
a surface (a rectangle filled, a character drawn); the draw device is
one surface, `Picture` another (the font's bits read here, a picture
in memory: SDL's, and a file's).

    bin/mini-turbopascal                  80 by 24, a pixel of the font 2 by 2 of the screen's
    bin/mini-turbopascal -scale 1 -rows 40 -cols 100

F9 compiles, Control-F9 runs, F10 opens the menus, F7 and F8 step;
Alt and a letter is a menu on Linux (on mini-9pi Alt is Plan 9's
compose key: F10); `-h` says them.

`Keys` is the IDE with no host: `mini-turbopascal-tty -keys 'A-c =p'`,
the screen those keys leave, as text (`16x60` in it: the screen
resized), or with `-frame f.ppm` as the picture a window shows.
`tests/keys.sh` compares the playground's five sessions' screens and
eight at other sizes (`keys.expected`), and eight pictures' sums
(`frames.expected`), by dune's build and by mini-ml's. On mini-9pi:
`make -C kernels/9pi check-turbopascal`, two recorded sessions under
QEMU (the bare screen; a window of mini-rio's, resized).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh editors/turbopascal`'s, against
the playground at `028d8abf` (2026-10-06).

## What was copied

`appkits/editor`'s `Tui_turbo` and its five `Turbo_*`, with
`Turbo_model.mli` (types alone): 13 files, 1,250 lines there and 1,268
here.

## What changed

71 lines are not the playground's:

- **The screen's size is the model's** (`rows`, `cols`; a `Tui.Resize`
  changes them), where it was 80 by 24 in numbers: the text's window,
  the bars, the dialogs' place, the user screen of a program started.
  Never less than 7 by 20; no Watches window where it would leave
  fewer than three lines of text.

- `Turbo_view`: `attrs`'s bold and `frame`'s double and title are said,
  where they were optional; `frame`'s corner is a pair (it had eight
  parameters: mini-ml's most for arm is seven).
- `Turbo_update`, `Turbo_edit`: `Vt.key`'s alt is said, three
  `Option.value` written out.

## What is ix's own

`Keys`; the hosts' mains (the windows, `Cells` and `Picture`, 551
lines, written for it, are now `lib_terminal/hosts/`'s);
`tty/Main` (the playground's `apps/devtools/tty/TinyTurboPascal.ml` is
one line, here with `-keys`, `-frame` and `-h`); `tests/keys.sh`; the
mkfiles.

## What remains in the playground

- `apps/devtools/TinyTurboPascal.ml`, the IDE as a picture by the
  playground's Textmode way and its font of strokes: not wanted here
  (the plan: Plan 9's font, a cell a character).
- The rest of `appkits/editor`: vi and Emacs (`Tui_vi`, `Tui_emacs`,
  `Emacs_*`, `Gap_buffer`).
