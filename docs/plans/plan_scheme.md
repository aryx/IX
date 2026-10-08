# Plan: Scheme and TinyDrScheme in ix: the playground's `languages/scheme` and its DrScheme, on Linux and on mini-9pi (`languages/scheme/`, `lib_gui/`, `applications/devtools/`)

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
`applications/` as `games/` has, and, on mini-9pi, a frame that is
some hundreds of letters, a shape each: its speed is not known.

Its numbers are `applications/survey.sh`'s (run 2026-10-08), which
gives mini-ml's **first** refusal of a file: a file has others behind
it, found when the first is gone.

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
| `apps/devtools/TinyDrScheme` | 783 | 0 | `applications/devtools/` | `String.to_seq` |
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
- **A build for `applications/` as the games have** (`games/mkgames`:
  a directory's units, each linked with lib_playground and a
  platform). The program needs more libraries than a game:
  `WITH=scheme gui` beside `WITH=physics`.
- **The mouse.** The program is the first of ix's on the playground
  to read it (a click on Execute, the caret put where one clicks).
  `Plan9_loop` gives the events already; [`plan_playground.md`](plan_playground.md)'s
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
   where it comes from and what changed; `applications/survey.sh`
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
   - `applications/devtools/TinyDrScheme.ml`: the playground's folder
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
   to take a program of `applications/` too.
6. **The speed: measured first** (`stats=on`), then what
   [`plan_playground_speed.md`](plan_playground_speed.md) has, in
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
   `applications/`. Check: the four golden frames, no pixel
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
  share the build of `applications/`, `lib_playground/ways/` and the
  frames' script, done by whichever is first; nothing else.

## Status

2026-10-08: plan written, after the survey (`applications/survey.sh`).
The author: "ok let's start with scheme! with a single
languages/scheme/ (no separate sexpr/ folder I think), and then a
single languages/pascal/ converted so that it compiles with mini-ml".

2026-10-08, **stage 1 done: Scheme is a program of ix's, on Linux,
mini-scheme.** `languages/scheme/`: the playground's nine files (the
reader's two with them), `Scheme_map`, `CLI` and `Main`; 2,260 lines,
1,725 of them .ml, 215 ix's own; built by dune and by mini-mk (in the
top mkfile's list); mini-ml compiles the 12 files.
`applications/survey.sh` says, for each file, the lines it gained and
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
wants mini-mk's build). Next: stage 2 (mini-9pi's console), or stage 3
(TinyDrScheme without a window).
