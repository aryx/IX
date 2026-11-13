(* Printf, as tiny-ml reads it. This is not OCaml's module, whose formats
 * have a type of their own, but the functions that tiny-ml's expansion
 * of a call calls. tiny-ml reads a call to Printf.sprintf, ksprintf or
 * bprintf whose format is written in the call, and turns it into the
 * concatenation it makes (TinyML.ml's printf_call): %d becomes
 * string_of_int, %s the string itself, and %c String.make 1. The
 * functions below are for the other conversions. OCaml builds the same
 * files with its own Printf, and checks the formats. *)

(* %x: an integer that is not negative, in hexadecimal, in lower case *)
val hex : int -> string

(* %S: a string as OCaml writes it, between quotes, with the quote, the
 * backslash and the control characters escaped *)
val quoted : string -> string

(* a width: [pad left zero w s] pads s to w characters with spaces
 * before it. With -, the spaces go after it; with 0, zeros go before
 * it, after a sign. *)
val pad : bool -> bool -> int -> string -> string
