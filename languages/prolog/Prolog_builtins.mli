(* mini-prolog's built-in predicates with one answer, in OCaml (the
 * ones with several are Prolog_prelude's, over these): unification and
 * comparison, the type tests, functor, =.., arithmetic (is: integers
 * only), the atoms' characters, sort, assert and '$clauses', op, write,
 * format, read, consult, listing, statistics, halt. *)

(* a machine with all of it, the prelude read *)
val create : unit -> Prolog_machine.t

(* a text's clauses added and its directives run; a mistake is said by
 * the machine's [warn] with the text's name and the line, counted in
 * [errors], and the rest is read on *)
val consult_text : Prolog_machine.t -> string -> string -> unit

(* an uncaught throw's ball, as a message *)
val message : Prolog_machine.t -> Prolog.term -> string

(* is's value *)
val eval : Prolog.term -> int

(* a clause as listing writes it *)
val portray : Prolog_machine.t -> Prolog.term -> string
