(* String, OCaml's subset (see Stdlib.mli); concat joins by pairs, so a
 * long list is copied log n times *)
val length : string -> int
val get : string -> int -> char
val make : int -> char -> string
val init : int -> (int -> char) -> string
val sub : string -> int -> int -> string
val index_from_opt : string -> int -> char -> int option
val index_opt : string -> char -> int option
val index_from : string -> int -> char -> int
val rindex_opt : string -> char -> int option
val contains : string -> char -> bool
val exists : (char -> bool) -> string -> bool
val for_all : (char -> bool) -> string -> bool
val iteri : (int -> char -> unit) -> string -> unit
val iter : (char -> unit) -> string -> unit
val concat : string -> string list -> string
val map : (char -> char) -> string -> string
val lowercase_ascii : string -> string
val capitalize_ascii : string -> string
val trim : string -> string
val split_on_char : char -> string -> string list
