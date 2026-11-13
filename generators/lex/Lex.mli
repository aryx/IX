(* The description of a lexer in ocamllex's format (a .mll), limited to
 * the part that ix's lexers use, and its reader, which is written by
 * hand (plan_lex_yacc.md, decision 1).
 *
 *     { header }
 *     let digit = ['0'-'9']
 *     rule token = parse
 *       | digit+ as n      { INT (int_of_string n) }
 *       | "(*"             { comment 1 lexbuf; token lexbuf }
 *       | eof              { EOF }
 *     and comment depth = parse
 *       | "*)"             { if depth > 1 then comment (depth - 1) lexbuf }
 *       | _                { comment depth lexbuf }
 *     { trailer }
 *
 * A regexp can be 'c', "str", _ (any character), eof, [ 'a'-'z' '_' ]
 * and [^ ... ], a named regexp, r*, r+, r?, r1 r2, r1 | r2, (r), or
 * r as x. The reader does not accept r1 # r2, shortest and refill, and
 * gives an error for them.
 *
 * The header, the trailer and the actions are OCaml code, kept as text
 * along with the line where they start. The reader looks only at their
 * braces, strings and comments, to find where they end. So actions in
 * another language would be read the same way. *)

(* the line and the message *)
exception Error of int * string

(* A set of characters is 257 flags ('\001' means the character is in
 * the set), and the 257th flag is the end of the input. r+ is read as
 * Seq (r, Star r) and r? as Alt (r, Eps). A named regexp is put in the
 * place of its name. *)
type regexp =
  | Chars of string
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of string * regexp           (* r as x *)

(* OCaml text, with the line and the column where it starts *)
type code = { text : string; line : int; col : int }

type clause = { re : regexp; action : code }
(* a rule's name and its parameters (lexbuf comes after them) *)
type rule = { name : string; params : string list; clauses : clause list }
type t = { header : code option; rules : rule list; trailer : code option }

val read : string -> t
