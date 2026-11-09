(* tiny-ml's parser: a file's items, recursive descent with precedence
 * climbing for the operators; the types it declares are recorded as it
 * reads (TinyMLTree's cons and record_labels, the abbreviations), so
 * that a pattern knows a constructor. Read TinyMLTree.mli first. *)

(* the names of types declared as an object's: read and forgotten *)
val forgotten : string list ref
(* type 'a t = ...: a second name for a type, its parameters' names *)
val abbreviations : (string * (string list * TinyMLTree.texpr)) list ref
(* the abbreviation that a name with these arguments is *)
val abbreviation : string -> TinyMLTree.ty list -> TinyMLTree.ty option

(* a file's text, its items, each with its line *)
val parse : string -> (TinyMLTree.item * int) list
(* an .mli's text, its vals and their types (a val of module N : sig
 * ... end is N.x) *)
val mli_types : string -> (string * TinyMLTree.ty) list
