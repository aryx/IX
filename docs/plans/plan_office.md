# Plan: TinyOffice in ix: the playground's office suite and the kits under it, on Linux and on mini-9pi (`apps/office/`, `apps/kits/`)

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

**Status: not started** (the plan only; the survey is in).

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
| `appkits/document/Saved` | 21 | 33 | `apps/kits/` | none |
| `appkits/richtext/Style` | 19 | 26 | `apps/kits/` | none |
| `appkits/richtext/Rich` | 149 | 100 | `apps/kits/` | `?(style = Style.plain)` |
| `appkits/richtext/Page` | 334 | 129 | `apps/kits/` | `?(align = Left) ?(around = [])` |
| `appkits/paint/Bitmap` | 119 | 97 | `apps/kits/` | `Hashtbl.filter_map_inplace` |
| `appkits/paint/Pattern` | 39 | 33 | `apps/kits/` | none |
| `appkits/paint/Seed_fill` | 55 | 35 | `apps/kits/` | `Stack.is_empty` |
| `appkits/paint/Paint` | 83 | 49 | `apps/kits/` | none |
| `appkits/draw/Figure` | 130 | 96 | `apps/kits/` | `Option.value o ~default:d` |
| `appkits/draw/Drawing` | 100 | 80 | `apps/kits/` | none |
| `libs/compression/Packbits` (Bitmap's rows) | 65 | 37 | `lib_compression/` | not surveyed |
| `apps/graphics/draw_view/Figure_shapes` | 55 | 14 | `apps/office/` | its `Page.mli` |
| `apps/office/stroke_text/Stroke_text` | 51 | 34 | `apps/office/` | its `Page.mli` |
| `apps/office/file_menu/File_menu` | 137 | 88 | `apps/office/` | `?(items = items)` |
| `apps/office/embed/Component` | 78 | 88 | `apps/office/` | none |
| `apps/office/Part_text` | 133 | 12 | `apps/office/` | its `Rich.mli` |
| `apps/office/Part_sheet` | 98 | 11 | `apps/office/` | `?(cols = 3) ?(rows = 5)` |
| `apps/office/Part_picture` | 107 | 8 | `apps/office/` | none |
| `apps/office/Part_drawing` | 141 | 22 | `apps/office/` | `?(max_height = 220.)` |
| `apps/office/Part_chart` | 69 | 28 | `apps/office/` | none |
| `apps/office/TinyOffice` | 1,083 | 0 | `apps/office/Office.ml` | `` `Header `` |
| **21 files** | **3,066** | **1,020** | | |

Already here, and not copied again: `appkits/document/Undo`,
`appkits/sheet/Sheet`, `appkits/sheet_view/Sheet_view` (`apps/kits/`),
`languages/formula/Formula`, `libs/gui`'s `Focus`, `Immediate`, `Look`,
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
2. **One directory for what draws**: `Component`, `File_menu`,
   `Stroke_text` and `Figure_shapes` in `apps/office/`, flat. In the
   playground each is a library of its own because programs of other
   categories use them (music's, graphics', the browser's); here one
   program does. They move out when a second program asks.
3. **`apps/kits/` stays one flat library** (`ix_kits`), ten modules
   added to its three. One name to watch: `Pattern` is also
   `builder/`'s (mini-mk's); the two are never linked together, and
   `Paint_pattern` is the rename if that ever changes.
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

Not started. 2026-10-09: the survey (`apps/office/survey.sh`) and this
plan, its decisions agreed.
