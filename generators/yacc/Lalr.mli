(* A grammar's LALR(1) automaton, and the parser's actions: what yacc
 * computes (ocamlyacc is Berkeley yacc), so that the two parse alike.
 *
 * - The symbols by number. Terminals: 0 is the end of the input, which
 *   no lexer gives; then the tokens; then the names that are only
 *   precedences (%prec's). Non-terminals in the order of their first
 *   rule.
 * - The rules, the grammar's, then one for each start symbol,
 *   $accept: start, whose reduction is the parse's end.
 * - The LR(0) states: sets of items (a rule and a dot in it), from each
 *   start symbol's first state.
 * - The lookaheads: for each state and item, the terminals that may
 *   follow, by passing them along until nothing is added: inside a
 *   state from an item to those of the non-terminal after its dot
 *   (what may follow it there), and from an item to itself in the next
 *   state. That is LALR(1): the lookaheads of the canonical LR(1)
 *   states with the same items, merged.
 * - A state's action on a terminal: a shift, or the reduction of an
 *   item at its end whose lookaheads have the terminal. When there are
 *   two, yacc's rules: a shift against a reduction by their
 *   precedences (the token's, the rule's: its last terminal's, or
 *   %prec's), the higher wins, and on a tie the associativity (left:
 *   reduce; right: shift; none: an error); without precedences the
 *   shift, and it is counted a conflict; of two reductions the earlier
 *   rule, a conflict too.
 * - A state with no shift and one rule to reduce by has it as its
 *   default: it reduces whatever the next token, without reading it.
 *
 * References: Aho, Sethi, Ullman, "Compilers" (1986), 4.7; Berkeley
 * yacc's lalr.c and mkpar.c (from memory) for what a conflict and a
 * default are. *)

type symbol = T of int | N of int

type action = Shift of int | Reduce of int | Accept | Fail

type t = {
  terms : string array;
  nonterms : string array;
  rules : (int * symbol array) array;  (* a rule's non-terminal and its symbols; the $accept ones last, their non-terminal -1 - k *)
  nrules : int;                        (* the grammar's own *)
  kernels : (int * int) list array;    (* a state's kernel items: a rule, a dot *)
  actions : action array array;        (* state, terminal *)
  defaults : action array;             (* state: Reduce, Accept, or Fail for none *)
  gotos : int array array;             (* state, non-terminal: the state, or -1 *)
  starts : int list;                   (* each start symbol's first state *)
  sr : int; rr : int;                  (* the conflicts: shift/reduce, reduce/reduce *)
  (* what the grammar says for nothing, each with its line (0: none): the
   * tokens in no rule, a non-terminal no start symbol leads to, a token's
   * precedence and a rule's %prec that decide no conflict *)
  warnings : (int * string) list;
}

val make : Yacc.t -> t
