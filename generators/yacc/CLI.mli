(* mini-yacc: the parser generator. Reads a .mly, ocamlyacc's, and
 * writes its parser in OCaml and its interface. Its usage: [help] in
 * CLI.ml, what mini-yacc -h prints.
 *
 * A grammar says what a text may be (an expression is a number, or an
 * expression, a PLUS and an expression); a parser finds how a given
 * text is that. The one yacc writes never guesses a rule in advance:
 * it puts tokens on a stack (a shift), and when the top of the stack
 * is the whole right side of a rule, replaces it by the rule's left
 * side (a reduction), running the rule's action. Which of the two to
 * do is read in a table, by a state and the next token: the state
 * says all that matters of the stack below. Making that table is the
 * generator's work.
 *
 *     Parser.mly                       when the parser is made
 *        | Yacc     the grammar read: tokens, rules, actions as text;
 *        |          list(x), x? and the like made rules of their own
 *     Yacc.t
 *        | Lalr     the states, the lookaheads, the conflicts decided
 *     Lalr.t
 *        | Output   the tables as strings, the actions an array of
 *        |          functions; the interface; -v's listing
 *     Parser.ml, Parser.mli
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     tokens (the lexer's: mini-lex)   when the parser runs
 *        | Parsing.run (lib_core's): the stack of states and values
 *     the start symbol's value: a tree, most often
 *
 * With e: INT | e PLUS e | e TIMES e, TIMES declared above PLUS, the
 * text 1 + 2 * 3 is parsed so (the states are Lalr.mli's, where the
 * same grammar is worked out; $ is the end of the input):
 *
 *     the stack                next   what is done
 *     0                        INT    shift
 *     0 INT 2                  PLUS   reduce e: INT
 *     0 e 1                    PLUS   shift
 *     0 e 1 PLUS 3             INT    shift
 *     0 e 1 PLUS 3 INT 2       TIMES  reduce e: INT
 *     0 e 1 PLUS 3 e 5         TIMES  shift: 2 * 3 first
 *     0 e 1 PLUS 3 e 5 TIMES 4 INT    shift, then reduce e: INT
 *     0 e 1 PLUS 3 e 5 TIMES 4 e 6    $      reduce e: e TIMES e
 *     0 e 1 PLUS 3 e 5         $      reduce e: e PLUS e
 *     0 e 1                    $      accept
 *
 * A reduction pops as many states as the rule has symbols, and the
 * state then on top says, by the rule's non-terminal, which to push
 * (the gotos). The rules are reduced in the order a calculator would
 * compute: the tree is built from its leaves, bottom up.
 *
 * In ix the grammars are mini-ml's and mini-cc's, awk's, bc's, hoc's
 * and the database's SQL. dune's build gives them to ocamlyacc;
 * mini-mk's, where ix is built by ix, to this program. The other
 * parsers are functions that call each other, a function a rule, top
 * down (recursive descent): the shell's Parser, Pascal_compile, which
 * emits its code as it goes, Formula; and Prolog_read, which cannot
 * be generated since op/3 changes its grammar while the text is read.
 *
 * cs-history:
 * Donald Knuth defined the LR(k) grammars in 1965: those a parser
 * reading from the Left, building a Rightmost derivation backwards,
 * can decide with k tokens of lookahead, and no deterministic parser
 * of one pass does more. His tables were far too large for the
 * machines of then. Frank DeRemer's thesis (MIT, 1969) kept the small
 * automaton that looks at nothing ahead and added the lookaheads to
 * it: LALR, a table of hundreds of states for a real language, where
 * Knuth's had thousands. Stephen Johnson's yacc (Bell Labs; "Yet
 * Another Compiler-Compiler", there being many then) made it a
 * tool, and added what made grammars short: an ambiguous grammar of
 * expressions, its conflicts decided by %left and %right (Aho,
 * Johnson and Ullman, 1975). The portable C compiler, awk, bc and
 * Plan 9's compilers and shell are yacc grammars.
 *
 * evolution:
 * Robert Corbett wrote the two free ones: bison, GNU's, and Berkeley
 * yacc. ocamlyacc is Berkeley yacc with its output made OCaml, and
 * its language is this program's. Plan 9 kept Johnson's, one file of
 * C (principia's generators/yacc/yacc.c), which Go's first years
 * translated to Go. menhir (Francois Pottier and Yann Regis-Gianas)
 * is OCaml's second generator: LR(1), rules with parameters such as
 * list(x), named values, places as $sloc; the part of it read here
 * is in Yacc.mli.
 *
 * modern:
 * The large compilers have left their generators. GCC had yacc
 * grammars for C and C++ and replaced them by parsers written by
 * hand, recursive descent; Clang never had one; Go's compiler lost
 * its own. What they wanted: error messages that say what was
 * expected in the language's words, recovery after an error, and C++,
 * which no LALR grammar fits. A small language's grammar is still
 * best said to a generator, which also proves it unambiguous: a
 * recursive descent takes the first rule that fits and says nothing
 * of the others.
 *
 * References: S. C. Johnson, "Yacc: Yet Another Compiler-Compiler"
 * (Bell Laboratories Computing Science Technical Report 32, 1975):
 * still the manual to read; Donald Knuth, "On the Translation of
 * Languages from Left to Right" (Information and Control, 1965);
 * A. V. Aho, S. C. Johnson and J. D. Ullman, "Deterministic Parsing
 * of Ambiguous Grammars" (Communications of the ACM, 1975); the OCaml
 * manual's chapter on ocamllex and ocamlyacc; menhir's manual;
 * principia's generators/yacc; xix's generators/yacc (an SLR
 * generator in OCaml). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
