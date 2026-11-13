(* Names_ml: what mini-ml's parser says about the names of an OCaml
 * text, for Highlight_ml, which can only guess from the tokens alone.
 * This module is ix's own. The playground's Highlight_ml has a parser
 * of its own for this, Parse_ml, of 1,184 lines; here we ask the
 * compiler's parser instead.
 *
 *     let area (r : rect) =          r: a Parameter, here and where it is used
 *       let w = r.right - r.left in  w: a Local; right, left: a Field
 *       w * height r                 height: neither, left to the guess
 *
 * The tree's expressions and patterns say where they are in the text
 * (Ast's espan and pspan), and a token says where it starts. So the
 * token of a name is known, and no place is guessed. The scopes are
 * OCaml's: a function's parameters are in scope in its body, a let's
 * names after it (and in it too, with rec), and a clause's names in
 * its guard and its body.
 *
 * The text is parsed one item of the program at a time. An item starts
 * at a line that does not start with a space and follows an empty line,
 * as mini-emacs's Ebuffer cuts a text. So the item being typed, which
 * does not parse, is the only one left to the guess. *)

(* [names src] maps a token's start in src (its offset) to what the
 * token is: a Parameter, a Local or a Field. The other tokens are not
 * in the table. *)
val names : string -> (int, Highlight_code.category) Hashtbl.t
