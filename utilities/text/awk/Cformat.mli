(* One conversion of print's (Plan 9's fmt, as awk's format() calls it):
 * a directive's text, "%-8.3f", applied to one value. *)

(* the directive's parts: flags, width, precision, then its letter *)
type spec = { minus : bool; plus : bool; space : bool; zero : bool; sharp : bool; width : int; precision : int option; verb : char }

(* "%-8.3f"'s parts; the letter is the text's last character *)
val parse : string -> spec

(* e f g E G: the number's shortest digits, rounded a half upward (Plan 9's
 * print, not C's: %.1f of 2.55 is 2.6) *)
val float : spec -> float -> string

(* d: a long's 32 bits; o x X u: those bits unsigned *)
val int : spec -> float -> string

(* s: its width counts characters, its precision bytes *)
val string : spec -> string -> string

(* a float by a format of one directive, "%.6g": CONVFMT's use *)
val number : string -> float -> string
