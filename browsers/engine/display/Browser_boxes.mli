(* Browser_boxes: a page laid out by the box model (Box_layout), drawn
 * as the playground's shapes. This is mini-netscape's drawing, where
 * Browser_draw draws the first layout (Html_layout).
 *
 * It follows CSS's painting order, simplified (CSS 2.1 appendix E).
 * Each box draws its background, then its border, then what is inside
 * it: the backgrounds and borders of its inline elements, the words and
 * pictures of its lines (with Browser_draw.glyphs, the same pen), its
 * list marker, and its children in order. The absolute boxes come
 * last, because they are the page's last children. A colour with
 * transparency is mixed with white (which is, most of the time, the
 * page under it).
 *
 * A box whose overflow is not visible (hidden, and here also auto and
 * scroll, for a box that would scroll) clips what it holds. It clips
 * by what is drawn, not by pixels, because the playground has no
 * clipping: a background or a border is cut to the box, and a line or
 * a word that is not wholly inside is left out. This is how the text
 * given to screen readers in a 1-pixel box stays hidden, and how a
 * table of contents taller than its column is cut at its bottom.
 *
 * A background-image is drawn once its picture has come. It is drawn
 * at its own size at the box's top left, or shrunk to fit the box if it
 * is larger; background-size, -position and -repeat are read as that.
 *
 * A mask-image (as in Wikipedia's icons, where it is an SVG and the
 * box's background shows through its shape in currentColor) is drawn
 * as its picture tinted with the background's colour, with its alpha
 * kept, fitted to the box and centred. That is what a mask of one
 * colour gives.
 *
 * Some things are not drawn: border styles (every border is solid),
 * rounded corners, shadows and gradients.
 *
 * modern:
 * A real browser does not draw from its boxes at each frame. Painting
 * makes a list of drawing commands, which is kept. The page is cut into
 * layers (what scrolls, what is fixed, what is transformed or
 * animated), and the graphics card draws each one once into a texture.
 * A separate thread, the compositor, only moves the layers for each
 * frame. Scrolling and an animation of position or opacity then cost
 * no layout and no painting at all, which is why they stay smooth
 * while a script runs. Here the shapes of every frame are made from
 * the boxes, and there is one layer.
 *
 * terminology:
 * The painter's algorithm: what is behind is drawn first, and what is
 * in front is drawn over it, as a painter covers the sky with the tree.
 * No depth is kept with a pixel (as the z-buffer of 3D graphics does);
 * the order of the list of shapes is the depth. A window system works
 * the same way, drawing its windows from the back. *)

(* the page's shapes, each with its top and bottom on the page (y goes
 * down, and the shapes are turned over: see Browser_draw.drawn) *)
val draw :
  visited:(string -> bool) -> picture_of:(string -> Browser_picture.t option) -> Box_layout.box -> Browser_draw.drawn

(* a CSS colour as a playground colour, with its transparency mixed with
 * white; None if it is fully transparent *)
val color : Css_values.color -> Playground.color option
