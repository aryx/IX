(* The lexer turns characters into rc's tokens. It is written by hand,
 * as principia's lex.c is.
 *
 * rc's lexer does four things that a grammar cannot do:
 *
 *     'it''s'            the only quote is ', and '' in quotes is a quote
 *     $x.c   x$y         free carets: a word right after a word (no blank
 *                        between) is joined to it, as if by ^
 *     $x(1)              a ( right after a word is a subscript, not a list
 *     if(  echo if       keywords -- for in while if not switch fn ~ ! @ --
 *                        are words the parser gives meaning to; after one
 *                        there is no free caret, so if( is if then (
 *
 * It also skips a newline right after | && or ||, so that a pipeline
 * can go on on the next line. A # at the start of a token starts a
 * comment.
 *
 * The characters that end a word are the blanks and \n#;&|^$=`'{}()<>
 * (lex.c's wordchr). After a $, a name stops at any punctuation
 * (idchr), so $stem.c is $stem^.c. An unquoted = can only be an
 * assignment, so echo a=b is a syntax error, as in rc.
 *
 * A redirection comes as one token that holds its file descriptors
 * (> >> < <> << and |, with [fd], [fd=], [fd=fd]):
 *
 *     >[2]   REDIR (Open (Write, 2))    >[2=1]   REDIR (Dup (2, 1))
 *     >[2=]  REDIR (Close 2)            |[2]     PIPE (2, 0)
 *
 * The input is read a line at a time, through [refill], which is told
 * whether the command is continued. That is how the terminal prompts
 * with the first or the second string of $prompt. A here document's
 * body is read, raw, right after the line that asked for it.
 *
 * cs-history:
 * Free carets are a concession. Joining is an operator in rc, ^, and
 * by the language's own rule $x.c should be written $x^.c. "User
 * demand has dictated that rc insert carets in certain places, to
 * make the syntax look more like the Bourne shell": the lexer adds
 * the ^ where two words touch, and the grammar never knows. Here
 * documents come from Bourne's shell too: the lines between <<! and !
 * are given to a command as its standard input.
 *
 * design:
 * rc has one quote. The Bourne shell has four: the single quote, the
 * double quote, the backslash and the backquote, and each one stops
 * some of the rescanning that the others allow. When nothing is
 * rescanned (Word), there is nothing to stop except the lexer itself,
 * once. So ' is enough, and a quote inside quotes is written twice.
 *
 * References: principia's lex.c; Tom Duff, "Rc -- The Plan 9 Shell"
 * (1990), "Free carets", which gives the exact rule; S. R. Bourne,
 * "An Introduction to the UNIX Shell" (1978), for here documents. *)

type token =
  | WORD of string * bool     (* the text, and whether it was quoted *)
  | DOLLAR | COUNT | JOIN     (* $, $# and dollar-quote *)
  | CARET | SUB               (* ^, and a ( right after a word *)
  | LPAREN | RPAREN | LBRACE | RBRACE
  | BACKQUOTE | EQUAL | SEMI | AMP | NEWLINE | EOF
  | ANDAND | OROR
  | PIPE of int * int
  | REDIR of rtok

(* a redirection: > >> < or <> with its fd, << with its fd, >[a=b], or
 * >[a=] *)
and rtok = Open of Ast.rkind * int | Here of int | Dup of int * int | Close of int

type t

exception Error of string

(* [create ~refill]: [refill continued] returns the next line, with its
 * \n, or None at the end *)
val create : refill:(bool -> string option) -> t

val of_string : string -> t

val token : t -> token

(* skip the blanks, comments and newlines (after if(...), for(...)
 * and the like) *)
val skip_newlines : t -> unit

(* a new command starts, so the next line read is not a continuation *)
val new_command : t -> unit

(* read this here document's body after the current line *)
val add_heredoc : t -> Ast.heredoc -> unit

(* skip the rest of the line, after a syntax error *)
val skip_line : t -> unit

val line : t -> int

(* for in while if not switch fn ~ ! @, which the parser takes as
 * keywords where a command starts *)
type keyword = Kfor | Kin | Kwhile | Kif | Knot | Kswitch | Kfn | Kmatch | Kbang | Kat

val keyword_of : string -> keyword option

val is_keyword : string -> bool

(* how the token is written, for error messages *)
val show : token -> string
