(* Prolog's reader: a text's clauses, one at a time, each read by the
 * operators' priorities as they are at that moment (a directive may
 * have changed them: op/3). Written by hand for that reason: the
 * grammar is not known before the text is read
 * (docs/plans/plan_prolog.md, decision 3).
 *
 * A term of priority 1200 at most, then a dot and a blank. An argument
 * and a list's element are of 999 at most (so a comma separates them).
 * An atom right before an open parenthesis is a functor; - or + right
 * before a number is its sign; a prefix operator before what cannot
 * begin a term is an atom. *)

(* the message, the place in the text *)
exception Error of string * int

(* a text being read *)
type t

val make : Prolog.ops -> string -> t

(* the next clause and its variables by name, in the order met (not _);
 * None at the text's end *)
val next : t -> (Prolog.term * (string * Prolog.term) list) option

(* after an Error: to the end of the clause it was in *)
val skip : t -> unit

(* where the token last read starts, and a place's line (from 1) *)
val position : t -> int
val line : t -> int -> int

(* does the text end with a clause's end? (a prompt reads on if not) *)
val complete : string -> bool

(* a term, written without its final dot *)
val term : Prolog.ops -> string -> Prolog.term * (string * Prolog.term) list
