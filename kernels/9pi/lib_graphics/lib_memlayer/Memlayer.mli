(* Screens and their windows (memlayer's). All of a window's pixels are
 * in its own image, so its content is always whole, where memlayer
 * keeps only what is hidden. A window never needs a refresh, and
 * Refmesg's messages are never sent. The screen's image shows each
 * window's pixels where that window is frontmost, and the fill where
 * there is no window. A drawing on a window is copied there ([draw]),
 * and allocating, raising, lowering, moving or deleting a window
 * repaints what changed. A screen's image may itself be a window (for
 * a program in a rio window), and then the copies go on up.
 *
 *     the screen                    each window, in its own image
 *     +--------------------+
 *     |  +------+          |        A: +------+     B: +--------+
 *     |  | A  +-+------+   |           | all  |        | all of |
 *     |  |    | B      |   |           | of A |        | B      |
 *     |  +----+        |   |           +------+        +--------+
 *     |       +--------+   |
 *     +--------------------+        B is in front: where they
 *                                   overlap the screen shows B's
 *
 *     a drawing in A goes into A's image, all of it; then it is copied
 *     to the screen where A is frontmost, which leaves out B's corner
 *     when A is raised, nothing is asked of A's program; the corner is
 *     copied from A's image
 *
 * wib:
 * This trades memory for simplicity. memlayer keeps a window's visible
 * part on the screen itself and saves only the hidden parts, in pieces
 * that a drawing must be cut along; it was written when memory for
 * pixels was dear. Keeping every window whole costs the screen's size
 * again for each window, and drawing twice, but it removes the cutting
 * and the refresh protocol from this file.
 *
 * modern:
 * It is also what today's window systems do, for another reason. Each
 * window is drawn off the screen into its own buffer, and a compositor
 * (macOS's since 2001, Wayland's) builds the screen from them on the
 * graphics processor, which is what gives windows their shadows and
 * their transparency. The layers' cleverness belonged to machines that
 * could not afford the buffers.
 *
 * References: Rob Pike, "Graphics in Overlapping Bitmap Layers"
 * (ACM Transactions on Graphics, 1983), for the idea of layers and
 * the algorithm this file does not need. memlayer(2) in the Plan 9
 * manual. *)

type rect = Memimage.rect

(* memdraw: memimagedraw, then the window's changed rectangle is shown
 * on its screen *)
val draw : Memimage.t -> rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* ix: Memdraw.scale, then the result is shown as draw shows it *)
val scale : Memimage.t -> rect -> Memimage.t -> int * int -> int -> bool
(* ix: Memdraw.shrink, then the result is shown as draw shows it *)
val shrink : Memimage.t -> rect -> Memimage.t -> int * int -> int -> bool

(* memopaque: a 1x1 replicated white GREY1 image *)
val opaque : Memimage.t

val screen : Memimage.t -> Memimage.t -> Memimage.lscreen

(* memlalloc: a window at screenr (which is its r), with a clip within
 * it, and its pixels filled with a colour (given as rgba's halves;
 * DNofill means what the screen shows there) *)
val alloc : Memimage.lscreen -> rect -> rect -> int -> int -> Memimage.t

(* memldelete repaints the window's screen; memlfree does not *)
val delete : Memimage.t -> unit
val free : Memimage.t -> unit

(* memltofrontn makes the first window frontmost, with the others
 * behind it in order; memltorearn makes the first rearmost, with the
 * others in front of it in order *)
val tofront : Memimage.t list -> unit
val torear : Memimage.t list -> unit

(* memlorigin sets a window's logical origin and its place on the
 * screen. It returns 1 when the window moved on the screen, and 0 when
 * not. *)
val origin : Memimage.t -> int * int -> int * int -> int

(* loads the rows of r (by Memimage.load or cload) and shows them *)
val load : Memimage.t -> rect -> string -> bool -> int
