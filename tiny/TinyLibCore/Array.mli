(* Array, OCaml's subset (see Stdlib.mli); a.(i) is Array.get a i *)
val make : int -> 'a -> 'a array
val length : 'a array -> int
val get : 'a array -> int -> 'a
val set : 'a array -> int -> 'a -> unit
val init : int -> (int -> 'a) -> 'a array
val sub : 'a array -> int -> int -> 'a array
val copy : 'a array -> 'a array
val map : ('a -> 'b) -> 'a array -> 'b array
val append : 'a array -> 'a array -> 'a array
val concat : 'a array list -> 'a array
val of_list : 'a list -> 'a array
val to_list : 'a array -> 'a list
val iter : ('a -> unit) -> 'a array -> unit
val to_seq : 'a array -> 'a Seq.t
