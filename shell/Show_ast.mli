(* This module prints rc's tree as text, as principia's pcmd.c does,
 * and keeps its spacing. The text is what whatis shows and what a
 * function is exported as in the environment (fn#name=...); -x traces
 * only the arguments, each written by [quote]. The text must read
 * back as the same tree, so it is rc's syntax, written by hand, and
 * not the debugging dump that a derived printer would give. *)

(* a word with the quotes it needs, when it is empty or has a character
 * that rc would read otherwise (fmt.c's needsrcquote) *)
val quote : string -> string

(* a redirection's arrow, and the descriptor it means without [n] *)
val arrow : Ast.rkind -> string * int

(* the printers, each writing into a buffer *)
val word : Buffer.t -> Ast.word -> unit
val cmd : Buffer.t -> Ast.cmd -> unit

(* [to_string cmd c]: the text that a printer gives *)
val to_string : (Buffer.t -> 'a -> unit) -> 'a -> string
