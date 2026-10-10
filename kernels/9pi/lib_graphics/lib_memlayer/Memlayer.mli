(* Screens and their windows (memlayer's), each window's pixels all in
 * its own image: its content is always whole, where memlayer keeps only
 * what is hidden (a window's refresh is never needed: Refmesg's
 * messages never sent). The screen's image shows each window's pixels
 * where it is frontmost, the fill where none is: a drawing on a window
 * is copied there ([draw]); a window allocated, raised, lowered,
 * moved or deleted repaints what changed. A screen's image may be a
 * window itself (a program in a rio window): the copies go on up.
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
 *     a drawing in A: into A's image, all of it; then copied to the
 *     screen where A is frontmost, which leaves out B's corner
 *     A raised: nothing asked of A's program; the corner is copied
 *     from A's image
 *
 * wib:
 * Memory for simplicity. memlayer keeps a window's visible part on
 * the screen itself and saves only the hidden parts, in pieces that
 * a drawing must be cut along; it was written when memory for
 * pixels was dear. Keeping every window whole costs
 * the screen's size again for each, and drawing twice, and removes
 * the cutting and the refresh protocol from this file.
 *
 * modern:
 * It is also what today's window systems do, for another reason:
 * each window is drawn off the screen into its own buffer, and a
 * compositor (macOS's since 2001, Wayland's) builds the screen from
 * them, on the graphics processor, which is what gives windows
 * their shadows and their transparency. The layers' cleverness
 * belonged to machines that could not afford the buffers.
 *
 * References: Rob Pike, "Graphics in Overlapping Bitmap Layers"
 * (ACM Transactions on Graphics, 1983): the idea of layers and
 * the algorithm this file does not need. memlayer(2) in the Plan 9
 * manual. *)

type rect = Memimage.rect

(* memdraw: memimagedraw, then a window's changed rectangle on its
 * screen *)
val draw : Memimage.t -> rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit

(* memopaque: a 1x1 repl white GREY1 image *)
val opaque : Memimage.t

val screen : Memimage.t -> Memimage.t -> Memimage.lscreen

(* memlalloc: a window at screenr (its r), its clip (within), its
 * pixels a colour (rgba's halves; DNofill: what the screen shows) *)
val alloc : Memimage.lscreen -> rect -> rect -> int -> int -> Memimage.t

(* memldelete (its screen repainted), memlfree (not) *)
val delete : Memimage.t -> unit
val free : Memimage.t -> unit

(* memltofrontn, memltorearn: the first frontmost (rearmost), the others
 * behind (in front of) it in order *)
val tofront : Memimage.t list -> unit
val torear : Memimage.t list -> unit

(* memlorigin: its logical origin, its place on the screen; 1 when it
 * moved there, 0 when not *)
val origin : Memimage.t -> int * int -> int * int -> int

(* its r's rows loaded (Memimage.load, cload), shown *)
val load : Memimage.t -> rect -> string -> bool -> int
