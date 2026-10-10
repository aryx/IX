# lib_graphics/pdf and lib_graphics/fonts: a PDF file read, drawn and written

The plan: [`plan_pdf.md`](../../docs/plans/plan_pdf.md). Who uses it:
`mini-page` (`apps/page/`: a file's pages looked at), `mini-office`
(`apps/office/`: File > Export writes one), and `mini-netscape` when
it shows pictures.

## Read: mini-chrome's, copied

`~/github/mini-chrome`'s `libs/pdf` and `libs/fonts` (its commit
`27319fd`; copied at `8af888e`, 2026-10-07): 15 files, 2,621 lines of
.ml there and 2,650 here. Bytes in, a picture out:

```
  bytes ──Pdf──▶ objects, pages ──Pdf_render──▶ Pdf_canvas ──▶ Rgba_image
            │                        │    │
       Pdf_object               Pdf_font  Pdf_color, Pdf_shading, Pdf_image
       Pdf_filter                    │
       (Zlib, Jpeg)             Truetype, Cff, Type1 ──▶ Outline ──Curve──▶ polygons
                                                                   (Fill, Stroke)
```

Each file says in one line where it comes from and what changed (`ix:
mini-chrome's <path>; ...`). The numbers are
`scripts/stats/pdf_survey.sh`'s, file by file.

What changed, all of it for mini-ml:

- **Optional arguments are said**: `Pdf_render.render ~options
  ~stroke_glyph` (they were `full` and `hershey`, which the interface
  gives now), `Pdf_filter.lzw ~early`, `Outline.polygons ~tolerance`,
  `Type1.of_string ~clear` (0: not known). Where the argument was
  only for a function to give itself, the function is two:
  `Pdf_object.parse_with ~length` and `parse`, `Truetype.outline_at`
  and `outline`, `Type1.glyph_at` and `glyph`.
- **`Pdf_font`**: two types where there were polymorphic variants (a
  ToUnicode table's entries; a font's file by its kind).
- **A picture's pixels are a `Bytes`** (`Rgba_image` here), where they
  were a Bigarray: `Pdf_canvas.to_image`, `Pdf_image`.
- **`Zlib` is ix's**: `Zlib.inflate`, and `Zlib.inflate_blocks` (new
  there: the blocks alone, for a stream whose header or checksum is
  wrong) where the playground's `Inflate` was called.
- `for _` has a name; three `Option.value ~default` are their match.

Under them, the playground's, in the folders beside:
`../geometry/Curve`, `../images/Jpeg` with `Dct` and
`Jpeg_progressive`, `lib_compression/Huffman`; and `../images/Png` for
the tests' pictures and mini-page's.

What remains in mini-chrome: its viewer (`src/viewers/Pdf_viewer`, a
document as a page of HTML: for mini-netscape) and `tests/pdf/Dump`
(mini-page's `-t` and `-ppm` do its work here).

Not read, there or here: an encrypted file, the outline, links and
form fields, tiling patterns, dashed lines, blend modes, layers,
annotations.

## Written: ix's own

`Pdf_write` (a file's objects, its pages, a content's operators) has
no origin: neither mini-chrome nor the playground writes a PDF.
`lib_playground/platforms`' `Shape_render_pdf` turns Playground shapes
into its operators; it names nothing of the reader.

## Tests

`tests/`: `Unit_pdf`, `Unit_fonts`, `Unit_pdf_render` (mini-chrome's
`tests/pdf`, 332 lines: seven files of other programs in `data/`, each
page near poppler's picture of it; `data/make.sh` says how they were
made) and `Unit_pdf_write` (ix's: a file's table, a shape's operators,
and what is written read back and held to the screen's picture).
`tests/write.sh` has poppler read a written file (not in `make test`).
