(* awk's regexps over Plan 9's (re.c): a pattern as awk writes it made
 * one libregexp takes, and the matches awk asks for. *)

(* the pattern compiled; Regex.Error for one that is not a pattern.
 * awk's own notation first: \t \n \f \r \b, \ddd and \xhh as their
 * characters, () and [] as the empty string, a - at a class's start or
 * end as itself *)
val compile : string -> Regex.t

(* the leftmost longest match at or after an offset: its start and its
 * length *)
val find : Regex.t -> string -> int -> (int * int) option

(* the same, but not an empty one *)
val find_nonempty : Regex.t -> string -> int -> (int * int) option

val matches : Regex.t -> string -> bool
