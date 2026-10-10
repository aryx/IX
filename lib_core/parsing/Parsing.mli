(* ix: the run time of mini-yacc's parsers (plan_lex_yacc.md), for
 * mini-ml: OCaml's Parsing by its names, for what ix's grammars and
 * their callers use, and the engine, which is OCaml here: no primitive
 * of the runtime's. dune's builds take OCaml's Parsing and ocamlyacc's
 * parsers.
 *
 * The tables are mini-yacc's: an LALR(1) automaton not compacted, a
 * state a row of actions by terminal and a row of gotos by
 * non-terminal. No error recovery: the first token no action takes
 * raises Parse_error.
 *
 * The parser reads tokens from the left and keeps a stack of the
 * symbols it has recognized. At each step the state on top of the
 * stack and the next token index the table, which says one of two
 * things: *shift*, the token goes on the stack; or *reduce* by a
 * rule: the rule's symbols are on top of the stack, they come off
 * and the rule's name goes on in their place, with the value the
 * rule's action computed. For the grammar
 *
 *     e: e PLUS NUM   { $1 + $3 }      (rule 0)
 *      | NUM          { $1 }           (rule 1)
 *
 * on the text 1 + 2:
 *
 *     the stack            what is left     the action
 *     (empty)              1 + 2            shift NUM
 *     NUM:1                + 2              reduce by rule 1
 *     e:1                  + 2              shift PLUS
 *     e:1 PLUS             2                shift NUM
 *     e:1 PLUS NUM:2       (the end)        reduce by rule 0: 1 + 2
 *     e:3                  (the end)        accept: 3
 *
 * What the stack really holds is states, a number each: a state
 * stands for all that is below it, as far as the grammar cares,
 * which is why one look at the top is enough. After a reduce, the
 * state uncovered and the rule's name index [gotos] for the state to
 * push. The tree is never built by the engine: it is the order of
 * the reduces, leaves first (a parse from the bottom up), and the
 * actions make of it what they want.
 *
 * Where it stands: generators' mini-yacc builds the tables from a
 * .mly (Lalr) and writes them with the actions as functions; the
 * grammars of the ML and C compilers, of awk, bc and hoc, of the
 * database are parsed so. [run] asks the lexer (Lexing) for a token
 * when it needs one and not before, so that a calculator answers a
 * line when the line ends.
 *
 * cs-history:
 * Donald Knuth defined the LR(k) grammars in 1965 and showed that
 * such a table exists for them; it was too large for the machines
 * of the time. Frank DeRemer's LALR (1969) merges the states that
 * differ only by the tokens expected after them, which made the
 * table small enough, and Stephen Johnson's yacc (Bell Labs, 1975)
 * made it the way a Unix language was written: C's compiler, awk,
 * bc, eqn. ocamlyacc is Berkeley's yacc made to write OCaml.
 *
 * others:
 * The other family reads from the top down: a function a rule,
 * which looks at the next token and calls the functions of the
 * rule's symbols (recursive descent). No tool and no table, and an
 * error message is written where the error is seen; gcc and clang
 * parse C and C++ that way today, and ix's assembler does. What it
 * cannot do directly is a rule that starts with itself, as e above,
 * and it does not say when a grammar is ambiguous, which yacc's
 * conflicts do.
 *
 * modern:
 * yacc's parsers recover from an error (a rule with the token
 * "error", so that a compiler reports several in one run), and its
 * tables are compacted as lex's. Neither here. Menhir, which
 * OCaml's own parser is made with, builds LR(1) tables, where
 * states are merged only when it is safe to.
 *
 * References: D. E. Knuth, "On the Translation of Languages from
 * Left to Right", Information and Control 8 (1965); F. L. DeRemer,
 * "Practical Translators for LR(k) Languages", MIT thesis (1969);
 * S. C. Johnson, "Yacc: Yet Another Compiler-Compiler", Bell Labs
 * Computing Science Technical Report 32 (1975); Aho, Sethi and
 * Ullman, "Compilers: Principles, Techniques, and Tools" (1986),
 * chapter 4, for how the tables are made; plan_lex_yacc.md. *)

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
