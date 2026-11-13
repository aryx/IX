(* tiny-cc's parser: reads C declarations, statements and expressions
 * from the tokens, by recursive descent. The tree is typed as it is
 * built (with Tree's functions). It reads one declaration at a time and
 * returns its definitions: a function's tree, or a global's data. Read
 * Tree.mli first. *)

(* start gives the file's tokens to read; at_end is true once all of them
 * are read. *)
val start : Lexer.located list -> unit
val at_end : unit -> bool
val last_loc : unit -> Lexer.loc option   (* None before any token *)

val typedefs : (string, Types.ty) Hashtbl.t  (* TinyC.ml adds intptr *)

(* A string literal's data comes before the function or global it is
 * in. *)
val declaration : unit -> Tree.def list
