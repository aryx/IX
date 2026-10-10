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
 * The grammar of CLI.mli's parse, with TIMES above PLUS:
 *
 *     %left PLUS  %left TIMES
 *     e: INT (rule 0) | e PLUS e (1) | e TIMES e (2);   $accept: e (3)
 *
 *     state  its kernel items            INT   PLUS  TIMES  $end   e
 *       0    $accept: . e                s2                        1
 *       1    $accept: e .                      s3    s4     acc
 *            e: e . PLUS e
 *            e: e . TIMES e
 *       2    e: INT .                    r0 whatever comes: the default
 *       3    e: e PLUS . e               s2                        5
 *       4    e: e TIMES . e              s2                        6
 *       5    e: e PLUS e .                     r1    s4     r1
 *            e: e . PLUS e
 *            e: e . TIMES e
 *       6    e: e TIMES e .              r2 whatever comes: the default
 *            e: e . PLUS e
 *            e: e . TIMES e
 *
 * (s2: shift and go to state 2; r1: reduce by rule 1; the last column
 * is the goto. It is mini-yacc -v's listing, in a table.) The dot is
 * how much of the rule is on the stack. State 5 is where the grammar
 * is ambiguous: an e, a PLUS and an e are there, the rule could be
 * reduced, and the next token could also be shifted, both items being
 * in the state. On PLUS the two have the same precedence, and %left
 * says reduce: 1 + 2 + 3 is (1 + 2) + 3. On TIMES the token is higher
 * than the rule (its PLUS), so it is shifted: 1 + 2 * 3 is
 * 1 + (2 * 3). In state 6 the rule is higher than both tokens: always
 * reduced. Without the two %left lines the automaton is the same and
 * yacc shifts everywhere, counting 4 conflicts: every operator would
 * group to the right.
 *
 * terminology:
 * Four parsers on one kind of table, told apart by when a state may
 * reduce. LR(0): whenever an item is at its end, with no look at the
 * next token; few grammars pass. SLR(1): when the next token may
 * follow the rule's non-terminal somewhere in the grammar (its
 * FOLLOW set). LALR(1): when it may follow it in this state, which is
 * the lookaheads above; the states are still LR(0)'s. LR(1), Knuth's:
 * the lookahead is part of the item, so a set of items met with other
 * lookaheads is another state, and there are several times more of
 * them. A grammar that is LR(1) and not LALR(1) has a reduce/reduce
 * conflict that merging two such states made; it is rare, and hard
 * to understand from yacc's message when it comes.
 *
 * others:
 * The lookaheads here are a fixpoint over every item of every state,
 * the definition run until nothing changes. Berkeley yacc and bison
 * compute them for the reductions only, by Frank DeRemer and Thomas
 * Pennello's relations (1982), each set a union along a graph visited
 * once. menhir builds LR(1) states and merges those that can be
 * merged without a new conflict (David Pager's way, 1977): never a
 * conflict that LR(1) would not have.
 *
 * References: Aho, Sethi, Ullman, "Compilers" (1986), 4.7; Berkeley
 * yacc's lalr.c and mkpar.c for what a conflict and a
 * default are; Frank DeRemer, "Practical Translators for LR(k)
 * Languages" (MIT, 1969) and "Simple LR(k) Grammars" (Communications
 * of the ACM, 1971); Frank DeRemer and Thomas Pennello, "Efficient
 * Computation of LALR(1) Look-Ahead Sets" (ACM Transactions on
 * Programming Languages and Systems, 1982). *)

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
