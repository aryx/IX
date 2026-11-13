(* Letter_strokes: a run of letters (Playground's Letters) as the
 * strokes of their pen, each stroke a thin rectangle turned to its
 * angle. A platform that keeps no letter draws these strokes (the PDF
 * writer, and the draw device for now); a platform that keeps letters
 * makes each one from them, once (Shape_render_software's masks;
 * docs/notes/notes_font.md).
 *
 * A letter comes from Hershey (Hershey.mli), or from Glyph_unicode
 * beyond ASCII. Its look is a pen's: the pen is a sixteenth of the
 * letter's size wide, or a seventh for bold, and for italic the points
 * are slanted by a fifth of their height.
 * The rectangles are those Stroke_text.glyph made, moved here from the
 * browser's and the word processor's Stroke_text when their text
 * became a shape of its own (2026-10-20). *)

(* [letter color ~size ~bold ~italic s ~x ~baseline]: the strokes of
 * [s], one letter, with its left at [x] on [baseline] *)
val letter : Playground.color -> size:float -> bold:bool -> italic:bool -> string -> x:float -> baseline:float -> Playground.shape list

(* the strokes of a run's letters, each letter at its place *)
val shapes : Playground.color -> Playground.letters -> Playground.shape list
