(* Screens and their windows (memlayer's), each window's pixels all in
 * its own image: its content is always whole, where memlayer keeps only
 * what is hidden (a window's refresh is never needed: Refmesg's
 * messages never sent). The screen's image shows each window's pixels
 * where it is frontmost, the fill where none is: a drawing on a window
 * is copied there ([draw]); a window allocated, raised, lowered,
 * moved or deleted repaints what changed. A screen's image may be a
 * window itself (a program in a rio window): the copies go on up. *)

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
