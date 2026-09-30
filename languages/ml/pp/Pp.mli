(* mlpp (plan_ml_bootstrap.md, decision 7): a file's text with mlpp's
 * constructs rewritten into OCaml, the rest of the text as it is. Where
 * the rewritten text moves the source's lines, a line # n "file" says
 * where the next line comes from, so that a compiler's errors name the
 * source's lines (and its columns: a copy starts at its column). A file
 * without constructs comes back unchanged.
 *
 * The constructs: [%bits "..."], a clause's whole pattern
 * or an expression (Bits); type t = _ in a .ml, which takes the .mli's
 * "= ...", on the hole's line; [@@deriving show] after a group of types
 * (Derive). *)

(* the line, the message *)
exception Error of int * string

(* the .mli of a .ml: its file name, its text, its type declarations *)
type mli = { mli_file : string; mli_text : string; mli_decls : Ast.type_decl list }

(* a .ml's tree, or a .mli's, with mlpp's constructs where they are
 * (Ast's Pextension, Eextension, Hole, tattrs) *)
type tree = Structure of Ast.structure | Signature of Ast.signature

(* the file's text, given its tree *)
val file : file:string -> string -> tree -> mli:(unit -> mli option) -> string

(* a construct's mark in a text, [%bits, [@@deriving, a line type ... =
 * _, even in a string or a comment: for a warning *)
val has_constructs : string -> bool
