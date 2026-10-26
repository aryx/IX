val repr : TinyMLTree.ty -> TinyMLTree.ty
val tglobals : (string, TinyMLTree.ty) Hashtbl.t
val find_name : ('a * 'b) list -> ('a, 'b) Hashtbl.t -> 'a -> 'b option
val add_name : ('a, 'b) Hashtbl.t -> 'a -> 'b -> unit
val unit_done : unit -> unit
val implicit : string -> bool
val qualify : string -> string -> string
val opened : (string, 'a) Hashtbl.t -> string -> unit
val export :
  (string, 'a) Hashtbl.t -> string -> (string * 'a) list -> 'b -> 'b
val type_unit :
  'a -> (TinyMLTree.item * int) list -> 'a * (string * TinyMLTree.ty) list
