(* Text drawn from Hershey's own strokes, in a look. This is how the two
 * word processors here get bold, italic, underline and strike out of a
 * playground whose [words] knows only a colour and a string.
 *
 * A Hershey glyph (lib_graphics/software/Hershey, 1967) is a few pen
 * strokes, so drawing one ourselves means drawing its strokes, each a
 * thin rectangle. A look is then a change to the *pen*, not a second font:
 *
 *   bold       a thicker pen (Hershey's own duplex and triplex faces
 *              are the same letters drawn with more strokes, which was
 *              the plotter's way to be bold)
 *   italic     the points of the strokes are sheared right as they go
 *              up, by a fifth of their height. This is a slant, which
 *              is what an oblique face is (a true italic is drawn
 *              differently)
 *   underline  a rule below the baseline; strike is a rule through the
 *              middle, as a typewriter's backspace-and-overstrike did
 *
 * Because the same glyph data gives both the widths ([metrics]) and
 * the strokes, what is laid out is exactly what is drawn. The caret
 * goes between two letters where they really meet, which the rest of
 * the toolkit, measuring with an average width, could not promise.
 *
 * Next to the Playground's own [words] (Playground.mli), which also
 * draws text:
 *
 *                 Playground.words            Stroke_text.run
 *   takes         a colour and a string       a colour, a look, the
 *                                             letters and their places
 *   gives         one shape, which the        one shape, Playground's
 *                 platform draws              Letters: the platform
 *                                             draws each letter's
 *                                             strokes (Letter_strokes)
 *                                             once, then copies it
 *   the letters   the platform's              Hershey's on every
 *                                             platform, so a page is
 *                                             laid out the same on all
 *   looks         none; [scale] for a size    bold, italic, underline,
 *                                             strike, any size
 *   placed        centred on a point          by left edge and baseline
 *   width         not known to the program    [metrics], exact
 *
 * A word wrapped at the right place needs the last three, so a page's
 * text is drawn here: Browser_text asks [metrics] for the layout, and
 * Browser_draw asks [run] for the screen. (Until 2026-10-20, [glyph]
 * gave a letter's strokes as thin rectangles, and every platform drew
 * them all again at each frame: see docs/notes/notes_font.md.)
 *
 * This is the browser's copy of the office apps' Stroke_text, with the
 * letters beyond ASCII (Glyph_unicode).
 *
 * cs-history:
 * These are a plotter's letters. Allen V. Hershey drew them at the
 * Naval Weapons Laboratory in the 1960s (his report is of 1967) for
 * machines that could only move a pen or a beam from point to point:
 * there was no curve and no filled shape, and a letter was a list of
 * short straight strokes. Being a government's work, they were free to
 * copy, and for decades they were the letters of programs that had no
 * font to rely on: plotters, oscilloscope displays, CAD, engraving
 * machines. The same reason holds here: they are a few thousand
 * numbers, with no font file to read and no rasterizer of outlines to
 * write.
 *
 * modern:
 * A font today (TrueType, 1991, and PostScript's Type 1 before it) is
 * made of outlines, not strokes. Each letter is the closed curves of
 * its edge, filled, with hints to fit small sizes to the pixels, and
 * its bold is a second set of outlines drawn by the designer. Knuth's
 * Metafont (1979) is what kept the stroke and its thicker pen: its
 * letters are described as a pen's path, and the weight is a
 * parameter. *)

(* the width of a character in a look: Hershey's width, scaled to the
 * look's size *)
val metrics : Style.t -> string -> float

(* [run color look letters ~baseline]: the letters in [look], each with
 * its left edge at its x, on [baseline], in the playground's
 * coordinates (y up). They make one shape, and the underline and the
 * strike are rules under and through them all *)
val run : Playground.color -> Style.t -> (float * string) list -> baseline:float -> Playground.shape list
