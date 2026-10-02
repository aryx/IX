(* A lexer's rules as one deterministic automaton: Lexing's tables
 * (lib_core's: a state a row of 257 next states, and the clause it
 * accepts), and each rule's first state.
 *
 * By the book: each regexp to a nondeterministic automaton (Thompson),
 * a rule's clauses side by side, then the sets of its states reached
 * together are the deterministic one's states (the subset
 * construction). A state that ends several clauses accepts the first:
 * with the engine's longest match, ocamllex's rule. Nothing is
 * minimized or compacted. *)

type t = {
  trans : int array array;            (* a state's 257 next states, -1 for none *)
  accept : int array;                 (* a state's clause, -1 for none *)
  starts : int list;                  (* each rule's first state, in the rules' order *)
}

val make : Lex.rule list -> t
