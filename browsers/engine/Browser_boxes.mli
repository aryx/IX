(* Browser_boxes: a page laid out by the box model (Box_layout) as the
 * playground's shapes -- TinyChrome's drawing, where Browser_draw is
 * the teaching browsers'.
 *
 * CSS's painting order, simplified (CSS 2.1 appendix E): each box's
 * background, then its border, then what is inside it -- its inline
 * elements' backgrounds and borders, its lines' words and pictures
 * (Browser_draw.glyphs, the same pen), its list marker, its children
 * in order; the absolute boxes come last, being
 * the page's last children. A colour with transparency is mixed with
 * white (the page under it, most of the time).
 *
 * A box whose overflow is not visible (hidden, and here auto and
 * scroll, a box that would scroll) clips what it holds -- by what is
 * drawn, not by pixels (the playground has no clipping): a background
 * or a border cut to it, a line or a word not wholly inside left out.
 * What screen readers are given in a 1-pixel box is so hidden, and a
 * table of contents taller than its column cut at its bottom.
 *
 * A background-image is drawn once its picture has come, at its own
 * size at the box's top left, or shrunk to fit the box if larger:
 * background-size, -position and -repeat read as that.
 *
 * A mask-image (Wikipedia's icons: an SVG, the box's background
 * showing through its shape in currentColor) is drawn as its picture
 * tinted with the background's colour, its alpha kept, fitted to the
 * box and centred -- what a mask of one colour gives.
 *
 * Not drawn: border styles (every border solid), rounded corners,
 * shadows, gradients.
 *
 * modern:
 * A real browser does not draw from its boxes each frame. Painting
 * makes a list of drawing commands, kept; the page is cut into layers
 * (what scrolls, what is fixed, what is transformed or animated),
 * each drawn once into a texture by the graphics card, and a separate
 * thread -- the compositor -- only moves the layers for each frame.
 * Scrolling and an animation of position or opacity then cost no
 * layout and no painting at all, which is why they stay smooth while
 * a script runs. Here every frame's shapes are made from the boxes,
 * and there is one layer.
 *
 * terminology:
 * The painter's algorithm: what is behind is drawn first and what is
 * in front over it, as a painter covers the sky with the tree. No
 * depth is kept with a pixel (the z-buffer of 3D graphics); the
 * order of the list of shapes is the depth. It is the windows' way
 * too, a window system drawing its windows from the back. *)

(* the page's shapes, each with its top and bottom on the page (y down,
 * turned over: Browser_draw.drawn) *)
val draw :
  visited:(string -> bool) -> picture_of:(string -> Browser_picture.t option) -> Box_layout.box -> Browser_draw.drawn

(* a CSS colour as the playground's, its transparency mixed with white;
 * None if fully transparent *)
val color : Css_values.color -> Playground.color option
