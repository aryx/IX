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
 * shape does).
 *
 * It is possible at all because a view is data (Playground.mli): two
 * frames are two lists, and what changed is found by comparing
 * values, before a pixel is made. A program that drew by calling
 * the screen would have to say itself what it dirtied.
 *
 * terminology:
 * The boxes are what games call *dirty rectangles* and window
 * systems *damage*: the part of the screen that is no longer right.
 * A window system does the same accounting from the other side --
 * it tells a program which part of its window was uncovered and
 * must be drawn again (X's Expose event; Plan 9's rio keeps the
 * window's pixels itself and asks for nothing).
 *
 * reframe:
 * Comparing the new list with the old and touching only the
 * difference is what React does to a page, there called the virtual
 * DOM's diff: the view is a function that gives the whole picture
 * each time, and the saving is made below it, where the program
 * does not see it. *)

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
