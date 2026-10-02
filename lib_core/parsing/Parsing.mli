(* ix: the run time of mini-yacc's parsers (plan_lex_yacc.md), for
 * mini-ml: OCaml's Parsing by its names, for what ix's grammars and
 * their callers use, and the engine, which is OCaml here: no primitive
 * of the runtime's. dune's builds take OCaml's Parsing and ocamlyacc's
 * parsers.
 *
 * The tables are mini-yacc's: an LALR(1) automaton not compacted, a
 * state a row of actions by terminal and a row of gotos by
 * non-terminal. No error recovery: the first token no action takes
 * raises Parse_error. *)

exception Parse_error

(* In a rule's action: the positions of the rule's whole text
 * (symbol_...) and of its n-th symbol (rhs_... n, from 1). A symbol
 * that derived nothing has no text: symbol_start_pos is the first
 * symbol's that has one, or where the rule's text would be. *)
val symbol_start_pos : unit -> Lexing.position
val symbol_end_pos : unit -> Lexing.position
val rhs_start_pos : int -> Lexing.position
val rhs_end_pos : int -> Lexing.position
(* the same, as offsets *)
val symbol_start : unit -> int
val symbol_end : unit -> int
val rhs_start : int -> int
val rhs_end : int -> int

(* mini-yacc's. Numbers of 16 bits, the low byte first.
 * - actions: for state s and terminal t, at nterms s + t: 0 an error, 1
 *   accept, 2 + 2 s' shift to s', 3 + 2 r reduce by rule r;
 * - defaults: for state s, the action it takes whatever the token,
 *   without reading it (a statement is then reduced before the next
 *   line is asked), or 0;
 * - gotos: for state s and non-terminal n, at nnonterms s + n, the
 *   state plus 1;
 * - lhs, len: a rule's non-terminal, its number of symbols;
 * - reduce: a rule's action, which reads its symbols' values by value *)
type tables = {
  nterms : int; nnonterms : int;
  actions : string; defaults : string; gotos : string; lhs : string; len : string;
  reduce : (unit -> Obj.t) array;
}

(* in a rule's action: the value of its n-th symbol (from 1), $n *)
val value : int -> Obj.t

(* The input parsed from that state (a start symbol's): its value.
 * number and semantic: a token's terminal, and its value ($n's). *)
val run : tables -> int -> number:('token -> int) -> semantic:('token -> Obj.t) -> (Lexing.lexbuf -> 'token) -> Lexing.lexbuf -> Obj.t
