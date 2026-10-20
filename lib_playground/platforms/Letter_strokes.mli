(* Letter_strokes: a run of letters (Playground's Letters) as the
 * strokes of their pen, each a thin rectangle turned to its angle --
 * what a platform draws when it keeps no letter (the PDF writer, the
 * draw device for now), and what a letter it keeps is made of once
 * (Shape_render_software's masks; docs/notes_font.md).
 *
 * A letter is Hershey's (Hershey.mli), or Glyph_unicode's beyond
 * ASCII; its look a pen: a sixteenth of its size wide, a seventh for
 * bold, and its points slanted by a fifth of their height for italic.
 * The rectangles are those Stroke_text.glyph made, moved here from the
 * browser's and the word processor's Stroke_text when their text
 * became a shape of its own (2026-10-20). *)

(* [letter color ~size ~bold ~italic s ~x ~baseline]: [s], one letter,
 * its left at [x] on [baseline] *)
val letter : Playground.color -> size:float -> bold:bool -> italic:bool -> string -> x:float -> baseline:float -> Playground.shape list

(* a run's letters, each at its place *)
val shapes : Playground.color -> Playground.letters -> Playground.shape list
