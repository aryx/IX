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

**Status: stages 1 to 6 of 7 done** (the text; a file on the screen; the minibuffer, buffers, windows, the kill ring, searches; Unicode's wide and combining characters; the languages' colors; dired, the buffers' menu, macros; the author's configuration; the windows and the mouse; see Status, at the end).

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
6. ~~**The minibuffer is a line.**~~ Not taken (the author,
   2026-10-09, the two ways laid out: "the buffer actually seems
   simpler"): the minibuffer is efuns' and Emacs's, a buffer in a
   frame of one row with a map of its own, and every command works in
   it. It was proposed as a string edited by a dozen keys; with
   stage 2's frames and maps at hand, that would have been a second,
   poorer `Edit` and `Move`.
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
- ~~**The minibuffer as a line** (deviation 6)~~: answered, a buffer
  (stage 3).
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

Stages 1 to 5, the author's configuration and OCaml's names by
mini-ml's parser, and stage 6 done (2026-10-09; the author: "let's
start the mini-emacs plan!", the decisions taken as proposed).

- **Stage 1, the text**: `editors/emacs/core/Text` (166 lines, its
  interface 117): the bytes and their gap, points, the lines found by
  scanning, undo by commands (`boundary`), a regexp searched forward
  and backward. What deviation 3 said, and: no redo (what is undone is
  not recorded, where Emacs's is); a position is a byte's (UTF-8 is
  the commands'); `line` counts from the text's start. efuns' own
  `unit_text` was not found in `~/efuns`: the tests are this plan's.
- **Stage 2, a file on the screen**: `mini-emacs-tty file` (the name
  as `mini-turbopascal-tty`'s: `mini-emacs` is left for the window),
  a file read, moved in, typed in, saved, on a terminal of any size.
  `core/`: `Efuns` (the types), `Globals`, `Keymap`, `Action`,
  `Ebuffer`, `Frame`, `Window`, `Top_window`; `features/`: `Move`,
  `Edit`, `Scroll`, `Multi_buffers` (save, exit); `Config` (the
  keys, bound to the functions as efuns' `default_config`); `tty/Main`
  (and `-keys`, a session with no terminal). 847 lines of .ml in 15
  files, 360 of interfaces. What was decided on the way:
  - **a window is the tree alone** (a frame, or two windows): no link
    upward, no place of its own; the frames' places are given from
    the top (`Window.place`), and a frame's top window is the one
    whose tree has it. No value that names itself is built. A ninth
    deviation;
  - **a key is its name**, Emacs's (`C-x`, `M-f`, `RET`, `<up>`), and a
    map a table from names; `Keymap.of_bytes` from a terminal's bytes.
    Escape before a key is Meta (the open question: a terminal's Alt
    sends that). A character bound to nothing is looked up as
    `<char>`, bound to `self_insert_command`: not 200 bindings;
  - **a long line is folded** (a `\` in the last column), a tab goes
    to the next column of 8, a byte that is no character is `^A` or
    `?`; the frame moves (the point's line in its middle) when the
    point is not in the rows made;
  - **the column kept** by `C-n` and `C-p` is a field of the frame
    with the position the move left: good while the point is there
    (efuns asks what the last command was);
  - **a command that raises** says so on the minibuffer's line
    (`Failure "End of buffer"`);
  - **no `Hooks` yet**: nothing runs one before stage 4's modes;
  - **`Tty_unix.run_sized`** (lib_terminal): the terminal asked its
    rows and columns at the start (the cursor sent far, its place
    reported); `run` is as it was, for mini-turbopascal.
  The command's names are efuns' (`move_forward`, `forward_line`,
  `begin_of_file`, `forward_screen`, `insert_return`).
- **Stage 3, the minibuffer and what asks through it** (the author:
  "the buffer actually seems simpler"). `features/`: `Minibuffer` (a
  question on the last line, its answer a buffer of one row in a
  frame that is in no window; `Efuns.minibuffer`: the frame, the
  prompt, the frame that asked; RET and TAB in the buffer's own map,
  the first looked up; a file's, a buffer's, a command's name
  completed, the names said after the answer, in brackets; one
  question at a time), `Interactive` (`M-x`), `Multi_buffers` (`C-x
  C-f`, `C-x C-w`, `C-x b`, `C-x k`, the exit asked again if a file's
  buffer was modified; a buffer keeps where its last frame was),
  `Multi_frames` (`C-x 2`, `3`, `o`, `0`, `1`: the tree's leaf
  replaced or taken out, a bar between two windows side by side),
  `Copy_paste` (the mark, `C-w`, `M-w`, `C-k`, `M-d`, `M-DEL`, `C-y`,
  `M-y`; a kill follows another, or `M-y` a yank, if the text's
  version and the point are as the last one left them: efuns'
  `last_kill`), `Search` (`C-s`, `C-r`, `M-C-s`: a minibuffer whose
  map searches at each character, the cursor shown the asking
  frame's; `M-%` and `M-x replace_string`, `replace_regexp`: y, n, !,
  q the keys of a minibuffer's map), `Edit.undo` (`C-_`, `C-x u`: a
  word typed is one). What is not Emacs's: the names completed are
  said on the last line, not in a window of their own; another
  command does not end a search; no `\1` in what replaces; a search
  tells a capital from a small letter; the match is not in another
  color (stage 4's).
- **Unicode** (the author, 2026-10-09: "it would be great if
  mini-emacs handle well unicode characters and display them
  correctly", "or at least some popular one", "which is not the case
  for efuns I think"): `Utf8.width` (lib_core: 2 for Chinese,
  Japanese, Korean, the full-width forms and the emoji, 0 for the
  combining accents, the joiners and the variation selectors; the
  popular blocks, not all of Unicode's tables); `Curses.put` and
  `pieces` (lib_terminal) give a wide character two cells, the second
  with no glyph, and put a combining one in the cell before, where a
  cell a character left the terminal a column off after each;
  `Frame` counts columns so (the fold, the tab, the status line's
  column), and a byte that is no character shows as its number
  (`\377`, Emacs's way; it was `?`). A point still stops between a
  letter and its combining accent, as Emacs's. Not done: the windows'
  font (Plan 9's has Latin-1), a right-to-left text.
- **Two bugs found by mini-ml's builds** (`docs/plans/bugs/ix.md`):
  lib_core's `Filename.basename` and `dirname` were OCaml Light's for
  a name that ends with a slash (`basename "d/sub/"`: `""`, where
  OCaml says `sub`): fixed, as OCaml 4.14's, with
  `languages/ml/tests/modern/file_names.ml`; mini-5i has no `statx`,
  so a directory is not listed under it: not fixed, `keys.sh -5`
  leaves out four sessions.
- **Stage 4, the languages.** `lib_code/` (`Highlight_code`) and the
  playground's four highlighters, each in its language's
  `highlight/` (`languages/ml`, `languages/c`, `assembler`,
  `languages/smalltalk`), Scheme's and Pascal's written (161 lines
  with their interfaces): 1,683 lines in all, their languages' and
  not mini-emacs's. In mini-emacs: `Efuns.colors` (a line's pieces
  that are not plain) asked of the buffer's mode when a frame is
  drawn (`Ebuffer.colors`), a frame's rows made of pieces
  (`Curses.pieces`); `features/Highlight` (a category's color, of a
  terminal's eight and bold; a mode made of a highlighter);
  `modes/`: `Ocaml_mode`, `C_mode`, `Asm_mode`, `Smalltalk_mode`,
  `Scheme_mode`, `Pascal_mode`, chosen by a file's name's end
  (`Config.modes`), and `Paren_mode`, a minor mode: the parenthesis
  that matches the one before or at the point, in reverse (counted,
  not parsed); what a search or a replacement found, in reverse too
  (`edt_highlights`: asked when a frame is drawn); `features/Indent`,
  the open question's first way: TAB in a language's mode (not C's
  nor assembly's, where it is a tab) makes the line's indentation the
  line before's, then two spaces more at each TAB; `C-j` a new line
  with this one's; RET indents nothing. `mini-emacs-tty -colors`:
  with `-keys`, how each cell is shown, for the tests.
  - **The tokens, not the tree** (what the plan's table did not see:
    it counted `Highlight_ml` and `Highlight_c` without what they
    stand on): the playground's OCaml and C highlighters make a second
    pass over a parse of the file (`Parse_ml` and `Ast_ml`, 1,338
    lines; `Parse_c` and `Ast_c`, 1,013), which says of each name
    whether it is a parameter, a local, a field. Not copied: OCaml's
    first pass is most of the colors; C's says keywords, types'
    keywords, numbers, strings, comments, constants in capitals.
    **For the author**: are the two parsers wanted (2,351 lines)?
    Answered, below.
  - **OCaml's names by mini-ml's parser** (the author, 2026-10-09: "we
    already have a C parser and OCaml parser that returns an AST we
    can use to color no?", then "I'll prefer option 2, if we manage
    to keep the LOC added small. We can start with OCaml; Most of the
    code in ix should parse correctly with the mini-ml parser and if
    it does not we can always revert to just use the tokenizer; the
    tokenizer is pretty good and can keep line/col so what we need
    from the parser is really just syntactical/semantic info for each
    name (ideally we could get the type info"). `Names_ml`
    (`languages/ml/highlight`, 123 lines, where the playground's
    `Parse_ml` and `Ast_ml` are 1,338): mini-ml's `Parser` and `Lexer`
    asked for the tree of each item of the text (a line that does not
    start with a space, after an empty one), a walk of it with the
    names in scope, and a token's start to what it is: a Parameter or
    a Local where it is bound and where it is used, a Field (`r.l`).
    A tree's expression already said where it is (`espan`, mlpp's);
    a pattern does now (`pspan`: 2 lines of mini-ml more). An item
    that does not parse is the guess's alone: the one being typed.
    `Ebuffer.colors` ends a part of the text at an item's end. A
    character typed in `tiny/TinyML.ml`: 2.6 ms by OCaml's code (1.3
    without), 9 to 15 by mini-ml's; mini-yacc's parser gives the same
    places as menhir's. **Not done**: the types (mini-ml's `Resolve`
    and `Typing` want the other units' interfaces, found by `-I`, and
    stop at the first name they do not know: a loader for the editor,
    and a tree kept where they stop, first); a record's labels where
    it is built or matched, a let's name where it is a function's (as
    a local: one color); C, whose parser reads the text after the
    preprocessor.
  - **A part of the text highlighted, not the whole** (deviation 2's
    open question, measured): the whole text at each change was 21 to
    37 ms a character typed in `tiny/TinyML.ml` (83,342 bytes) by
    OCaml's code, 73 to 91 by mini-ml's. `Ebuffer.colors` gives the
    highlighter the lines shown, from the start of an item before
    them (a line that does not begin with a space, after an empty
    one): 1.3 to 1.7 ms, 6 by mini-ml's. `-whole` is the simple way,
    kept. `tests/colors.sh` compares the two on ix's 1,860 sources of
    these languages at four places in each: 26 screens of 7,440 are
    not the whole text's (a comment or a string with such a line in
    it; an assembly file's labels and a Smalltalk class's variables,
    said far from where they are used).
  - mini-lex and mini-ml took the two lexers once their polymorphic
    variants were a type and one comment was said in words.
- **Stage 5, the rest.** `modes/Dired` (a directory opened by `C-x
  C-f` is a buffer, a line a file: RET or f opens it, `^` the
  directory above, g reads again; the directory read, not `ls`'s
  answer), `modes/Buffer_menu` (`C-x C-b`), `features/Transform`
  (`M-u`, `M-l`, `M-c` a word's case, `C-t`, `M-q` a paragraph filled
  to 70 columns, `M-g g` a line by its number), `features/Macros`
  (`C-x (`, `C-x )`, `C-x e`: the top window keeps the keys typed).
  No fill mode that breaks a line as one types (an electric key), no
  tab mode (TAB is a tab but in a language's mode).
- **The author's configuration** (2026-10-09: "would be great to have
  a Pad.ml with my config and stuff I usually extend from emacs (see my
  own ~/.emacs and especially my own config for ~/efuns; I especially
  like my colors, numbers in yellow, syntax in blue, etc. dircolors.el,
  and DarkStalegrey background", "put all those pad specific stuff in
  a Config_pad.ml or something (linked by default)"): `Config_pad`
  (112 lines), called by the program unless it is started with `-q`.
  His colors are codemap's (the playground's `Highlight_code.rgb`,
  "pad taste": wheat on DarkSlateGray, a keyword orange, a number
  yellow3, punctuation cyan3, an operator DeepSkyBlue3, a comment
  gray), his dircolors' table a file's name's color in a directory;
  `M-g`, `M-C-l`, `M-<down>` and `M-<up>` (a line and the text
  scrolled one); y for yes; the compiler's files not completed; `M-x
  gtd`. For them: `Vt.color` has `Rgb of int * int * int`
  (lib_terminal: `Curses` sends SGR 38;2 and 48;2; the windows'
  `Cells` paints it), the editor a plain color and ground
  (`edt_plain`, the whole screen's), `Highlight.attrs`, `Dired.color`,
  `Minibuffer.y_or_n` and `Multi_buffers.ignored_extensions` are
  what a configuration sets; an arrow with Alt or Control has a name.
  Not there, mini-emacs having nothing for them: M-RET (compile), C-n
  as the next error, M-1 to M-5 (a shell); nor what a terminal cannot
  say (C-TAB, C-M-TAB, C-!). The tests run with `-q` but six sessions.
- **Stage 6, the windows** (the author: "let's do stage 6 !").
  mini-turbopascal's hosts are `lib_terminal/hosts/`'s (the open
  question's first answer; `unix/`, the terminal, is beside): `Cells`,
  `Picture`, `sdl/Window_sdl`, `draw/Window_draw` (two modules were
  named `Window`, and mini-emacs has one), moved by `git mv`;
  mini-turbopascal keeps its mains, its mkfiles name the new places.
  `Cells.key` (it was `Keys.key`, mini-turbopascal's) and
  `Cells.click`: a host given `~mouse:true` says a click and the wheel
  as the bytes xterm sends for them (mini-turbopascal's are given
  false: as before); the SDL window gives a character typed as its
  bytes of UTF-8 (it took ASCII only). In mini-emacs:
  `bin/mini-emacs` (`sdl/Main`, dune's alone) and `emacs` for mini-9pi
  (`draw/Main` and its mkfile, on the card: `kernels/9pi/Makefile`);
  `Start` (the editor made, for the three mains); `<mouse-1>`,
  `<wheel-up>`, `<wheel-down>` named by `Keymap`, the mouse's place
  the top window's (`top_mouse`), `features/Emouse` (a click: the
  frame under it has the keys, its point at the character clicked,
  `Frame.position_at`; the wheel: three lines); `mini-emacs-tty
  -frame f.ppm` (a session's screen as a window paints it) and
  `Click@2,10`, `WheelUp@2,10` in a script. Plan 9's font has Latin's
  letters: another character is a blank in a window.
- **mini-9pi: nothing painted after the first screen** (the author,
  2026-10-09, having run `emacs` there: "the C-x C-f didn't seem to
  work, Alt-x neither"): `Window_draw` paints when the model is
  another value, and mini-emacs's was its top window, changed in
  place. `Top_window.program`'s model is now a box made again after a
  key or a new size (`docs/plans/bugs/ix.md`). Fixed by reading, a unit
  test for what a host may rely on; not run under mini-9pi since.
- **The lines**: 2,312 of .ml in 38 files, 742 of interfaces: 3,054,
  of which `Config_pad` 112 and the three mains 190. The 3,000 held
  but for them: efuns' 8,073 in what an Emacs cannot be without.

Checked: 16 unit tests (`editors/emacs/tests/`: the text, one of
them 3,000 changes drawn at random against a string changed the plain
way, then all undone; the keys' names, the maps, the columns; a
character's width, a wide one's cells and what is sent of them to a
terminal, the windows' tree); 130 sessions (`tests/keys.sh`: 1,262 lines
of screens, 24 of them with their colors, read once; and two
pictures' sums, one looked at: the author's colors on DarkSlateGray), the same by
dune's build, by mini-ml's on arm64 and on arm under mini-5i (mini-mk
in a copy of the tree; ten sessions less there), the lexers
mini-lex's there; `tests/terminal.py`, the program in a pty answered
30 rows of 100 columns, and the author's colors sent as red, green
and blue; `tests/colors.sh` (above; not in `make test`:
some minutes, and ix's sources change); `compile_ix.sh` on
`editors/emacs`, `lib_code` and the six `highlight/` (38 of 38);
`modern.sh file_names.ml`; mini-turbopascal's `keys.sh` and
mini-pascal's tests after `Curses`' change; after the hosts' move:
mini-turbopascal's sessions and pictures by dune's build and by
mini-ml's, `turbopascal` and `emacs` built for Plan 9 (mini-mk O=5
OS=plan9, in the copy), `bin/mini-emacs` and `bin/mini-turbopascal`
each opened four seconds on this machine's screen. Not done: mini-emacs
or mini-turbopascal run under mini-9pi (QEMU: minutes), so no key's
nor screen's time there, which the plan wanted measured first, and
`check-turbopascal` not run after the move; a key or a click by hand
in the SDL window; a person at a
real terminal (none here: no tmux), so the colors and a wide character
have been seen in cells, not on a screen; the terminal's window
resized while the program runs; the status line's line number still
counts from the text's start (0.7 ms in 83,000 bytes); the rest of ix
rebuilt by mini-ml after `Filename`'s change; `docs/loc.md` (stage 7);
the whole of `make test`.

Before it, 2026-10-09: the survey (`editors/emacs/survey.sh`) and
this plan; first as a copy of efuns' files trimmed, then, the author
having said efuns is an inspiration, as a program written anew.
