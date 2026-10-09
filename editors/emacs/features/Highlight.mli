(* Colors: a language's highlighter gives a text's pieces their
 * categories (lib_code's Highlight_code: a keyword, a comment, a
 * function defined); here the color of each category, and a major
 * mode made of a highlighter. efuns' Highlight and its lexers set a
 * color at each character of the text; here the frame asks when it
 * draws (Ebuffer.colors).
 *
 * A terminal's colors: eight, and bold. Chosen to be read on a dark
 * background as on a light one: no white, no black. *)

(* how a category is shown: [terminal]'s way at first, plain for most
 * (a name, an operator); a configuration sets another (Config_pad) *)
val terminal : Highlight_code.category -> Vt.attrs
val attrs : (Highlight_code.category -> Vt.attrs) ref

(* [mode name lines]: a major mode whose colors are the highlighter's *)
val mode : string -> (string -> Highlight_code.span list array) -> Efuns.major_mode
