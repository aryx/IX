(* Option, OCaml's subset (see Stdlib.mli) *)
val get : 'a option -> 'a
val iter : ('a -> unit) -> 'a option -> unit
val map : ('a -> 'b) -> 'a option -> 'b option
val to_list : 'a option -> 'a list
