(* Js_lexer: JavaScript's text cut into tokens.

   cs-history:
   Two things here are JavaScript's own, from its first years. The
   newline that may end a statement: semicolons were made optional so
   that a page's author, not a programmer, would not be stopped by one
   left out ("automatic semicolon insertion"), and the rules for when a
   newline counts have surprised everyone since (a "return" alone on
   its line returns nothing). And the slash: "/" is a division after a
   value and the start of a regular expression anywhere else (Perl's
   syntax, taken in Navigator 4, 1997), so that this lexer, unlike
   most, must
   know what kind of token came before to know what it is reading.

   The first stage of the engine (mini-chrome's notes_javascript.md,
   section 1):
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

     a / b / g          Name a  Punct /  Name b  Punct /  Name g
     x = /b/g           Name x  Punct =  Regex /b/g
     (x) / y / 1        after a ")" that closes an expression: a division
     if (x) /y/.test(s) after the ")" of an if's condition: a regexp

   The last two are why the token before is not always enough: after
   a ")" or a "}" the lexer must know what was closed, a statement's
   head or a value. A grammar's lexer could not say; this one keeps
   that much of the parser's knowledge (its after_statement).

   design:
   A lexer that needs the parser's context is a sign that the tokens
   were designed after the fact. rc's has the same trouble on purpose
   (the shell's Lexer: a free caret, and a "(" right after a word is a
   subscript), C's with a typedef's name (mini-cc's), and all three
   are solved the same way: a little state in the lexer that says
   where in the grammar it is. A language designed with its grammar
   (Pascal; Go, whose rule for semicolons is the lexer's alone, by
   the last token of the line) does not need it.

   A template literal (`...${x}...`) is one token: its ${ } hold
   whole expressions -- strings, regular expressions, braces, other
   templates -- so each is lexed here, to the } that closes it, and
   kept as its tokens for the parser.

   A number is a float whatever its writing (0x10, 0b11, 0o17, 1e3,
   .5), and a BigInt's literal is read as the number it says: 10n is
   10, there being no integers of any size here. A name may have
   letters beyond ASCII (any byte above 127: the text is UTF-8), and
   a class's private name, #x, is a name like any other.

   Not read: numeric separators (1_000: "a number followed by '_'").

   Where it stands: Js_parse calls [tokenize] once for a text and has
   them all in an array before it starts, which is what lets it look
   ahead for an arrow's "=>" at no cost. A string's escapes are made
   UTF-8 here (the escape of U+00E9, six characters in the text, is
   two bytes in the token; half of a pair alone is kept as Js_utf16
   says), so the rest of the engine sees no escape.

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
