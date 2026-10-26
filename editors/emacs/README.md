# editors/emacs: mini-emacs

An Emacs in small, written anew after efuns: Fabrice Le Fessant's
Emacs in OCaml (INRIA, 1998), the author's since 2015 (`~/efuns`, and
its book, `efuns.nw`). The plan:
[`plan_emacs.md`](../../docs/plans/done/plan_emacs.md).

Every key is a command looked up in a table, and a command is a
function on the editor's one structure: Emacs's idea without its Lisp.
`Start.mli` draws a key's way from the keyboard to the screen.

## What is efuns' and what is not

efuns' design is kept: one type for the editor, its buffers, its frames
and its windows, changed in place, a global; keymaps (the buffer's, its
modes', the editor's) and prefixes; major and minor modes as OCaml
values; the minibuffer a buffer in a frame of one row; and the names
(`Ebuffer`, `Frame`, `Top_window`, `Keymap`, `Action`, a command's
name as `M-x` says it). A file whose design is one of efuns' says so in
a line.

No file of efuns' is here. What is done another way, each simpler for
the same result (the plan's "Where it deviates"):

- the screen made whole from the text at each key, and the difference
  sent (`Curses.refresh`), where efuns repairs its lines; a frame keeps
  its rows for a key that only moves the point (`Frame.cache`);
- the colors asked of the mode when a frame is drawn, for the lines
  shown, where efuns keeps an attribute for each character;
- `Text` is the gap buffer, points, undo and a search, nothing else;
- a variable is a field or a mode's own table, not a value found by
  its name (efuns' `Store` and `Var`, with `Obj.magic`);
- a command is a line of a list given to `Action.define`, not
  `[@@interactive]` and a preprocessor;
- one thread; the configuration is OCaml compiled with the program
  (`Config`, and the author's, `Config_pad`), not a file of options;
- a search's syntax is `Regex`'s (egrep's), not Emacs's backslashes;
- a window is the tree alone, with no link upward.

## The directories

| | | `.ml` | `.mli` |
|---|---|---:|---:|
| `core/` | the structure: `Efuns` (the types), `Text`, `Ebuffer`, `Frame`, `Window`, `Top_window`, `Keymap`, `Action`, `Globals` | 1,047 | 606 |
| `features/` | the commands: `Move`, `Edit`, `Scroll`, `Copy_paste`, `Search`, `Minibuffer`, `Interactive`, `Multi_buffers`, `Multi_frames`, `Transform`, `Macros`, `Indent`, `Highlight`, `Emouse` | 825 | 368 |
| `modes/` | OCaml, C, assembly, Smalltalk, Scheme, Pascal, Prolog; `Paren_mode`; `Dired`, `Buffer_menu` | 223 | 75 |
| top | `Config` (the keys, the modes by a file's name), `Config_pad`, `Start` (the editor made, for a host) | 210 | 153 |
| `tty/`, `sdl/`, `draw/` | the three mains | 204 | |

(`wc -l`, 2026-10-26; the `.mli`s with their header comments, which
`make loc` does not count.) The highlighters are their languages', not
mini-emacs's: `lib_code/` and each language's `highlight/`
(`lib_code/README.md`); OCaml's names (a parameter, a local, a field)
by mini-ml's parser (`languages/ml/highlight/Names_ml`).

## Running it

    bin/mini-emacs-tty file        in a terminal (dune's and mini-mk's)
    bin/mini-emacs file            a window on Linux (dune's alone: SDL)
    emacs file                     on mini-9pi, in a window of mini-rio's
                                   or on the bare screen (on the card)

`-q` leaves out the author's configuration: Emacs's keys and a
terminal's eight colors, where `Config_pad` has codemap's colors (wheat
on DarkSlateGray), dircolors' in a directory, `M-g` and a few more.
`-h` says the rest.

The keys are Emacs's (`Config.keys`):

| | |
|---|---|
| moving | `C-f C-b C-n C-p C-a C-e`, `M-f M-b`, `M-< M->`, `C-v M-v C-l`, `M-g g` a line, the arrows |
| editing | `C-d DEL`, `C-j` a new line indented, `TAB` (in a language's mode: the line before's indentation, then two more), `C-_` or `C-x u` undo |
| the kill ring | `C-@` the mark, `C-x C-x`, `C-w M-w`, `C-k M-d M-DEL`, `C-y M-y` |
| searching | `C-s C-r`, `M-C-s` a regexp, `M-%` replace (y, n, !, q) |
| words | `M-u M-l M-c`, `C-t`, `M-q` a paragraph filled |
| files, buffers | `C-x C-f` (a directory is a Dired buffer), `C-x C-s C-x C-w`, `C-x b`, `C-x k`, `C-x C-b`, `C-x C-c` |
| windows | `C-x 2 3 o 0 1`; a click and the wheel |
| macros | `C-x ( C-x ) C-x e` |
| the rest | `M-x` a command by its name (completed by TAB), `C-g` |

Not there: a redo, `M-x compile` and a shell (a process read by the
editor: a plan of its own), keys that indent or close by themselves,
the types of OCaml's names, a right-to-left text; in a window, Plan 9's
font has Latin-1 only.

## Tests

- `tests/Test.exe`: the unit tests (the text, against a string changed
  the plain way; the keys, the maps, the columns; a wide character's
  cells; the windows' tree).
- `tests/keys.sh`: sessions, each a file and a line of keys
  (`mini-emacs-tty -keys`), the screen they leave against
  `keys.expected`, some with their colors, and pictures' sums
  (`frames.expected`, `-frame`); the same by dune's build and by
  mini-ml's (`-5`: arm, under mini-5i).
- `tests/terminal.py`: the program in a pseudo-terminal.
- `tests/colors.sh`: the colors of the lines shown against the whole
  text's, on ix's sources (some minutes; not in `make test`).

`survey.sh` gives the plan's numbers: efuns' files, what of OCaml
mini-ml has not in them, the playground's highlighters.
