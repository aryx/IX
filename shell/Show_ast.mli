(* rc's tree as text (principia's pcmd.c, whose spacing it keeps):
 * what whatis shows, what a function is exported as in the
 * environment (fn#name=...), what -x traces. The text must read back
 * as the same tree, so it is rc's syntax, written by hand: not a
 * debugging dump, which a derived printer would do. *)

(* a word with the quotes it needs: empty, or with a character rc
 * would read otherwise (fmt.c's needsrcquote) *)
val quote : string -> string

(* a redirection's arrow, and the descriptor it means without [n] *)
val arrow : Ast.rkind -> string * int

(* the printers, each into a buffer *)
val word : Buffer.t -> Ast.word -> unit
val cmd : Buffer.t -> Ast.cmd -> unit

(* [to_string cmd c]: a printer's text *)
val to_string : (Buffer.t -> 'a -> unit) -> 'a -> string
