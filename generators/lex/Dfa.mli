(* The rules of a lexer turned into one deterministic automaton. The
 * result is Lexing's tables (in lib_core), where each state has a row of
 * 257 next states and the clause it accepts, and the first state of
 * each rule.
 *
 * It is done by the book. Each regexp becomes a nondeterministic
 * automaton (Thompson's construction), and the clauses of a rule are
 * put side by side. Then each set of its states that are reached
 * together becomes a state of the deterministic automaton (the subset
 * construction). A state that ends several clauses accepts the first
 * one; together with the engine's longest match, this is ocamllex's
 * rule. Nothing is minimized or compacted.
 *
 *     rule token = parse "if" { IF } | ['a'-'z']+ { IDENT }
 *
 *     nondeterministic: both clauses leave from one start, and after an
 *     i the automaton is in two places at once (an arrow without a
 *     character is taken for free)
 *
 *                 i          f
 *            .---> ( ) ----> ( ) ----> (( IF ))
 *     start -|                           .--. a-z
 *            |    a-z                    v  |
 *            '---> ( ) ----------------> (( IDENT ))
 *
 *     deterministic: a state is a set of those places, and each
 *     character leads to one next state (mini-lex -v counts 5 states)
 *
 *     state  after              accepts   i   f   another letter
 *       0    nothing            -         2   1   1
 *       1    a letter, not i    IDENT     3   3   3
 *       2    i                  IDENT     3   4   3
 *       3    anything longer    IDENT     3   3   3
 *       4    if                 IF        3   3   3
 *
 * On a character that is not a lowercase letter, every row has -1, and
 * the engine stops. State 4 holds the end of both clauses and accepts
 * the first one, IF. On "iffy" the states are 0 2 4 3 3. The last
 * accepting state passed is at the end of the text, so the token is an
 * IDENT of four characters, and not IF followed by "fy": this is the
 * longest match. States 1 and 3 behave the same, and a minimization
 * would merge them; here they stay two states.
 *
 * In ix a regular expression is matched in three ways. Here the
 * automaton is made deterministic before any text is read, so each
 * character costs one table lookup, but the tables may be large. Regex
 * (used by grep, sed and awk) keeps the nondeterministic automaton and
 * follows all its places together as it reads, each with its own
 * submatches. Js_regexp tries one way at a time and backtracks when it
 * fails; backreferences need this, and it can take exponential time.
 *
 * cs-history:
 * The two automata are the two halves of a theorem. Stephen Kleene
 * (1956) showed that regular expressions describe what finite automata
 * accept. Michael Rabin and Dana Scott (1959) showed that a
 * nondeterministic automaton has a deterministic one that accepts the
 * same texts, whose states are sets of the other's states. This is the
 * subset construction; it can make up to 2^n states from n, which is
 * seldom seen in a lexer. Ken Thompson (1968) turned a regular
 * expression into a program: for the editor QED, his compiler wrote
 * machine code for an IBM 7094 that followed every place at once. The
 * construction that bears his name is the one [make] does: one
 * automaton per subexpression, glued together by free arrows.
 *
 * others:
 * lex and ocamllex skip the nondeterministic automaton. Each character
 * of the expression is a position, and a deterministic state is a set
 * of positions; the next states come from a table of what may follow
 * each position (the followpos of Aho, Sethi and Ullman, 3.9). They
 * also compact the table. Most of a state's 257 entries are the same,
 * so the rows are laid over each other in one array, with a second
 * array that says which row each entry belongs to (xix's Compact).
 * Here a state costs 514 bytes, and mini-ml's lexer, which has some
 * 200 states, costs a hundred kilobytes.
 *
 * References: Ken Thompson, "Regular Expression Search Algorithm"
 * (Communications of the ACM, 1968); M. O. Rabin and D. Scott, "Finite
 * Automata and Their Decision Problems" (IBM Journal of Research and
 * Development, 1959); Aho, Sethi, Ullman, "Compilers" (1986), 3.6 to
 * 3.9; Russ Cox, "Regular Expression Matching Can Be Simple And Fast"
 * (2007), which compares the three ways. *)

type t = {
  trans : int array array;            (* a state's 257 next states, -1 for none *)
  accept : int array;                 (* a state's clause, -1 for none *)
  starts : int list;                  (* each rule's first state, in the rules' order *)
}

val make : Lex.rule list -> t
