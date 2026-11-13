(* A subfont (memdraw's Memsubfont). Its characters' bits are side by
 * side in one image. For each character it records its column in that
 * image (x), its rows (top and bottom), where it starts from the pen
 * (left), and how far the pen moves after it (width). The default
 * subfont is the one in libdraw's defont.c (lucm/latin1.9, here
 * Memdata.defont), parsed as getmemdefont parses it. *)

type fontchar = { fx : int; top : int; bottom : int; left : int; width : int }

type t = { n : int; height : int; ascent : int; info : fontchar array; bits : Memimage.t }

val default : unit -> t

(* memimagestring draws s (UTF-8) at p in dst: the characters' bits are
 * the mask through which src at sp is drawn, by [draw] with SoverD. It
 * returns the point after the string. *)
val string : (Memimage.t -> Memimage.rect -> Memimage.t -> int * int -> Memimage.t -> int * int -> int -> unit) ->
  Memimage.t -> int * int -> Memimage.t -> int * int -> t -> string -> int * int

(* the width of a string, as memsubfontwidth's x gives it *)
val width : t -> string -> int
