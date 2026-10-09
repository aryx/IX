# Plan: an Emacs in ix: mini-emacs, written after efuns (`editors/emacs/`, `languages/*/Highlight_*`)

The author (2026-10-09): "lets write a plan for a mini_emacs, like we
did recently for mini_office amd mini_netscape; The idea would be
actually to mostly do a mini version of ~/efuns/, which itself is an
port in ocaml of most of the good ideas in Emacs; mini_emacs would
also be in OCaml, and would not need to have a lisp interpreter; the
code and plugins and so on can remain in OCaml, like in efuns; we just
need a small version of ~/efuns really. Also we will not rely on
tree-sitter so we can add some highlighters to ~/langages/ like we did
in the ~/playground/ instead". And, of a first plan that copied
efuns' files and trimmed them: "the ~/efuns/ is a source of
inspiration; you can deviate from it, especially if you find a simpler
technique that achieve similar results".

The short answer: **mini-emacs is written anew, efuns' ideas and its
vocabulary kept, its files not copied: 3,000 lines the aim, where
efuns is 17,100 (82 files) and what an Emacs cannot be without is
8,100 of them (38 files).** What makes it that small:

- **efuns draws a grid of characters**, through six functions
  (`Xdraw.graphics_backend`, 18 lines). ix has that screen already,
  and what shows it: `lib_terminal`'s `Curses` (a screen of cells as a
  value, and what changed between two of them) and the hosts written
  for mini-turbopascal (a terminal on Linux; a window of SDL's, a
  window of Plan 9's draw device). So the screen is drawn whole at
  each key and `Curses` sends what changed: none of efuns' own
  bookkeeping of what is on the screen.
- **A third of efuns is what it is to its author, not to an Emacs**:
  magit, a shell in a buffer, merlin, ocp-indent, org, TeX, the pfff
  modes, the server and its client, a file of options read at the
  start (4,800 lines).
- **Colors are not the text's**: efuns keeps a color with each
  character and lexers that set them (1,000 lines of ocamllex and
  what is around). Here a highlighter gives the colors of the lines
  shown, when they are shown: the playground's (`Highlight_ml`,
  `Highlight_c`...), put in ix beside each language.
- **Each simpler technique that does the same is taken** ("Where it
  deviates", below): eight of them proposed.

Its numbers are `editors/emacs/survey.sh`'s (run 2026-10-09, against
efuns at `9a58b65`, 2026-07-02, and the playground at `028d8abf`,
2026-10-06).

**Status: not started** (the plan only; the survey is in).

## What efuns is

Fabrice Le Fessant's Emacs in OCaml (INRIA, 1998), the author's since
2015 and the subject of a book of his (`docs/efuns.nw`). The ideas of
Emacs, typed:

- **A text** (`Text`, 1,408 lines): the characters with a gap where
  one types, the lines, the points that move with the text, a color
  for each character, what was done to undo it, a regexp searched.
- **A buffer** (`Ebuffer`): a text and its file, its modes, its
  variables (`Var`, over `Store`: a variable of any type by name, the
  buffer's, the mode's or the editor's), its keys.
- **A frame** (`Frame`, 794): a buffer seen through a rectangle of the
  screen, its lines cut or folded to the width, its cursor, its
  status line; **windows** (`Window`): the screen split in two, again
  and again; **the top window** (`Top_window`): a key or a click taken
  and given to the keymaps, the minibuffer's line, the screen updated.
- **Keys** (`Keymap`): a key or a sequence of them (`C-x C-f`) to an
  action, in the buffer's map, its modes', then the editor's.
- **Actions** (`Action`): a command by its name, for `M-x` and for a
  configuration; a mode or a plugin is OCaml code that defines some
  and binds keys to them. There is no Lisp.
- **Hooks** (`Hooks`), and the modes: a major mode a buffer (its keys,
  its colors, its indentation), minor modes over it.

All of it is one mutually recursive type (`Efuns`, 441 lines: the
editor, a buffer, a frame, a window, a mode) and values changed in
place: the editor is a global.

## What is taken from efuns

Its ideas and its names, not its files. efuns' lines (.ml and .mll),
by what mini-emacs has of them.

| | efuns | in mini-emacs |
|---|---:|---|
| `src/core`: `Text`, `Ebuffer`, `Efuns`, `Frame`, `Window`, `Top_window`, `Keymap`, `Action`, `Var`, `Hooks`, `Globals`, `Attr`, `Error` | 4,371 | all of what they do, written again |
| `libs/commons`: `Store` (a variable of any type) | 121 | what it is for, another way (below) |
| `src/features`: `Edit`, `Move`, `Scroll`, `Copy_paste` (the kill ring), `Search` (incremental, and replace), `Minibuffer`, `Select` (completion: a file, a buffer, a command), `Interactive` (`M-x`), `Multi_buffers`, `Multi_frames`, `Message`, `Indent`, `Highlight`, `Structure`, `Transform`, `Macros`, `Misc_features` | 2,934 | the commands, written again |
| modes: `Dired`, `Buffer_menu`, `Paren_mode`, `Fill_mode`, `Tab_mode`, and the two lists of modes | 647 | yes, written again |
| **what an Emacs cannot be without** | **8,073** | **aim: 3,000** |
| `src/graphics`: `Xdraw`'s six functions, X11's keys and types | 90 | as `Curses`' screen and `Tui`'s keys |
| `src/main`: the command line | 231 | small |
| the modes of languages: `Ocaml_mode`, `C_mode`, `Lisp_mode`, `Makefile_mode`, `Common_indenter` | 1,609 | a mode a language over its highlighter; the indentation is an open question |
| their lexers and colors: `ocaml_lexer.mll`, `c_lexer.mll`, `lisp_lexer.mll`, `Common_lexer`, `Pl_colors` | 1,009 | no: the highlighters |
| `src/features`, later or never: `Compil` (a compilation's errors visited), `System`, `Mouse`, `Rectangle`, `Abbrevs`, `Dircolors`, `Color` | 1,196 | a stage of their own (processes, the mouse), or not |
| `Electric` (a key that indents or closes as it is typed) | 67 | no (the author, 2026-10-09: "I don't like electric keys") |
| the author's own tools: `Magit`, `Shell`, `Outline_mode`, `Ocaml_merlin`, `Ocaml_ocp_indent`, `Bento`, `Org_mode`, `tex_mode`, `html_mode`, `Abbrevs_mode`, the sample mode, `Text_colors` | 3,101 | no |
| `libs/commons`: `Options` and `Genlex_` (the file of options), `Concur` (threads), `Utils`, `Str2`, `Log` | 1,454 | no: a configuration is OCaml, a program is one thread; `Utils`' few functions used go where they are used |
| `src/ipc`: the server and `efuns_client`; `Parameter_option` | 266 | no |
| the backends (`src/graphics/*/`) | 1,624 | no |
| the pfff modes (`modes/pfff_modes`) | 1,621 | no |

And from the playground, copied (they are the author's, and ix's
way with the playground's files): the highlighters, a source's text
to lines of colored spans (`lines : string -> span list array`), over
a lexer that never fails on a text half typed, and a guess of what
each name is (a definition, a parameter, a type).

| the playground's | .ml | .mli | here |
|---|---:|---:|---|
| `libs/code/highlight/Highlight_code` (the categories and their colors, shared) | 170 | 112 | `lib_code/` |
| `languages/ocaml/Highlight_ml`, `Token_ml`, `Lexer_ml.mll` | 729 | 33 | `languages/ml/` |
| `languages/c/Highlight_c`, `Token_c`, `Lexer_c.mll` | 507 | 33 | `languages/c/` |
| `languages/asm/Highlight_asm` | 131 | 29 | `assembler/` |
| `languages/smalltalk/Highlight_st` (over `St_lexer`, which ix has) | 359 | 46 | `languages/smalltalk/` |

ix's Scheme and Pascal have none there: to write, as these (a
hundred lines each or so, ix's `Sexpr_read` and `Pascal_lexer` at
hand).

**Not taken**: the playground's own Emacs (`Emacs_editor`,
`Emacs_simple`, `Tui_emacs`, TinyEmacs: 1,320 lines, with a Lisp). It
is the other design, an editor that is a value and a Lisp over it; the
author asked for efuns'.

## Where it deviates (proposed)

Each is a simpler way to the same result; efuns' way is said, and why
it can go.

1. **The screen drawn whole.** efuns' `Frame` (794 lines) keeps what
   each line of the screen shows and repairs it as the text changes.
   Here a frame's lines are computed from the text and written in a
   screen of cells at each key; `Curses.refresh` compares it with the
   one before and sends the difference. A screen is 2,000 cells.
2. **Colors computed, not kept.** efuns' `Text` has an attribute a
   character, set by a mode's lexer over the whole buffer, and kept
   right as the text changes. Here the highlighter is asked when a
   frame is drawn, and its answer kept until the buffer changes (one
   pass over the text for a change: its cost on a large file is to be
   measured, stage 4).
3. **A text as a gap buffer and nothing else.** efuns' `Text` (1,408
   lines) is the gap buffer, a table of its lines, the attributes,
   the points, the undo's records and the searches. Here: the bytes
   and the gap; a line's start found by scanning from a point known
   (the frame's first line, kept); points, a list of positions moved
   by each insertion and deletion; undo, a list of the inverse
   operations; a search, `Regex`'s over the text.
4. **A variable is a field or a table.** efuns' `Store` and `Var` give
   a buffer, a mode or the editor variables of any type by name
   (`Obj.magic` under them), as Emacs Lisp has. Without a Lisp
   nothing reads a variable by a name computed: what every buffer has
   is a field of the buffer's record, and what one mode keeps for a
   buffer is that mode's own table, from the buffer to a value of its
   own type.
5. **A command is a line in a table.** efuns' `[@@interactive]` (119
   uses, a preprocessor) becomes, at the end of each file, a list of
   names and functions given to `Action.define`: what `M-x`
   completes and a key is bound to.
6. **The minibuffer is a line.** efuns' is a buffer in a frame of one
   line, with its own keymap (Emacs's way: every command works in
   it). Here it is a string edited by a dozen keys, a prompt, a
   function that completes and one that takes the answer; `C-s`'s
   line is the same. What is lost: yanking and the other commands in
   the minibuffer, beyond those dozen keys.
7. **One thread, no file of options.** A process (a compilation, a
   shell) is read when `Tui` ticks, in the stage that has one;
   `Config.ml` is the configuration, OCaml compiled with the program.
8. **A search's syntax is `Regex`'s** (egrep's, as mini-awk's), not
   Emacs's backslashes over `Str`: one engine in ix.

What stays efuns': one type for the editor, its buffers, its frames
and its windows, changed in place, a global; buffers, frames and
windows as its book has them; keymaps (the buffer's, its modes', the
editor's) and prefixes; major and minor modes as OCaml values with
their hooks; and the names (`Ebuffer`, `Frame`, `Top_window`,
`Keymap`, `Action`, a command's name as `M-x` says it).

## What it requires

1. **Nothing of what efuns stands on**: semgrep's `Common` and its
   kin, `Str` (78 lines of uses), `Stream` and `Genlex`, threads (57),
   `Obj.magic`. Written anew, mini-emacs stands on `lib_core` and
   `lib_terminal` alone, and is what mini-ml takes from its first
   line.
2. **The modes linked.** A mode registers itself when its unit starts,
   and nothing names it: efuns links with `-linkall`. In ix a
   program's own units are given to the linker by name and always
   linked; only a library's unit must be named by some code (`Link`'s
   weak names, 2026-10-09). So the modes are the program's units, not
   a library's.
3. **The screen and its hosts.** The editor is a `Tui` program (a key
   in, a screen of cells out), its model the global editor. The hosts
   are mini-turbopascal's (`editors/turbopascal/hosts/`, `tty/`): they
   move to a place both programs share.
4. **The keys.** A terminal gives `C-x` as a byte, `M-x` as Escape
   then `x`, and has no `C-;`. A table from `Tui`'s keys to Emacs's
   names, and the bindings a terminal cannot say given another key.
5. **Files and directories** through capabilities, as every program
   of ix's.
6. **Tests.** Sessions, as mini-turbopascal's `-keys`: the keys
   typed, the screen they leave as text, compared with a recorded
   one, by dune's build and by mini-ml's. Unit tests of the text (the
   gap, the points, undo), with efuns' `unit_text` as the list of what
   to check. efuns itself is not run by the tests (it needs GTK): a
   session's expected screen is read by a person once.

## Decisions (proposed, for the author)

1. **The name and the place**: `mini-emacs`, in `editors/emacs/`, its
   directories efuns': `core/`, `features/`, `modes/`. A module that
   does what one of efuns' does has its name (`Ebuffer`, `Frame`,
   `Top_window`, `Keymap`).
2. **Written anew, efuns' design**: one type for the editor, its
   buffers and its frames, changed in place, a global; and the eight
   deviations above. Not the playground's editor as a value.
3. **efuns is credited, not copied**: the README says whose ideas
   these are (Fabrice Le Fessant's efuns, INRIA, 1998; the author's
   since 2015, and his book), and a file whose design is one of
   efuns' says so in a line. No file of efuns' is in ix, so its
   license (the Q Public License 1.0 for INRIA's files outside
   `commons`, by its `copyright.txt`; ix's is the LGPL 2.1) is not
   ix's question. The highlighters are the playground's, the
   author's, copied as its other files are.
4. **Not the book's code**: mini-emacs is not `efuns.nw`'s tangle and
   has none of its markers.
5. **No file of options, no Lisp**: a configuration is an OCaml file
   of the program (`Config.ml`: the keys, the colors, the modes by a
   file's name), compiled with it.
6. **A terminal first, windows after**: Linux's terminal is the first
   host, then the two windows as mini-turbopascal's are ready. The
   mouse comes with the windows.
7. **`lib_code/` for `Highlight_code`**, a top-level library as the
   playground's `libs/code`: the languages' highlighters and the
   editor both stand on it. Each highlighter beside its language.
8. **Counted in m-IX's budget** (an editor one writes programs in is a
   part of a system, as mini-ed is), 3,000 lines the aim; the
   highlighters with their languages. The budget is already passed by
   the browser's plan: this adds to what the trimming must find.
9. **A README in `editors/emacs/`**: what is efuns' idea and what is
   not, the commands and their keys, its numbers a script's; the
   highlighters in `scripts/playground_copies.sh`'s table.

## The stages (each checked before the next)

1. **The text.** `Text` (the gap, the points, undo, a search), built
   by dune and by mini-ml, its unit tests.
2. **A file on the screen.** The editor's type, `Ebuffer`, `Frame`,
   `Window`, `Top_window`, `Keymap`, `Action`, `Hooks`; `Edit`,
   `Move`, `Scroll`; the screen of cells and the terminal's keys.
   `mini-emacs file` in a terminal: typed in, moved in, saved. The
   first sessions recorded. The lines counted: the aim corrected.
3. **The minibuffer and what asks through it.** Its line and
   completion (a file, a buffer, a command), `M-x`, messages; the
   kill ring, `C-s` and replace, undo's keys; several buffers and
   windows: `C-x C-f`, `C-x b`, `C-x 2`, `C-x o`.
4. **The languages.** `lib_code/` and the four highlighters copied,
   Scheme's and Pascal's written; a frame's colors; the matching
   parenthesis; indentation; a mode a language, chosen by the file's
   name. ix's own sources in colors, and the time of a key in the
   largest of them.
5. **The rest.** `Dired`, the buffers' menu, fill and tab, the
   transformations (a word's case, two characters swapped), keyboard
   macros; `Config.ml`.
6. **The windows.** The hosts shared with mini-turbopascal; mini-emacs
   in a window on Linux and in one of mini-rio's on mini-9pi; the
   mouse. A screen's time on mini-9pi measured first.
7. **The docs.** The README, `playground_copies.sh`, `docs/loc.md`,
   the ledger, this plan's Status. What a process asks (`M-x compile`
   and its errors visited, a shell) is a plan after this one.

## Open questions

- **Indentation.** efuns' OCaml mode is 757 lines, most of them an
  indenter over its own lexer's tokens, which goes. Three ways: a new
  line given the previous line's indentation, and Tab asked for more
  (a few lines, any language; no key that indents or closes by
  itself: the author, "I don't like electric keys"); an
  indenter of any language over the highlighters' tokens (what an
  opening word or bracket adds, what a closing one takes back: efuns'
  `Common_indenter` is 260 lines of that), run when Tab is typed; or
  one that knows OCaml as efuns' does. The first for stage 4, the
  second if it is missed?
- **The 3,000.** Not measured: the playground's Emacs is 1,320 lines
  with its Lisp, efuns' kept files 8,100; the deviations take out most
  of `Frame`, `Text`, `Store` and the minibuffer's frame. A number to
  correct after stage 2.
- **The minibuffer as a line** (deviation 6): what it loses is every
  command working where one answers. Is that an idea of Emacs's to
  keep, at its cost?
- **Colors for a large file** (deviation 2): the playground's
  highlighters take the whole text. If a key is slow in a file of
  10,000 lines, the answer kept by line and redone from the line
  changed, or only the lines shown scanned from a line known to be
  outside a comment.
- **Emacs's keys in a terminal**: which bindings have no byte, and
  what stands for them.
- **The hosts' place**: `lib_terminal/hosts/`, or a directory of
  `editors/` both programs name.
- **mini-ed and mini-emacs**: nothing shared today (`editors/ed/Text`
  is ed's lines); should it stay so?
- **`M-x compile` and a shell in a buffer**: an editor one builds ix
  in wants a compilation and its errors visited. After this plan, or
  its stage 8?

## Status

Not started. 2026-10-09: the survey (`editors/emacs/survey.sh`) and
this plan; first as a copy of efuns' files trimmed, then, the author
having said efuns is an inspiration, as a program written anew.
