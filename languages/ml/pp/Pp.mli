(* mlpp (plan_ml_bootstrap.md, decision 7): a file's text with mlpp's
 * constructs rewritten into OCaml, the rest of the text as it is. Where
 * the rewritten text moves the source's lines, a line # n "file" says
 * where the next line comes from, so that a compiler's errors name the
 * source's lines (and its columns: a copy starts at its column). A file
 * without constructs comes back unchanged.
 *
 * The constructs: [%bits "..."], a clause's whole pattern
 * or an expression (Bits); type t = [%mli] in a .ml, which takes the .mli's
 * "= ...", on the hole's line; [@@deriving show] after a group of types
 * (Derive); [@@class] after a record type, its methods (Derive). The
 * classes' dictionaries are a second rewrite's (classes, below). *)

(* the line, the message *)
exception Error of int * string

(* the .mli of a .ml: its file name, its text, its type declarations *)
type mli = { mli_file : string; mli_text : string; mli_decls : Ast.type_decl list }

(* the file's text, given its tree, which has mlpp's constructs where
 * they are (Ast's Pextension, Eextension, Hole, tattrs) *)
val file : file:string -> string -> Ast.source -> mli:(unit -> mli option) -> string

(* The classes (plan_ml_bootstrap.md, "Type classes"), a second rewrite, of
 * the first's text and tree: the dictionaries Typing found (a name's
 * place in the text, what is to follow it) written at their uses, and
 * [%using: t], a parameter or its type, made OCaml's *)
val classes : file:string -> string -> Ast.source -> (Ast.span * string) list -> string

(* whether a unit has a class's construct of its own: a class, an
 * instance, a [%using: ...] *)
val has_classes : file:string -> string -> Ast.structure -> bool

(* a construct's mark in a text, [%bits, [@@deriving, [%using, a line
 * type ... = _, even in a string or a comment: for a warning *)
val has_constructs : string -> bool
