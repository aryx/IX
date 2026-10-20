(* Printf, as tiny-ml reads it: not OCaml's module, whose formats have a
 * type of their own, but what tiny-ml's expansion of a call calls.
 * tiny-ml reads Printf.sprintf, ksprintf and bprintf with a format
 * written there as the concatenation they make (TinyML.ml's
 * printf_call): %d is string_of_int, %s the string, %c String.make 1;
 * these are the others. OCaml builds the same files on its own Printf,
 * and checks the formats. *)

(* %x: an integer, not negative, in hexadecimal, lower case *)
val hex : int -> string

(* %S: a string as OCaml writes it, between quotes, " \ and the
 * control characters escaped *)
val quoted : string -> string

(* a width: [pad left zero w s] s to w characters, spaces before it
 * (after it with -, zeros before it with 0, after a sign) *)
val pad : bool -> bool -> int -> string -> string
