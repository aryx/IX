(* Colors: a language's highlighter gives a text's pieces their
 * categories (lib_code's Highlight_code: a keyword, a comment, a
 * function defined); here the color of each category, and a major
 * mode made of a highlighter. efuns' Highlight and its lexers set a
 * color at each character of the text; here the frame asks when it
 * draws (Ebuffer.colors).
 *
 * A terminal's colors: eight, and bold. Chosen to be read on a dark
 * background as on a light one: no white, no black.
 *
 *     let move (p : point) ~dx = ...
 *
 *     Highlight_ml:   let  Keyword      move  Def_function
 *     [terminal]:     magenta           blue, bold
 *
 * Two tables, then: the language's, from a text to categories, which
 * knows no color and is kept with the language; and this one, from a
 * category to a color, which knows no language and is a
 * configuration's to change. The split is codemap's
 * (Highlight_code.mli).
 *
 * others:
 * Emacs colors a text by regular expressions that each mode lists
 * (font-lock); efuns by a lexer a language, written with ocamllex.
 * Editors of today keep a syntax tree that a parser repairs as one
 * types (tree-sitter), or ask the language's compiler, running
 * beside them, what each name is (a language server). The
 * highlighters here are in between: a lexer by hand and rules on a
 * token's neighbours, enough to tell a function defined from a
 * function called. *)

(* how a category is shown: [terminal]'s way at first, plain for most
 * (a name, an operator); a configuration sets another (Config_pad) *)
val terminal : Highlight_code.category -> Vt.attrs
val attrs : (Highlight_code.category -> Vt.attrs) ref

(* [mode name lines]: a major mode whose colors are the highlighter's *)
val mode : string -> (string -> Highlight_code.span list array) -> Efuns.major_mode
