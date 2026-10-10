# lib_graphics/software, core, geometry, images: pixels computed by the program

The author's playground's software rasterizer (`~/playground`, its
`libs/graphics`): a `Framebuffer` of the program's own memory, and
what fills it. Nothing of Plan 9's nor of the draw device's, which is
the directory above. What `lib_playground`'s software and ppm
platforms draw with. The plan:
[`plan_playground.md`](../../docs/plans/plan_playground.md).

Four folders, as the playground has them (they were one, `software/`,
until 2026-10-09; the author: "like we did in the ~/playground", "and
also have a geometry subfolder"), each a library of dune's; mini-mk
compiles a unit from the folder that has it (`games/mkgames`):

| folder | modules | there |
|---|---|---|
| `../core/` | `Framebuffer`, `Opti`, `Blit` | `libs/graphics/core` |
| | `Rgba_image` | `libs/graphics/images/rgba` |
| `../geometry/` | `Vec2`, `Affine`, `Curve` | `libs/graphics/2d/geometry` |
| `../images/` | `Xpm` | `libs/graphics/images/xpm` |
| | `Png` | `libs/graphics/images/png` |
| | `Jpeg`, `Dct`, `Jpeg_progressive` | `libs/graphics/images/jpeg` |
| `software/` | `Fill`, `Line`, `Circle`, `Stroke` | `libs/graphics/2d` |
| | `Hershey` | `libs/graphics/font` |

Beside them, and not the playground's: `../pdf/` and `../fonts/` (a
PDF file read, drawn and written: their
[`README.md`](../pdf/README.md)).

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers are `scripts/playground_copies.sh lib_graphics/core
lib_graphics/geometry lib_graphics/images lib_graphics/software`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

22 files, 1,619 lines there and 1,662 here, at first (2026-10-06);
and for a PDF's pages and mini-page's pictures (2026-10-09,
[`plan_pdf.md`](../../docs/plans/plan_pdf.md)), `Blit`, `Curve`,
`Png`, `Jpeg`, `Dct` and `Jpeg_progressive`: 12 files more.

`Hershey_futural.ml` is the playground's `font/fonts/futural.jhf` as
it is, in a string: its dune makes that file there; here it is kept, so
that neither dune nor mini-mk has a rule for it.

## What changed

- `Framebuffer`, `Rgba_image`: the pixels are a `Bytes`, where they
  were a Bigarray of SDL's (mini-ml has no Bigarray; and the bytes are
  the draw device's, the `.mli` says). `clear` fills a grey by one
  `Bytes.fill` (an optimization, `Opti.enabled`).
- `Blit`: an image is an `Rgba_image`, where it was a record of its
  own over a Bigarray.
- `Curve`: `flatten`'s tolerance and `through`'s steps are said.
- `Png`: `Zlib` and its CRC are ix's (`lib_compression`), where they
  were the playground's `Zlib` and `Crc32` (an `Int32`): the CRC by
  halves (`Zlib.crc32_halves`), an int of 31 bits on arm not holding
  one; `encode`'s alpha and filter are said.
- `Jpeg`: `decode`'s three optional arguments are `decode_with`'s,
  said; the upsampling is a type, where it was a polymorphic variant.
- `Fill`: the rule is said, where it was optional (`Nonzero`); the
  sub-rows are 4.
- `Circle`: `segments_for_radius`'s tolerance is not an optional
  argument.
- `Hershey`: the font is made at the first glyph asked, without `Lazy`.

The others only by their header line.

## What remains in the playground

244 files of `libs/graphics`:

- `core/`: `Matting`, `Pixelate`.
- `2d/`: `Magnifier`. `font/`: `Vga_font`.
- `3d/` (the triangles, the depth of each pixel, the ray tracer), `gpu/`:
  [`plan_gpu.md`](../../docs/plans/plan_gpu.md).
- `animation/`, `imaging/` (blur, blend, gradients, layers...).
- `images/` (GIF, ILBM, SVG read; a JPEG written; `Image_decode`, a
  picture fetched by its name) and `videos/` (AVI, FLI,
  MPEG-1...).
- Its tests.
