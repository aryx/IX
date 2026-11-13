(* tiny-ml's type checker: Hindley-Milner inference on the tree. The
 * toplevel names of a unit go into tables, where the units after it
 * find them as M.x. Compile then compiles the typed tree. Read
 * Tree.mli first. *)

(* Follows the links of type variables. *)
val repr : Tree.ty -> Tree.ty

(* The types of the toplevel names; Compile's globals has the values. *)
val tglobals : (string, Tree.ty) Hashtbl.t
(* [find_name env tbl x] looks x up in the local env, then in the
 * table. *)
val find_name : ('a * 'b) list -> ('a, 'b) Hashtbl.t -> 'a -> 'b option
(* Adds a toplevel name of the current unit; unit_done removes it. *)
val add_name : ('a, 'b) Hashtbl.t -> 'a -> 'b -> unit
val unit_done : unit -> unit

(* Whether a unit's names are also unqualified (Stdlib). *)
val implicit : string -> bool
val qualify : string -> string -> string   (* M.x *)
(* open M makes each M.x known as x too. module A = M makes each M.x
 * known as A.x too. *)
val opened : (string, 'a) Hashtbl.t -> string -> unit
val aliased : (string, 'a) Hashtbl.t -> string -> string -> unit
(* A unit's names, as M.x, for the units after it. *)
val export : (string, 'a) Hashtbl.t -> string -> (string * 'a) list -> unit

(* The names a unit defined, with their types. *)
val type_unit :
  (Tree.item * int) list -> (string * Tree.ty) list
