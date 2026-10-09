# Plan: TinyOffice in ix: the playground's office suite and the kits under it, on Linux and on mini-9pi (`apps/office/`)

The author (2026-10-09): "let's try to port TinyOffice and its many
compoments in the ~/playground to ix under apps/office (and
apps/kits)"; and: "let's make a plan document for it".

The short answer: **21 files to copy, 4,086 lines (3,066 of .ml), and
little to invent.** TinyOffice is one file of 1,083 lines over five
parts (548 lines), four small libraries that draw (321) and eleven
modules of kits that draw nothing (1,114). What is under those ix has
already, whole: `Playground` (one value missing, `capture`, which
nothing here names), `Gui`, `lib_gui`'s seven modules, `Hershey`,
`Formula`, and three kits (`Sheet`, `Sheet_view`, `Undo`). What it
requires beyond the copy: the files made what mini-ml takes (11
optional arguments, a polymorphic variant, 2 functions of OCaml's
stdlib that lib_core has not), four functions in each platform for a
document saved and opened, a build for `apps/office/` as
`editors/drscheme/` has, and, on mini-9pi, a page of text drawn stroke
by stroke: its speed is not known.

Its numbers are `apps/office/survey.sh`'s (run 2026-10-09, against the
playground at `028d8abf`, 2026-10-06), which gives mini-ml's **first**
refusal of a file: a file has others behind it, found when the first
is gone.

**Status: stages 1 and 2 of 6 done** (the kits; what draws and the
parts; see Status at the end).

## What it is

- **TinyOffice**: the office suite as people know it today, where the
  playground's other office programs are each a period piece. A start
  screen (a document, a spreadsheet, a presentation, a picture, a
  drawing); each kind an editor, and each editor a host of the others'
  objects, which float, are dragged and resized, with the text running
  round them; an object clicked again is edited in place, the menu bar
  its editor's and File the host's; pages, a header and a footer; a
  File menu (New, Open, Save, Save As, Export). A `Playground` program
  with `Gui`'s widgets: it reads the mouse and the keyboard.
- **The parts** (`Part_text`, `Part_sheet`, `Part_picture`,
  `Part_drawing`, `Part_chart`): what an object of each kind is, each
  behind `Component`'s protocol (what a part of a document has to be
  able to do).
- **The kits** (`appkits/`: what programs of a kind share, drawing
  nothing): `richtext` (a text with looks, `Rich`; its lines and pages
  laid out round boxes, `Page`), `paint` (a picture as bits, `Bitmap`,
  its patterns, its flood fill, its tools), `draw` (a picture as
  objects, `Figure` and `Drawing`), `document`'s `Saved` (a document's
  bytes, Marshal's behind a magic line).
- **What draws them**: `Stroke_text` (Hershey's strokes in a look:
  bold, italic, underlined), `Figure_shapes` (a figure as Playground
  shapes), `File_menu` (the menu and its dialogs).

## What to copy

The playground's file, its lines (.ml, .mli), where it goes here, and
what mini-ml refuses first (none: it compiles as it is; "its X.mli":
the refusal is in a file before it).

| the playground's | .ml | .mli | here | mini-ml's first refusal |
|---|---:|---:|---|---|
| `appkits/document/Saved` | 21 | 33 | `apps/office/document/` | none |
| `appkits/richtext/Style` | 19 | 26 | `apps/office/richtext/` | none |
| `appkits/richtext/Rich` | 149 | 100 | `apps/office/richtext/` | `?(style = Style.plain)` |
| `appkits/richtext/Page` | 334 | 129 | `apps/office/richtext/` | `?(align = Left) ?(around = [])` |
| `appkits/paint/Bitmap` | 119 | 97 | `apps/office/paint/` | `Hashtbl.filter_map_inplace` |
| `appkits/paint/Pattern` | 39 | 33 | `apps/office/paint/` | none |
| `appkits/paint/Seed_fill` | 55 | 35 | `apps/office/paint/` | `Stack.is_empty` |
| `appkits/paint/Paint` | 83 | 49 | `apps/office/paint/` | none |
| `appkits/draw/Figure` | 130 | 96 | `apps/office/draw/` | `Option.value o ~default:d` |
| `appkits/draw/Drawing` | 100 | 80 | `apps/office/draw/` | none |
| `libs/compression/Packbits` (Bitmap's rows) | 65 | 37 | `lib_compression/` | not surveyed |
| `apps/graphics/draw_view/Figure_shapes` | 55 | 14 | `apps/office/shapes/` | its `Page.mli` |
| `apps/office/stroke_text/Stroke_text` | 51 | 34 | `apps/office/shapes/` | its `Page.mli` |
| `apps/office/file_menu/File_menu` | 137 | 88 | `apps/office/file_menu/` | `?(items = items)` |
| `apps/office/embed/Component` | 78 | 88 | `apps/office/parts/` | none |
| `apps/office/Part_text` | 133 | 12 | `apps/office/parts/` | its `Rich.mli` |
| `apps/office/Part_sheet` | 98 | 11 | `apps/office/parts/` | `?(cols = 3) ?(rows = 5)` |
| `apps/office/Part_picture` | 107 | 8 | `apps/office/parts/` | none |
| `apps/office/Part_drawing` | 141 | 22 | `apps/office/parts/` | `?(max_height = 220.)` |
| `apps/office/Part_chart` | 69 | 28 | `apps/office/parts/` | none |
| `apps/office/TinyOffice` | 1,083 | 0 | `apps/office/Office.ml` | `` `Header `` |
| **21 files** | **3,066** | **1,020** | | |

Already here, and not copied again: `appkits/document/Undo`,
`appkits/sheet/Sheet`, `appkits/sheet_view/Sheet_view`
(`apps/office/sheet/` since stage 2), `languages/formula/Formula`
(`apps/office/formula/` since stage 2), `libs/gui`'s `Focus`, `Immediate`, `Look`,
`Text`, `Text_edit`, `Theme`, `Widget` (`lib_gui/`), `Gui`
(`lib_playground/apis/`), `Hershey` (`lib_graphics/software/`). Every
value of theirs that these 21 files name, ix's interfaces have.

**Not in this plan** (the survey's fourth list): the office's ten
other programs (TinyVisiCalc, TinyLotus123, TinyExcel, TinyBravo,
TinyWord, TinyOpenDoc, TinyPowerPoint, TinyFrameMaker, TinyNLS,
TinyHyperCard: 4,891 lines) and what they alone stand on (`Compound`,
`Outline`, `Nls_doc`: 472 of .ml; `languages/hypertalk`; the terminal's
`Curses`, which `lib_terminal/` has not). Each would be a small plan
after this one: the kits under them are the same.

## What it requires, beyond the copy

1. **The files made what mini-ml takes.** Counted in the 20 surveyed
   files:
   - **11 optional arguments** (5 of them in an interface: `Rich`'s,
     `Page`'s, `File_menu`'s, the two parts'). As `Undo`'s were in
     `apps/kits/`: the argument is said by every caller, the default
     written in the interface's comment. `Page.layout` is the large
     one (`?align ?around ?both ...`): a record of its options with a
     `Page.plain` to change with `{ Page.plain with around }` reads
     better than five positional arguments.
   - **A polymorphic variant**, `` `Header `` and `` `Footer `` (10
     uses, TinyOffice only): a type `band = Header | Footer`.
   - **`Option.value o ~default:d`** (3 uses): `match`, or lib_core's
     operator where the file has it (the author's rule: no label for
     it).
   - **`Hashtbl.filter_map_inplace`** (`Bitmap`, once) and
     **`Stack.is_empty`** (`Seed_fill`, once): added to lib_core's
     `Hashtbl` and `Stack` with OCaml's signature if they are a few
     lines, else the one call rewritten. The other 74 distinct stdlib
     functions these files name, lib_core has.
   - **4 `let open`**: the module's name written.
   - `Marshal` (`Saved`: `to_string`, `from_bytes`, `total_size`,
     `header_size`) and `Printf`'s `%S` (`Component`): mini-ml has
     them.
2. **A document saved and opened**: `Playground_platform`'s `store`,
   `fetch`, `stored` and `export`, which ix's interface says are "to
   come with the first program that asks for it". This is that
   program. In `ppm/` and `sdl/` (Linux): the files of a directory, as
   the playground's `Store` (42 lines; `$ELM_PLAYGROUND_STORE` or
   `~/.elm-playground/documents`). In `draw/` and `software/` (Plan
   9): the files of a directory of mini-9pi's. Each takes its
   capability (`Cap.open_out`, `Cap.open_in`, `Cap.readdir`), as the
   playground's do.
3. **A build**: dune's (`apps/office/dune`, the program with the `ppm`
   platform; `apps/office/sdl/`, the one with a window, as
   `editors/drscheme/sdl/`), and mini-mk's (`apps/office/mkfile` over
   `games/mkgames`, with a `WITH=` for the kits, as mini-drscheme's
   `WITH=scheme gui ways`). `bin/mini-office`.
4. **Tests**: the playground's 16 golden frames of TinyOffice, each a
   scripted session (`tests/common/scenes/Scenes_2d.ml`: `document`,
   `drag`, `active`, `spreadsheet`, `presentation`, `picture`,
   `drawing`, `chart`, `wrap`, `both`, `push`, `header`, `scroll`,
   `show`, `reopened`, and the start screen), as lines of
   `apps/office/tests/frames.expected` run by `games/tests/frames.sh`:
   the frame's sum, and the playground's PNG pixel by pixel where it
   is there. And its unit tests of the kits copied (Testo, for dune
   only: `Unit_rich`, `Unit_page`, `Unit_flow`, `Unit_paint`,
   `Unit_draw`, `Unit_document`, `Unit_embed`: 1,056 lines).
5. **mini-9pi**: the program linked for Plan 9 (`mini-mk O=5
   OS=plan9`), on the screen and in a window of mini-rio. A page is a
   few hundred letters, each several strokes, each stroke a shape
   given to the draw device: mini-drscheme's frame was the same kind
   of load, and what it cost there is the first measure to take.

## Decisions (proposed; agreed by the author)

The author (2026-10-09): "I agree with your plan and your decisions".
`Page.layout`'s options, the first of the open questions, are a record
then.

1. **The name**: `apps/office/Office.ml`, the program `mini-office`,
   as TinyDrScheme became `DrScheme` and `mini-drscheme`. The parts
   keep their names.
2. **`apps/office/` in folders, and what only mini-office uses under
   it** (the author, 2026-10-09, stage 2 under way: "we can probably
   better organize apps/office/ in further subfolders, and maybe move
   some of the apps/kits/ files that are relevant really only for
   mini-office under apps/office/"; then: "I would be also willing to
   move languages/formula/ under apps/office/", "it is not in the same
   class than the other languages/"). This replaces the two decisions
   first agreed (what draws flat in `apps/office/`, the ten kits in
   `apps/kits/`):

   | folder | modules | the playground's |
   |---|---|---|
   | `document/` | `Saved` | `appkits/document` |
   | `richtext/` | `Style`, `Rich`, `Page` | `appkits/richtext` |
   | `paint/` | `Bitmap`, `Pattern`, `Seed_fill`, `Paint` | `appkits/paint` |
   | `draw/` | `Figure`, `Drawing` | `appkits/draw` |
   | `shapes/` | `Stroke_text`, `Figure_shapes` | `apps/office/stroke_text`, `apps/graphics/draw_view` |
   | `parts/` | `Component`, the five `Part_*` | `apps/office/embed`, `apps/office` |
   | `file_menu/` | `File_menu` (stage 3) | `apps/office/file_menu` |
   | `formula/` | `Formula` | `languages/formula` |
   | `sheet/` | `Sheet`, `Sheet_view` | `appkits/sheet`, `appkits/sheet_view` |
   | `tests/` | the unit tests of all of them | `appkits/tests`, `apps/office/tests` |

   Folders only, one library (`ix_office`, dune's `include_subdirs`),
   as `lib_playground/`'s (`ix_formula` is gone). `Office.ml` at the
   top.
3. **`apps/kits/` keeps `Undo` alone**, Gui7Circles' and
   mini-office's. `Sheet` and `Sheet_view` are `apps/office/sheet/`'s
   (the author, 2026-10-09: "let's move the Sheet to apps/office/sheet
   and get rid of the Gui7Cells example maybe (or link the apps/office/
   libs necessary, which is fine too)"): Gui7Cells is kept, `examples/`
   linked with `ix_office` (dune) and with `WITH=formula sheet`
   (mini-mk: the two units and `Formula`, not the rest of the office).
   `Undo` could follow into `apps/office/document/`, beside `Saved` as
   in the playground, and `apps/kits/` go: not asked, not done. One
   name to watch:
   `Pattern` is also `builder/`'s (mini-mk's); the two are never
   linked together, and `Paint_pattern` is the rename if that ever
   changes.
4. **`Packbits` in `lib_compression/`**, beside `Zlib`: it is a
   compression, and the playground has it there.
5. **TinyOffice only, for now.** The ten period programs are 4,891
   lines more and two of them need libraries ix has not; they are not
   what was asked.
6. **Not counted in m-IX's budget**, as `apps/` and `editors/drscheme/`
   are not (`scripts/stats/loc.py`'s "apps/" row).
7. **A README in `apps/office/`** (copied, changed, remains), its
   numbers `scripts/playground_copies.sh`'s, with a group for
   `apps/office` added to its table; `apps/kits/README.md` updated.
   Each copied `.ml` says its origin in one `ix:` line.

## The stages (each checked before the next)

1. **The kits.** The eleven modules copied and made mini-ml's, the
   stdlib's two functions; `ix_kits` built by dune and by mini-ml;
   the six unit tests of them copied and passing.
2. **What draws, and the parts.** `Stroke_text`, `Figure_shapes`,
   `Component`, the five parts; built by both. `Unit_embed`.
3. **A document saved.** The four functions in the Linux platforms;
   `File_menu`; a test that stores a document, lists it and fetches
   the same bytes.
4. **mini-office on Linux.** `Office.ml`, dune's build and mini-mk's,
   `bin/mini-office` in a window; the 16 sessions recorded, each
   against the playground's golden frame; a job in `tests/lite.sh`
   beside the games' frames.
5. **mini-office on mini-9pi.** The Plan 9 platforms' four functions,
   the program on the screen and in a window; a frame's time measured
   first, and what to do about it decided from the number.
6. **The docs.** The two READMEs, `playground_copies.sh`'s group,
   `docs/loc.md`'s row, the ledger of `plan_ml_bootstrap.md` for what
   mini-ml or lib_core gained, this plan's Status.

## Open questions

- **`Page.layout`'s options**: a record (decision above) or the
  arguments said one by one? The record changes more of the callers'
  text than the playground's has; the positional form changes less
  and reads worse.
- **Where documents live on mini-9pi**: a directory of the kernel's
  file system that survives a boot, if there is one; else documents
  last a session, which the Status would say.
- **The golden frames on arm64**: seven of the examples' sessions
  differ from OCaml's by a few pixels under mini-ml (one rounding
  where OCaml has two); the office's pages of anti-aliased strokes
  may have more such lines than the games had. A second sum, as
  `frames.sh` allows, if so.
- **A saved document across builds**: `Saved` is Marshal's bytes.
  OCaml 5.5's Marshal writes a block's header with its color where
  4.14's and mini-ml's write none: a document's bytes are not the
  same by each, so a test must not compare them, and whether mini-ml
  reads OCaml 5.5's is to be checked in stage 3.
- **The ten other programs**: which, if any, after this one.

## Status

2026-10-09: the survey (`apps/office/survey.sh`) and this plan, its
decisions agreed.

**Stage 1, the kits: done** (2026-10-09). The ten modules (first in
`apps/kits/`, then in `apps/office/`'s folders: decision 2) and
`Packbits` in `lib_compression/`, built by dune and compiled by
mini-ml. What changed is each file's `ix:` line; against what the
plan said:

- **`Bitmap` named `Scanf`** (its saved picture's first line), which
  lib_core has not and the survey did not see: it was behind
  `Hashtbl.filter_map_inplace`, the file's first refusal. The line is
  read by hand (8 lines for 1).
- **`Hashtbl.filter_map_inplace` and `Stack.is_empty` are in
  lib_core** (19 and 5 lines with their interfaces), with OCaml's
  signatures. The first had been rewritten out of ix once
  (`plan_ml_bootstrap.md`'s ledger, 2026-10-01: its one call a fold);
  `Bitmap`'s call is the second, kept as the playground's.
- **`Packbits` had a `for _`**, which mini-ml refuses: `for _i`.
- **Five of the six unit tests**, 50 tests, pass
  (`apps/office/tests/`, in `make test` and `tests/lite.sh`).
  `Unit_flow` is `Flow`'s, a module TinyOffice does not use (a text
  through columns): not copied. `Unit_document` has `Undo`'s and
  `Saved`'s tests, not `Document`'s nor `Clipboard`'s.
- **mini-mk**: `games/mkgames` has `WITH=office` (the units of
  `apps/office/`'s folders, each compiled from the folder that has
  it, and `Packbits` from `lib_compression/`).
- Checked beyond the tests: a program over the kits (an oval drawn
  and flood-filled, its rectangles, the picture saved and read; a
  text laid out plain, justified, round a box and on both its sides;
  a drawing grouped and moved; a value saved, and refused under
  another magic line), built by dune and by mini-mk, mini-ml and
  mini-ld on a copy of the tree: the same nine lines printed. Thrown
  away: stage 4's frames are that test, kept. And `examples/` built
  again by mini-mk, its recorded frames the same.

**Stage 2, what draws and the parts: done** (2026-10-09).
`Stroke_text`, `Figure_shapes`, `Component` and the five parts in
`apps/office/`'s `shapes/` and `parts/`, with the kits one library
(`ix_office`), built by dune and compiled by mini-ml (`compile_ix.sh
apps`: 23 of 23). Against what the plan said:

- **`Part_text` named `Scanf`** too (a look's line of its saved
  text, `5 1000 16`): read by hand.
- `Part_sheet.make`'s columns and rows and `Part_drawing.make`'s
  greatest height are said (3, 5; 220.); `Part_drawing` says a
  style's type in three functions that name its field.
- **`Unit_embed` is `Compound`'s** but for one test (a document of
  parts nested: TinyOpenDoc's and TinyPowerPoint's, not here): that
  one, `Component`'s scaling, is copied. Added, ix's own:
  `Unit_parts`, each of the five parts saved, read back by its `load`
  and saved again to the same text (the text's looks line by line,
  since their reader was rewritten), and a kind no program knows kept
  whole. 7 tests; with stage 1's, 57 in one program
  (`apps/office/tests/Test.exe`).
- **The folders** (decision 2), `languages/formula/` moved to
  `apps/office/formula/` and `apps/kits/`'s `Sheet` and `Sheet_view`
  to `apps/office/sheet/` (decision 3; `git mv`; `games/mkgames`, `compile_ix.sh`,
  `playground_copies.sh`, the two surveys, `loc.py`, whose row for it
  is gone: it is `apps/`'s now).
- Checked: dune's build whole, the 57 tests, `compile_ix.sh apps
  lib_compression examples` (42 of 42); on a copy of the tree, by
  mini-mk, mini-ml and mini-ld: a program of two lines over
  `Part_text` and `Part_picture` linked with `WITH=office` and run
  (2 MB), and `examples/` built again (`WITH=formula sheet`), its 40
  recorded frames the same by dune's programs and by mini-mk's.
  Not run: `tests/lite.sh` whole (another session's linker is in the
  shared tree, half way).
- Left for stage 6: `apps/office/README.md`,
  `playground_copies.sh`'s group for `apps/office`, `docs/loc.md`.

Next: stage 3, a document saved.
