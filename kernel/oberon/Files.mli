(* Files and riders (Oberon's Files): a file is found by its name
 * (old) or made without one in the directory (new_), which register
 * gives it; it is read and written through a rider, a position in it.
 * A rider past the end reads 0 and says eof. *)

type t = FileDir.file

val old : string -> t option
val new_ : string -> t
val register : t -> unit
val length : t -> int

type rider = { file : t; mutable pos : int; mutable eof : bool }

val set : t -> int -> rider
val read_byte : rider -> int
val read : rider -> char
(* 4 bytes, the low one first, signed *)
val read_int : rider -> int
val write_byte : rider -> int -> unit
val write : rider -> char -> unit
