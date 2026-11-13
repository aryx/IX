(* Css_syntax: reading a style sheet's text, first into tokens, then into
   rules and blocks.

   (See mini-chrome's notes_css_engine.md sections 1 and 2.) CSS's
   syntax is older and smaller than its properties, and CSS Syntax
   Level 3 wrote down the tokenizer that every browser had converged
   on: identifiers, functions ("rgb("), at-keywords ("@media"), hashes
   ("#top"), strings, url()s, numbers with their kind (2, 50%, 1.5em),
   delimiters, and the punctuation. The tokens come first, then the
   **blocks**, by matching brackets, then the **rules**. So a "{"
   inside a string, a "}" inside a url() or a block inside @media
   never cuts a rule in the wrong place, as a split on braces does (the
   playground's first Css did that).

     a:hover > .x { color: #f00 !important }

     Ident a, Colon, Ident hover, Whitespace, Delim >, Whitespace,
     Delim ., Ident x, Whitespace, then a { } block:
     Ident color, Colon, Whitespace, Hash f00, Whitespace, Delim !,
     Ident important

   A style sheet is made of **rules**. A rule is either a qualified
   rule (a prelude, which is the selectors, and a { } block of
   declarations) or an at-rule (@media ... { rules }, @import
   url(x.css);). **Errors are skipped, not fatal.** That is CSS's own
   rule, the one that lets a browser read a sheet written for a newer
   one. A declaration that does not parse is dropped up to its ";", a
   rule up to its block's end, and an unknown at-rule with its block.

   Not done: the tokens' exact positions (for a devtools' "line 3"),
   CSS nesting ("&:hover" inside a rule; its nested rules are dropped),
   and @charset (a sheet is taken as UTF-8).

   In the system, Cascade and Css read a sheet's rules from here,
   Selectors reads a rule's prelude, and Css_values and Computed read a
   declaration's components. It is the same order of work as Html_lexer
   and Html_tree for a page, with the same manners: nothing typed is an
   error, and a meaning is found for all of it.

   design:
   This is a syntax made to be skipped. CSS1 (1996) already said how
   to read what a browser does not know. A declaration with an unknown
   property, or a value the browser cannot read, is dropped alone; a
   rule with a selector it cannot read is dropped whole; an unknown
   @-rule is skipped to its ";" or its matching "}". So a style sheet
   written for tomorrow's browsers does no harm in today's, and CSS
   could grow for thirty years without versions: a page says "display:
   grid" and an old browser simply lays it out as blocks. Reading CSS
   is mostly knowing where the thing one does not understand ends;
   hence the blocks are matched by their brackets before anything is
   interpreted.

   others:
   A C compiler stops at the first thing it cannot read, and a JSON
   reader refuses the whole file; HTML repairs (Html_tree.mli) and
   CSS skips. The two languages of the page are the two whose readers
   may not say no, since the one who reads is not the one who wrote.

   Reference: W3C, "CSS Syntax Module Level 3", sections 4 (tokenization)
   and 5 (parsing). *)

type token =
  | Ident of string
  | Function of string (* "rgb(": the name, its case kept as written *)
  | At_keyword of string (* "@media" gives "media" *)
  | Hash of string (* "#f00" gives "f00" *)
  | String of string (* with its escapes decoded *)
  | Url of string (* url(x.png), unquoted, gives "x.png" *)
  | Delim of char
  | Number of float
  | Percentage of float
  | Dimension of float * string (* 1.5em gives 1.5 and "em" *)
  | Whitespace
  | Colon
  | Semicolon
  | Comma

(* a token, a block ("(", "[" or "{" and what is inside), or a function
 * and its arguments *)
type component = Token of token | Block of char * component list | Func of string * component list

type declaration = { name : string; (* lowercased *) value : component list; important : bool }

type rule =
  | Style_rule of { prelude : component list; declarations : declaration list }
  | At_rule of { name : string; (* lowercased *) prelude : component list; block : component list option }

val tokenize : string -> token list

(* a text's components: its tokens, blocks and functions *)
val components_of : string -> component list

(* trim takes the spaces off both ends; split_on cuts a list at a token
 * (at the commas, say) *)
val trim : component list -> component list
val split_on : token -> component list -> component list list

(* the rules of a style sheet's text *)
val parse_stylesheet : string -> rule list

(* the declarations of a style="..." attribute *)
val parse_declarations : string -> declaration list

(* an at-rule's block, read as rules (for @media) or as declarations
 * (for @font-face) *)
val rules_of_block : component list -> rule list
val declarations_of_block : component list -> declaration list

(* components written back as text, with the spaces made one:
 * "rgb(1, 2, 3)", "0 auto", "calc(100% - 2em)". This is how a
 * declaration's value is given to the properties' readers. *)
val to_string : component list -> string
