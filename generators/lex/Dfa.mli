(* A lexer's rules as one deterministic automaton: Lexing's tables
 * (lib_core's: a state a row of 257 next states, and the clause it
 * accepts), and each rule's first state.
 *
 * By the book: each regexp to a nondeterministic automaton (Thompson),
 * a rule's clauses side by side, then the sets of its states reached
 * together are the deterministic one's states (the subset
 * construction). A state that ends several clauses accepts the first:
 * with the engine's longest match, ocamllex's rule. Nothing is
 * minimized or compacted.
 *
 *     rule token = parse "if" { IF } | ['a'-'z']+ { IDENT }
 *
 *     nondeterministic: both clauses leave one start, and after an i
 *     the automaton is in two places at once (an arrow without a
 *     character is free)
 *
 *                 i          f
 *            .---> ( ) ----> ( ) ----> (( IF ))
 *     start -|                           .--. a-z
 *            |    a-z                    v  |
 *            '---> ( ) ----------------> (( IDENT ))
 *
 *     deterministic: a state is a set of those places, and there is
 *     one next state a character (mini-lex -v counts 5)
 *
 *     state  after              accepts   i   f   another letter
 *       0    nothing            -         2   1   1
 *       1    a letter, not i    IDENT     3   3   3
 *       2    i                  IDENT     3   4   3
 *       3    anything longer    IDENT     3   3   3
 *       4    if                 IF        3   3   3
 *
 * On what is no small letter every row has -1, and the engine stops.
 * State 4 holds the end of both clauses and accepts the first, IF. On
 * "iffy" the states are 0 2 4 3 3: the last accepting one passed is at
 * the text's end, so it is an IDENT of four characters and not IF then
 * "fy": the longest match. States 1 and 3 do the same and a
 * minimization would make them one; here they stay two.
 *
 * In ix a regular expression is matched three ways. Here the automaton
 * is made deterministic before any text is read: a table lookup a
 * character, and tables that may be large. Regex (grep's, sed's,
 * awk's) keeps the nondeterministic one and follows all its places
 * together as it reads, with each one's submatches. Js_regexp tries
 * one way at a time and comes back when it fails, which backreferences
 * need and which can take exponential time.
 *
 * cs-history:
 * The two automata are the two halves of a theorem. Stephen Kleene
 * (1956) showed that regular expressions say what finite automata
 * accept; Michael Rabin and Dana Scott (1959) that a nondeterministic
 * automaton has a deterministic one for the same texts, its states the
 * sets of the other's: the subset construction, with up to 2^n states
 * for n, seldom met in a lexer. Ken Thompson (1968) made a regular
 * expression a program: his compiler wrote, for the editor QED,
 * machine code of an IBM 7094 that followed every place at once. The
 * construction called by his name is the one [make] does: an automaton
 * a subexpression, glued by free arrows.
 *
 * others:
 * lex and ocamllex skip the nondeterministic automaton: each character
 * of the expression is a position, and a deterministic state is a set
 * of positions, the next ones by a table of what may follow each (the
 * followpos of Aho, Sethi and Ullman, 3.9). And they compact the
 * table: most of a state's 257 entries are the same, so the rows are
 * laid over each other in one array with a second to check whose an
 * entry is (xix's Compact). Here a state costs 514 bytes, and
 * mini-ml's lexer, of some 200 states, a hundred kilobytes.
 *
 * References: Ken Thompson, "Regular Expression Search Algorithm"
 * (Communications of the ACM, 1968); M. O. Rabin and D. Scott, "Finite
 * Automata and Their Decision Problems" (IBM Journal of Research and
 * Development, 1959); Aho, Sethi, Ullman, "Compilers" (1986), 3.6 to
 * 3.9; Russ Cox, "Regular Expression Matching Can Be Simple And Fast"
 * (2007): the three ways compared. *)

type t = {
  trans : int array array;            (* a state's 257 next states, -1 for none *)
  accept : int array;                 (* a state's clause, -1 for none *)
  starts : int list;                  (* each rule's first state, in the rules' order *)
}

val make : Lex.rule list -> t
