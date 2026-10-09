# Plan: Scheme and TinyDrScheme in ix: the playground's `languages/scheme` and its DrScheme, on Linux and on mini-9pi (`languages/scheme/`, `lib_gui/`, `editors/drscheme/`)

The author (2026-10-08): "I'm thinking about adding DrScheme (and
languages/scheme) and TurboPascal (and languages/pascal) from the
~/playground in ix. What it would require? Can you write 2 plan
documents for it?"; and: "and what we do need to copy from the
playground". The other one is [`plan_pascal.md`](plan_pascal.md).

The short answer: **13 files to copy, 3,602 lines (2,741 of .ml), and
little to invent.** The language is pure OCaml with nothing under it
(9 files, 1,529 lines); the program is one file of 783 lines over
three small things ix has not (a text and its editing, 299 lines; the
Bigbang way, 130) and over `Playground`, which ix has, mouse
included. What it requires beyond the copy: the files made what
mini-ml takes (5 optional arguments, 2 `Map.Make`, 2 `let open`, 3
functions of OCaml's stdlib that lib_core has not), a build for
`apps/` as `games/` has, and, on mini-9pi, a frame that is
some hundreds of letters, a shape each: its speed is not known.

Its numbers are `apps/survey.sh`'s (run 2026-10-08), which
gives mini-ml's **first** refusal of a file: a file has others behind
it, found when the first is gone.

**Status: done** (2026-10-09; the author: "can we move plan_scheme.md
to done/ (with possiblt remaining stuff noted at the end?)"), and this
file kept as its record: stages 1 to 4 below, each with what it found
in its Status: mini-scheme on Linux and on mini-9pi's console,
TinyDrScheme on Linux and on mini-9pi's screen and in a window, the
screen made 1024 by 768 and Plan 9's letters. What is left is listed
at the end, "What is left".

## What it is

- **`languages/sexpr`**: s-expressions, each part with its span in the
  text; the reader, Scheme's dialect and Emacs Lisp's (the playground
  shares it with `languages/lisp`, TinyEmacs's).
- **`languages/scheme`**: a small Scheme (R5RS's core) and How to
  Design Programs' Beginning Student over it: the special forms
  checked and the derived ones rewritten (`Scheme_syntax`), the
  built-ins (`Scheme_prims`), `map` and its kin written in Scheme
  (`Scheme_prelude`), a CESK machine (`Scheme_eval`: the continuation
  is data, so call/cc, tail calls, and a budget of steps),
  2htdp/image's images as data (`Scheme_image`), and the stepper,
  evaluation as rewriting (`Scheme_step`). What a program touches
  outside itself (big-bang's window) is its host's.
- **TinyDrScheme**: DrScheme 209's two windows, Definitions above and
  Interactions below, Execute, Break, Step, the language chosen; an
  error's culprit painted pink; an image printed as a picture;
  big-bang's world run in the window. A `Playground.game`: it reads
  `computer.keyboard` (the keys down and what was typed) and
  `computer.mouse`.

## What to copy

The playground's file, its lines (.ml, .mli), where it goes here, and
what mini-ml refuses first.

| the playground's | .ml | .mli | here | mini-ml's first refusal |
|---|---:|---:|---|---|
| `languages/sexpr/Sexpr` | 43 | 44 | `languages/scheme/` | none |
| `languages/sexpr/Sexpr_read` | 189 | 60 | `languages/scheme/` | none |
| `languages/scheme/Scheme_image` | 61 | 45 | `languages/scheme/` | `Float.is_integer` |
| `languages/scheme/Scheme` | 147 | 130 | `languages/scheme/` | `Array.for_all2` |
| `languages/scheme/Scheme_syntax` | 208 | 36 | `languages/scheme/` | none |
| `languages/scheme/Scheme_prims` | 345 | 27 | `languages/scheme/` | `let open Scheme_image in` |
| `languages/scheme/Scheme_prelude` | 68 | 12 | `languages/scheme/` | none |
| `languages/scheme/Scheme_eval` | 243 | 100 | `languages/scheme/` | `module Smap = Map.Make (String)` |
| `languages/scheme/Scheme_step` | 225 | 43 | `languages/scheme/` | `let steps ?(max = 1000)` |
| `libs/gui/Text` | 77 | 50 | `lib_gui/` | none |
| `libs/gui/Text_edit` | 222 | 141 | `lib_gui/` | none |
| `playground/ways/Bigbang` | 130 | 173 | `lib_playground/ways/` | `big_bang`'s optional handlers |
| `apps/devtools/TinyDrScheme` | 783 | 0 | `editors/drscheme/` | `String.to_seq` |
| all, 13 files | 2,741 | 861 | | 6 of the 13 compile as they are |

And its tests, for dune's build only (Testo: not mini-ml's):
`languages/scheme/tests/Unit_scheme.ml` (115 lines) and
`Unit_scheme_step.ml` (43).

**Not to copy, ix has them**: `Playground` (of the playground's 82
values ix's interface lacks one, `capture`, which this program does
not call), `Color Basics Time Cmd Sub Set` (`lib_playground/core`),
`Set_` (lib_core's), `Lehmer`, the three platforms, the rasterizer.

**Not to copy at all**: `libs/gui`'s other eleven modules (`Widget`,
`Layout`, `Look`, `Mvu`...: the program draws its own buttons and
uses the library for its two texts only); `languages/lisp` (TinyEmacs's);
`Program` (the playground's launcher's: a program's last line is ix's,
as the games').

## What it requires, beyond the copy

- **mini-ml's constructs**, in the 13 files: 5 definitions with
  optional arguments (12 in the interfaces: said, as in the games' and
  the physics' copies); 2 `Map.Make` (below); 2 `let open` (the
  names qualified); 4 lines of `Hashtbl` (lib_core has it).
- **lib_core's stdlib**: `Float.is_integer`, `Array.for_all2`,
  `String.to_seq` are OCaml's and not there: added (lib_core keeps
  OCaml's API), or the three calls written out. The language prints
  its numbers with `%g` and `%.15g`: lib_core's `Printf` to check
  with them, by OCaml's build and by mini-ml's, on a Pi1's floats too.
- **The machine's two maps.** `Scheme_eval`'s state is a value
  threaded through the machine: its store an `Imap` (a location to a
  value: read at each variable), its globals an `Smap`. lib_core has
  no `Map` and mini-ml no functor. The physics' copy made its
  `Map.Make` a list of pairs; a store is too large for that.
- **A build for `apps/` as the games have** (`games/mkgames`:
  a directory's units, each linked with lib_playground and a
  platform). The program needs more libraries than a game:
  `WITH=scheme gui` beside `WITH=physics`.
- **The mouse.** The program is the first of ix's on the playground
  to read it (a click on Execute, the caret put where one clicks).
  `Plan9_loop` gives the events already; [`plan_playground.md`](../plan_playground.md)'s
  Status says what is not tried: "a click shorter than a frame would
  be lost as a tap was".
- **A frame's cost on mini-9pi.** The program draws its text a letter
  a shape (`words` of one character: a monospaced look from a font of
  strokes), so a window full of text is several hundred shapes, each
  some lines of the device's. TinyWolfenstein's frame, 200 rectangles
  and a few words, is 32 ms under QEMU. Not measured for this one.
- **The edges.** The draw platform does not smooth them: letters of
  strokes one pixel wide at 480 by 480 may read badly. To look at.

## Decisions (proposed, for the author)

1. **Copied, not depended on**, as the games: each file's header says
   where it comes from and what changed; `apps/survey.sh`
   holds the copies against the playground's. The names of the
   modules, the values and their types are the playground's.
2. **The directories.**
   - `languages/scheme/` alone, the reader in it (the author,
     2026-10-08: "a single languages/scheme/ (no separate sexpr/
     folder I think)"): `Sexpr` and `Sexpr_read` keep their names, so
     a `languages/lisp` could still read with them.
     `languages/README.md` says "ix's compilers": it gains a second
     table, the languages that are interpreted (mini-smalltalk is one
     already).
   - `lib_gui/`, top-level as the other libraries: `Text`,
     `Text_edit`; the rest of the playground's `libs/gui` when a
     program asks.
   - `lib_playground/ways/`: `Bigbang` (the playground's folder for
     it; [`plan_pascal.md`](plan_pascal.md) puts `Teletype` and
     `Textmode` there).
   - `editors/drscheme/TinyDrScheme.ml`: the playground's folder
     and name ("organize games/ and applications/ like in the
     playground, with subfolders"). On mini-9pi's card: `drscheme`.
3. **A Scheme without a window, first: `CLI.ml` and `Main.ml` in
   `languages/scheme/`**, as mini-smalltalk has (about 60 lines, ix's
   own, not the playground's): a file run, or a prompt on the
   console. So the language is a program of ix's on Linux and on
   mini-9pi's console before a pixel is drawn, and is tested by text.
   big-bang answers there that it has no window.
4. **The two maps: one small module of the language's**, a balanced
   tree whose keys are compared by `compare` (about 50 lines, in
   `languages/scheme/`), in place of the two functor applications;
   `Scheme_eval`'s text keeps `Imap` and `Smap` as names. Not in
   lib_core: it would not be OCaml's `Map`. (The other way, mini-ml
   given `Map.Make`, is against its feature policy: ix is rewritten
   rather.)
5. **The tests.** For dune, the playground's two Testo files, copied.
   For both builds, by text: a directory of `.scm` files and what
   each prints (`languages/scheme/tests/`, a script comparing, in
   `make test-lite`), and the stepper's steps of a few expressions.
   For the program: its four golden frames (`TinyDrScheme.png`,
   `_execute`, `_prompt`, `_stepper`: the playground's
   `tests/2d/golden`), the sessions of its `Scenes_2d.ml`, compared
   pixel by pixel on the `ppm` platform; `games/tests/frames.sh` made
   to take a program of `apps/` too.
6. **The speed: measured first** (`stats=on`), then what
   [`plan_playground_speed.md`](../plan_playground_speed.md) has, in
   this order: a frame whose view is the last one's not drawn (a
   program that waits for a key is still most of the time); then a
   run of letters one message. Each switchable, the simple path kept.

## The stages (each checked before the next)

1. **The language on Linux.** `languages/scheme/` (the reader in it),
   the maps' module, `CLI.ml`, `Main.ml`; built by dune and by
   mini-mk (the top mkfile's list); mini-ml compiles the 9 files and
   the 3 new ones. Check: the Testo tests (dune); the `.scm` files'
   output the same by OCaml's build and by mini-ml's (arm64, and arm
   under mini-5i: a Pi1's 31-bit ints and its floats); the survey's
   table again, every file compiling.
2. **The language on mini-9pi's console.** `scheme` on the card.
   Check: a recorded session (`make -C kernels/9pi check-scheme`: a
   file run, three lines at the prompt, an error and its message),
   the same under mini-qemu and QEMU.
3. **TinyDrScheme on Linux, without a window.** `lib_gui/`,
   `lib_playground/ways/Bigbang`, the program, the build of
   `apps/`. Check: the four golden frames, no pixel
   differing, or the difference said; by dune's build and mini-ml's.
4. **TinyDrScheme on mini-9pi**, on the bare screen and in a window
   of mini-rio's, the draw platform. Check: a session by
   `kernels/9pi/tests/live.py` (the program typed, Control-T, a line
   at the prompt, a click on Step), its screens; frames a second,
   here in a table; a big-bang world run (the rocket of the
   program's own example).
5. **What stage 4 found**: the speed (decision 6), the letters'
   look, a click shorter than a frame.

Not in this plan: the program's own exercises (Check Syntax,
check-expect, Intermediate Student, a file saved and opened: the
last would be the first thing to add here, mini-9pi has files);
`languages/lisp` and TinyEmacs; the playground's web and SDL
platforms.

## Open questions

- The console program's name: `scheme`, or `mini-scheme` (mini-xxx is
  a faithful twin's name, and this is no twin of a Plan 9 program)?
- `lib_gui/` for two modules, or the two beside the program until a
  second program asks?
- The maps (decision 4): the tree, or `Hashtbl` and the machine's
  state no longer a value (the stepper and Break to read first: do
  they keep an old state?).
- This plan before [`plan_pascal.md`](plan_pascal.md), or after? They
  share the build of `apps/`, `lib_playground/ways/` and the
  frames' script, done by whichever is first; nothing else.

## Status

2026-10-08: plan written, after the survey (`apps/survey.sh`).
The author: "ok let's start with scheme! with a single
languages/scheme/ (no separate sexpr/ folder I think), and then a
single languages/pascal/ converted so that it compiles with mini-ml".

2026-10-08, **stage 1 done: Scheme is a program of ix's, on Linux,
mini-scheme.** `languages/scheme/`: the playground's nine files (the
reader's two with them), `Scheme_map`, `CLI` and `Main`; 2,260 lines,
1,725 of them .ml, 215 ix's own; built by dune and by mini-mk (in the
top mkfile's list); mini-ml compiles the 12 files.
`apps/survey.sh` says, for each file, the lines it gained and
lost against the playground's: 52 and 33 in all.

Checked: the playground's 17 unit tests (`languages/scheme/tests`,
Testo, dune's build: in `make test` and `test-lite`); and
`languages/scheme/tests/differential.sh`: those tests' 42 programs
typed at the prompt, in Scheme's printing and in Beginning Student's,
and the stepper's steps of its 7, **the same by mini-ml's build as by
OCaml's**, on arm64 and on arm under mini-5i (`-5`, a Pi1's integers
and floats: some eight minutes each of the three under the emulator).

What the copy changed (each file says):

- The four optional arguments are said: `Scheme_eval.run`, `call`,
  `eval_all` (`~fuel`) and `Scheme_step.steps` (`~max`); the labels
  kept, so a caller's text is the playground's with the value added.
- `Scheme_eval`'s two maps are `Scheme_map` (decision 4: an AVL tree,
  its keys compared by `compare`, 47 lines), under the names `Imap`
  and `Smap`.
- `Scheme_prims`: `let open Scheme_image` written out; a string's
  characters taken without a `Seq`.
- lib_core gained `Float.is_integer` and `Array.for_all2`, OCaml's.

`mini-scheme` (the open question's name, taken for now as
mini-smalltalk's): files, `-e`, a prompt that reads on while a
parenthesis is open, `-student`, `-step`; each form's value printed as
DrScheme does on Execute; an image said (`(circle 20 "solid" "red")`);
big-bang refused.

Not done of stage 1: a directory of `.scm` files (the tests' programs
are the unit tests'); the differential test is not in `test-lite` (it
wants mini-mk's build).

2026-10-08, **stage 2 done: `scheme` on mini-9pi's card, at its
console** (the author: "ok let's to stage 2"). mini-scheme built for
Plan 9 on arm as it was (`mini-mk O=5 OS=plan9`, 1.2 MB), `/bin/scheme`
on the card's root, and a file for it, `/lib/scheme/queens.scm`
(`languages/scheme/tests/queens.scm`: the queens by lists).

Checked: `make -C kernels/9pi check-scheme`, the console as recorded
(`tests/session-card-scheme.cmds`, `tests/session-card-scheme`), **the
same under mini-qemu and QEMU**, 70 seconds the two: two `-e`; the file
run (`-s`: 64,017 steps); at the prompt a definition, its call, floats
(`(sqrt 2)`, `(/ 1 3)`), a definition of two lines, an error and its
message (`(car '())`), the machine going on after it, Control-D;
`-student` and an image said; `-step`; an error's exit (`status:
scheme 40: 1`); a file that is not there. `check-card` again, its
records with the two programs in `/bin` and `/lib`.

What it asked:

- **The prompt was not seen**: `Console.print` does not flush, and on
  a console nothing does it for it. `CLI` flushes before it waits for
  a line, before an error's message and before `-s`'s number (which
  came first). Pascal's `CLI` the same, for `readln`'s question.
- A file that is not there was said by its name alone (Plan 9's
  `Sys_error`): "nothere.scm: cannot be read".
- `session.py` types at a program's prompt too (`--also "> "`, and
  `"  "` inside an expression), and a line that is Control-D is sent
  without its CR.

**The speed** (decision 6), the eight queens' 92 boards, 3,435,425
steps of the machine: 0.9 s by OCaml's build, 4.8 s by mini-ml's on
arm64 (five times), and some 5,000 steps a second under mini-5i (52,018
steps in 10 s): ten minutes there, and not finished in fourteen under
mini-qemu, which is why the session's file has five queens. Not
measured: QEMU alone, a real Pi1. A start is 4 seconds under mini-qemu
(the prelude read and evaluated each time).

2026-10-08, **stage 3 done: TinyDrScheme on Linux, without a window**
(the author: "yes!", and with it the rest of the playground's gui and
the 7GUIs: [`plan_gui.md`](../plan_gui.md)). `editors/drscheme/TinyDrScheme.ml`
(786 lines, 11 gained and 8 lost: its last line, the machine's fuel and
the stepper's limit said, a string's characters without a `Seq`),
`lib_gui/` (whole, not its two texts only), `lib_playground/ways/Bigbang`
(its handlers `Some f` or `None`). Built by dune and by mini-mk
(`editors/drscheme/mkfile`, over `games/mkgames`: `WITH=scheme gui
ways`; in the top mkfile's list after the games).

Checked, `editors/drscheme/tests/frames.sh` (the games' test with another
list): **the playground's four golden frames, no pixel differing, by
dune's build and by mini-ml's** (the program as it opens; Control-T and
its values, the rocket's world opened; the stepper three steps into a
factorial; at the prompt a list, an image and car's error: the scenes
of its `Scenes_2d.ml`, the last 140 frames in 0.3 s by mini-ml's
code). In `test-lite`, both builds.

Decision 4 is undone: the machine's maps are lib_core's `Map_`, where
`Scheme_map` moved when a second program asked for one
([`plan_gui.md`](../plan_gui.md), its decision 4).

The same day, the directories renamed (the author: "let's rename
applications to apps, like in ~/playground, and move the devtools to
editors/ instead, so we have ed there, drscheme, and soon
turbopascal"): `apps/` (misc, kits, the survey), and the program in
`editors/drscheme/` with its mkfile and its frames' test; this file's
paths follow. `make loc` sets it apart with the languages ("let's not
cound drscheme and turbopascal as part of make loc ... just like we
don't consider languages/{scheme,smalltalk,pascal} just ml and c we
count"), and `languages/formula/` with them.

Not done: `mini-scheme`'s big-bang is still refused (the command has no
window).

2026-10-08, **stage 4 done: TinyDrScheme on mini-9pi, on the bare
screen and in a window of mini-rio's** (the author, trying it:
"drscheme is working from under mini-9pi!"). Built for Plan 9 on arm
with the draw platform (`mini-mk O=5 OS=plan9` in `editors/drscheme`,
2.2 MB), `/bin/drscheme` on the card.

Checked, `make -C kernels/9pi check-drscheme`: two sessions by the
mouse and the keyboard (`tests/drscheme-bare.steps`, `drscheme-win.steps`;
`graphics.py`, each step's screen against the one recorded): Execute
clicked (120, the three discs, the rocket's world run to its end:
200), two lines typed at the prompt (`(list 1 4 9)`, car's error in
red), Step clicked and the stepper's own Step twice (step 3 of 40).
Every click is seen. **The same screens under mini-qemu and QEMU**, 12
on the bare screen and 15 in the window.

What it asked:

- **mini-ml's code for arm takes seven parameters**: `Bigbang.big_bang`
  had ten once its optional ones were said (refused: "at most 7"), and
  `text_view` eight (compiled, and `ml_curry8_0` undefined at the link:
  a bug of mini-ml's, in `docs/plans/bugs/ix.md`). big_bang's handlers
  are a record (`{ handlers with on_tick = Some f }`), text_view's x and
  y a pair.
- **A line typed fast was not run** (the playground's program: found
  by the session under mini-qemu, reproduced on Linux, in the bugs'
  list): Enter asked whether the line was whole before the frame's
  typed text was in it. Fixed here.
- **`fps=off`**, a flag of the draw platform: no frames a second
  written. A recorded session waits for a still screen, and a program
  that waits for a key is still but for that number.
- The screens are recorded under QEMU (`expected-drscheme-%`: four
  minutes a session), not under mini-qemu as the others. And the line
  typed has no key twice in a row (`3) )`): the second of two was lost
  under mini-qemu in the window.

**A frame's cost** (decision 6; `tests/perf/frames.sh drscheme
x:12000`, QEMU, a key held so that each frame differs): 571 shapes,
**125 ms a frame, 8 a second**: the view 11 ms, the messages made 64
ms, the device 51 ms. A letter is a shape, as the plan said. Left
alone it is 51 frames a second (a frame the same as the last is not
drawn).

2026-10-08, **the screen 1024 by 768 and Plan 9's letters** (stage
5's "the letters' look"; the author, of his Pi1: "the text is hard to
read; would it be possible to reuse the font from plan9 instead of
hershey thing?", then "1024x768 sounds right"):

- **mini-9pi asks the firmware for 1024 by 768** (`Swconsole.wid`,
  `ht`: one line; it was 640 by 480). The kernel asks for a
  framebuffer of a size and draws in it; the VideoCore stretches it to
  the monitor's own mode, so 640 by 480 on a board was shown enlarged
  and blurred. Both emulators give the size asked (mini-xv6's is
  1024 by 768 already). A playground's program has a square of 768
  pixels where it had 480.
- **The monitor's own size is said at boot on a board**
  (`Machine.display_size`: the firmware's tag 0x00040003, asked before
  the framebuffer): `display: W by H, the screen 1024 by 768`. Not
  said when it is 640 by 480, an emulator's answer, so the recorded
  consoles stay. On the author's Pi1, 2026-10-09: "it says display
  1280 by 800, the screen 1024x768" (and "I can now actually see the
  first kernel message too!"): the screen is still stretched, 4:3 on a
  monitor of 16:10.
- **The draw platform draws a word with the device's default font**
  (`Font`: Lucida Sans Typewriter, 9 by 15 pixels, a bitmap that is
  not scaled) when the word is upright, its size there is 11 to 16
  pixels, and it is one letter or no wider than the strokes' by a
  tenth; else the strokes (Hershey) as before. TinyDrScheme's text,
  letters it places itself in cells of 8 by 15 pixels at 768, is the
  font's; its buttons' names and its status line, given the strokes'
  room, stay strokes. In a window of mini-rio's smaller than some 710
  pixels the letters are under 11 and are strokes again (the author:
  "I guess we need to default to hershey if the word requested need
  scaling?"). `font=hershey`: the strokes always. No change to the
  playground's interface, to lib_gui or to the programs.

Seen under QEMU (one screen, after Execute). **A frame that changes is
72 ms where it was 125** (14 a second for 8; the messages 22 ms for
64, the device 38 for 51): a letter is one message, where it was a
line for each of its strokes.

**Not run again**, the author having asked for no long checks now
("this is too long!"): every recorded screen of mini-9pi's graphical
checks is of 640 by 480 and is stale (`tests/*.md5`,
`hellodraw.ppm.gz`: check-windows, check-drscheme, check-games-draw;
to record again, `make expected-windows` and `expected-drscheme-bare`,
`-win`, whose steps' mouse moves were for the old size). The consoles'
records (check-ix, check-card) do not change.

**To do** (the author, 2026-10-09: "it's fine for now, but maybe we
can record the TODO somewhere"): **the screen the display's own size
on a board**, 1280 by 800 on the author's monitor, where it is 1024 by
768 stretched: `Swconsole` would take `Machine.display_size`'s answer
when it is not an emulator's 640 by 480 (a few lines; a framebuffer of
2 MB, a third more pixels to fill; a program's square 800, its letter's
cell 9 by 16).

And what the larger screen cost: **TinyCameltry is 11 frames a second
on the Pi1 where it was 22** (the author; its square 768 pixels for
480, 2.56 times the pixels, and its whole picture turns each frame).
For now a flag of the draw platform, `size=480`: the square's side at
most (`cameltry 'size=480'`: the picture of before, centred, smaller on
the screen), not yet tried on the board; a window of mini-rio's that
size does the same. What would make it fast at the full size is
[`plan_playground_speed.md`](../plan_playground_speed.md)'s.

Not done, for stage 5: a run of letters as one message (decision 6);
the letters' look at 480 by 480 was read and is legible; a real Pi1;
big-bang's world was run but its frames not recorded (they move).

## What is left

For a plan of their own, or the next one's, if they are wanted:

- **The screen the display's own size on a board** (1280 by 800 on the
  author's monitor; it is 1024 by 768, stretched): the to-do above.
- **The speed at the larger screen**: TinyCameltry 11 frames a second
  on the Pi1 where it was 22; `size=480` is a stopgap, not tried on the
  board. And stage 5's own: a run of letters as one message, a frame
  whose view is the last one's not computed
  ([`plan_playground_speed.md`](../plan_playground_speed.md)).
- **Scheme's own speed**: 5,000 steps of the machine a second under
  the OCaml emulators; not measured under QEMU alone nor on a Pi1.
- **The recorded screens of mini-9pi's graphical checks**, all of 640
  by 480 and stale since the screen is 1024 by 768 (`check-windows`,
  `check-drscheme`, `check-games-draw`): to record again, and
  drscheme's steps to write for the new size. Done, 2026-10-09 (the
  author: "let's do 1"): `make expected-draw expected-windows` (15
  sessions under mini-qemu, 17 minutes; their steps as they were, the
  mouse's moves being from the screen's corner: the same windows, on a
  larger screen) and `expected-drscheme-bare`, `-win` (QEMU, four
  minutes and a half), drscheme's clicks placed again: its square is
  768 pixels on the bare screen, and its window is swept 880 by 750,
  a square of 742, so that its letters are the font's there too.
- **A smaller font of Plan 9's**, for a window of mini-rio's under
  some 710 pixels, where the letters are strokes again.
- **`mini-scheme`'s `(big-bang ...)`**, refused: the command has no
  window. And a directory of `.scm` files; the differential test in
  `test-lite`.
- **mini-ml's code for arm and a function of eight parameters**
  (`docs/plans/bugs/ix.md`): it compiles and does not link.
- **The playground's `TinyDrScheme.ml`** has the bug of the line typed
  fast still (fixed here).
- **Its name** (the author, 2026-10-09: "to remain in the terminology
  of ix, maybe TinyDrScheme should be called mini-drscheme really and
  we should also have a version in bin/ like we have mini-squeak"):
  done after this plan. The program is mini-drscheme, its unit
  `editors/drscheme/DrScheme.ml`; `bin/mini-drscheme` is it in a window
  on Linux (`lib_playground/platforms/sdl`). What is above says
  TinyDrScheme, as it was written.
- What the plan left out from the start: Check Syntax, check-expect,
  Intermediate Student, a file saved and opened; `languages/lisp` and
  TinyEmacs.
