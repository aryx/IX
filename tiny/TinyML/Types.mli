(* tiny-ml's type checker: Hindley-Milner inference on the tree. The
 * toplevel names of a unit go into tables, where the units after it
 * find them as M.x. Compile then compiles the typed tree. Read
 * Tree.mli first. *)

(* The links of type variables followed. *)
val repr : Tree.ty -> Tree.ty

(* The types of the toplevel names; Compile's globals has the values. *)
val tglobals : (string, Tree.ty) Hashtbl.t
(* [find_name env tbl x]: in the local env, then in the table. *)
val find_name : ('a * 'b) list -> ('a, 'b) Hashtbl.t -> 'a -> 'b option
(* A toplevel name of the current unit, until unit_done. *)
val add_name : ('a, 'b) Hashtbl.t -> 'a -> 'b -> unit
val unit_done : unit -> unit

(* Whether a unit's names are also unqualified (Stdlib). *)
val implicit : string -> bool
val qualify : string -> string -> string   (* M.x *)
(* open M: each M.x also as x. module A = M: each M.x also as A.x. *)
val opened : (string, 'a) Hashtbl.t -> string -> unit
val aliased : (string, 'a) Hashtbl.t -> string -> string -> unit
(* A unit's names, as M.x, for the units after it. *)
val export : (string, 'a) Hashtbl.t -> string -> (string * 'a) list -> unit

(* The names a unit defined, with their types. *)
val type_unit :
  (Tree.item * int) list -> (string * Tree.ty) list
