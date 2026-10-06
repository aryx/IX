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
 * names it (list_statement_), before the automaton is made.
 *
 * Not read, and said so: the error token, an action before a rule's
 * end, %token's aliases; menhir's own rules with parameters, x = symbol,
 * $startpos. The header, the trailer and the actions are
 * OCaml, kept as text with where they start. *)

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
