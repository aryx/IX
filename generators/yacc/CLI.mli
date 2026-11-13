(* mini-yacc: the parser generator. It reads a grammar in ocamlyacc's
 * format (a .mly) and writes the parser in OCaml, with its interface.
 * Its usage is [help] in CLI.ml, which is what mini-yacc -h prints.
 *
 * A grammar says what a text may be (for example, an expression is a
 * number, or an expression followed by a PLUS and another expression).
 * A parser finds how a given text fits the grammar. The parser that
 * yacc writes never guesses a rule in advance. It puts tokens on a
 * stack (a shift), and when the top of the stack is the whole right
 * side of a rule, it replaces it by the rule's left side (a reduction)
 * and runs the rule's action. Which of the two to do is read in a
 * table, by the current state and the next token; the state sums up
 * all that matters about the stack below it. Making that table is the
 * generator's work.
 *
 *     Parser.mly                       when the parser is made
 *        | Yacc     reads the grammar: tokens, rules, actions as text;
 *        |          list(x), x? and the like become rules of their own
 *     Yacc.t
 *        | Lalr     computes the states and the lookaheads, and
 *        |          decides the conflicts
 *     Lalr.t
 *        | Output   writes the tables as strings, the actions as an
 *        |          array of functions, the interface, and -v's listing
 *     Parser.ml, Parser.mli
 *     - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 *     tokens from a mini-lex lexer     when the parser runs
 *        | Parsing.run (in lib_core) keeps the stack of states and values
 *     the value of the start symbol, most often a tree
 *
 * With the grammar e: INT | e PLUS e | e TIMES e, where TIMES is
 * declared above PLUS, the text 1 + 2 * 3 is parsed as below. The
 * states are those of Lalr.mli, which works out the same grammar, and
 * $ is the end of the input.
 *
 *     the stack                next   what is done
 *     0                        INT    shift
 *     0 INT 2                  PLUS   reduce e: INT
 *     0 e 1                    PLUS   shift
 *     0 e 1 PLUS 3             INT    shift
 *     0 e 1 PLUS 3 INT 2       TIMES  reduce e: INT
 *     0 e 1 PLUS 3 e 5         TIMES  shift: 2 * 3 goes first
 *     0 e 1 PLUS 3 e 5 TIMES 4 INT    shift, then reduce e: INT
 *     0 e 1 PLUS 3 e 5 TIMES 4 e 6    $      reduce e: e TIMES e
 *     0 e 1 PLUS 3 e 5         $      reduce e: e PLUS e
 *     0 e 1                    $      accept
 *
 * A reduction pops as many states as the rule has symbols. Then the
 * state on top, with the rule's non-terminal, says which state to push
 * (the gotos). The rules are reduced in the order a calculator would
 * compute them, so the tree is built from its leaves, bottom up.
 *
 * In ix, the grammars are those of mini-ml, mini-cc, awk, bc, hoc and
 * the database's SQL. The dune build gives them to ocamlyacc; the
 * mini-mk build, where ix is built by ix, gives them to this program.
 * The other parsers are written top down, as functions that call each
 * other, one function per rule (recursive descent):
 *  - the shell's Parser;
 *  - Pascal_compile, which emits its code as it goes;
 *  - Formula;
 *  - Prolog_read, which cannot be generated, since op/3 changes its
 *    grammar while the text is read.
 *
 * cs-history:
 * Donald Knuth defined the LR(k) grammars in 1965. They are the
 * grammars that a parser can decide with k tokens of lookahead, reading
 * from the Left and building a Rightmost derivation backwards, and no
 * deterministic parser of one pass can do more. His tables were far too
 * large for the machines of the time. Frank DeRemer's thesis (MIT,
 * 1969) kept the small automaton that looks at nothing ahead and added
 * the lookaheads to it. This is LALR: its table has hundreds of states
 * for a real language, where Knuth's had thousands. Stephen Johnson's
 * yacc (Bell Labs; "Yet Another Compiler-Compiler", since there were
 * many then) made it a tool. It also added what made grammars short:
 * an ambiguous grammar of expressions, whose conflicts are decided by
 * %left and %right (Aho, Johnson and Ullman, 1975). The portable C
 * compiler, awk, bc, and Plan 9's compilers and shell all have yacc
 * grammars.
 *
 * evolution:
 * Robert Corbett wrote the two free versions: bison, which is GNU's,
 * and Berkeley yacc. ocamlyacc is Berkeley yacc changed to output
 * OCaml, and its input language is the one this program reads. Plan 9
 * kept Johnson's yacc, one file of C (principia's
 * generators/yacc/yacc.c), which Go translated to Go in its first
 * years. menhir (Francois Pottier and Yann Regis-Gianas) is OCaml's
 * second generator. It is LR(1), and it has rules with parameters such
 * as list(x), named values, and places such as $sloc; Yacc.mli says
 * which part of it is read here.
 *
 * modern:
 * The large compilers have left their generators. GCC had yacc grammars
 * for C and C++ and replaced them by recursive descent parsers written
 * by hand; Clang never used a generator; Go's compiler dropped its own.
 * They wanted error messages that say what was expected in the
 * language's own words, recovery after an error, and C++, which no
 * LALR grammar fits. A small language's grammar is still best given to
 * a generator, which also proves that it is unambiguous. A recursive
 * descent parser takes the first rule that fits and says nothing about
 * the others.
 *
 * References: S. C. Johnson, "Yacc: Yet Another Compiler-Compiler"
 * (Bell Laboratories Computing Science Technical Report 32, 1975),
 * which is still the manual to read; Donald Knuth, "On the Translation
 * of Languages from Left to Right" (Information and Control, 1965);
 * A. V. Aho, S. C. Johnson and J. D. Ullman, "Deterministic Parsing
 * of Ambiguous Grammars" (Communications of the ACM, 1975); the OCaml
 * manual's chapter on ocamllex and ocamlyacc; menhir's manual;
 * principia's generators/yacc; xix's generators/yacc (an SLR
 * generator in OCaml). *)

type caps = < Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr >

val main : < caps; .. > -> string array -> int
