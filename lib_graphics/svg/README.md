# lib_graphics/svg: an SVG picture read and drawn

The author's playground's `libs/graphics/images/svg` (`~/playground`),
copied for the browser's pictures
([`plan_browser.md`](../../docs/plans/plan_browser.md), stage 5): the
logos and icons of the web's pages. `Svg.mli` says what is read (a
small XML reader, the shapes, a path's grammar, the fill rules) and
what is not (text, gradients, `<use>`, clips, filters).

Who uses it: `browsers/engine/` (`Browser_picture`: an SVG file as a
page's picture; `Browser_boxes`: an `<svg>` written in the page).

It is not in `../images/` as in the playground: that directory is
built before `../software/`, whose `Fill` and `Stroke` Svg calls.

## Changed

For mini-ml, each said in the file's `ix:` line:

- a path's tokens and its last control point are types (`token`,
  `control`), where they were polymorphic variants;
- `render node ~width ~height` and `render_in color node ~width
  ~height`, where `render` had an optional `?color`;
- the pixels are a `Bytes` (`Rgba_image`'s here), not a Bigarray;
- `Curve.flatten`'s tolerance is said (0.1, its default there).

## Remains

`tests/` has the playground's `Unit_svg` (7 tests, dune's only). The
numbers against the playground: `scripts/playground_copies.sh`.
