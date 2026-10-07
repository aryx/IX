(* A view drawn again where it changed only (docs/plans/plan_playground.md,
 * decision 8): the pixels a frame costs are the ones that differ from
 * the frame before, not the window's.
 *
 * A view is a list of shapes. The shapes of the last frame that are not
 * in this one, and those of this one that were not in the last, are
 * what changed: the boxes around them (in pixels) are drawn again, all
 * the shapes in each, and nothing else is touched. Tetris's falling
 * piece is four squares of some 230,000 pixels.
 *
 * Off ([enabled] false: the simple way), each frame is the whole
 * picture. The pixels are the same either way.
 *
 * What it does not see: two shapes that stay as they are and change
 * places in the list, one over the other (which is on top changes, no
 * shape does). *)

val enabled : bool ref

type t

(* a picture of width by height pixels, [scale] pixels a unit of the
 * playground's, on white *)
val create : width:int -> height:int -> scale:float -> Shape_render_software.options -> t

(* [frame t shapes]: the parts of the picture that are not what they
 * were at the last frame, each its box (x0, y0, x1, y1: x1 and y1 not
 * in it) and its pixels, a Framebuffer of the box's size. The first
 * frame is the whole picture; a frame like the one before is no part. *)
val frame : t -> Playground.shape list -> ((int * int * int * int) * Framebuffer.t) list

(* the parts copied where they go in a picture of the whole (a platform
 * that keeps one: the frame written to a file) *)
val paste : Framebuffer.t -> ((int * int * int * int) * Framebuffer.t) list -> unit
