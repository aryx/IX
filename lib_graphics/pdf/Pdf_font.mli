(* Pdf_font: a font of a PDF file made what a renderer wants -- for
   each code of a string, a shape, a width, and the characters it
   reads as.

   "(Hello) Tj" is five codes, not five letters: what a code draws is
   the font's business, and a PDF font is a dictionary that says it
   in one of four ways.

     simple fonts         one byte a code
       Type 1               the glyph is found by *name*: the code's
                            name in the font's encoding (/Encoding: a
                            standard one, and /Differences from it),
                            then that name's program in the font file
                            (Type1.mli; or Cff.mli if the file is CFF)
       TrueType             by the font file's own table of characters
                            (Truetype.cmap), asked with the code's
                            character, or the code itself in a font of
                            symbols
       Type 3               no font file: each glyph is a little page,
                            drawn by the page's own operators (a
                            [Program]); TeX's bitmap fonts
     composite (Type 0)   two bytes a code: a glyph's number in a
                          TrueType or CFF file, directly (the encoding
                          Identity-H, what a browser and a word
                          processor write)

   The width is not the font file's: the dictionary gives each code's
   (/Widths, /W), in thousandths of the font's size, and the page's
   layout was computed with those.

   What a code reads as (to copy text, to search; to draw it with a
   font of ours) is a third table, /ToUnicode: a small stream of
   "<code> <characters>" pairs and ranges. Without it, the glyph's
   name says (Glyph_names).

   A font file is usually a *subset*: only the glyphs the document
   uses, renamed with six letters and a plus (ABCDEF+Times-Roman).
   A font may also not be in the file at all -- the fourteen that
   every PostScript printer had (Times, Helvetica, Courier...): then
   [glyph] is [Missing], the renderer draws our stroke font, and the
   widths are the standard ones (Standard_widths).

   Not done: composite fonts with a named CMap (the East Asian
   encodings), vertical writing.

   Reference: ISO 32000-1:2008, section 9.6 to 9.10. *)
(* ix: mini-chrome's libs/pdf/Pdf_font.mli (docs/plans/plan_pdf.md) *)

type glyph =
  | Shape of Outline.t (* in an em of 1, y up, the pen starting at (0, 0) *)
  | Program of string (* a Type 3 font's: drawing operators, in the font's own units *)
  | Missing (* no font file: no outline to be had *)

type t = {
  name : string;
  wide : bool; (* codes of two bytes *)
  width : int -> float; (* a code's advance, in an em of 1; negative if not known *)
  glyph : int -> glyph;
  unicode : int -> int list; (* a code's characters; none if not known *)
  matrix : float list; (* a Type 3 font's units to the em *)
  resources : Pdf_object.t; (* and what its programs name *)
}

(* a font dictionary read, its file with it; glyphs are made as asked for, and kept *)
val load : Pdf.t -> Pdf_object.t -> t

(* a /ToUnicode stream's text: each code's characters.
 * "1 beginbfchar <0041> <00660069> endbfchar" says code 0x41 reads "fi" *)
val to_unicode : string -> (int, int list) Hashtbl.t
