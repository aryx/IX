# browsers/engine: a page's boxes, and their shapes

The author's mini-chrome's `src/layout` and `src/display`
(`~/github/mini-chrome`), **its first version** (`475a979`,
2026-09-30), the base of
[`plan_browser.md`](../../docs/plans/plan_browser.md) (stage 6). Over
`browsers/html` and `browsers/css`, and for the shapes `lib_playground`
(`Playground`) and `lib_graphics` (`Hershey`, `Rgba_image`). A page
(`src/www`) and its address (`src/url`) come here too, flat, as the
plan's decision 3 says: not yet.

Each copied file says in one line where it comes from
(`ix: the author's mini-chrome's <path>, its first version`).

## What was copied

5 modules, 2,271 lines of `.ml` and 626 of `.mli` there (2,243 and 631 here):

| module | what |
|---|---|
| `Html_layout` | Mosaic's engine: one pass, each element's look the browser's own (`Looks`); and the types the other shares with it (a line, a fragment, a line breaker) |
| `Box_layout` | CSS's boxes: blocks, inlines, floats, positioned boxes, over `Computed`'s styles |
| `Flex_layout`, `Table_layout` | a flex container's main axis; a table's columns |
| `Hit` | the element under a point |

And its tests, `tests/` (mini-chrome's `tests/layout`: 61, Testo,
dune's only).

From `src/display`, 5 modules (587 lines there), and `Style` (its
`libs/richtext`'s, 19 lines: a letter's look, the browser's own copy):

| module | what |
|---|---|
| `Stroke_text` | a letter as Hershey's strokes, each a thin rectangle of the playground's |
| `Browser_text` | a word's width by those letters: the layout's metrics |
| `Browser_draw` | a line's words, a control, Motif's bevels: Mosaic's drawing, and the pen `Browser_boxes` shares |
| `Browser_boxes` | CSS's boxes painted: backgrounds, borders, lines, markers, in order, clipped by what is drawn |
| `Browser_picture` | a picture waiting, arrived or broken |

From `src/www`, `src/url`, `src/chrome` and `libs/typeset` (675 lines
there):

| module | what |
|---|---|
| `Browser_page` | a page read: its bytes to a tree, its sheets found (`<link>`, `<style>`, `@import`), laid out and drawn; the pages the browser writes (an error's) |
| `Browser_forms` | a click or a key on a form's control; what a form sends |
| `Browser_url` | a link's address against its page's; `data:` |
| `Browser_history` | Back and Forward: two stacks |
| `Linebreak` | Knuth and Plass's lines (`text-wrap: pretty`) |

## What changed

No optional argument:

- `Html_layout.layout metrics options`: a record (`breaker`,
  `picture_size`, `style`) and `Html_layout.defaults`, where they were
  three optional arguments. `Box_layout.layout metrics picture_size`
  (`Html_layout.no_picture` when none has come).
- A line breaker is `float -> unit_ array -> ...`: its `~measure`
  label is gone (mini-ml does not see a label through a type's name).
- Inside: `add_word`'s box, owner and edge are said at each call; a
  block's content width is an option said.
- The display: `Browser_draw.frame` and `frame_thick t`; `glyphs
  ~visited ~picture_of` and `plain_glyphs` (neither link nor picture);
  `draw ~extensions` and `text_shapes ~cells` are said;
  `Browser_boxes`'s tinted picture is a `Bytes` (it was a Bigarray).
- **No picture is read yet**: `Browser_picture.decode` says Broken for
  any bytes (it named `Png`, `Jpeg`, `Gif` and `Svg`: `Png` and `Jpeg`
  are being brought to `lib_graphics/images` by `plan_office.md`'s
  stage 7; `Svg` and `Gif` are this plan's stage 5), and an `<svg>`
  written in the page keeps its room and is not drawn
  (`Browser_boxes`'s `svg_node` and `svg_picture` left out).

## ix's own

`tests/Boxes.ml`, `tests/mkfile`, `tests/boxes.sh`, `tests/pages/`: a
page as its boxes, printed (element, place, size, lines), with a font
of fixed width: no window. So that mini-ml's build of the three
directories is run, and compared with OCaml's.

`tests/Frame.ml` (dune's only for now): a page as a picture, a PPM,
no window: the boxes laid out with the letters' own widths, drawn
(`Browser_boxes`), rasterized (`Shape_render_software`). By hand,
2026-10-09: **the Wikipedia article, 1,400 by 900, reads**: the title,
Article and Talk, the text with its links in blue, the box at the
right with its headings, "Philosophy" and its rule; 0.3 s of styles,
0.03 s of boxes, 0.4 s for the 72 shapes of a screen (862 for the
page, 15,890 high). As the plan said of the first version: a letter
with an accent is `?` (`Glyph_unicode` not yet back), the Contents are
above the article (no grid), and here no picture.

By hand, 2026-10-09: the Wikipedia article (354 KB) with its two
sheets (223 KB and 7 KB, fetched by mini-curl), 1,400 wide: **the same
1,436 lines of boxes by both builds**; OCaml's 0.30 s for the styles
and 0.02 s for the boxes, mini-ml's (arm64) 0.90 s and 0.13 s. The
Contents are above the article, for want of a grid.

Seen on the way: in `pages/small.html` the `<ul>` after a table whose
last cell is not closed (`<td>d</table>`) was laid out inside that
cell: mini-chrome's tree builder's, fixed in `browsers/html`
(`docs/plans/bugs/mini_chrome.md`, 1).

## What remains in mini-chrome

Its first version's `Browser_script` (a page's scripts: stage 9) and
the pictures' reading. Its tab and window are written anew in
`browsers/netscape`. And what its layout gained since
(`Grid_layout`, `Box_grid`, the split of `Box_layout` in five).
