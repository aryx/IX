(* tiny-c's parser: C's declarations, statements and expressions read
 * from the tokens, recursive descent, the tree built typed as it reads
 * (TinyCTree's functions): a declaration at a time, its definitions,
 * a function's tree or a global's data. Read TinyCTree.mli first. *)

type storage = Auto | Static | Extern | Typedef

(* a name's type and place *)
type var = { vty : TinyCTypes.ty; where : TinyCTree.place; }

(* the tokens, the position of the next, and each token's file and line *)
val toks : TinyCLexer.token array ref
val pos : int ref
val locs : TinyCLexer.loc array ref
val peek : unit -> TinyCLexer.token
val next : unit -> TinyCLexer.token
(* the next token if it is that punctuation *)
val accept : string -> bool
val expect : string -> unit

(* the typedefs (TinyC.ml adds intptr) *)
val typedefs : (string, TinyCTypes.ty) Hashtbl.t

(* a declaration of the file's: what it defines, in their order (a
 * string literal's data before the function or the global it is in) *)
val external_decl : unit -> TinyCTree.def list
