(* What a character looks like: Bravo's word was a "look" (Xerox PARC,
 * 1974), and every word processor since has had the same handful.
 *
 * A look is a value with no identity of its own -- two characters are
 * in the same style exactly when their looks are equal -- which is
 * what lets a text keep its styles as *runs* (Rich.mli): a stretch of
 * characters that all look the same is stored once, and a change of
 * look is where one run ends and the next begins.
 *
 * There is no font in it: Stroke_text draws every look with the one
 * face ix has, Hershey's, and a look is how the pen is held (thicker,
 * slanted, a rule under the line).
 *
 * terminology:
 * Look, format, style. Bravo's "look" is what Word's menus call a
 * character format: the properties themselves, as here. A "style" in
 * a word processor came to mean something else, a name for a set of
 * them ("Heading 1") that the text refers to, so that changing the
 * style changes every heading at once: a level of indirection this
 * record does not have, and CSS's class is the same idea. *)

type t = {
  bold : bool;
  italic : bool;
  underline : bool;
  strike : bool;
  (* in the playground's units, the height of an em *)
  size : float;
}

(* the body text: nothing on, at a size a page reads well at *)
val plain : t

(* the looks a toolbar toggles, by name, for the apps and the tests *)
val toggle_bold : t -> t
val toggle_italic : t -> t
val toggle_underline : t -> t
val toggle_strike : t -> t
