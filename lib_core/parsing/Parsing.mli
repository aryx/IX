(* ix: the run time of mini-yacc's parsers (plan_lex_yacc.md), for
 * mini-ml. It has the names of OCaml's Parsing, for what ix's grammars
 * and their callers use. It also has the engine, which is written in
 * OCaml here, with no primitive of the runtime. dune's builds take
 * OCaml's Parsing and the parsers of ocamlyacc.
 *
 * The tables are mini-yacc's. They hold an LALR(1) automaton that is
 * not compacted: each state has a row of actions, one for each
 * terminal, and a row of gotos, one for each non-terminal. There is no
 * error recovery: the first token that no action takes raises
 * Parse_error.
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
 * What the stack really holds is states, each a number. A state stands
 * for all that is below it, as far as the grammar cares, which is why
 * one look at the top is enough. After a reduce, the state uncovered
 * and the rule's name index [gotos] to find the state to push. The
 * engine never builds the tree: the tree is the order of the reduces,
 * leaves first (a parse from the bottom up), and the actions make of it
 * what they want.
 *
 * Where it stands: mini-yacc, in generators/, builds the tables from a
 * .mly (Lalr) and writes them, with the actions as functions. The
 * grammars of the ML and C compilers, of awk, bc and hoc, and of the
 * database are parsed this way. [run] asks the lexer (Lexing) for a
 * token when it needs one and not before, so that a calculator answers
 * a line when the line ends.
 *
 * cs-history:
 * Donald Knuth defined the LR(k) grammars in 1965 and showed that
 * such a table exists for them; it was too large for the machines
 * of the time. Frank DeRemer's LALR (1969) merges the states that
 * differ only by the tokens expected after them, which made the
 * table small enough, and Stephen Johnson's yacc (Bell Labs, 1973)
 * made it the way a Unix language was written: C's compiler, awk,
 * bc, eqn. ocamlyacc is Berkeley's yacc made to write OCaml.
 *
 * others:
 * The other family reads from the top down: there is a function for
 * each rule, which looks at the next token and calls the functions of
 * the rule's symbols (recursive descent). It needs no tool and no
 * table, and an error message is written where the error is seen. gcc
 * and clang parse C and C++ that way today, and so does ix's assembler.
 * What it cannot do directly is a rule that starts with itself, as e
 * above, and it does not say when a grammar is ambiguous, which yacc's
 * conflicts do.
 *
 * modern:
 * yacc's parsers recover from an error (with a rule that has the token
 * "error", so that a compiler reports several errors in one run), and
 * its tables are compacted like lex's. Neither is done here. Menhir,
 * with which OCaml's own parser is made, builds LR(1) tables, where
 * states are merged only when it is safe to do so.
 *
 * References: D. E. Knuth, "On the Translation of Languages from
 * Left to Right", Information and Control 8 (1965); F. L. DeRemer,
 * "Practical Translators for LR(k) Languages", MIT thesis (1969);
 * S. C. Johnson, "Yacc: Yet Another Compiler-Compiler", Bell Labs
 * Computing Science Technical Report 32 (1975); Aho, Sethi and
 * Ullman, "Compilers: Principles, Techniques, and Tools" (1986),
 * chapter 4, for how the tables are made; plan_lex_yacc.md. *)

exception Parse_error

(* In a rule's action, these give the positions of the rule's whole text
 * (symbol_...) and of its n-th symbol (rhs_... n, counted from 1). A
 * symbol that derived nothing has no text, so symbol_start_pos is the
 * position of the first symbol that has one, or where the rule's text
 * would be. *)
val symbol_start_pos : unit -> Lexing.position
val symbol_end_pos : unit -> Lexing.position
val rhs_start_pos : int -> Lexing.position
val rhs_end_pos : int -> Lexing.position
(* The same, as offsets. *)
val symbol_start : unit -> int
val symbol_end : unit -> int
val rhs_start : int -> int
val rhs_end : int -> int

(* mini-yacc's tables. They hold numbers of 16 bits, with the low byte
 * first.
 * - actions holds, at nterms s + t, the action for state s and terminal
 *   t: 0 is an error, 1 is accept, 2 + 2 s' is a shift to s', and
 *   3 + 2 r is a reduce by rule r.
 * - defaults holds, for state s, the action it takes whatever the
 *   token, without reading it (so a statement is reduced before the
 *   next line is asked for), or 0.
 * - gotos holds, at nnonterms s + n, the state plus 1 for state s and
 *   non-terminal n.
 * - lhs and len hold, for each rule, its non-terminal and its number of
 *   symbols.
 * - reduce holds the action of each rule, which reads the values of its
 *   symbols with value. *)
type tables = {
  nterms : int; nnonterms : int;
  actions : string; defaults : string; gotos : string; lhs : string; len : string;
  reduce : (unit -> Obj.t) array;
}

(* In a rule's action, the value of its n-th symbol (counted from 1),
 * which is $n. *)
val value : int -> Obj.t

(* Parses the input from that state (the state of a start symbol) and
 * returns its value. number gives the terminal of a token, and semantic
 * gives its value (what $n gives). *)
val run : tables -> int -> number:('token -> int) -> semantic:('token -> Obj.t) -> (Lexing.lexbuf -> 'token) -> Lexing.lexbuf -> Obj.t
