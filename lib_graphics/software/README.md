# lib_graphics/software: pixels computed by the program

The author's playground's software rasterizer (`~/playground`, its
`libs/graphics`): a `Framebuffer` of the program's own memory, and
what fills it. Nothing of Plan 9's nor of the draw device's, which is
the directory above. What `lib_playground`'s software and ppm
platforms draw with. The plan:
[`plan_playground.md`](../../docs/plans/plan_playground.md).

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_graphics/software`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

22 files, 1,619 lines there and 1,662 here, the playground's folders
made one:

| module | there |
|---|---|
| `Framebuffer`, `Opti` | `libs/graphics/core` |
| `Fill`, `Line`, `Circle`, `Stroke` | `libs/graphics/2d` |
| `Vec2`, `Affine` | `libs/graphics/2d/geometry` |
| `Hershey` | `libs/graphics/font` |
| `Rgba_image` | `libs/graphics/images/rgba` |
| `Xpm` | `libs/graphics/images/xpm` |

`Hershey_futural.ml` is the playground's `font/fonts/futural.jhf` as
it is, in a string: its dune makes that file there; here it is kept, so
that neither dune nor mini-mk has a rule for it.

## What changed

- `Framebuffer`, `Rgba_image`: the pixels are a `Bytes`, where they
  were a Bigarray of SDL's (mini-ml has no Bigarray; and the bytes are
  the draw device's, the `.mli` says). `clear` fills a grey by one
  `Bytes.fill` (an optimization, `Opti.enabled`).
- `Fill`: the rule is said, where it was optional (`Nonzero`); the
  sub-rows are 4.
- `Circle`: `segments_for_radius`'s tolerance is not an optional
  argument.
- `Hershey`: the font is made at the first glyph asked, without `Lazy`.

The others only by their header line.

## What remains in the playground

244 files of `libs/graphics`:

- `core/`: `Blit` (a picture drawn: until it is here `lib_playground`
  draws a picture as its box), `Matting`, `Pixelate`.
- `2d/`: `Curve`, `Magnifier`. `font/`: `Vga_font`.
- `3d/` (the triangles, the depth of each pixel, the ray tracer), `gpu/`:
  [`plan_gpu.md`](../../docs/plans/plan_gpu.md).
- `animation/`, `imaging/` (blur, blend, gradients, layers...).
- `images/` (GIF, ILBM, JPEG, PNG, SVG read) and `videos/` (AVI, FLI,
  MPEG-1...).
- Its tests.
