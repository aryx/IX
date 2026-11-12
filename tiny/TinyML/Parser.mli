(* tiny-ml's parser: reads a file's items by recursive descent, with
 * precedence climbing for the operators. The types the file declares
 * are recorded as soon as they are read (in Tree's cons and
 * record_labels, and in the abbreviations), so that a pattern later in
 * the file knows its constructors. Each name read is qualified by its
 * unit (M.t, M.C; see Names in Tree.ml). Read Tree.mli first. *)

(* The names of types declared as object types: read and forgotten. *)
val forgotten : string list ref
(* type 'a t = ...: a second name, with the names of the parameters. *)
val abbreviations : (string * (string list * Tree.texpr)) list ref
val abbreviation : string -> Tree.ty list -> Tree.ty option

(* The items, each with its line number. *)
val parse : string -> (Tree.item * int) list
(* An .mli's vals; one in module N : sig ... end is named N.x. *)
val mli_types : string -> (string * Tree.ty) list
