(* awk's regexps, built on Plan 9's (re.c). This module turns a pattern
 * as awk writes it into one that libregexp takes, and gives the
 * matches that awk asks for. *)

(* the pattern compiled, or Regex.Error for one that is not a pattern.
 * awk's own notation is handled first: \t \n \f \r \b, \ddd and \xhh
 * become their characters, () and [] become the empty string, and a -
 * at a class's start or end stands for itself *)
val compile : string -> Regex.t

(* the leftmost longest match at or after an offset, as its start and
 * its length *)
val find : Regex.t -> string -> int -> (int * int) option

(* the same, but never an empty match *)
val find_nonempty : Regex.t -> string -> int -> (int * int) option

val matches : Regex.t -> string -> bool
