(* Array, OCaml's subset (see Stdlib.mli); a.(i) is Array.get a i *)
val make : int -> 'a -> 'a array
val length : 'a array -> int
val get : 'a array -> int -> 'a
val set : 'a array -> int -> 'a -> unit
