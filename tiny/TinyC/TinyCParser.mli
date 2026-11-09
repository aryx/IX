(* tiny-c's parser: C's declarations, statements and expressions read
 * from the tokens, recursive descent, the tree built typed as it reads
 * (TinyCTree's functions): a declaration at a time, its definitions,
 * a function's tree or a global's data. Read TinyCTree.mli first. *)

(* the file's tokens to read; read all of them *)
val start : TinyCLexer.located list -> unit
val at_end : unit -> bool
(* where the last token read is, for an error (None: no token yet) *)
val last_loc : unit -> TinyCLexer.loc option

(* the typedefs (TinyC.ml adds intptr) *)
val typedefs : (string, TinyCTypes.ty) Hashtbl.t

(* a declaration of the file's: what it defines, in their order (a
 * string literal's data before the function or the global it is in) *)
val external_decl : unit -> TinyCTree.def list
