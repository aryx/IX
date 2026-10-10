(* A grammar's description, ocamlyacc's (a .mly), the part ix's
 * grammars use, and its reader, written by hand (plan_lex_yacc.md,
 * decision 1).
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
 * And of menhir's, so that a grammar is one text for menhir and for
 * mini-yacc, its standard rules, a symbol as any other:
 *
 *     main: list(statement) EOF { $1 };
 *     call: IDENT LPAREN separated_list(COMMA, expr) RPAREN { Call ($1, $3) }
 *
 * option(x) (None, or Some x), boption(x) (is x there), list(x),
 * nonempty_list(x), separated_list(sep, x), separated_nonempty_list(sep, x)
 * (the x's, in the text's order), loption(x) (a list, or none: []);
 * and x?, x*, x+ for option(x), list(x), nonempty_list(x).
 * Each use is a non-terminal with rules of its own, named as menhir
 * names it (list_statement_), before the automaton is made. And in an
 * action, menhir's places: $sloc, where the rule's text is, and
 * $loc($n), where its n-th symbol's is (Output).
 *
 * Not read, and said so: the error token, an action before a rule's
 * end, %token's aliases; menhir's own rules with parameters, x = symbol.
 * The header, the trailer and the actions are
 * OCaml, kept as text with where they start.
 *
 * cs-history:
 * A rule as a name, a colon and what it may be is John Backus's
 * notation, made for Algol 58; Peter Naur's report on Algol 60 (1960)
 * defined a whole language's syntax by it, and it has been the way
 * since (BNF). yacc's part is the braces: the code to run when the
 * rule is recognized, $1, $2 the values of its symbols, so that a
 * grammar is also the program that builds the tree. list(x) and x*
 * are the other old notation, a rule's right side as a regular
 * expression (Niklaus Wirth's EBNF, 1977), which an LR generator
 * must first make plain rules again. *)

(* the line, the message *)
exception Error of int * string

(* OCaml text, the line and the column it starts at *)
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
