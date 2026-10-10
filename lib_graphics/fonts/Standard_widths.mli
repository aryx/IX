(* Standard_widths: how wide each letter of Times, Helvetica and
   Courier is -- the fonts a PDF may name without carrying them.

   Thirteen fonts were in the first PostScript printer (Times,
   Helvetica and Courier, each in four styles; Symbol), Zapf Dingbats
   too in those that followed, and a
   PDF file was allowed to name them and say nothing more: not the
   outlines, not even the widths. A reader that has none of them
   (this one draws its own stroke font in their place) still needs
   the widths, or the words overlap: the page's layout was computed
   with them.

   The numbers are Adobe's, from the fonts' metric files (AFM), taken
   by a program for the 228 glyphs they share; Courier's are all 600.
   A font is known by its name: "Arial" is Helvetica's widths (it was
   drawn to match them), anything else Times's.

   cs-history:
   Times and Helvetica were the LaserWriter's (1985), licensed from
   Linotype; their metrics became a fact of printing that everyone
   after had to match -- Arial and Times New Roman at Microsoft,
   URW's Nimbus fonts in Ghostscript, Liberation in a Linux
   distribution: different outlines, the same widths, so that a
   document breaks its lines the same everywhere. *)
(* ix: mini-chrome's libs/fonts/Standard_widths.mli (docs/plans/plan_pdf.md) *)

(* [width font glyph]: the advance of a glyph by its name, in
 * thousandths of an em, in the font of that name ("Times-Bold",
 * "ABCDEF+Helvetica-Oblique", "ArialMT"); none for a glyph these
 * fonts do not have *)
val width : string -> string -> int option
