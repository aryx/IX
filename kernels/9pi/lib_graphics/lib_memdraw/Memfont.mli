(* A subfont (memdraw's Memsubfont): its characters' bits side by side
 * in one image, each character's column there (x), its rows (top,
 * bottom), where it starts from the pen (left) and how far the pen
 * moves (width). The default one is libdraw's defont.c's (lucm/latin1.9:
 * Memdata.defont), parsed as getmemdefont does. *)

type fontchar = { fx : int; top : int; bottom : int; left : int; width : int }

type t = { n : int; height : int; ascent : int; info : fontchar array; bits : Memimage.t }

val default : unit -> t

(* memimagestring: s (UTF-8) at p in dst, its bits the mask of src at
 * sp, drawn by [draw] (SoverD's); the point after it *)
val string : (Memimage.t -> Memimage.rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit) ->
  Memimage.t -> int * int -> Memimage.t -> int * int -> t -> string -> int * int

(* memsubfontwidth's x *)
val width : t -> string -> int
