(* Js_lexer cuts JavaScript's text into tokens.

   cs-history:
   Two things here are JavaScript's own, from its first years. The
   first is the newline that may end a statement. Semicolons were made
   optional so that a page's author, who was not a programmer, would
   not be stopped by one left out ("automatic semicolon insertion"),
   and the rules for when a newline counts have surprised everyone
   since (a "return" alone on its line returns nothing). The second is
   the slash: "/" is a division after a value, and the start of a
   regular expression anywhere else (Perl's syntax, taken in Navigator
   4, 1997). So this lexer, unlike most, must know what kind of token
   came before to know what it is reading.

   This is the first stage of the engine (section 1 of mini-chrome's
   notes_javascript.md). Characters come in, and tokens go out: a
   keyword (let, function), a name (n, document), a number, a string
   (with its escapes decoded), a punctuation, or an operator. Spaces
   and comments (// to the end of the line, /* ... */) are dropped,
   with one exception: each token remembers whether a **newline** came
   before it. That is the one fact about spacing that the grammar needs
   (a newline may end a statement, and a `return` alone on its line
   returns nothing: see Js_parse.mli).

   The one real decision is the **longest match**: "===" is one token,
   not "==" then "=", and "=>" is one token, not "=" then ">". So the
   operators of three characters are tried first, then those of two,
   then those of one.

   A worked example (the tests' one):

     let s = "a" + 'b'; // two strings
     x=>x===1

     Keyword let  Name s  Punct =  String "a"  Punct +  String "b"  Punct ;
     Name x (a newline before)  Punct =>  Name x  Punct ===  Number 1

   A '/' starts a regular expression where a value may start (after an
   operator, a "(" or a keyword), and it is a division after a value.
   This is one of JavaScript's lexing traps, and the lexer tells the
   two apart by the token before.

     a / b / g          Name a  Punct /  Name b  Punct /  Name g
     x = /b/g           Name x  Punct =  Regex /b/g
     (x) / y / 1        after a ")" that closes an expression: a division
     if (x) /y/.test(s) after the ")" of an if's condition: a regexp

   The last two are why the token before is not always enough: after a
   ")" or a "}", the lexer must know what was closed, a statement's
   head or a value. A lexer made from a grammar could not say; this
   one keeps that much of the parser's knowledge (in its
   after_statement).

   design:
   A lexer that needs the parser's context is a sign that the tokens
   were designed after the fact. rc has the same trouble on purpose
   (in the shell's Lexer, a caret may be left out, and a "(" right
   after a word is a subscript), and C has it with a typedef's name (in
   mini-cc). All three are solved the same way, by a little state in
   the lexer that says where in the grammar it is. A language designed
   with its grammar does not need it (Pascal; or Go, whose rule for
   semicolons belongs to the lexer alone, which looks at the last token
   of the line).

   A template literal (`...${x}...`) is one token. Its ${ } hold whole
   expressions (with strings, regular expressions, braces, and other
   templates), so each one is lexed here, up to the } that closes it,
   and kept as its tokens for the parser.

   A number is a float whatever its writing (0x10, 0b11, 0o17, 1e3,
   .5), and a BigInt's literal is read as the number it says: 10n is
   10, since there are no integers of any size here. A name may have
   letters beyond ASCII (any byte above 127, since the text is UTF-8),
   and a class's private name, #x, is a name like any other.

   Numeric separators are not read (1_000 gives "a number followed by
   '_'").

   Where it stands: Js_parse calls [tokenize] once for a text and has
   all the tokens in an array before it starts, which lets it look
   ahead for an arrow's "=>" at no cost. A string's escapes are made
   into UTF-8 here (the escape of U+00E9, six characters in the text,
   is two bytes in the token: see Js_string), so the rest of the engine
   sees no escape.

   Reference: ECMAScript, section 12 (the lexical grammar): 12.7 for
   names and keywords, 12.8 for punctuators, 12.9.3 for numbers, and
   12.9.4 for strings. *)
(* ix: copied from languages/javascript/parsing/Js_lexer.mli in the
 * author's mini-chrome, at its commit 8af888e (docs/plans/plan_browser.md) *)

type kind =
  | Keyword of string (* let, const, var, function, return, if, ... *)
  | Name of string
  | Number of float
  | String of string (* decoded: "a\nb" is three characters *)
  | Punct of string (* an operator or a punctuation: "===", "{" *)
  | Regex of string * string (* /[0-9]+/g: its pattern and its flags; it comes where an expression may start *)
  (* `a${x}b${y}c`: its strings ("a", "b", "c"), with escapes decoded
   * and newlines kept, and between them the tokens of each ${ }, for
   * the parser to read as an expression *)
  | Template of string list * token list list
  | Eof

and token = {
  kind : kind;
  line : int; (* from 1 *)
  newline_before : bool; (* a line ended between this token and the one before *)
  at : int; (* where it starts in the text; a function's own text is cut from there (Function.prototype.toString) *)
}

(* a mistake in the text, with its line: an unterminated string or
 * comment, or a character that starts no token *)
exception Error of int * string

(* returns a code point as its UTF-8 bytes, which is what a \u escape
 * stands for; half of a surrogate pair gives its three bytes too *)
val utf_8 : int -> string

(* the words that are not names *)
val keywords : string list

(* returns the tokens of a script, ending with Eof; raises Error on a
 * mistake *)
val tokenize : string -> token list

(* prints a token as the notes and the tests write it: Keyword let, Name
 * s, String "a" (quoted, escaped), Number 1, Punct ===, Eof *)
val to_string : kind -> string

(* every punctuation that the lexer makes a token of *)
val punctuators : string list
