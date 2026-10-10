(* Js_lexer: JavaScript's text cut into tokens.

   cs-history:
   Two things here are JavaScript's own, both from its first days. The
   newline that may end a statement: semicolons were made optional so
   that a page's author, not a programmer, would not be stopped by one
   left out ("automatic semicolon insertion"), and the rules for when a
   newline counts have surprised everyone since (a "return" alone on
   its line returns nothing). And the slash: "/" is a division after a
   value and the start of a regular expression anywhere else (Perl's
   syntax, taken in ES3, 1999), so that this lexer, unlike most, must
   know what kind of token came before to know what it is reading.

   The first stage of the engine (notes_javascript.md section 1):
   characters in, tokens out -- a keyword (let, function), a name (n,
   document), a number, a string (its escapes decoded), a punctuation
   or an operator. Spaces and comments (// to the end of the line,
   /* ... */) are dropped, with one exception: each token remembers
   whether a **newline** came before it, the one fact about spacing the
   grammar needs (a newline may end a statement; `return` alone on its
   line returns nothing: Js_parse.mli).

   The one real decision is the **longest match**: "===" is one token,
   not "==" then "=", and "=>" one, not "=" then ">". So the operators
   are tried three characters first, then two, then one.

   Worked example (the tests'):

     let s = "a" + 'b'; // two strings
     x=>x===1

     Keyword let  Name s  Punct =  String "a"  Punct +  String "b"  Punct ;
     Name x (a newline before)  Punct =>  Name x  Punct ===  Number 1

   A '/' is a regular expression's where a value may start (after an
   operator, a "(" or a keyword), and a division after a value: one of
   JavaScript's lexing traps, told here by the token before.

   A template literal (`...${x}...`) is one token: its ${ } hold
   whole expressions -- strings, regular expressions, braces, other
   templates -- so each is lexed here, to the } that closes it, and
   kept as its tokens for the parser.

   Not read: BigInt (10n), numeric separators (1_000), and identifiers
   beyond ASCII letters, digits, _ and $.

   Reference: ECMAScript, section 12 (lexical grammar): 12.7 names and
   keywords, 12.8 punctuators, 12.9.3 numbers, 12.9.4 strings. *)
(* ix: the author's mini-chrome's languages/javascript/parsing/Js_lexer.mli (its 8af888e) (docs/plans/plan_browser.md) *)

type kind =
  | Keyword of string (* let, const, var, function, return, if, ... *)
  | Name of string
  | Number of float
  | String of string (* decoded: "a\nb" is three characters *)
  | Punct of string (* an operator or a punctuation: "===", "{" *)
  | Regex of string * string (* /[0-9]+/g: its pattern, its flags -- where an expression may start *)
  (* `a${x}b${y}c`: its strings ("a", "b", "c"), escapes decoded and
   * newlines kept, and between them the tokens of each ${ }, for the
   * parser to read as an expression *)
  | Template of string list * token list list
  | Eof

and token = {
  kind : kind;
  line : int; (* from 1 *)
  newline_before : bool; (* a line ended between this token and the one before *)
  at : int; (* where it starts in the text: a function's own text is cut from there (Function.prototype.toString) *)
}

(* a mistake in the text, and its line: an unterminated string or
 * comment, a character that starts no token *)
exception Error of int * string

(* the words that are not names *)
(* a code point as UTF-8's bytes, what a \u escape stands for; half of
 * a surrogate pair too, as its three bytes *)
val utf_8 : int -> string

val keywords : string list

(* the tokens of a script, ending with Eof; Error on a mistake *)
val tokenize : string -> token list

(* a token as the notes and the tests write it: Keyword let, Name s,
 * String "a" (quoted, escaped), Number 1, Punct ===, Eof *)
val to_string : kind -> string

(* every punctuation the lexer makes a token of *)
val punctuators : string list
