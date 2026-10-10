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

**Status: stages 1 to 4 of 6 done, stage 5 begun** (the kits; what
draws and the parts; a document saved; mini-office on Linux; on
mini-9pi it starts, a document is typed in, its menus do not open yet;
see Status at the end). **Stage 7, a picture from a file (PNG, JPEG):
done on Linux** (Insert > Image..., turned by quarters, saved,
exported), **not run on mini-9pi**: its own section, after the stages.

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
   | `document/` | `Saved`, `Undo`, `Document` (mini-office's own) | `appkits/document` |
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
3. **`apps/kits/` is gone.** `Sheet` and `Sheet_view` are
   `apps/office/sheet/`'s (the author, 2026-10-09: "let's move the
   Sheet to apps/office/sheet and get rid of the Gui7Cells example
   maybe (or link the apps/office/ libs necessary, which is fine
   too)"), and `Undo` `apps/office/document/`'s, beside `Saved` as in
   the playground ("let's move Undo indeed too"). Gui7Cells and
   Gui7Circles are kept, `examples/` linked with `ix_office` (dune)
   and with `WITH=formula sheet undo` (mini-mk: those units, not the
   rest of the office). One
   name to watch:
   `Pattern` is also `builder/`'s (mini-mk's); the two are never
   linked together, and `Paint_pattern` is the rename if that ever
   changes.
4. **`Packbits` in `lib_compression/`**, beside `Zlib`: it is a
   compression, and the playground has it there.
5. **TinyOffice only, for now.** The ten period programs are 4,891
   lines more and two of them need libraries ix has not; they are not
   what was asked.
6. **Counted in m-IX's budget** (the author, 2026-10-09, stage 5
   under way: "let's actually count apps/ now in make loc; an Office
   is also pretty fundamental in an OS for a user"; first agreed: not
   counted, as `editors/drscheme/` is not). `scripts/stats/loc.py`'s
   row that set `apps/` apart is gone: m-ix goes from 84,714 lines to
   90,353 with tests (`apps/` 5,639 without its tests, 975 of tests).
   Then the two libraries under it ("yes lib_gui and lib_playground
   should also count now for make loc I think"): `lib_gui/` and
   `lib_playground/` are `make loc`'s libraries. Still not m-ix's:
   `lib_physics/` (the games' engine, which `lib_playground`'s
   `Physics` is the face of) and `games/`, in "other"; the software
   platform and `lib_graphics/software/` (Hershey's strokes among
   them), apart.
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
7. **A picture from a file** (PNG, JPEG), scaled and turned: the next
   section, its four sub-stages.

## A picture from a file (PNG, JPEG): stage 7, done on Linux

The author (2026-10-09): "for mini-office, we need to add from the
~/playground code to load images (png, jpeg, etc.) so we can load them
in a Document (and possibly scale them, rotate them). What do we need?
Can you extend the office plan for it? Also note that the plan browser
and netscape will also need support for those images in
lib_graphics/images/ ?"

The short answer: **six files to copy (1,149 lines of .ml, 560 of
.mli), and three things to write, which the playground's office has
not either.** The playground's TinyOffice loads no file's picture: its
`Part_picture` is `Bitmap`'s, dots black or white drawn with the
mouse. What reads a PNG or a JPEG is in the playground's
`libs/graphics/images/`, and what draws one scaled and turned in its
`Blit`; ix has neither, and its platforms draw `Playground.Bitmap` and
`Playground.Image` as a grey rectangle (`Shape_render_software.ml:258`,
`draw/Playground_platform.ml:302`). The three to write: the picture
drawn by the platforms, a part for it (`Part_image`), and a way to
choose a file that is not a document.

The same six files are `plan_browser.md`'s `lib_graphics/` row less
`Svg` and `Curve`, and the same drawing is the first half of its stage
5 ("Pictures, and the window's size"): done here, the browser's stage
5 is `Svg`, `Curve`, a picture by URL and the window's size.

### What to copy

The playground at `028d8abf`; what mini-ml refuses first, by
`bin/mini-ml -m 7` over ix's `Rgba_image` and `Zlib`.

| the playground's | .ml | .mli | here | mini-ml's first refusal |
|---|---:|---:|---|---|
| `libs/compression/Huffman` | 88 | 80 | `lib_compression/` | none |
| `libs/graphics/images/png/Png` | 280 | 114 | `lib_graphics/images/` | `img.rgba.{o} <- r` (a Bigarray) |
| `libs/graphics/images/jpeg/Dct` | 101 | 60 | `lib_graphics/images/` | none |
| `libs/graphics/images/jpeg/Jpeg_progressive` | 89 | 95 | `lib_graphics/images/` | none |
| `libs/graphics/images/jpeg/Jpeg` | 434 | 120 | `lib_graphics/images/` | `for _ = 1 to n` |
| `libs/graphics/core/Blit` | 157 | 91 | `lib_graphics/software/` | `image.rgba.{o + k}` |
| **all six** | **1,149** | **560** | | |

Behind the first refusals, counted by grep:

- **Bigarray**: 20 lines in the six (`Png` 5 indexings, `Jpeg` 4,
  `Blit` 1 and its `image` type). ix's `Rgba_image.t` is a `Bytes`
  already (mini-ml has no Bigarray): `Bytes.set` and `Bytes.get`, and
  `Blit.image` is `Rgba_image.t`, the playground's copy from one to
  the other gone.
- **`Zlib` and `Crc32`** (`Png`, 6 uses): the playground's
  `Zlib.decompress`, `Zlib.compress`, `Crc32.update` and
  `Crc32.string` (an `int32`) are ix's `Zlib.inflate`, `Zlib.deflate`,
  `Zlib.crc32_sub` and `Zlib.crc32` (an `int`). `Png`'s 7 uses of
  `Int32` go with them. **To check on arm**: a CRC is 32 bits and
  mini-ml's `int` there is 31.
  **Checked (2026-10-09, `plan_pdf.md`)**: it does not fit, and
  `Zlib.crc32` is wrong there (`bugs/ix.md`); `Png` reads and writes
  a chunk's CRC by `Zlib.crc32_halves`, its two halves of 16 bits, and
  a PNG then reads on arm under mini-5i, the frame OCaml's.
- **Optional arguments**: `Png.encode ?alpha ?filter`,
  `Jpeg.parse_frame ?progressive`, `Jpeg.decode ?idct ?upsampling
  ?keep`, the last with a polymorphic variant (`` `Triangle ``): a
  type, and each argument said by the caller, as in the kits.
- **`for _`**: `for _i`, as `Packbits`'.
- **Floats**: `Dct` and `Jpeg`'s colours are floats, `Blit` too. mini-ml
  has them; what a photograph's decoding costs on arm is not known
  (see the open questions).

mini-chrome's `libs/images/Png.ml` is the playground's, the same 280
lines: one `Png` serves both plans.

**Not copied**: `Image_decode` (271 lines: a URL fetched, a cache, a
thread, GIF's animation by the clock; the browser has its own
`Fetch`), `Download`, `Texture_decode` (3D); `Gif` and `Lzw` (249
lines; `plan_browser.md` cuts GIF too; they compile but for `Gif`'s 6
Bigarray lines, so a later hour); `Jpeg_encode` (251: nothing here
writes a JPEG); `Ilbm`, `Xpm` (already in `lib_graphics/software/`);
`libs/graphics/imaging/` (856 lines: blur, levels, layers: a picture
edited, not shown).

### What to write

1. **`Image_file`** in `lib_graphics/images/` (about 15 lines):
   `decode : string -> Rgba_image.t`, the format by the file's first
   bytes (`\137PNG`, `\255\216`), not by its name; an exception with
   what the format is not. What mini-office and mini-netscape both
   call.
2. **A picture drawn by the platforms**: `Playground.Bitmap (w, h,
   img)`, which the interface has and nothing draws.
   - *The software renderer* (`ppm`, `sdl`, Plan 9's `software`): the
     playground's `draw_pixels` and `image_to_local`, about 15 lines
     of `Shape_render_software`: `Blit.draw` with the shape's matrix,
     so moved, scaled and turned by any angle for nothing more.
     `rendering.smooth_images` chooses `Bilinear` or `Nearest`.
   - *The draw platform* (mini-9pi): the device copies a rectangle of
     an image and neither scales nor turns it. So the picture is made
     in the program at the size and angle shown (`Blit.draw` into a
     `Framebuffer` of its bounding box), loaded once into an image of
     the kernel's (`Display.alloc`, `Display.load_sub`), and each
     frame after is one `Draw.draw`. Kept by the picture (`==`) and
     its matrix's four numbers, freed when another replaces it: a
     picture being resized is made again each frame of the drag, one
     at rest costs a message. A turned picture's corners need a mask
     (a second image, or a channel with alpha if the device's `draw`
     takes one: to check). This is what `plan_playground_speed.md`'s
     redesign does for a letter (an image of the kernel's, copied),
     and should be written with it in mind, not beside it.
   - `Playground.Image` (a URL) stays a grey rectangle: it needs the
     network, and is the browser's.
3. **`Part_image`** in `apps/office/parts/` (about 80 lines by
   `Part_picture`'s 107), a `Component.part` of kind `"image"`:
   - its state: the file's bytes as read, the `Rgba_image.t` decoded
     from them once, quarter turns (0 to 3);
   - `save`: **the file's bytes**, not the pixels: a document carries
     a photograph at its JPEG's size (a 1024x768 one is 3 MB of RGBA).
     `load` decodes again. A build without the readers shows
     `Component.placeholder` and saves the bytes back, as for any
     kind it does not know;
   - `natural`: the picture's width and height (swapped at 1 and 3
     turns). **Scaling is then there already**: an object with a
     natural size and `scaled` is drawn by `Component.draw_in` to its
     frame keeping its proportions, and the frame is resized by its
     corners (`Document.placed`'s `w`, `h`, `scaled`);
   - `draw`: one `Playground.bitmap`, turned by `Playground.rotate`;
   - `menu`: "Image": Rotate Left, Rotate Right, Original Size;
     `input`: nothing (it is not painted on).
   The name: `Part_picture` is taken (the dots), and the menu's
   "Picture" with it: "Image" here, Insert > Image...
4. **A file chosen**: Insert > Image... needs a name. `Store.fetch`
   gives any stored name's bytes already; `File_menu`'s Open lists
   the names of one kind (a magic line, an extension) and reads a
   document. A second use of its list for `.png`, `.jpg`, `.jpeg`
   giving the bytes: its size depends on how `File_menu`'s dialog is
   cut, not read yet. On mini-9pi the pictures are files of the card
   (`kernels/9pi/Makefile`, as `CARD_SRC`), in the store's directory.
5. **The build**: `lib_graphics/images/dune` (a library of its own,
   `ix_images`, over `ix_compression` and the software library's
   `Rgba_image`); `games/mkgames`'s `WITH=images`; `ix_office` and
   mini-office linked with it.
6. **Tests**: the playground's `Unit_png` (235 lines, over PngSuite's
   116 files, 472K, its licence beside them), `Unit_jpeg` (133, over
   11 JPEGs, 96K with what each decodes to: baseline, progressive, 4:2:0, 4:2:2, restart
   markers, gray, CMYK) and `Unit_blit` (123),
   for dune; a `Part_image` test in `Unit_parts` (saved and loaded,
   turned four times is itself); a scripted session and its frame
   (an image inserted, resized, turned) in `frames.expected`; one
   PNG and one JPEG decoded by mini-ml's build, their sums against
   dune's.

### Sub-stages (each checked before the next)

- **7a. The readers.** `Huffman`, `Png`, `Dct`, `Jpeg_progressive`,
  `Jpeg`, `Image_file`, built by dune and by mini-ml; the two unit
  tests; a decoding's time on arm64 and on arm under mini-5i.
- **7b. A picture drawn on Linux.** `Blit`, `Unit_blit`, the software
  renderer's `Bitmap`; a Playground example with a picture scaled and
  turned, its frame against the playground's.
- **7c. `Part_image` on Linux.** The part, Insert > Image..., the
  file chosen, the document saved and opened; the session's frame.
- **7d. mini-9pi.** The draw platform's `Bitmap`, the pictures on the
  card; a frame's time with a picture at rest and one being resized.

### Decisions to confirm

- **A turn is a quarter turn** at first. `Blit` and `Playground.rotate`
  take any angle; what any angle asks beyond them is the frame (the
  turned picture's bounding box, the text running round it) and a
  handle to drag. Quarter turns ask a menu.
- **`lib_graphics/images/` flat** (`Png`, `Dct`, `Jpeg`,
  `Jpeg_progressive`, `Image_file`; `Svg` and `Gif` when they come),
  not the playground's folder a format; `Huffman` in
  `lib_compression/`, `Blit` in `lib_graphics/software/`: what
  `plan_browser.md`'s decision 5 says.
- **PNG and JPEG only**; GIF when a document or a page asks.
- **`make loc`**: `lib_graphics/images/` counted in m-ix as the
  libraries are, or apart as `lib_graphics/software/`? `Blit` goes
  with the second either way.

### Open questions

- **A JPEG's time on arm**: the cosine transform is floats, 64 a
  block, and mini-ml's floats are boxed. Measured in 7a before the
  part is written; if it is seconds for a photograph, the first thing
  to say is the size of picture that is reasonable, not an integer
  transform.
- **Memory on mini-9pi**: a picture is its file's bytes, 4 bytes a
  pixel decoded (a string of mini-ml's on arm holds 16 MB, 2048 by
  2048), the same again at the size shown, and that in the kernel's
  image. What a process there can have is `plan_self_hosting.md`'s
  open question too.
- **A picture larger than its frame** is sampled down by `Blit`, one
  pixel of 16 taken at a quarter of its size (`Bilinear` blends 4
  neighbours, it does not average what it skips): a photograph much
  reduced is grainy. The playground's `imaging/Scale` has an averaging
  one, if it shows.
- **Export**: a document with an image exported to what? (`Png.encode`
  is in the copy, and `Zlib.deflate` under it.)
  A PDF, by `plan_pdf.md` (2026-10-09): the picture an image object
  in it, its bytes deflated. Export writes one since that plan's
  stage A (`Office_export`).

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

**Stage 7, a picture from a file: 7a, 7b and 7c done, 7d written
and not run** (2026-10-10; the author, of what was left after
`plan_pdf.md`: "ok let's do them all, one at a time").
- *7a.* `Image_file` (`lib_graphics/images/`, 17 lines: `decode`,
  the format by the first bytes; mini-page calls it too). The
  playground's `Unit_png`, `Unit_jpeg` and `Unit_blit` in
  `lib_graphics/images/tests/` with their pictures (`pngsuite/`,
  `jpegs/`, and `ours/` for the three PNG files of the playground one
  test reads; 656K): 19 tests, dune's. A decoding's time, the
  playground's `aldrin.jpg` (400 by 400, 4:2:0, 47K) shown by
  mini-page, the whole run: 0.10 s by OCaml's build, 0.61 s by
  mini-ml's (arm64), the same frame; not timed on arm.
- *7b.* `Unit_blit` (above). No example was written: mini-page and
  the office's sessions draw a picture.
- *7c.* `Part_image` (`apps/office/parts/`, 64 lines): the file's
  bytes kept and saved after a digit, the turns; the picture decoded
  and turned once, the same value shown frame after frame; its menu,
  Image: Rotate Left, Rotate Right (Original Size is Arrange > Natural
  Size, already there). **The pixels are turned, not the shape**: every
  platform is given an upright `Bitmap`, the draw platform's case.
  `File_menu.choose` and its result `Chosen (name, bytes)`: a third
  dialog, Open's list for other endings, the bytes not looked at;
  `File_menu.say`. Insert > Image... in `Office_update` (the
  capabilities are there, a command has none), `Office_edit.insert_image`.
  Two things of the host changed for it: an object larger than the
  page inside its margins is inserted at the size that fits; an
  object whose natural size its own command changed keeps its scale,
  its frame taking the new shape (`Office_edit.commanded`). Checked:
  `Unit_parts`'s test of the part (saved, read back, turned four
  times, what is no picture kept whole); `apps/office/tests/image.sh`
  (new; a store with a picture in it, which `frames.sh` has not):
  the picture inserted, then turned and the document exported, the
  two frames' sums, the PDF read back by mini-page, by dune's build
  and by mini-ml's (arm64; `inserted` has a second sum there, 3
  pixels a grey level apart); both frames looked at, and poppler's
  picture of the exported page: the picture is in it, turned.
- *7d.* The draw platform's `Bitmap` is `plan_pdf.md`'s C2, seen on
  the Pi 1 by mini-page. The card has two pictures in the store
  (`/usr/pad/lib/documents/shapes.png` and `aldrin.jpg`,
  `apps/office/pictures/`). **Not run**: the card not built again,
  Insert > Image... not tried on mini-9pi; a frame's time with a
  picture there.
- Not done: any angle; a picture not opaque on the draw platform
  (its grey box); `make loc`'s row; a picture chosen from another
  directory than the store.

Of stage 7, by `plan_pdf.md` (2026-10-09), which needed them first:
`Huffman`, `Png`, `Dct`, `Jpeg_progressive` and `Jpeg` are here
(`lib_compression/`, `lib_graphics/images/`), by dune and by mini-ml,
and `Blit` (`lib_graphics/core/`); `Shape_render_software` draws a
`Bitmap`. Left of 7a: `Image_file`, the playground's unit tests of
the readers, a decoding's time. Left of 7b: `Unit_blit`, the
example. 7c and 7d whole. And `lib_graphics/software/` is four
folders now (`core/`, `geometry/`, `images/`, `software/`).

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

**Stage 3, a document saved: done** (2026-10-09). Against what the
plan said:

- **The capabilities are used** (the author: "and let's try to use
  capabilities for those IO document"). The playground's store takes
  none (its platform is trusted; the wrappers' types alone name one).
  Here `lib_playground/platforms/Store` (written again, 46 lines)
  does each thing through the capability it is given: the directory's
  name read in the environment (`CapSys.getenv`, `Cap.env`), a file
  read (`FS.read_opt`, `Cap.open_in`), one written and its directory
  made (`FS.write`, `FS.mkdir`, `Cap.open_out`), the directory listed
  (`Sys_plan9.dirread`, `Cap.readdir`). So `File_menu.caps` has
  `Cap.env` too, one more than the playground's.
- **Not four functions in each platform**: one `Store` for the four
  (in `ix_playground_render`), which `File_menu` names. A library
  cannot name `Playground_platform` here: a platform is a program's
  choice at its link, and `File_menu` is in `ix_office`, the two
  programs' (ppm, SDL). The platforms would have been four lines each
  that call `Store`.
- **The directory**: `$PLAYGROUND_STORE`, else
  `$HOME/.ix-playground/documents` (`$home` on Plan 9: stage 5 says
  where on mini-9pi). Not the playground's `~/.elm-playground`: a
  document there is another program's.
- **`File_menu`** in `apps/office/file_menu/`: `menu_in`'s items
  said, an `Option.value` a `match`, `Gui.button_in`'s `~enabled`
  said (ix's `Gui` has it so).
- **Tests** (`Unit_store`, ix's own, 2; 59 with the others): a
  document stored in a directory two levels below one that is there,
  listed, fetched to the same bytes, stored over; a name with `/` or
  a leading `.` kept in the directory; `File_menu`'s Save asking for a
  name once (the dialog given the keys), then writing at once. The
  tests' program has `Cap.main`'s capabilities.
- **A saved document across builds** (the open question): a document
  stored by OCaml 4.14's program and by mini-ml's (a record, a list of
  tuples with floats, a look, a bitmap's bytes) are the same 97 bytes,
  and each program reads the other's, lists both, and finds nothing
  under a name not stored. Run by mini-mk, mini-ml and mini-ld on a
  copy of the tree. **Not checked: OCaml 5.5's** (this machine's
  switch is 4.14.2); its Marshal's headers differ, and a document
  across those two is still open.

**Stage 4, mini-office on Linux: done but for the window looked at**
(2026-10-09). `apps/office/Office.ml` (1,099 lines for TinyOffice's
1,083), built by dune (`apps/office/dune`: the ppm platform;
`apps/office/sdl/`: `bin/mini-office`, the window) and by mini-mk
(`apps/office/mkfile`, `WITH=gui kits formula office`; the top
`mkfile`'s `AFTER`). Against what the plan said:

- **The bands are `Head` and `Foot`** (a type `band`), not `Header`
  and `Footer`: those are `area`'s constructors already.
- Said where they were optional: `styled`'s bold, `obj`'s slide and
  link, `insert`'s link, `a_run`'s name (6 definitions, 20 callers).
- **A record copied with a field of another type** (`{ d with body;
  objects }` from a document of parts to one of their saved texts,
  `{ o with part }`): mini-ml gives the copy the type the record had,
  and refused the result. Written whole, in two functions
  (`with_part`, `with_parts`): the 16 lines more.
- Its main is ix's (`Cap.main`, the capabilities to `run_app` and to
  `File_menu`).
- **The 16 sessions** (`apps/office/tests/frames.expected`, run by
  `apps/office/tests/frames.sh`; in `tests/lite.sh`'s frames job and
  its build by ix): by dune's program, each frame is the playground's
  golden frame, **0 pixels of a million apart, the 16**; `reopened`
  among them, which saves a document, goes back to the start screen
  and opens it (`games/tests/frames.sh` gives each session a store of
  its own, `$PLAYGROUND_STORE`). By mini-mk's program (mini-ml,
  mini-ld, on a copy of the tree; 2.3 MB): 9 the same sums, 7 one
  pixel apart (`active`, `both`, `push`, `scroll`, `header`,
  `reopened`, `chart`), their second sum recorded (`RECORD=2`): the
  open question's answer, one pixel and not more.
- Run: the 16 by both programs (10 seconds, 21 by mini-ml's);
  dune's build whole; `compile_ix.sh apps` (23 of 23);
  `bin/mini-office` started with SDL's dummy driver, 3 seconds
  without an error. Linked for Plan 9 too (`mini-mk O=5 OS=plan9`,
  2.3 MB), not run there. **Not done: the window looked at** (no
  screen here: the author's to try, `bin/mini-office`), and
  `tests/lite.sh` whole.

**After stage 4, asked by the author** (2026-10-09):

- **`Office.ml` in modules** ("we need to split Office.ml, it is far
  too big and go beyond I think the usual 700 LOC judgment-limit we
  set before in ix"; "I would expect to have a core data structure
  like Document with all those parts referenced, that is marshalled on
  the disk, but I don't see one"). `document/Document` (129 lines):
  the document's record with its parts in it (`doc = Component.part
  doc_`: its kind, its body, the objects placed on it, its header and
  footer), the same record as it is saved (`saved = (string * string)
  doc_`, each part its kind and its text: what Marshal writes),
  `to_saved`, `of_saved`, the parts' registry, the file's magic line.
  And `suite/`: `Office_page` (165), `Office_templates` (109),
  `Office_model` (69), `Office_edit` (200), `Office_update` (252),
  `Office_view` (173), each with its interface (what the others use);
  `Office.ml` (126) is the header and the main. They `open` the
  modules before them, the playground's text being one file's. The 16
  sessions give the same frames, by dune's program and by mini-mk's.
- **The window on Linux starts at 1000 pixels**, the playground's
  units one for one, or the screen's usable height if less ("let's
  make the default font used a bit bigger; it's hard to see the label
  when running mini-office right now in Linux/SDL at least"): it was
  800, every label a quarter smaller. Not the theme's letters made
  larger: every recorded frame, and the 16 that are the playground's
  golden frames pixel for pixel, would be others. For every program
  of the SDL platform (mini-drscheme too). To be said if the letters
  themselves should grow.
- **`apps/` counted in `make loc`** (decision 6).

**Stage 5, mini-office on mini-9pi: begun** (2026-10-09).

- On the card (`kernels/9pi/Makefile`: `apps/office` in the
  directories built for Plan 9, `office` in the card's `bin/arm`),
  2.3 MB. Documents: `$home/lib/documents` (`Store`), a directory of
  the card's second partition, which the kernel writes (Kfs): they
  stay on a real card, and last a session under an emulator, whose
  card is a snapshot.
- **It runs on the bare screen** under QEMU (`office 'fps=off'`): the
  start screen, Document clicked, its page with the sheet floating on
  it and the text round it, a line typed in the text. The four screens
  looked at, recorded (`tests/office-bare.steps`, `.md5`; `make
  check-office`, QEMU only, not in `check-windows`).
- **Its menus do not open there** (`docs/plans/bugs/ix.md`): File
  clicked shows no item, so nothing was saved nor opened on mini-9pi.
  On Linux they do.
- **Not measured: a frame's time**, the stage's first question. What
  was seen: a session of 19 steps took 6 minutes under QEMU where
  mini-drscheme's 11 take 2 and a half (a step waits for the screen
  to stand still); a session with the frames' counter shown never
  stood still and was stopped, its counter not read.
- Not run: under mini-qemu, in a window of mini-rio's, on a real Pi.

**The menus, and the speed** (2026-10-09; the author, of the window
on Linux: "it is hard to click a menu; the menu disappear almost
immediately; also the graphics are pretty slow; moving around a sheet
inside a Word document is really slow"; then "are we optimizing and
adding fixes on top of something that is too slow to start from",
"TinyOffice was fast on Native and the web without extra opti", and of
Cairo for the window: "no, let's not go with Cairo; the ~/playground
does, because it tries to be fast, but here we are more on the
teaching side and we want opti to help also mini-9pi, really our main
target", "let's try to optimize the right thing").

- **Why the playground needed none of it**: its window is drawn by
  Cairo and its loop gives one update then one view. ix's window on
  Linux is drawn by the program's own pixels (the software renderer),
  mini-9pi's by the draw device (the program computes no pixel there:
  `lib_graphics/software` is the strokes' coordinates and the
  geometry), and ix's loops give the ticks due since the last frame,
  several updates, before one view.
- **The menu's bug, found and fixed** (`bugs/ix.md`): the `Gui`'s
  frame was opened by an update and closed by a view only, so the
  first update's click was the next update's too, which closed the
  menu it had opened. On mini-9pi and on Linux the same. A frame is
  opened for each update now, known by its time, and each tick has
  its own time (`Gui`, `Plan9_loop`, the SDL platform).
  `tests/Unit_menu`: fails without, passes with.
- **Measured** (Linux, a page of text: 7,942 shapes, a letter's
  strokes each): a frame of a document nobody touches was 25 ms, 5 of
  update and view, 17 for `Redraw` to find that nothing changed; a
  sheet dragged, the text flowing again, 80 ms, 60 of them pixels. By
  mini-ml's code on the same machine, update and view are 17 ms.
- **The right thing first: not computing again what did not change.**
  A document is a value, the same record until an edit:
  `Office_page.kept` keeps the objects' places, the layout and the
  pages of the last document asked, `Office_view.glyphs_at` its
  letters' shapes; `Redraw` leaves out what two frames share at both
  ends before comparing them. Each behind `Opti.enabled`, the simple
  code kept. A still page: 25 ms a frame to 1.5; update and view by
  mini-ml's code 17 to 1.4. The 16 sessions give the same frames, by
  both programs. (The playground's notes_opti_ocaml.md, section 23.)
- **Not gained: the drag**, each frame another document: 6 ms of
  update and view (15 by mini-ml's code) and a page's letters drawn
  again, 60 ms of pixels on Linux; on mini-9pi as many messages to
  the draw device as there are strokes. The letters are the cost:
  next, a letter drawn once and kept (a picture of it copied), or a
  line of text one shape, for both platforms; to be planned.
- **Found on the way** (`bugs/ix.md`, not fixed): mini-office's
  picture drawn by what changed is not the one drawn whole, in the
  menu bar's row (it was so before these changes).
- On mini-9pi after the fixes (QEMU, 1024 by 768): File clicked
  shows its items and they stay, New lit under the mouse; the
  recorded session (`office-bare`, 7 steps now) has the click and the
  menu open.
- **An Enter lost**, found by that session after the fixes: "Typed on
  mini-9pi." and Enter, the Enter in the full stop's tick, and
  TinyOffice's text takes what was typed or else Enter. A key that
  edits is given a tick of its own (`Plan9_loop.on_keys`); `bugs/ix.md`.
- **A frame's time on mini-9pi** (QEMU's Pi1; `stats=on`, the sheet
  dragged 70 small steps, each frame a new document): update 12 ms,
  view 97 ms, the showing 556 ms -- 7,941 shapes, 307 ms to make their
  messages and 235 ms for the device to draw them. The draw platform
  draws every shape of a frame that changed; a letter of TinyOffice's
  is not a `Words` but its strokes' segments, each a turned rectangle
  (`Stroke_text.glyph`), a polygon filled by the device, and thinner
  than a pixel at the body's size: strokes are missing on the screen
  ("the first" reads "lne li~st"; `bugs/ix.md`, not fixed).

- **A thin rectangle a line** (the author, the two ways laid out, a
  line in the draw platform or a letter one `Words`: "ok let's do 1"):
  the draw platform's rectangle thinner than a pixel and a half,
  turned, is the device's line, one pixel wide; upright, with two
  sides in one pixel, one pixel. The body's letters are whole on
  mini-9pi. The same drag: the showing 415 ms where it was 556 (the
  messages 255 for 307, the device 144 for 235); update 13, view 95.
  Other programs' screens that changed, each looked at beside the
  one before: mini-drscheme's buttons have their left sides (138
  pixels), TinyWolfenstein's map its rays whole (291). Recorded
  again under QEMU: `office-bare`, `drscheme-bare`, `drscheme-win`,
  `draw-wolf`; `draw-tetris` is as it was.

- **File > Exit** (the author: "in the menu can you add an Exit
  entry, in addition to open file, save, etc."): ix's, the
  playground's menu having none; the program ends at once, nothing
  asked of a document not saved (as New). `File_menu.caps` has
  `Cap.exit`. On mini-9pi's bare screen the shell answers after it
  (`office-bare`, 10 steps: Exit clicked, a command typed); the
  picture stays, nothing there drawing over it. Found by it:
  `games/mkgames` did not have `file_menu/`'s sources among what a
  program's objects depend on (`[a-eg-z]*`, written to leave
  `formula/` out), so the card's office was the one before; said.

Paused (the author: "let's pause this"): what is left of the speed,
the letters' ways with it, is in
[`plan_playground_speed.md`](plan_playground_speed.md), "A page of
text". Next here: the window of mini-rio's, and stage 6.
