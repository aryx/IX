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
 * Next to the Playground's own [words] (Playground.mli), which also
 * draws text:
 *
 *                 Playground.words            Stroke_text.glyph
 *   takes         a colour and a string       a colour, a look, one
 *                                             character
 *   gives         one shape, the platform's   the letter's strokes as
 *                 to draw                     shapes: thin rectangles
 *   the letters   the platform's              Hershey's on every
 *                                             platform: a page is laid
 *                                             out the same on all
 *   looks         none; [scale] for a size    bold, italic, underline,
 *                                             strike, any size
 *   placed        centred on a point          left edge and baseline
 *   width         not known to the program    [metrics], exact
 *
 * A word wrapped at the right place needs the last three, so a page's
 * text is drawn here: Browser_text asks [metrics] for the layout and
 * Browser_draw [glyph] for the screen.
 *
 * Shared by the office apps (TinyBravo and TinyWord first) and
 * TinyMosaic.
 *
 * cs-history:
 * A plotter's letters. Allen V. Hershey drew them at the Naval
 * Weapons Laboratory in the 1960s (his report is of 1967) for
 * machines that could only move a pen or a beam from point to point:
 * no curve, no filled shape, a letter a list of short straight
 * strokes. Being a government's work they were free to copy, and
 * were for decades the letters of programs that had no font to rely
 * on: plotters, oscilloscope displays, CAD, engraving machines. The
 * same reason holds here: a few thousand numbers, no font file to
 * read and no rasterizer of outlines to write.
 *
 * modern:
 * A font today (TrueType, 1991; PostScript's Type 1 before it) is
 * outlines, not strokes: each letter the closed curves of its edge,
 * filled, with hints to fit small sizes to the pixels, and its bold
 * a second set of outlines drawn by the designer. A thicker pen is
 * what Knuth's Metafont (1979) kept of the stroke: letters described
 * as a pen's path, the weight a parameter. *)

(* the width of a character in a look: Hershey's, scaled to its size *)
val metrics : Style.t -> string -> float

(* [glyph color look ch ~x ~baseline]: [ch] drawn in [look], its left
 * edge at [x] and its baseline at [baseline], in the playground's
 * coordinates (y up) *)
val glyph :
  Playground.color -> Style.t -> string -> x:float -> baseline:float -> Playground.shape list
