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
 * Not read, and said so: the error token, an action before a rule's
 * end, %token's aliases. The header, the trailer and the actions are
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
  rules : rule list;
  trailer : code option;
}

val read : string -> t
