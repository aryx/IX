(* Plan 9's ARGBEGIN. Flags are single letters, grouped (-cp) or apart.
 * A flag's argument is attached (-ffile) or is the next word (-f file).
 * "--", or the first word not starting with '-', ends the flags. *)

exception Usage

(* the flags seen, in order, with their arguments ("" for none), and
 * the rest of the words; [with_arg] lists the letters that take an
 * argument *)
val parse : flags:string -> with_arg:string -> string list -> (char * string) list * string list

val has : (char * string) list -> char -> bool
val get : (char * string) list -> char -> string option
val all : (char * string) list -> char -> string list
