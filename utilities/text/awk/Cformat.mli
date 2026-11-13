(* This module does one conversion of print's (Plan 9's fmt, as awk's
 * format() calls it): it applies a directive's text, such as "%-8.3f",
 * to one value. *)

(* the directive's parts: flags, width, precision, then its letter *)
type spec = { minus : bool; plus : bool; space : bool; zero : bool; sharp : bool; width : int; precision : int option; verb : char }

(* the parts of "%-8.3f"; the letter is the text's last character *)
val parse : string -> spec

(* e f g E G: the number's shortest digits, with a half rounded upward
 * (as Plan 9's print does, not C's: %.1f of 2.55 is 2.6) *)
val float : spec -> float -> string

(* d: the number as a long's 32 bits; o x X u: those bits read as
 * unsigned *)
val int : spec -> float -> string

(* s: its width counts characters, and its precision counts bytes *)
val string : spec -> string -> string

(* a float written by a format of one directive, such as "%.6g"; this
 * is how CONVFMT is used *)
val number : string -> float -> string
