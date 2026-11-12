(* tiny-ml's parser: a file's items, recursive descent with precedence
 * climbing for the operators; the types it declares are recorded as it
 * reads (Tree's cons and record_labels, the abbreviations), so
 * that a pattern knows a constructor, and the names it reads made
 * their unit's (M.t, M.C: Tree.ml's Names). Read Tree.mli first. *)

(* the names of types declared as an object's: read and forgotten *)
val forgotten : string list ref
(* type 'a t = ...: a second name for a type, its parameters' names *)
val abbreviations : (string * (string list * Tree.texpr)) list ref
(* the abbreviation that a name with these arguments is *)
val abbreviation : string -> Tree.ty list -> Tree.ty option

(* a file's text, its items, each with its line *)
val parse : string -> (Tree.item * int) list
(* an .mli's text, its vals and their types (a val of module N : sig
 * ... end is N.x) *)
val mli_types : string -> (string * Tree.ty) list
