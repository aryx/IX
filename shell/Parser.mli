(* The parser: tokens to commands, by recursive descent (the grammar of
 * principia's syn.y, whose precedences it follows).
 *
 * rc's grammar is small because a condition is a command in
 * parentheses and a body is one command (often a brace):
 *
 *     line     cmd ; cmd & cmd ...                 up to a newline
 *     cmd      bang && bang || ...                 lowest: && ||
 *     bang     ! bang   @ bang   >f bang   x=v bang   pipe
 *     pipe     unit | unit |[2] unit ...
 *     unit     if(line) cmd   if not cmd   while(line) cmd
 *              for(x in words) cmd   for(x) cmd   switch word {...}
 *              fn names {...}   fn names   ~ word words   {line} >f
 *              simple: words and redirections, in any order
 *     word     comword ^ comword ...
 *     comword  WORD  $comword  $#comword  JOIN comword  $comword(words)
 *              (words)  `{line}  `sep{line}  <{line}  >{line}
 *
 * So `if(c) a && b` is if(c){a && b}, `! a | b` is !(a | b), `x=1 a | b`
 * runs the whole pipe with x set, and `a && b | c` is a && (b | c) --
 * what yacc makes of syn.y's precedences. A newline after if(...),
 * while(...), for(...), switch word or if not is skipped, as syn.y's
 * skipnl() does. Keywords are keywords only where a command starts:
 * echo if prints if.
 *
 * Why by hand, when rc's own parser is a yacc grammar (syn.y, 116
 * lines, which this file follows rule for rule) and ix has mini-yacc.
 * The plan was a generated parser; reading syn.y changed it:
 * - The grammar is not the whole of it. syn.y's rules call skipnl() in
 *   their middle (a newline after if(...), while(...), switch word, if
 *   not is skipped), give prefix redirections and assignments a
 *   precedence by hand (%prec BANG), and turn keywords back into
 *   words; lex.c knows where a command starts, glues `if not` into one
 *   token and inserts the free carets ($x.c is $x^.c). The lexer needs
 *   to know where the parser is. A recursive descent says each of
 *   these where it happens; a generated parser needs the same tricks,
 *   passed through flags the lexer and the grammar's actions share.
 * - The lines: 257 here, about 130 estimated for the grammar, to which
 *   the flags and their handling in the lexer would add. Not measured
 *   by writing both (the plan had said it would be): decided by
 *   reading. (plan_rc.md, decision 2 and its Status.)
 * What a grammar would give is syn.y's own text to compare with; what
 * keeps this one honest instead is the corpus: every case parsed,
 * printed (Show_ast) and compared with 9base's rc.
 *
 * cs-history:
 * "Nobody really knows what the Bourne shell's grammar is", wrote
 * Duff: its parser "is implemented by recursive descent, but the
 * routines corresponding to the syntactic categories all have a flag
 * argument that subtly changes their operation". Hence rc's yacc
 * grammar, "so I can say precisely what the grammar is". This file
 * is a recursive descent again, but of a grammar yacc has already
 * checked, one function per level above. (Bourne's sources are
 * famous for another reason: C written through macros to look like
 * Algol 68, IF ... THEN ... FI, which is where sh's fi and esac
 * come from.)
 *
 * References: Tom Duff, "Rc -- The Plan 9 Shell" (1990), "Design
 * Principles". A. V. Aho, S. C. Johnson and J. D.
 * Ullman, "Deterministic parsing of ambiguous grammars" (CACM, 1975),
 * the idea behind syn.y's %left and %right: keep a short ambiguous
 * grammar and let precedences settle its conflicts, where a recursive
 * descent must write each level out. *)

exception Error of string   (* e.g. token 'x': syntax error *)

(* the next command line, or None at the end of the input. Raises
 * Error, or Lexer.Error. *)
val line : Lexer.t -> Ast.cmd option

(* all the commands of a string, e.g. a function body from the
 * environment *)
val parse_string : string -> Ast.cmd
