(* The OCaml programmers
 * OCaml. Copyright 2018 INRIA. LGPL 2.1, with the linking exception of OCaml's LICENSE. *)

type t = int

external div : int -> int -> int = "%divint"
external rem : int -> int -> int = "%modint"



external int_of_string : string -> int = "int_of_string"

external format_int : string -> int -> string = "format_int"

(* ix: OCaml's later functions, those ix's programs use *)

let max (a : int) (b : int) = if a >= b then a else b
