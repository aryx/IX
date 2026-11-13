(* The software cursor (9pi's swcursor.c, and screen.c's cursoron,
 * cursoroff and ksetcursor). The cursor is a 16x16 picture drawn on the
 * screen. What it covers is kept aside (in back) and put back when the
 * cursor is hidden. Any drawing on the screen first calls [avoid] with
 * its rectangle (Kdraw.on_screen, which is memdraw's hwdraw hook). At
 * each tick, the clock redraws the cursor at the mouse's position
 * ([clock]).
 *
 * The pictures are GREY8 images built from the cursor's bits, which are
 * then drawn into GREY1 images, as 9pi does. *)

(* swcursor_init: makes the cursor's images (after the screen's) *)
val init : unit -> unit

(* [load (ox, oy) clr set] loads a cursor: its offset, and its clr and
 * set bits, 2x16 bytes each *)
val load : int * int -> string -> string -> unit

(* hides the cursor when its rectangle meets r (x0, y0, x1, y1) *)
val avoid : int * int * int * int -> unit

(* arch_cursoron, arch_cursoroff, arch_ksetcursor *)
val cursoron : unit -> bool
val cursoroff : unit -> unit
val ksetcursor : int * int -> string -> string -> unit

(* swcursor_clock: moves the cursor to the mouse's position (x, y), and
 * draws it anew there *)
val clock : int * int -> unit

(* drawlock: the console's drawing takes it, and the clock then leaves
 * the cursor as it is *)
val drawlock : bool ref
