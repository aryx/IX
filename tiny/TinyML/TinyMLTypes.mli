(* tiny-ml's type checker: Hindley-Milner's inference on the tree, a
 * unit's toplevel names in tables (a unit's names M.x for the units
 * after it), what TinyMLCompile then compiles. Read TinyMLTree.mli
 * first. *)

(* a type, its variables' links followed *)
val repr : TinyMLTree.ty -> TinyMLTree.ty

(* the types of the program's toplevel names (TinyMLCompile's globals
 * has their values) *)
val tglobals : (string, TinyMLTree.ty) Hashtbl.t
(* [find_name env tbl x]: x in the local env, else in the table *)
val find_name : ('a * 'b) list -> ('a, 'b) Hashtbl.t -> 'a -> 'b option
(* a name of this unit's toplevel added to a table, until unit_done *)
val add_name : ('a, 'b) Hashtbl.t -> 'a -> 'b -> unit
val unit_done : unit -> unit

(* the unit whose names are also unqualified (Stdlib) *)
val implicit : string -> bool
(* [qualify m x]: M.x *)
val qualify : string -> string -> string
(* open M: M.x as x too; module A = M: M.x as A.x too *)
val opened : (string, 'a) Hashtbl.t -> string -> unit
val aliased : (string, 'a) Hashtbl.t -> string -> string -> unit
(* [export tbl m defs]: a unit's names, M.x, for the units after it *)
val export : (string, 'a) Hashtbl.t -> string -> (string * 'a) list -> unit

(* a unit's items typed: the names it defined and their types *)
val type_unit :
  (TinyMLTree.item * int) list -> (string * TinyMLTree.ty) list
