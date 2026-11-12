(* tiny-ml's Printf. A call of Printf.sprintf, ksprintf or bprintf
 * whose format is a string literal written at the call is rewritten
 * into the concatenation that the format makes, so the type checker
 * never sees a format. Read Tree.mli first. *)

(* The pieces of a format: its text, and its holes. A hole such as %d
 * has a conversion character, the flags - and 0, and a width. *)
type piece = Text of string | Hole of char * bool * bool * int

(* [printf_call f args] is the call of Printf.f with these arguments,
 * the format first, rewritten as an expression without a format. *)
val printf_call : string -> Tree.expr list -> Tree.expr
