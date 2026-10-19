(* List, OCaml's subset (see Stdlib.mli); sort a merge sort, stable *)
val length : 'a list -> int
val rev : 'a list -> 'a list
val hd : 'a list -> 'a
val tl : 'a list -> 'a list
val nth : 'a list -> int -> 'a
val nth_opt : 'a list -> int -> 'a option
val map : ('a -> 'b) -> 'a list -> 'b list
val mapi : (int -> 'a -> 'b) -> 'a list -> 'b list
val map2 : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list
val iter : ('a -> unit) -> 'a list -> unit
val iteri : (int -> 'a -> unit) -> 'a list -> unit
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b list -> 'a
val fold_right : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
val mem : 'a -> 'a list -> bool
val assoc : 'a -> ('a * 'b) list -> 'b
val assoc_opt : 'a -> ('a * 'b) list -> 'b option
val find_opt : ('a -> bool) -> 'a list -> 'a option
val mem_assoc : 'a -> ('a * 'b) list -> bool
val iter2 : ('a -> 'b -> unit) -> 'a list -> 'b list -> unit
val rev_map : ('a -> 'b) -> 'a list -> 'b list
val remove_assoc : 'a -> ('a * 'b) list -> ('a * 'b) list
val memq : 'a -> 'a list -> bool
val exists : ('a -> bool) -> 'a list -> bool
val for_all : ('a -> bool) -> 'a list -> bool
val filter : ('a -> bool) -> 'a list -> 'a list
val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
val filteri : (int -> 'a -> bool) -> 'a list -> 'a list
val to_seq : 'a list -> 'a Seq.t
val of_seq : 'a Seq.t -> 'a list
val filter_map : ('a -> 'b option) -> 'a list -> 'b list
val concat : 'a list list -> 'a list
val concat_map : ('a -> 'b list) -> 'a list -> 'b list
val init : int -> (int -> 'a) -> 'a list
val sort : ('a -> 'a -> int) -> 'a list -> 'a list
val sort_uniq : ('a -> 'a -> int) -> 'a list -> 'a list
val stable_sort : ('a -> 'a -> int) -> 'a list -> 'a list
