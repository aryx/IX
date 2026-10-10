(* Text drawn from Hershey's own strokes, in a look -- how the two word
 * processors here get bold, italic, underline and strike out of a
 * playground whose [words] knows only a colour and a string.
 *
 * A Hershey glyph (graphics/font, 1967) is a few pen strokes, so
 * drawing one ourselves is drawing its strokes -- each a thin
 * rectangle -- and a look is then a change to the *pen*, not a second
 * font:
 *
 *   bold       a thicker pen (Hershey's own duplex and triplex faces
 *              are the same letters drawn with more strokes: the
 *              plotter's way to be bold)
 *   italic     the strokes' points sheared right as they go up, a
 *              fifth of their height -- a slant, which is what an
 *              oblique face is (a true italic is drawn differently)
 *   underline  a rule below the baseline, and strike one through the
 *              middle, as a typewriter's backspace-and-overstrike did
 *
 * and because the same glyph data gives the widths ([metrics]) and the
 * strokes, what is laid out is exactly what is drawn: the caret goes
 * between two letters where they really meet, which is what the rest
 * of the toolkit, measuring with an average width, could not promise.
 *
 * Shared by the office apps (TinyBravo and TinyWord first) and
 * TinyMosaic.
 *
 * The numbers, for a look of size s: the pen is s / 16 wide, bold
 * s / 7; italic moves a point right by a fifth of its height above
 * the baseline; the underline is 0.18 s under the baseline, the
 * strike 0.25 s over it. A stroke is drawn a pen's width longer than
 * it is, so that two strokes meeting at a corner overlap and leave
 * no notch. Hershey's face has the printable ASCII characters: any
 * other is drawn as its question mark.
 *
 * Where it stands in ix (those three programs are the playground's):
 *
 *   Hershey          a glyph's strokes and its two sides    lib_graphics
 *   [metrics]        its width in a look  ->  Page.layout, which
 *                    places every glyph and knows no font
 *   [glyph]          a placed glyph  ->  thin rectangles, turned
 *                    (Office_view for a document's text and bands,
 *                    Part_text for a text box, Figure_shapes for a
 *                    drawing's text)
 *   the platform     the rectangles filled; or written to a PDF
 *                    (Shape_render_pdf)
 *
 * A page of text is so some thousands of rectangles, which a small
 * machine feels: Office_view keeps a page's letters as one group while the
 * page is the same. And the words of an exported PDF are drawings
 * of letters, not text: they cannot be searched or copied.
 *
 * others:
 * A real font is outlines, not strokes: each letter the closed
 * curves round its ink, filled (Truetype, Type1, Cff, in
 * lib_graphics, read them for the PDF viewer). There bold is another
 * face, drawn by a person, with its own widths, and italic a third.
 * What this module does is what a browser does when a face is
 * missing, and typographers have names for it, faux bold and
 * oblique: the outline thickened, the letters slanted. It is right
 * for a stroke font, whose letters have no thick and thin to spoil.
 *
 * References: Hershey.mli for the font and A. V. Hershey's report
 * (1967). The playground's apps/office/stroke_text. *)

(* the width of a character in a look: Hershey's, scaled to its size *)
val metrics : Page.metrics

(* [glyph color look ch ~x ~baseline]: [ch] drawn in [look], its left
 * edge at [x] and its baseline at [baseline], in the playground's
 * coordinates (y up) *)
val glyph :
  Playground.color -> Style.t -> string -> x:float -> baseline:float -> Playground.shape list
