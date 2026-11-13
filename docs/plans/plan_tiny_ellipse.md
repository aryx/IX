# Plan: ellipses in t-IX, from the kernel's pixels to the office's printouts

The author (2026-11-13): "right now t-ix can not draw circles or
ellipses? Does it mean it can make games like tetris but not other
games like spacewar?", then "let's make a plan_tiny_circle.md (or
ellipse) document, so we can have ellipses in the playground, in
tiny-office drawing, etc. it's an interesting cross-cutting exercise
and whole system extension".

**Status: not started** (2026-11-13).

## Why this is worth doing

Today no layer of t-IX can draw a curve:

- KGraphics.mli lists "Ellipses, arcs, polygons and thick lines"
  among what it dropped from Plan 9's draw. It can fill a rectangle,
  draw a line one pixel thick, and draw text and rows of pixels.
- TinyLibPlayground's shapes are `Rect`, `Words`, `Group` and `Move`.
  It does not even expose the kernel's line. Its `dropped:` section
  names "circles, polygons and images", and its `exercises:` section
  asks for "circles and polygons, once KGraphics.ml draws them".
- TinyOffice's drawing has a box, an arrow and a text. Drawing.mli
  says the arrow goes across and then up or down because "the shapes
  can only draw rectangles".
- TinyTroff prints a drawing as text, as SVG and as PDF, and it only
  knows these three kinds.

An ellipse is a good exercise because it is one small idea that
crosses every layer of the system: a kernel message, the library that
makes the messages, the window system that forwards them, the C
runtime, the game library, the GUI library's redrawing, an
application's file format and tools, and a formatter's three back
ends. Each step is a few lines, and each has a test that already
exists to extend. At the end, a game can have a ball and the office
can have an oval, and a reader of t-IX can follow one feature from
the pixels up to the printed page.

Arcs, polygons and thick lines stay out of this plan. They are listed
at the end as the next exercises.

## The design

### One kernel message, two letters

Plan 9's draw device has two messages for ellipses (principia's
kernel/devices/screen/drawmesg.c): `e` draws an ellipse's outline and
`E` fills it. Each carries the destination, the source, the centre,
the two half axes `a` and `b`, a thickness, a source point and two
angles for an arc. KGraphics keeps Plan 9's letters for `f`, `d` and
`s`, so it should keep `e` and `E` too, with fewer numbers:

    e dst src cx cy a b             an ellipse's outline, a pixel thick
    E dst src cx cy a b             a filled ellipse

Both are 13 bytes, the same size as `l`. The thickness is always one
pixel, which is what the line already does. There is no source point:
as for `l`, the source is a colour, so where it is read from does not
matter. There are no angles, because arcs are left for later. A circle
is an ellipse whose `a` equals `b`, so it needs no message of its own.

### Rows of pixels, drawn with the one operation

KGraphics has one operation, `draw`, and everything else is built on
it: the line is a series of one-pixel draws, and a text is a draw
through the font. The ellipse should follow the same rule, as m-IX's
Memshape.ml does (its `ring` turns a shape into horizontal runs of
pixels and draws each run with memdraw's draw). So the kernel needs
only one new function, which computes how wide the ellipse is at each
row:

- a filled ellipse is one `draw` per row, of a rectangle one pixel
  high, from `cx - w` to `cx + w`;
- an outline is at most two `draw`s per row, the left and the right
  pieces. Each piece goes from the row's own half width out to the
  half width of the neighbouring row that is wider. This is what keeps
  the outline connected near the top and the bottom, where the curve
  is almost flat and one row covers many pixels.

Clipping comes for free, since `draw` already clips to the
destination. The rows above and below the destination should be
skipped before the loop, though, so that a huge ellipse mostly off the
screen does not cost thousands of empty draws.

### Integers only, and no overflow on 31 bits

tiny-ml's integers are 31 bits (TinyML.mli), and t-IX has no floats
in the kernel. m-IX's `ring` uses floats, so it cannot be copied. The
half width at row `dy` can be computed with an integer square root:

    w(dy) = a * isqrt(b*b - dy*dy) / b

Every product stays below `32767 * 32767`, which fits in 31 bits, for
any `a` and `b` that a 16-bit message can carry. This formula
truncates, though, and makes small circles look thin (a circle of
radius 3 gets a half width of 2 at the row next to its middle). The
pilot should round like Memshape.ml's `ring`, which tests against half
axes of `a + 0.5` and `b + 0.5`. Done with doubled integers, that
means `A = 2a + 1` and `B = 2b + 1`, and then `B * B` must stay below
2^30. So the kernel should refuse half axes above 4,096 with
`Graphics`, as it already refuses images larger than 2,048 pixels.
The pilot decides the exact formula by drawing circles of radius 0 to
10 and looking at them, then fixing the result in the test.

`isqrt` is a few lines of Newton's method. It must be written in the
subset that mini-ml also compiles: no optional arguments, no Stdlib
(memory: tiny/ builds with mini-ml).

### The playground's shapes

The playground places a shape by its top left corner (`Move`), and a
`Rect` is a colour, a width and a height. An ellipse should be placed
the same way, as the ellipse that fits in its box:

    | Ellipse of colour * int * int        (* the outline in a w by h box *)
    | Disc of colour * int * int           (* the same, filled *)

They are two constructors and not one with a flag (memory: no bool
constructor args). The names are a decision to make; `Oval` and
`Filled_oval` are another choice. A box whose width or height is even
has no centre pixel. The simplest rule is that the ellipse's centre is
`(x + w / 2, y + h / 2)` and its half axes are `(w - 1) / 2` and
`(h - 1) / 2`, so an even box leaves its last column or row empty.
That is easy to say in the .mli and easy to test.

TinyLibPlayground's `draw` turns each into `d_ellipse` or
`d_fill_ellipse`. Nothing else there changes, since the playground
compares whole shape lists.

### The GUI library's redrawing

TinyLibGUI redraws only what changed by comparing the leaves of two
views (`leaves`, `area_of` and `compare_leaves` in TinyLibGUI.ml).
`area_of` falls through to an empty area for any leaf it does not
know:

    | _ -> x, y, x, y

So without a change there, an ellipse that moves would leave its old
picture on the screen: the old area would be erased as nothing. This
is the one place where forgetting the new shape fails silently, and
the plan's test for TinyLibGUI must catch it. The fix is one case:
an `Ellipse` or a `Disc` covers its box, like a `Rect`.

## The steps

Each step builds and passes its tests before the next one starts.
The sizes are estimates.

### 1. The kernel: KGraphics.ml (about 35 lines)

- `isqrt`, the half widths, `ellipse` (outline) and `fill_ellipse`,
  next to `line`.
- `e` and `E` in `message` and in the sizes of `messages` (13 each).
- KGraphics.mli: the two messages in the table of messages; "Ellipses"
  removed from the `dropped:` list (arcs, polygons and thick lines
  stay); the `exercises:` item "ellipses and filled polygons" reduced
  to filled polygons; a reference for the algorithm.
- The test: tests/KGraphics_tests/Picture.ml draws circles and
  ellipses of several sizes, both kinds, including one of radius 0,
  one cut by each side of the screen, and one with half axes above
  the limit (refused). The expected picture and its checksum are
  updated (`picture.expected`, `picture.cksum`, and the grey font's
  pair), and KGraphics_test.sh must give the same picture on the host
  and on tiny-machine.

### 2. The program's side: TinyLibDraw (about 8 lines)

- `d_ellipse` and `d_fill_ellipse`, each `dst src centre (a, b)`.
- `d_shape`: `'e' | 'E' -> 13, 2`, so that TinyWindows renumbers
  their two images.
- TinyLibDraw.mli: "There are eight letters" becomes ten.

### 3. The window system: TinyWindows.ml (about 3 lines)

Forwarding works once `d_shape` knows the letters. What remains is
`changed`, the area of the window that a message touched, which
decides what is copied to the screen: for `e` and `E` it is
`cx - a, cy - b, cx + a + 1, cy + b + 1`. Without it, an ellipse in
a window would be drawn in the window's image but not shown until
something else covers its area.

### 4. C programs: runtime/c/draw.h and draw.c (about 12 lines)

`d_ellipse` and `d_fillellipse` (the libdraw names), with the same
arguments as the message. Optionally, user/paint.c gets a tool that
draws a circle, which would be the test that a C program reaches the
new messages; it can also wait for a later pass.

### 5. The playground: TinyLibPlayground (about 8 lines)

The two constructors, their case in `draw`, the .mli's `dropped:`
and `exercises:` updated. A test in TinyLibPlayground_tests draws
both shapes and checks the messages produced.

### 6. The GUI library: TinyLibGUI.ml (about 3 lines)

The case in `area_of`. A test in TinyLibGUI_tests shows a view with a
disc, then a view with the disc moved, and checks that the old place
is erased.

### 7. The office: TinyOffice/Drawing.ml (about 20 lines)

- A fourth kind, `oval x y w h label`, in the drawing's data. It is
  made like a box, by dragging, and its label is centred like a box's.
- `tools` becomes `[ "box"; "arrow"; "text"; "oval" ]`. The tool
  numbers are written as literals in `stroked`, `draw_stroke` and
  `sketch_key` (`tool = 2`, `mod 3`). Appending the oval as tool 3
  keeps the other numbers, and `mod 3` becomes the length of `tools`.
- `figure_shapes` draws it with the playground's `Ellipse`.
- Drawing.mli's header: four kinds of shapes, and the sentence on
  rectangles updated (the arrow still goes across and then up or
  down; a slanted arrow is now possible with the kernel's line, but
  that is a separate change).
- A test in TinyOffice_tests/Pages.ml: a page with an oval, saved and
  read back, and drawn.

### 8. The printouts: TinyTroff.ml (about 30 lines)

TinyTroff prints a drawing in three ways, and each needs the oval:

- **Text** (`drawing_lines`, one character for 8 by 8 pixels): the
  oval's outline as characters, using the same half widths at the
  scale of the cells, with its label in the middle. The characters
  are a decision for the pilot: `(` and `)` on the sides and `-` at
  the top and bottom read well for a wide oval.
- **HTML** (`drawing_html`, SVG): `<ellipse cx cy rx ry fill="none"
  stroke="black"/>`, and the label as for a box.
- **PDF** (`drawing_pdf`): PDF has no ellipse operator, so the oval is
  four Bézier curves, one per quarter. Each control point is at about
  0.552 of the half axis from the end point. With integers, that is
  `a * 552 / 1000`.

TinyTroff_tests gets a page with an oval in each of the three outputs.

### 9. A demo: an orrery (optional, about 80 lines)

The author (2026-11-13): "I like this planet demo; I think I had such
a demo in ~/playground". The twin is ~/playground's
examples/PhysicsSolarSystem.ml (233 lines): the Solar System seen
from above, the planets on their real ellipses at their real speeds,
sped up, with keys for the speed, a pause, and true or compressed
distances and sizes. (Its neighbours are examples/PhysicsOrbit.ml, one
planet and four integrators compared, and apps/education/
TinyStellarium.ml, the sky seen from the ground. The first is about
floats and the second is too big for t-IX.)

The tiny version, TinyAppOrrery on the playground, with a user/ glue
file of a few lines as tetris.ml is (memory: tiny-kernel programs are
small glue), would use both new shapes: each orbit an `Ellipse`, each
planet and the Sun a `Disc`.

- **Kept**: the view from above, the planets' real periods and their
  places at 2000-01-01, the Sun at a focus of each orbit (Mercury's is
  visibly off-centre), the compressed distances and magnified sizes,
  and the keys for the speed and the pause.
- **Dropped**: floats. The twin solves Kepler's equation by Newton's
  method in floats; tiny-ml has none in the kernel's subset. The
  places can come from a table of sines in fixed point (256 entries,
  scaled by 1024), with a planet moving at a constant angular speed.
  That keeps the period and the ellipse but not Kepler's second law
  (faster near the Sun). Whether the second law is worth an integer
  Newton's method is a decision for the pilot; it would show on
  Mercury and nowhere else.
- **Dropped**: the true scale (the `d` and `s` keys), the Moon, and
  the labels if they crowd.

It also measures something this plan does not know yet: how many
discs the playground can redraw at 30 frames a second on
tiny-machine, since each disc is one draw per row and an orbit's
outline two. The playground's `show` keeps the first shape, the
ground, in an image of its own, redrawn only when it changed; each
frame copies that image with one draw, draws the other shapes over
it, and copies the result to the screen. So the orbits and the Sun,
which do not move, go in the ground, a `Group` drawn once, and a
frame costs one copy plus the planets' discs.

### 10. The documentation

- docs/manuals/t-ix.md, section 7.3: the two messages, if it lists
  the messages.
- tiny/README.md: the line counts, by `make loc-readme`.
- The `twin:` sections that compare with m-IX's lib_graphics: m-IX
  draws ellipses with floats (Memshape.ml), t-IX with integers.

## The gate

1. `make -C tiny test`, and the new tests above, pass.
2. KGraphics_test.sh gives the same picture on the host and on
   tiny-machine.
3. Since the kernel changes: `make test` and `make self-quick-tix`
   (memory: self-quick before commit).
4. `mini-mk` in tiny/ still builds, since KGraphics.ml, TinyLibDraw,
   the playground and the GUI library are compiled by mini-ml too.
5. tiny/TinyKernel's `check.expected` has CRLF line endings: if the
   kernel's output changes, it is patched with sed or copied from
   `check.out`, not with the Edit tool.

## Decisions to make before starting

1. The playground's names: `Ellipse` and `Disc`, or `Oval` and
   `Filled_oval`, or another pair.
2. The office's word for the shape in the file format: `oval` (as
   pic and MacDraw say) or `ellipse` or `circle` (pic has both
   `circle` and `ellipse`).
3. Whether paint.c gets a circle tool in this plan or later.
4. The orrery: whether planets follow Kepler's second law, at the
   cost of an integer Newton's method.

## After this plan

These are the next exercises, each one a smaller step once ellipses
exist, and each already listed in KGraphics.mli's `dropped:` section:

- **Arcs**: the same rows, keeping only the pixels between two
  angles. Without floats, the angle test can compare the signs and
  the cross products of the pixel's offset with the two directions.
- **Filled polygons**: also rows of pixels, from the crossings of
  each row with the polygon's edges. They would give the playground a
  triangle, and a game a ship that turns.
- **Thick lines**: a filled polygon of four corners, with a disc at
  each end, which is what m-IX's Memshape.ml does.
- **A `Line` shape in the playground**: the kernel already draws
  lines, so this is a few lines in TinyLibPlayground and TinyLibGUI,
  and the office's arrow could then go straight.

## References

- M. D. McIlroy, "Best approximate circles on integer grids", ACM
  Transactions on Graphics 2(4), 1983: the integer circle, and how
  to choose its pixels.
- J. Bresenham, "A linear algorithm for incremental digital display
  of circular arcs", Communications of the ACM 20(2), 1977.
- Plan 9's draw(2) (`ellipse`, `fillellipse`, `arc`) and
  libmemdraw/ellipse.c; m-IX's
  kernels/9pi/lib_graphics/lib_memlayer/Memshape.ml.
- B. W. Kernighan, "PIC: a language for typesetting graphics" (1982):
  `circle` and `ellipse` beside `box` and `arrow`.
