(* Colors. A language's highlighter gives the pieces of a text their
 * categories (lib_code's Highlight_code: a keyword, a comment, a
 * function defined). Here is the color of each category, and a major
 * mode made from a highlighter. efuns' Highlight and its lexers set a
 * color at each character of the text; here the frame asks for the
 * colors when it draws (Ebuffer.colors).
 *
 * A terminal has eight colors, and bold. They are chosen to be read
 * on a dark background as on a light one, so there is no white and no
 * black.
 *
 *     let move (p : point) ~dx = ...
 *
 *     Highlight_ml:   let  Keyword      move  Def_function
 *     [terminal]:     magenta           blue, bold
 *
 * So there are two tables. The language's table goes from a text to
 * categories; it knows no color and is kept with the language. This
 * one goes from a category to a color; it knows no language, and a
 * configuration may change it. The split comes from codemap
 * (Highlight_code.mli).
 *
 * others:
 * Emacs colors a text by regular expressions that each mode lists
 * (font-lock); efuns colors it by a lexer for each language, written
 * with ocamllex. Editors of today keep a syntax tree that a parser
 * repairs as one types (tree-sitter), or ask the language's compiler,
 * running beside them, what each name is (a language server). The
 * highlighters here are in between: a lexer written by hand, and rules
 * on a token's neighbours, which are enough to tell a function defined
 * from a function called. *)

(* how a category is shown. At first it is [terminal]'s way, which is
 * plain for most categories (a name, an operator); a configuration
 * sets another way (Config_pad). *)
val terminal : Highlight_code.category -> Vt.attrs
val attrs : (Highlight_code.category -> Vt.attrs) ref

(* [mode name lines] makes a major mode whose colors come from the
 * highlighter *)
val mode : string -> (string -> Highlight_code.span list array) -> Efuns.major_mode
