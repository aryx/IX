(* Draws a list of Playground shapes into a framebuffer, using only the
 * from-scratch algorithms of graphics/ -- the software
 * rasterizer's counterpart of playground/platforms/native/Shape_render_native.ml,
 * which asks Cairo to do the same job.
 *
 * A shape's way to the pixels, the whole of what a 2D graphics
 * library does, in order:
 *
 *   a shape            circle red 20 |> move 100 50 |> rotate 30
 *     |
 *   its transform      one matrix (Affine): its scale, its angle, its
 *     |                move; then its group's, and the group's
 *     |                group's; then the screen's, which puts (0, 0)
 *     |                at the framebuffer's middle and turns y over
 *     v
 *   points in pixels   a rectangle, an n-gon, a polygon: their corners
 *     |                through the matrix. An oval: a polygon of
 *     |                enough sides. A circle, when the matrix left it
 *     |                round: its center and radius (Circle). Words:
 *     |                Hershey's strokes, each widened to the outline
 *     |                of a pen's path (Stroke), or left a line a
 *     |                pixel wide when the pen is thinner (Line)
 *     v
 *   which pixels       the polygon filled a row at a time (Fill), each
 *     |                edge pixel by how much of it is covered when
 *     |                antialiasing is on
 *     v
 *   what colour        the shape's over what is there, by its alpha
 *                      (Framebuffer); a Bitmap's own pixels, placed
 *                      by the matrix (Blit)
 *
 * The shapes are drawn in the list's order, each over the ones
 * before: the painter's algorithm, with no depth to compare. A group
 * is not drawn, it is a matrix its members are drawn through.
 *
 * Where it stands: three of the four platforms end here
 * (Playground_platform.mli draws them), Redraw calls [render_region]
 * for the boxes that changed, and Shape_render_pdf is the same walk
 * stopped after its second step, the points written down where here
 * they are filled. The fourth platform sends the same points to
 * Plan 9's draw device, and the kernel's Memdraw does the last two
 * steps.
 *
 * terminology:
 * A *rasterizer* turns geometry into a raster, a grid of pixels;
 * done by the program it is *software rendering*, where today a
 * graphics card does it. A matrix that keeps lines straight and
 * parallels parallel is *affine*: moves, turns, scales and their
 * products, which is why a group of groups is still one matrix. *)
(* ix: the author's playground's playground/platforms/software/Shape_render_software.mli (docs/plans/plan_playground.md) *)

(* ix: of the playground's options, the two that are not debug views;
 * render's options and scale are said (they were optional: the
 * defaults, and 1.), for render_region and pixel_bounds too. *)

(* Rendering features that can be turned on or off *)
type options = {
  (* false: no Porter-Duff blending; a faded shape is either drawn
   * fully opaque (alpha > 0) or not at all (alpha = 0) *)
  alpha_blending : bool;
  (* true: smooth edges, pixels partly covered drawn partly transparent
   * (Fill.polygons_aa, Line.draw_aa); false: all-or-nothing pixels,
   * "jaggies" *)
  antialiasing : bool;
}

(* blending on, antialiased *)
val default_options : options

(* [render ~options ~scale fb shapes]: the shapes drawn into [fb], the
 * playground's (0, 0) at its center; [scale] pixels per playground unit,
 * e.g. 0.48 to draw the 1000 units of a game's screen into a 480-wide
 * framebuffer *)
val render : options:options -> scale:float -> Framebuffer.t -> Playground.shape list -> unit

(* [render_region ~options ~scale ~window:(width, height) ~origin:(x0, y0) fb shapes]:
 * the part of the [width] x [height] window that [fb] covers, from the
 * window's pixel (x0, y0): the same pixels as [render] on the whole
 * window, cropped, for less work when only a part is needed *)
val render_region :
  options:options -> scale:float -> window:int * int -> origin:int * int -> Framebuffer.t -> Playground.shape list -> unit

(* [pixel_bounds ~width ~height ~scale shapes]: the box, (x0, y0, x1, y1) in
 * pixels of a [width] x [height] window (x1, y1 excluded, clipped to
 * the window), outside of which [render] paints nothing -- a little
 * larger than what it paints, for antialiased edges and pens; None if
 * nothing is drawn. *)
val pixel_bounds : width:int -> height:int -> scale:float -> Playground.shape list -> (int * int * int * int) option

(* ix: what Shape_render_pdf says the same way, so that a file's
 * shapes are where the screen's are: a colour as 0xRRGGBB; a shape's
 * own transform (its scale, its angle, its place); a rectangle's and
 * an n-gon's corners about (0, 0); Hershey's units to a [words]
 * shape's own (a text of that width, centred); the pen that draws
 * words, in Hershey's units; by how much a transform scales a length *)
val rgb_of_color : Color.t -> int
val shape_transform : Playground.shape -> Affine.t
val rectangle_corners : float -> float -> (float * float) list
val ngon_corners : int -> float -> (float * float) list
val text_to_local : width:float -> Affine.t
val pen_width : float
val length_scale : Affine.t -> float

(* ix: [draw_pixels fb m ~w ~h picture ~alpha]: a Bitmap's picture
 * drawn in its box of w by h about (0, 0), put in [fb] by m: what the
 * draw platform makes a picture's pixels with, before the device has
 * them *)
val draw_pixels : Framebuffer.t -> Affine.t -> w:float -> h:float -> Rgba_image.t -> alpha:float -> unit
