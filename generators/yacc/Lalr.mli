(* The LALR(1) automaton of a grammar, and the parser's actions. They
 * are computed as yacc computes them (ocamlyacc is Berkeley yacc), so
 * that the two parsers parse alike.
 *
 * - The symbols are numbered. Among the terminals, 0 is the end of the
 *   input, which no lexer returns; then come the tokens, and then the
 *   names that are only precedences (used by %prec). The non-terminals
 *   are in the order of their first rule.
 * - The rules are the grammar's, followed by one rule $accept: start
 *   for each start symbol, whose reduction ends the parse.
 * - The LR(0) states are sets of items (an item is a rule with a dot in
 *   it), built from the first state of each start symbol.
 * - The lookaheads are, for each state and item, the terminals that may
 *   follow. They are passed along until nothing is added: inside a
 *   state, from an item to the items of the non-terminal after its dot
 *   (with what may follow that non-terminal there), and from an item to
 *   the same item in the next state. That is LALR(1): the lookaheads of
 *   the canonical LR(1) states that have the same items, merged.
 * - A state's action on a terminal is a shift, or the reduction of an
 *   item that is at its end and whose lookaheads have the terminal.
 *   When there are two actions, yacc's rules choose:
 *    - between a shift and a reduction, their precedences decide (the
 *      token's, and the rule's, which is that of its last terminal or
 *      of its %prec), and the higher one wins. On a tie, the
 *      associativity decides: left reduces, right shifts, and none
 *      makes it an error;
 *    - without precedences, the shift wins, and it is counted as a
 *      conflict;
 *    - between two reductions, the earlier rule wins, and it is also
 *      counted as a conflict.
 * - A state with no shift and only one rule to reduce by has that
 *   reduction as its default: it reduces whatever the next token is,
 *   without reading it.
 *
 * Here is the grammar of the parse shown in CLI.mli, with TIMES above
 * PLUS:
 *
 *     %left PLUS  %left TIMES
 *     e: INT (rule 0) | e PLUS e (1) | e TIMES e (2);   $accept: e (3)
 *
 *     state  its kernel items            INT   PLUS  TIMES  $end   e
 *       0    $accept: . e                s2                        1
 *       1    $accept: e .                      s3    s4     acc
 *            e: e . PLUS e
 *            e: e . TIMES e
 *       2    e: INT .                    r0 whatever comes (the default)
 *       3    e: e PLUS . e               s2                        5
 *       4    e: e TIMES . e              s2                        6
 *       5    e: e PLUS e .                     r1    s4     r1
 *            e: e . PLUS e
 *            e: e . TIMES e
 *       6    e: e TIMES e .              r2 whatever comes (the default)
 *            e: e . PLUS e
 *            e: e . TIMES e
 *
 * (s2 means shift and go to state 2; r1 means reduce by rule 1; the
 * last column is the goto. This is mini-yacc -v's listing, shown as a
 * table.) The dot shows how much of the rule is on the stack. State 5
 * is where the grammar is ambiguous. An e, a PLUS and an e are on the
 * stack, so the rule could be reduced, but the next token could also be
 * shifted, since both items are in the state. On PLUS, the token and
 * the rule have the same precedence, and %left says to reduce, so
 * 1 + 2 + 3 is (1 + 2) + 3. On TIMES, the token is higher than the rule
 * (whose precedence is PLUS's), so it is shifted, and 1 + 2 * 3 is
 * 1 + (2 * 3). In state 6 the rule is higher than both tokens, so it is
 * always reduced. Without the two %left lines, the automaton is the
 * same, but yacc shifts everywhere and counts 4 conflicts, so every
 * operator would group to the right.
 *
 * terminology:
 * Four kinds of parser use the same kind of table, and they differ in
 * when a state may reduce:
 *  - LR(0) reduces whenever an item is at its end, without looking at
 *    the next token; few grammars pass.
 *  - SLR(1) reduces when the next token may follow the rule's
 *    non-terminal somewhere in the grammar (its FOLLOW set).
 *  - LALR(1) reduces when the next token may follow it in this state,
 *    which is what the lookaheads above say; the states are still
 *    those of LR(0).
 *  - LR(1), Knuth's, makes the lookahead part of the item, so the same
 *    set of items reached with other lookaheads is another state, and
 *    there are several times more states.
 * A grammar that is LR(1) but not LALR(1) has a reduce/reduce conflict
 * that the merging of two such states created. It is rare, and when it
 * happens it is hard to understand from yacc's message.
 *
 * others:
 * Here the lookaheads are a fixpoint over every item of every state:
 * the definition is applied until nothing changes. Berkeley yacc and
 * bison compute them only for the reductions, with the relations of
 * Frank DeRemer and Thomas Pennello (1982), where each set is a union
 * along a graph that is visited once. menhir builds LR(1) states and
 * merges those that can be merged without a new conflict (David
 * Pager's method, 1977), so it never has a conflict that LR(1) would
 * not have.
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
  (* the parts of the grammar that have no effect, each with its line (0
   * when there is none): the tokens used in no rule, a non-terminal that
   * no start symbol leads to, and a token's precedence or a rule's %prec
   * that decides no conflict *)
  warnings : (int * string) list;
}

val make : Yacc.t -> t
