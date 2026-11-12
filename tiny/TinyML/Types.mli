(* tiny-ml's type checker: Hindley-Milner's inference on the tree, a
 * unit's toplevel names in tables (a unit's names M.x for the units
 * after it), what Compile then compiles. Read Tree.mli
 * first. *)

(* a type, its variables' links followed *)
val repr : Tree.ty -> Tree.ty

(* the types of the program's toplevel names (Compile's globals
 * has their values) *)
val tglobals : (string, Tree.ty) Hashtbl.t
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
  (Tree.item * int) list -> (string * Tree.ty) list
