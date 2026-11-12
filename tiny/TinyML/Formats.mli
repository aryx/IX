(* tiny-ml's Printf: a call of Printf.sprintf, ksprintf or bprintf, its
 * format a string written at the call, read as the concatenation it
 * makes, so that the type checker sees no format. Read Tree.mli
 * first. *)

(* a format's pieces: its text, and its holes (%d: the conversion, the
 * flags - and 0, the width) *)
type piece = Text of string | Hole of char * bool * bool * int

(* [printf_call f args]: the call of Printf.f with these arguments, the
 * format first, as an expression without format *)
val printf_call : string -> Tree.expr list -> Tree.expr
