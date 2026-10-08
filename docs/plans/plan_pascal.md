# Plan: Pascal and TinyTurboPascal in ix: the playground's `languages/pascal` and its Turbo Pascal, in a terminal, on Linux and on mini-9pi (`languages/pascal/`, `lib_terminal/`, `applications/devtools/`)

The author (2026-10-08): "I'm thinking about adding DrScheme (and
languages/scheme) and TurboPascal (and languages/pascal) from the
~/playground in ix. What it would require? Can you write 2 plan
documents for it?"; and: "and what we do need to copy from the
playground". The other one is [`plan_scheme.md`](plan_scheme.md).

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

Its numbers are `applications/survey.sh`'s (run 2026-10-08), which
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
| `apps/devtools/TinyTurboPascal` | 59 | 0 | `applications/devtools/` | an interface (`Textmode`) |
| `apps/devtools/tty/TinyTurboPascal` | 21 | 0 | `applications/devtools/tty/` | an interface (`Curses`) |
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
- **A build for `applications/`** as `games/mkgames`, with
  `WITH=pascal terminal` ([`plan_scheme.md`](plan_scheme.md) asks the
  same); the terminal's program is linked with no playground at all.
- **A Pi1's ints**: 31 bits. The P-machine's integers are OCaml's
  ints: what a Pascal program sees of `maxint` and of an overflow
  differs from Linux's 63 bits. To say in `Pmachine`'s header, and
  one test.

## Decisions (proposed, for the author)

1. **Copied, not depended on**, as the games: each file's header says
   where it comes from and what changed; `applications/survey.sh`
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
   - **The IDE (`Tui_turbo`, `Turbo_*`): `applications/devtools/editor/`**,
     the playground's kit's name, beside its one program. ix has no
     `appkits/`; a top-level one when a second top directory asks.
   - `applications/devtools/TinyTurboPascal.ml` (the picture) and
     `applications/devtools/tty/TinyTurboPascal.ml` (the terminal),
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
   `Textmode`, the program; the build of `applications/`. Check: the
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
- The IDE's kit: `applications/devtools/editor/` (decision 2), or a
  top-level `appkits/` as the playground's from the start?
- The function keys: from mini-9pi's keyboard (the kernel's table,
  the loop's names), or Esc and a digit only, for now?
- Stage 5 before stage 4 on mini-9pi, if the guess (ten times
  TinyWolfenstein's shapes) is enough to decide without measuring?
- This plan before [`plan_scheme.md`](plan_scheme.md), or after?
  Scheme is the smaller (3,602 lines for 5,490) and its program a
  plain `Playground.game`; this one's first three stages need no
  playground at all.

## Status

2026-10-08: plan written, after the survey (`applications/survey.sh`).
The author: "ok let's start with scheme! [...] and then a single
languages/pascal/ converted so that it compiles with mini-ml": after
[`plan_scheme.md`](plan_scheme.md)'s stage 1, this one's.

2026-10-08, **stage 1 done: Pascal is a program of ix's, on Linux,
mini-pascal.** `languages/pascal/` (the playground's six files, `CLI`
and `Main`: 2,344 lines, 1,914 of them .ml, 101 ix's own) and
`lib_terminal/` (`Line_discipline`, `Vt`, `Talk`: 1,203 lines, 765 of
.ml), built by dune and by mini-mk (in the top mkfile's list); mini-ml
compiles the 11 files. `applications/survey.sh` says the lines each
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
console** (with [`plan_scheme.md`](plan_scheme.md)'s, which says what
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
