# apps/office: mini-office

The author's playground's TinyOffice (`~/playground`,
`apps/office/TinyOffice.ml`): a document of pages, a text with looks
round objects floating on it, each a part (a text, a sheet, a picture
in bits, a drawing, a chart, a picture from a file), on lib_gui and
lib_playground. The plan:
[`plan_office.md`](../../docs/plans/done/plan_office.md). `Office.ml`'s
header draws the suite's layers, and `dune` says what each folder holds.

    bin/mini-office                a window on Linux (dune's alone: SDL)
    office                         on mini-9pi, on the bare screen or in
                                   a window of mini-rio's (on the card)

Its documents are in the platform's store: `$PLAYGROUND_STORE` or
`~/.ix-playground/documents` on Linux, `$home/lib/documents` on
mini-9pi (the card has two pictures there for Insert > Image...:
`pictures/`).

Each copied `.ml` says in one line where it comes from and what
changed (`ix: the author's playground's <path>; ...`). The numbers
below are `scripts/playground_copies.sh apps/office`'s, against the
playground at `ff335663` (2026-10-23).

## What was copied

TinyOffice and what it alone stands on: the kits of `appkits/`
(`document`, `richtext`, `paint`, `draw`, `sheet`, `sheet_view`),
`apps/office/`'s parts, `embed/Component`, `stroke_text`, `file_menu`,
`apps/graphics/draw_view`'s `Figure_shapes`, `languages/formula`
(`formula/README.md`), and the kits' unit tests: 50 files, 6,095 lines
there (4,754 of `.ml`), 7,015 here (4,745 of `.ml`; the interfaces
have their header comments).

## What changed

- **TinyOffice.ml, 1,083 lines, is eight modules**: `Office.ml` (the
  main and the playground's header, whole), `document/Document` and
  `suite/`'s `Office_model`, `Office_update`, `Office_edit`,
  `Office_page`, `Office_view`, `Office_templates`, a `Document` at
  their core.
- **What mini-ml takes**: an optional argument is said by every caller
  (`Page.layout`'s options a record, `Page.plain` to change); the
  polymorphic variant a type (`Document.band = Head | Foot`);
  `Option.value`'s `~default` a `match`; `Scanf` read by hand; a
  `Map.Make` lib_core's `Map_`.
- **The store through capabilities** (`File_menu`'s, with `Cap.env`
  and `Cap.exit`), in each platform: Linux's and mini-9pi's.
- **Ix's own items**: File > Exit, File > Export (the pages as a PDF
  file, `Office_export`), Insert > Image... (`parts/Part_image`: PNG
  and JPEG, turned by quarters, saved and exported).
- **Not computed again what did not change** (behind `Opti.enabled`,
  the simple code kept): `Office_page.kept`, a document's places and
  pages; `Office_view.glyphs_at`, its letters' shapes.

## What is ix's own

`parts/Part_image`, `suite/Office_export`, the interfaces of the
suite and of the parts, `survey.sh`, and the tests: `frames.sh` (the
playground's 16 sessions, each against its golden frame, by dune's
build and by mini-ml's; `make test-lite`), `image.sh` (a picture
inserted, turned, exported), `export.sh` (a PDF read back by
mini-page), `Unit_parts`, `Unit_store`, `Unit_menu`, `Unit_export`.
On mini-9pi: `make -C kernels/9pi check-office` (QEMU, the bare
screen).

## What remains in the playground

What TinyOffice does not use: `appkits/document`'s `Clipboard` and
its `Document`, `appkits/richtext/Flow`, `apps/office/embed/Compound`
(548 lines): the other office programs' (TinyWord, TinyOpenDoc,
TinyFrameMaker...), each a small plan of its own over the same kits.
