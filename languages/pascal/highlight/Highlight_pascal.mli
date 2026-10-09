(* Highlight_pascal: a Pascal file's text given its categories
 * (Highlight_code's, shared by every language), the colour an editor
 * draws it in. Written for ix, as the playground's highlighters, from
 * the words alone:
 *
 *     program Queens;                 program: Keyword, Queens: Def_function
 *     var n : integer;                var: Keyword, integer: Type
 *     procedure Try(c : integer);     Try: Def_function
 *     begin if c > 8 then ... end;    if, then: Keyword_control
 *     { a comment }  'a string'  42
 *
 * A capital and a small letter are the same, as in Pascal. Nothing
 * fails: a comment or a string not closed goes to the text's end (a
 * string: its line's). *)

val lines : string -> Highlight_code.span list array
