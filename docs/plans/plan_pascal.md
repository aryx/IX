# Plan: Pascal and TinyTurboPascal in ix: the playground's `languages/pascal` and its Turbo Pascal, in a terminal, on Linux and on mini-9pi (`languages/pascal/`, `lib_terminal/`, `editors/turbopascal/`)

The author (2026-10-08): "I'm thinking about adding DrScheme (and
languages/scheme) and TurboPascal (and languages/pascal) from the
~/playground in ix. What it would require? Can you write 2 plan
documents for it?"; and: "and what we do need to copy from the
playground". The other one is [`plan_scheme.md`](done/plan_scheme.md).

The short answer: **23 files to copy, 5,490 lines (4,015 of .ml), in
three layers**, and more to decide than for Scheme. The language (6
files, 1,814 lines: a one-pass compiler to P-code, the P-machine, its
debugger) is pure OCaml, but its machine runs as a conversation
(`Talk`), so the playground's terminal library comes with it (6
files, 957 lines). The IDE (7 files, 882 lines and an interface of
types) is a program of that terminal: a model, a key, a screen of 80
by 25 cells. It is shown three ways, and that is the plan's question:
in a real terminal (53 lines, no Playground: ix's Linux has what it
asks), as a picture by the playground's Textmode way (282 lines, the
only way that is in the playground for mini-9pi), or by a host of
ix's own on the draw device, not written. What it requires beyond the
copy: 14 optional arguments said, one function of the stdlib, and on
mini-9pi a screen that is 2,000 cells, a shape or two each.

Its numbers are `apps/survey.sh`'s (run 2026-10-08), which
gives mini-ml's **first** refusal of a file: a file has others behind
it, and ten of these files stop at an interface of `Vt`'s,
`Curses`'s, `Pmachine`'s or `Textmode`'s (an optional argument
there), so their own text is not read yet.

## What it is

- **`languages/pascal`**: Pascal (Wirth, 1970) as Pascal-P (1973) and
  UCSD Pascal did it: `Pascal_lexer`; `Pascal_compile`, one pass of
  recursive descent that checks the types and emits the code as it
  reads, no tree; `Pcode`, the stack machine's instructions and their
  listing; `Pmachine`, the machine (frames, static links), a `Talk`
  program so that `readln` waits for a line and a long loop runs a
  slice at a time, or paused from outside; `Pdebug`, a paused machine
  read as Pascal (frames, watches, steps); `Pascal_disk`, the
  classics (Wirth's eight queens, the towers of Hanoi).
- **`libs/terminal`**: `Line_discipline` (a line typed, its keys),
  `Vt` (a VT100: bytes in, a screen of cells), `Curses` (a screen
  wanted, the bytes that make the terminal show it: only what
  changed), `Tui` (a full-screen program: `init`, `update` of a key
  or a tick, `view` a screen, `over`), `Talk` (a program that prints
  and asks, as a value).
- **TinyTurboPascal**: Turbo Pascal 7's IDE on the PC's text screen:
  the blue editor, the menus, F9 compiles, Ctrl-F9 runs, the error
  with the cursor on it, the P-code of the cursor's line, and the
  debugger (trace into, step over, breakpoints, watches, the call
  stack). The program's file is two lines; the IDE is `Tui_turbo` and
  its `Turbo_*`, the playground's `appkits/editor`.

## What to copy

The playground's file, its lines (.ml, .mli), where it goes here, and
what mini-ml refuses first ("an interface": it stops in another
file's .mli, its own text not read).

| the playground's | .ml | .mli | here | mini-ml's first refusal |
|---|---:|---:|---|---|
| `languages/pascal/Pcode` | 80 | 145 | `languages/pascal/` | none |
| `languages/pascal/Pascal_lexer` | 124 | 55 | `languages/pascal/` | none |
| `languages/pascal/Pascal_compile` | 939 | 46 | `languages/pascal/` | `let check_type ?at` |
| `languages/pascal/Pmachine` | 279 | 91 | `languages/pascal/` | `let resume ?(pause = ...)` |
| `languages/pascal/Pdebug` | 156 | 61 | `languages/pascal/` | an interface (`Pmachine`) |
| `languages/pascal/Pascal_disk` | 236 | 23 | `languages/pascal/` | none |
| `libs/terminal/Line_discipline` | 111 | 94 | `lib_terminal/` | `String.fold_left` |
| `libs/terminal/Vt` | 432 | 164 | `lib_terminal/` | `let key ?(alt = false)` |
| `libs/terminal/Curses` | 126 | 88 | `lib_terminal/` | `let put ?(attrs = Vt.plain)` |
| `libs/terminal/Tui` | 20 | 36 | `lib_terminal/` | an interface (`Curses`) |
| `libs/terminal/Talk` | 215 | 180 | `lib_terminal/` | `let run ?(seed = 1)` |
| `libs/terminal/unix/Tty_unix` | 53 | 27 | `lib_terminal/unix/` | an interface (`Curses`) |
| `playground/ways/Teletype` | 224 | 72 | `lib_playground/ways/` | `draw_screen`'s optional arguments |
| `playground/ways/Textmode` | 58 | 25 | `lib_playground/ways/` | `let textmode ?phosphor ?pc` |
| `appkits/editor/Turbo_model` | 0 | 90 | decision 2 | (types alone) |
| `appkits/editor/Turbo_edit` | 152 | 62 | decision 2 | an interface (`Vt`) |
| `appkits/editor/Turbo_debug` | 114 | 51 | decision 2 | an interface (`Vt`) |
| `appkits/editor/Turbo_menus` | 130 | 42 | decision 2 | an interface (`Vt`) |
| `appkits/editor/Turbo_update` | 108 | 17 | decision 2 | an interface (`Vt`) |
| `appkits/editor/Turbo_view` | 331 | 30 | decision 2 | `let attrs ?(bold = false)` |
| `appkits/editor/Tui_turbo` | 47 | 76 | decision 2 | an interface (`Vt`) |
| `apps/devtools/TinyTurboPascal` | 59 | 0 | `editors/turbopascal/` | an interface (`Textmode`) |
| `apps/devtools/tty/TinyTurboPascal` | 21 | 0 | `editors/turbopascal/tty/` | an interface (`Curses`) |
| all, 23 files with the terminal's main | 4,015 | 1,475 | | 3 compile as they are |

And its tests, for dune's build only (Testo: not mini-ml's):
`languages/pascal/tests/Unit_pascal.ml` (152 lines).

By layer: the language 1,814 and 421; the terminal 957 and 589; the
IDE and the ways it is shown 1,244 and 465.

**Not to copy, ix has them**: `Playground`, `Scene2d` (the keys
pressed), `Set_`, `Lehmer` (`Talk`'s seeded numbers), the platforms.

**Not to copy at all**: the rest of `appkits/editor` (`Tui_vi`,
`Tui_emacs`, `Emacs_*`, `Gap_buffer`: the two editors, and
`languages/lisp` under Emacs); `Program`.

## The three ways to show it

A `Tui.program` knows keys and a screen of cells, nothing else; a
host gives it a keyboard and shows the cells.

| | the host | lines | where it runs | what it needs that ix has not |
|---|---|---:|---|---|
| a real terminal | `Tty_unix` | 53 | Linux (a terminal emulator; a serial line) | nothing: lib_core's `Unix` has `tcgetattr` and `select` |
| a picture | `Textmode` over `Teletype`, a `Playground.game` | 282 | every platform of lib_playground's: `ppm` (the tests), mini-9pi's two | nothing, but a frame is 2,000 cells |
| the draw device | a host of ix's own, not written (about 100 lines) | | mini-9pi | to write |

- **Plan 9 has no terminal of escapes**: its console and rio's
  windows show the bytes they are given (mini-9pi's console to check,
  but that is the system's way). So `Tty_unix`'s counterpart there is
  not a port of it, and the first way does not reach mini-9pi.
- **Textmode's frame.** The whole screen is drawn each frame: a cell
  whose background is not the default is a rectangle, its character a
  `words` of one letter (the font of strokes), the PC's frames
  rectangles. Turbo Pascal's screen is blue from edge to edge: nearly
  2,000 rectangles and as many letters as there is text. For
  comparison TinyWolfenstein's frame, 200 rectangles, is 32 ms under
  QEMU on the draw platform. Not measured for this one; ten times the
  shapes is the first guess, and an IDE that takes a third of a
  second a key is not Turbo Pascal.
- **A host on the draw device** would be the Plan 9 program one
  would write: `Curses` already says which cells changed, the device
  has letters of its own (`x`: a string on its background, one
  message a run of cells; `lib_graphics`'s `Font.string`, which the
  draw platform does not use), and a screen that did not change costs
  nothing. No Playground under it, as `Tty_unix` has none. To check:
  whether the device's font has the PC's box characters (if not, they
  are lines, as Teletype draws them).

## What it requires, beyond the copy

- **mini-ml's constructs**, in the files: 14 definitions with
  optional arguments (15 in the interfaces), said at each call; no
  functor, no `let open`, no `Hashtbl`. `Turbo_model.mli` is an
  interface of types with no .ml: mini-ml's and mini-mk's way with
  one to check (dune's is `modules_without_implementation`).
- **lib_core's stdlib**: `String.fold_left` (OCaml's, added). More
  may be behind the files not read yet.
- **The keys.** `Teletype.keyboard_bytes` makes a terminal's bytes of
  the playground's key names. The Plan 9 loop names `Control`, `Alt`,
  `Shift`, `Enter`, `Escape`, `Tab`, `Backspace`, `Delete` and the
  arrows; **not the function keys**, which this program is made of
  (F9, Ctrl-F9, F7, F8, F10). Either mini-9pi's `Kbd` gives them
  (Plan 9's runes for them; to check that the kernel's table has
  them) and the loop names them, or the program's own way without
  them is used: Esc then a digit is the F key, Ctrl and a digit Ctrl
  and the F key, and every command is in a menu.
- **A build for `apps/`** as `games/mkgames`, with
  `WITH=pascal terminal` ([`plan_scheme.md`](done/plan_scheme.md) asks the
  same); the terminal's program is linked with no playground at all.
- **A Pi1's ints**: 31 bits. The P-machine's integers are OCaml's
  ints: what a Pascal program sees of `maxint` and of an overflow
  differs from Linux's 63 bits. To say in `Pmachine`'s header, and
  one test.

## Decisions (proposed, for the author)

1. **Copied, not depended on**, as the games: each file's header says
   where it comes from and what changed; `apps/survey.sh`
   holds the copies against the playground's. The names are the
   playground's.
2. **The directories.**
   - `languages/pascal/`, the playground's. It is an interpreter's
     compiler, not one that writes mini-asm's objects:
     `languages/README.md` gains a second table (with Scheme and
     mini-smalltalk).
   - `lib_terminal/`, top-level: the five modules, and `unix/` for
     `Tty_unix` (Linux only: not in mini-9pi's build).
   - `lib_playground/ways/`: `Teletype`, `Textmode`.
   - **The IDE (`Tui_turbo`, `Turbo_*`): `editors/turbopascal/editor/`**,
     the playground's kit's name, beside its one program. ix has no
     `appkits/`; a top-level one when a second top directory asks.
   - `editors/turbopascal/TinyTurboPascal.ml` (the picture) and
     `editors/turbopascal/tty/TinyTurboPascal.ml` (the terminal),
     as there. On mini-9pi's card: `turbopascal`.
3. **A Pascal without a screen, first: `CLI.ml` and `Main.ml` in
   `languages/pascal/`** (ix's own, about 60 lines): a file compiled
   and run, its `Talk` answered by the console's lines; `-S`, its
   P-code listed (`Pcode.show`). The language is then a program of
   ix's on Linux and on mini-9pi's console, tested by text.
4. **The order of the three ways: the terminal, then the picture,
   then the draw device if the picture is slow.** The terminal's is
   the whole IDE on Linux for 53 lines; the picture's gives the
   golden frames and a first run on mini-9pi with nothing new;
   stage 5 is written only if stage 4's number says so.
5. **The tests.** For dune, the playground's Testo file. For both
   builds, by text: `Pascal_disk`'s programs and a directory of
   `.pas` files, each with what it prints and one with its P-code;
   the IDE without any screen: a script of keys given to
   `Tui_turbo.program`, the last screen's cells as text (a `Tui`
   program is a pure function of its keys). For the picture: its six
   golden frames (`TinyTurboPascal.png`, `_run`, `_menu`, `_pcode`,
   `_error`, `_debug`), the sessions of the playground's
   `Scenes_2d.ml`, pixel by pixel on the `ppm` platform.
6. **The speed: measured first**, and the simple path kept beside
   whatever is added (decision 4's third way is another host, not a
   change of Textmode).

## The stages (each checked before the next)

1. **The language on Linux.** `languages/pascal/`, and of
   `lib_terminal/` what the machine asks (`Line_discipline`, `Vt`,
   `Talk`); `CLI.ml`, `Main.ml`; dune and mini-mk; mini-ml compiles
   them. Check: the Testo tests (dune); the `.pas` files' output and
   P-code the same by OCaml's build and by mini-ml's (arm64, and arm
   under mini-5i); the eight queens' 92 solutions.
2. **The language on mini-9pi's console.** `pascal` on the card.
   Check: a recorded session (`check-pascal`: the queens run, a
   program that asks a line, a type error and its message), the same
   under mini-qemu and QEMU.
3. **The IDE in a terminal, on Linux.** `Curses`, `Tui`, `Tty_unix`,
   the kit, the terminal's program; by dune and by mini-ml. Check:
   the script of keys and its last screen (decision 5), both builds;
   and by hand, in a terminal: F9, Ctrl-F9, a breakpoint, a watch.
4. **The picture, on Linux then on mini-9pi.** `Teletype`,
   `Textmode`, the program; the build of `apps/`. Check: the
   six golden frames, no pixel differing, or the difference said;
   then on mini-9pi (bare, and in a window of mini-rio's) a session
   by `kernels/9pi/tests/live.py` (a line typed, compiled, run),
   **the time of a frame and of a key**, here in a table; the
   function keys (or Esc and a digit).
5. **The draw device's host**, if stage 4's frame is too slow:
   `Tui.program` on the device (the cells that changed, the device's
   letters), `turbopascal` linked with it on mini-9pi. Check: the
   same session, the two side by side, their lines and their time.

Not in this plan: the program's own exercises (watches of any
expression, several windows, blocks, undo, the mouse); TinyVi and
TinyEmacs (the same `Tui` and hosts: little is left for TinyVi once
this is done); TinyBasic (`languages/basic` is a `Talk` program too,
shown by `Teletype`: the same two layers).

## After it

- **The exercise the playground leaves: "compiling to a machine's
  own code, as the real one did."** ix is where that is cheap: a
  second back end of `Pascal_compile`, P-code to mini-asm's objects
  (arm, arm64), linked by mini-ld, would make `languages/pascal` a
  compiler in `languages/README.md`'s sense, and P-code beside
  native code the same lesson as mini-ml's own. A plan of its own.

## Open questions

- The console program's name: `pascal`, or `mini-pascal`? And the
  terminal IDE's, on Linux: `turbopascal`?
- The IDE's kit: `editors/turbopascal/editor/` (decision 2), or a
  top-level `appkits/` as the playground's from the start?
- The function keys: from mini-9pi's keyboard (the kernel's table,
  the loop's names), or Esc and a digit only, for now?
- Stage 5 before stage 4 on mini-9pi, if the guess (ten times
  TinyWolfenstein's shapes) is enough to decide without measuring?
- This plan before [`plan_scheme.md`](done/plan_scheme.md), or after?
  Scheme is the smaller (3,602 lines for 5,490) and its program a
  plain `Playground.game`; this one's first three stages need no
  playground at all.

## The window (the author, 2026-10-09)

"Ideally we want to have TurboPascal running with the plan 9 fonts, in
a rio window, but still using a terminal style UI (like in DOS), so a
resize would drop the number of lines displayed rather than shrinking
the fonts and characters (which would be slower with Hershey than the
Plan 9 fonts)"; and: "ideally it also can be tested and build on
linux, like mini-squeak and mini-drscheme".

So of "The three ways to show it" the picture is **not taken**
(`Teletype`, `Textmode`: 282 lines not copied, no Playground under the
IDE, no font of strokes), and the third way, a host of ix's own, is
the program: a grid of cells, each a character of Plan 9's font.
Stages 4 and 5 above are replaced by the three below. What was
looked at for it:

- **The font is fixed**: `Font.default` (Lucida Sans Typewriter, as
  Plan 9 gives it) has every character 9 pixels wide, a line 15 high,
  the baseline at 13. A cell is 9 by 15: 80 by 24 is 720 by 360, and a
  window of w by h has w / 9 columns and h / 15 rows.
- **It has Latin-1 only**, 256 characters: none of the PC's box
  characters. The 12 the IDE draws its frames with (single and double:
  two sides and four corners each) are drawn by the host, a cell's
  lines as rectangles; the shadow is a colour.
- **The colours** are the PC's 16: `Vt`'s eight, bold the bright ones
  (not a bold font).
- **The size.** The IDE is 80 by 24 in 18 places of the kit (80, 24,
  23, 22, 20, 78 written as numbers). `Tui.event` gains
  `Resize of int * int` (rows, columns), the model its rows and
  columns, and the view is written from them; a size too small for the
  menu bar and a line of text shows what fits. `Tty_unix` may then
  give the terminal's own size (not asked).
- **The keys.** mini-9pi's kernel has F1 to F12 (`Kbd`'s table: Plan
  9's runes 0xF001 to 0xF00C); `Keyboard` names the arrows only. With
  Control, the console gives the same rune: Control is known from
  /dev/kbd (`Keyboard.held`), which mini-rio's windows have. Escape
  then a digit stays, for a keyboard without them. To check: that a
  window of mini-rio's is given these runes.
- **As mini-squeak, a host by system** (`languages/smalltalk/hosts/`):
  `hosts/draw/` (lib_graphics: `Display`, `Font`, `Draw`, `Mouse` for
  the window's new size; mini-ml, mini-9pi) and `hosts/sdl/` (dune
  only). What they share is pure and tested on Linux: from the screen
  shown and the next one, the runs of cells to paint (a row, a column,
  a text, two colours), `Curses`'s difference with rectangles for
  bytes. On Linux the font's bits are read from `Font_default` in
  OCaml (`Font`'s reading of them, apart from its `Display`) and a
  run painted in a picture: the SDL window shows it, and with no
  window it is written to a file, a frame whose sum is recorded as the
  games' are. The draw device's window should then be that picture,
  pixel for pixel (/dev/window, `tests/*.steps`).

The stages, after stage 3:

4. **The size in the model.** `Resize`, rows and columns; `-keys`
   takes a size. Check: `keys.sh`'s screens unchanged at 80 by 24, and
   sessions at 60 by 16 and 100 by 40.
5. **The window on Linux.** The shared painter, the font's bits, the
   box characters; `hosts/sdl/` (`bin/mini-turbopascal`, resized by the
   mouse) and frames to a file. Check: frames' sums recorded, looked
   at; by hand in the window.
6. **The window on mini-9pi.** `hosts/draw/`, `turbopascal` on the
   card; the F keys and Control. Check: a recorded session in a window
   of mini-rio's and on the bare screen (a line typed, F9, Control-F9,
   the window resized: fewer rows), its window's picture against
   stage 5's frame; the time of a key, here.

## Status

2026-10-08: plan written, after the survey (`apps/survey.sh`).
The author: "ok let's start with scheme! [...] and then a single
languages/pascal/ converted so that it compiles with mini-ml": after
[`plan_scheme.md`](done/plan_scheme.md)'s stage 1, this one's.

2026-10-08, **stage 1 done: Pascal is a program of ix's, on Linux,
mini-pascal.** `languages/pascal/` (the playground's six files, `CLI`
and `Main`: 2,344 lines, 1,914 of them .ml, 101 ix's own) and
`lib_terminal/` (`Line_discipline`, `Vt`, `Talk`: 1,203 lines, 765 of
.ml), built by dune and by mini-mk (in the top mkfile's list); mini-ml
compiles the 11 files. `apps/survey.sh` says the lines each
gained and lost: 57 and 42 in all.

Checked: the playground's 13 unit tests (`languages/pascal/tests`,
Testo, dune's build: in `make test` and `test-lite`); and
`languages/pascal/tests/differential.sh`: the disk's nine programs run
(the eight queens' 92 solutions; the one that asks, answered) and
their P-code listed, and six programs that fail (`tests/*.pas`: two
errors of the compiler, a range, a division by zero, the stack, an
integer past maxint), **the same by mini-ml's build as by OCaml's**,
what is said and the exit, on arm64 and on arm under mini-5i (`-5`).

What the copy changed (each file says):

- The five optional arguments are said, their labels kept:
  `Pascal_compile`'s `check_type ~at` (an option), `Pmachine.resume
  ~pause`, `Vt.key ~alt`, `Talk.run ~seed`, `Talk.start ~baud` (an
  option).
- `Talk.run`'s loop was polymorphic in its program's answer (`'b. 'b
  talk -> ...`), which mini-ml does not take: the program is made a
  `unit talk` first.
- `Pascal_compile.compile` says `Result.Error`: `Pascal_lexer` is
  open there, and its exception `Error` is the nearer one for mini-ml,
  which does not choose a constructor by the type wanted.
- Two `Option.value ... ~default` written out (a label after the
  argument).
- lib_core gained `String.fold_left`, OCaml's.
- **`Lehmer` is a library of its own for dune** (`ix_random`, in
  `lib_playground/random/`, where it was): `Talk` draws its numbers
  from it and has no use for the rest of the playground.

The survey's worry of a Pi1's 31 bits is none: the machine's integers
are Turbo Pascal's 16, wrapped by the machine itself (`wrap.pas`).

`mini-pascal`: files compiled and run, `readln` taking the lines
typed; `-S`, the P-code; `-disk`, the programs that come with it, and
a name that is no file is looked for there (`mini-pascal QUEENS.PAS`);
`-seed`. It runs the machine itself (`Pmachine.start`, `resume`), not
through `Talk`, so that a run-time error is its exit; `random`'s
numbers are drawn as `Talk` draws them.

2026-10-08, **stage 2 done: `pascal` on mini-9pi's card, at its
console** (with [`plan_scheme.md`](done/plan_scheme.md)'s, which says what
the two asked: a flush before a line is waited for, `session.py`'s
`--also`). mini-pascal built for Plan 9 on arm as it was (1.1 MB),
`/bin/pascal` on the card's root, and `/lib/pascal/types.pas`, which
does not compile.

Checked: `make -C kernels/9pi check-pascal`, the console as recorded
(`tests/session-card-pascal.cmds`, `tests/session-card-pascal`), **the
same under mini-qemu and QEMU**, under two minutes the two: `-disk`;
HELLO.PAS run and its P-code (`-S`); the eight queens (`-s`: 677,377
instructions, the last boards and "92 solutions"); GUESS.PAS, its
three questions answered at "Your guess? " (50, 88, 77: "Right, in 3
tries!", the seed's number the same as on Linux); a type error with its
line and column, and the exit (`status: pascal 42: 1`); a division by
zero in a file written there (`Runtime error 200 at line 1`); a name
that is neither a file nor on the disk.

The speed is not the worry it is for Scheme: the queens' 677,377
instructions are inside that session's two minutes under mini-qemu
(not timed alone).

Next: stage 3 (the IDE in a terminal: `Curses`, `Tui`, `Tty_unix`, the
kit).

2026-10-09, **stage 3 done: the IDE is a program of ix's, in a
terminal and with no screen** (the author: "let's start the
mini-turbopascal work! What's the first step?"). `lib_terminal/` gains
`Curses`, `Tui` and `unix/Tty_unix`; `editors/turbopascal/editor/` is
the playground's `Tui_turbo` and `Turbo_*` (13 files, 1,255 lines);
`Keys` (ix's, 48 lines) gives the program a line of keys and prints
the screen they leave; `tty/` is `mini-turbopascal-tty`, by dune and by
mini-mk (in the top mkfile's list). mini-ml compiles all of it: 1.5 MB
on arm64.

What the copy changed: `Curses.put`'s and `box`'s attrs, `Turbo_view`'s
`attrs ~bold` and `frame ~double ~title` are said (9 optional
arguments in all with `Vt.key`'s); three `Option.value` written out;
and `frame`'s corner is a pair: it had eight parameters, and mini-ml's
arm has seven (`mini-ld: undefined: ml_curry8_0`, bugs/ix.md's row of
2026-10-08, the same).

Checked: `editors/turbopascal/tests/keys.sh` (in `make test`): the
playground's five golden sessions (run: the queens on the user screen;
the Compile menu; the P-code of a line of try; an error in the red
bar; the debugger: a breakpoint at line 22, run to it twice, the
watches `x: (1,0,0,0,0,0,0,0)` and `j: 2`), the first screen and a
name that is no key: 159 lines of screens, read, **the same by dune's
build, by mini-ml's on arm64, and on arm under mini-5i** (20 seconds
there). mini-mk's builds were made in a copy of the tree (another
session is changing the shared `_mk`'s lib_core). Not done: the
terminal itself by hand (`bin/mini-turbopascal-tty`, after a `make
install`): F9, Control-F9 typed at a real keyboard.

Then the author's direction for the screen: "The window" above.

2026-10-09, **stage 4 done: the screen's size is the model's** (the
author: "excellent! let's commit and move forward"). `Tui.event` has
`Resize of int * int`; the model `rows` and `cols`, 24 and 80 at
first; `Turbo_edit.text_rows` and `text_cols` come from them, the view
is written from its screen's size (`Curses.rows`, `cols`), a dialog
centred in it, the P-code's window no larger than it, a program's
user screen the size the IDE had when it started (shown from its top
left corner after another resize). Never less than 7 by 20, and no
Watches window where fewer than three lines of text would be left.
46 lines of the kit for it (71 are not the playground's now, of
1,268).

`Keys`: `16x60` in a script is a `Resize`, and a dot a tick more (the
queens end five ticks after Control-F9: "92 solutions").

Checked: `keys.sh`: the seven sessions at 80 by 24 as recorded before
the change, byte for byte; eight more (16 by 60: the text, the
debugger with a watch; 12 by 40: the queens run to their end; 10 by
44: the P-code's window; 3 by 10 asked: 7 by 20 shown; 40 by 100: 38
lines of text and the Run menu; a run at 16 by 60 then 24 by 80, and
back to the editor), 324 lines of screens, read; the same by dune's
build, by mini-ml's on arm64 and on arm under mini-5i (the private
tree, as before). mini-pascal still builds by mini-mk.

2026-10-09, **stages 5 and 6 done: mini-turbopascal in a window, on
Linux and on mini-9pi, Plan 9's font, a cell a character.**
`editors/turbopascal/hosts/` (551 lines, ix's own):

- `Cells` (169): the PC's 16 colours, the 12 box characters as lines in
  a cell, the runs of cells that changed between two screens (the
  cursor's old and new places with them), painted on a `surface` (a
  rectangle filled, a character drawn), then the cursor: the cell's
  last two rows of pixels. `Curses` gained `cursor_at`.
- `Picture` (90): a surface in memory, the font's bits read from
  `Font_default` as `Font` reads them (12 lines the same: `Font` was
  not split, five mkfiles name lib_graphics's units); a PPM.
- `hosts/sdl/` (136): `bin/mini-turbopascal`, the window resized by
  the mouse; `-scale` (2), `-rows`, `-cols`. Dune's alone.
- `hosts/draw/` (156): `turbopascal` on mini-9pi's card (1.2 MB), in a
  window of mini-rio's or on the bare screen, by `Display`, `Draw` and
  `Font`; `Mouse`'s resized is `Tui.Resize`. What changed is painted,
  and nothing when the model is the one painted.
- `mini-turbopascal-tty -keys ... -frame f.ppm`: a session's screen as
  the picture, with no window: by dune and by mini-ml.

The keys on mini-9pi: the console's characters, Plan 9's runes named
(the arrows, Home, End, the pages, Insert, Delete, Backspace); an F
key from /dev/kbd, whose message says whether Control is down with
it. **Found: Control-F9 also broke the line at the cursor**: the
kernel's table gave a carriage return on the console for it
(`bugs/ix.md`'s row). `Kbd`: with Control an F key is its rune, as
without. Alt is Plan 9's compose key (it holds the next character
back): no Alt and a letter there, F10 opens the menus;
`graphics.py`: `('key', 'ctrl+f9')`, keys down together.

Checked:

- `editors/turbopascal/tests/keys.sh`: eight pictures' sums
  (`frames.expected`: the first screen, the Compile menu, the P-code,
  an error, the debugger, the Open dialog, a run at 12 by 40, 40 by
  100), four of them looked at; the same by mini-ml's build on arm64,
  and the first two on arm under mini-5i (a picture is a minute
  there: 3 minutes the script with `-5`).
- `bin/mini-turbopascal` on this machine's screen: opened 6 seconds at
  20 by 70, its window's picture taken and looked at (the editor, the
  cursor); with no display (`SDL_VIDEODRIVER=dummy`), 3 seconds.
  A key typed in it and the window resized by hand: the author's,
  2026-10-09 ("mini-turbopascal works perfect on Linux/SDL!").
- `make -C kernels/9pi check-turbopascal` (QEMU, 1 minute 17 with the
  expected screens; recording them was 2 and 4 and a half minutes):
  `turbopascal-bare` (9 screens: 51 rows of 113; F10's menu, Escape,
  PageDown, Control-F9 and "92 solutions", a key, x typed, F9: "end
  expected, not x." in the red bar) and `turbopascal-win` (21 screens:
  a window of 600 by 360 swept; the menu; a run; Resize from rio's
  menu on the background, the window pointed at and 380 by 210 swept:
  **14 rows of 42, the letters the same**; PageDown: 9:1, the text not
  modified; F7 and F8: the execution bar at line 34). The screens
  looked at.
- **mini-9pi's screen is Linux's picture**: `turbopascal-bare`'s first
  two screens against `-keys '51x113' -frame` and `'51x113 F10'`, at
  the screen's 16 bits a pixel: 170 pixels differ, all in the mouse's
  arrow at the corner.

Not run: under mini-qemu (the sessions are QEMU's, as check-office's);
`check-windows` after the change of `Kbd` (Control and an F key only;
`kernel-pi1-ixu.img` was rebuilt with it); a real Pi; **the time of a
key**, which stage 6 asked: not measured. `mini-mk` for Linux in the
shared tree (`editors/turbopascal/tty`): its `_mk/7` has no
`lib_core.a` while another session changes it; the private tree's.

Left, if wanted: Alt on mini-9pi (the kernel's compose would have to
be told apart); the mouse in the IDE (the playground's has none);
`Font`'s bits shared with `Picture`; TinyVi and TinyEmacs, which are
`Tui` programs too and would take the same two windows as they are.

2026-10-09, **mini-9pi: the speed of a key, and Alt** (the author:
"under mini-9pi things are too slow right now; the arrow key is slow,
and the Alt-xxx are not working; in Linux/SDL Alt-f correctly opens
the File menu", on the bare screen: 51 rows of 113).

The speed, three things, the first a bug:

1. **The host painted at every tick**, a key or none (`bugs/ix.md`'s
   row): twenty views a second of a screen that had not changed. Now
   nothing is made when the model is the one shown; the keys already
   there are taken before a screen is painted (an arrow held); the
   tick is `Source.alarm`'s.
2. **A view cost more than it had to**: a `Curses.put` a character of
   the text, each copying its row (`Curses.pieces`: a line's pieces,
   the row copied once; the user screen too), and a string made for
   each cell (`Curses`: the one-byte ones made once).
3. **A view and its comparison are a screen's work for a key that
   changes a line**: `Turbo_view.cache` keeps the last view's rows
   (the empty window, each row of text while its line is the same),
   `Curses.take` puts one in the next screen, and `Cells.runs` does
   not look at a row that is the screen before's own (`Curses.same`).
   Switchable (`-nocache`); `keys.sh` has the same screens both ways,
   made after each key (`-views`).

Measured, `mini-turbopascal-tty -keys '51x113 ArrowDown...' -views`
(200 keys, a view and a comparison each; mini-ml's code, arm64, this
machine): 1.37 s before; 0.66 with 2; **0.06 with 3** (OCaml's code,
before: 0.45). And on mini-9pi under QEMU, `turbopascal -time` on the
bare screen (its clock's step is 10 ms), a key's view and painting:

| | view | painting (the comparison, the draw device) |
|---|---:|---:|
| the first screen | 110 ms | 220 ms |
| a key, nothing kept (`-nocache`, with 1 and 2) | 50 to 60 ms | 40 to 80 ms |
| a key, the rows kept | 0 to 10 ms | 10 ms (a menu: 30 to 50) |

Before, a key was more than the middle row (the puts a character:
three times the view), and so was every tick.

**Why the playground's is fast with none of this** (the author's
question): the same view, made whole each frame, by ocamlopt or a
browser's compiler on a machine some fifty times a Pi 1, at 80 by 24
(a third of these cells). Here mini-ml's code is three times
OCaml's on it (1.37 s for 0.45, same machine), the screen three
times as large, the machine a Pi 1. 1 was this host's own fault; 2 is
in `Curses` and would serve the playground too; 3 is the one that is
there for the machine, 45 lines of `Turbo_view`, and what would make
it unnecessary is under it: a cell is a record and a string of its
own, a screen 5,763 of them made for each view (a cell as an integer
in `Vt` and `Curses`, or mini-ml's code for records and closures: not
looked at).

Alt: **a character typed while Alt is held is a chord** in mini-9pi's
kernel (`Kbd`): nothing on the console and no compose sequence left
waiting (Plan 9's kept the letter: Alt-F, and the F came with the
next key typed); Alt let go first is the compose sequence as it was.
The host reads Alt and a letter, and Alt or Control with an F key, in
/dev/kbd's message.

Checked: `keys.sh` (the screens with `-views` and `-views -nocache`,
by dune; by mini-ml on arm64 in the private tree); `make -C
kernels/9pi check-turbopascal`, its 30 screens as recorded; under
QEMU on the bare screen, looked at: Alt-F (the File menu), Escape,
"ab" typed (both letters, at once), Alt-F9 (the error's bar), Alt-X
(the shell's prompt back). Not run: a real Pi; mini-qemu; Alt in a
window of mini-rio's; `check-windows` after `Kbd`'s two changes.
