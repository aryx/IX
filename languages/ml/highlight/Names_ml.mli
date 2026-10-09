(* Names_ml: what mini-ml's parser says of the names of an OCaml text,
 * for Highlight_ml, whose tokens alone guess (ix's own; the
 * playground's Highlight_ml has a parser of its own for this,
 * Parse_ml, 1,184 lines: here the compiler's is asked).
 *
 *     let area (r : rect) =          r: a Parameter, here and where it is used
 *       let w = r.right - r.left in  w: a Local; right, left: a Field
 *       w * height r                 height: neither, left to the guess
 *
 * A tree's expression and its pattern say where they are in the text
 * (Ast's espan and pspan), and a token where it starts: so a name's
 * token is known, and no place is guessed. The scopes are OCaml's: a
 * function's parameters in its body, a let's names after it (in it
 * too, with rec), a clause's in its guard and its body.
 *
 * The text is parsed an item of the program at a time (a line that does
 * not start with a space, after an empty one, starts one: as
 * mini-emacs's Ebuffer cuts a text), so that the item being typed, which
 * does not parse, is alone left to the guess. *)

(* [names src]: a token's start in src (its offset) to what it is: a
 * Parameter, a Local or a Field; nothing for the others *)
val names : string -> (int, Highlight_code.category) Hashtbl.t
