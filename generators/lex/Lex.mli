(* A lexer's description, ocamllex's (a .mll), the part ix's lexers
 * use, and its reader, written by hand (plan_lex_yacc.md, decision 1).
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
 * A regexp: 'c', "str", _ (any character), eof, [ 'a'-'z' '_' ] and
 * [^ ... ], a named one, r*, r+, r?, r1 r2, r1 | r2, (r), r as x. Not
 * read, and said so: r1 # r2, shortest, refill.
 *
 * The header, the trailer and the actions are OCaml, kept as text with
 * the line they start at; nothing in them is looked at but their
 * braces, strings and comments, to find their end. So another
 * language's actions would be read the same. *)

(* the line, the message *)
exception Error of int * string

(* A set of characters as 257 flags ('\001': in), the 257th the end of
 * the input. r+ is Seq (r, Star r) and r? is Alt (r, Eps); a named
 * regexp is in the place of its name. *)
type regexp =
  | Chars of string
  | Eps
  | Seq of regexp * regexp
  | Alt of regexp * regexp
  | Star of regexp
  | Bind of string * regexp           (* r as x *)

(* OCaml text, the line and the column it starts at *)
type code = { text : string; line : int; col : int }

type clause = { re : regexp; action : code }
(* a rule's name, its parameters (lexbuf is the one after them) *)
type rule = { name : string; params : string list; clauses : clause list }
type t = { header : code option; rules : rule list; trailer : code option }

val read : string -> t
