(* The description of a grammar in ocamlyacc's format (a .mly), limited
 * to the part that ix's grammars use, and its reader, which is written
 * by hand (plan_lex_yacc.md, decision 1).
 *
 *     %{ header %}
 *     %token <int> INT
 *     %token PLUS TIMES LPAREN RPAREN EOF
 *     %left PLUS                      /* the lowest precedence first */
 *     %left TIMES
 *     %start main
 *     %type <int> main
 *     %%
 *     main: expr EOF { $1 };
 *     expr:
 *       | INT { $1 }
 *       | expr PLUS expr { $1 + $3 }
 *       | MINUS expr %prec TIMES { - $2 }
 *     ;
 *     %%
 *     trailer
 *
 * The reader also accepts menhir's standard rules, used like any other
 * symbol, so that one grammar text works for both menhir and mini-yacc:
 *
 *     main: list(statement) EOF { $1 };
 *     call: IDENT LPAREN separated_list(COMMA, expr) RPAREN { Call ($1, $3) }
 *
 * The standard rules are:
 *  - option(x), which is None or Some x;
 *  - boption(x), which says whether x is there;
 *  - list(x), nonempty_list(x), separated_list(sep, x) and
 *    separated_nonempty_list(sep, x), which are the x's in the text's
 *    order;
 *  - loption(x), which is a list, or [] when there is none;
 *  - x?, x* and x+, which stand for option(x), list(x) and
 *    nonempty_list(x).
 * Before the automaton is made, each use becomes a non-terminal with
 * rules of its own, named as menhir names it (list_statement_). In an
 * action, the reader also accepts menhir's places: $sloc, where the
 * rule's text is, and $loc($n), where its n-th symbol is (see Output).
 *
 * The reader does not accept the error token, an action before a
 * rule's end, %token's aliases, menhir's rules with parameters that a
 * grammar defines itself, and x = symbol; it gives an error for them.
 * The header, the trailer and the actions are OCaml code, kept as text
 * along with where they start.
 *
 * cs-history:
 * Writing a rule as a name, a colon and what it may be is John
 * Backus's notation, made for Algol 58. Peter Naur's report on Algol 60
 * (1960) defined the syntax of a whole language with it, and it has
 * been the usual way since (BNF). What yacc added is the braces: the
 * code to run when the rule is recognized, where $1 and $2 are the
 * values of its symbols, so that a grammar is also the program that
 * builds the tree. list(x) and x* come from the other old notation,
 * where a rule's right side is a regular expression (Niklaus Wirth's
 * EBNF, 1977); an LR generator must first turn them back into plain
 * rules. *)

(* the line and the message *)
exception Error of int * string

(* OCaml text, with the line and the column where it starts *)
type code = { text : string; line : int; col : int }

type assoc = Left | Right | Nonassoc

(* lhs: rhs { action }, with %prec's token if any *)
type rule = { lhs : string; rhs : string list; prec : string option; action : code; rline : int }

type t = {
  header : code option;
  tokens : (string * string option) list;       (* in their order, each with its values' type *)
  precs : (assoc * string list) list;           (* the lowest first; a name may be no token (%prec's) *)
  starts : string list;
  types : (string * string) list;               (* %type: a non-terminal's *)
  rules : rule list;                            (* the grammar's, then those made for list(x)... *)
  trailer : code option;
}

val read : string -> t
