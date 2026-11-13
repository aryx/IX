(* Standard_widths says how wide each letter of Times, Helvetica and
   Courier is. These are the fonts a PDF may name without carrying them.

   Thirteen fonts were in the first PostScript printer (Times,
   Helvetica and Courier, each in four styles, and Symbol), and Zapf
   Dingbats was in those that followed too. A PDF file was allowed to
   name them and say nothing more: not the outlines, not even the
   widths. A reader that has none of them (this one draws its own
   stroke font in their place) still needs the widths, or the words
   overlap, because the page's layout was computed with them.

   The numbers are Adobe's, from the fonts' metric files (AFM). A
   program took them for the 228 glyphs the fonts share, and Courier's
   are all 600. A font is known by its name: "Arial" gets Helvetica's
   widths (it was drawn to match them), and a name that is none of
   these gets Times's.

   cs-history:
   Times and Helvetica were in the LaserWriter (1985), licensed from
   Linotype. Their metrics became a fact of printing that everyone
   after had to match: Arial and Times New Roman at Microsoft, URW's
   Nimbus fonts in Ghostscript, Liberation in a Linux distribution.
   They have different outlines and the same widths, so that a
   document breaks its lines the same way everywhere. *)
(* ix: copied from libs/fonts/Standard_widths.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md) *)

(* [width font glyph] is the advance of a glyph, given by its name, in
 * thousandths of an em, in the font of that name ("Times-Bold",
 * "ABCDEF+Helvetica-Oblique", "ArialMT"). It is None for a glyph these
 * fonts do not have; a Courier font gives 600 for every glyph, since
 * all of its glyphs have that width. *)
val width : string -> string -> int option
