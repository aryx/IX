(* Pdf_font turns a font of a PDF file into what a renderer wants: for
   each code of a string, a shape, a width, and the characters that
   the code reads as.

   "(Hello) Tj" is five codes, not five letters. What a code draws is
   the font's business, and a PDF font is a dictionary that says it in
   one of four ways.

     simple fonts         have one byte a code
       Type 1               The glyph is found by *name*: first the
                            code's name in the font's encoding
                            (/Encoding, a standard one, and /Differences
                            from it), then that name's program in the
                            font file (Type1.mli, or Cff.mli if the
                            file is CFF).
       TrueType             The glyph is found by the font file's own
                            table of characters (Truetype.cmap), asked
                            with the code's character, or with the code
                            itself in a font of symbols.
       Type 3               There is no font file: each glyph is a
                            little page, drawn by the page's own
                            operators (a [Program]). TeX's bitmap fonts
                            are of this type.
     composite (Type 0)   has two bytes a code, which is a glyph's
                          number in a TrueType or CFF file, directly.
                          This is the encoding Identity-H, which a
                          browser and a word processor write.

   The width is not the font file's. The dictionary gives each code's
   width (/Widths, /W), in thousandths of the font's size, and the
   page's layout was computed with those.

   What a code reads as (to copy text or to search, or to draw it with
   a font of ours) is given by a third table, /ToUnicode, which is a
   small stream of "<code> <characters>" pairs and ranges. Without it,
   the glyph's name says what it reads as (Glyph_names).

   A font file is usually a *subset*: it has only the glyphs that the
   document uses, and it is renamed with six letters and a plus
   (ABCDEF+Times-Roman). A font may also not be in the file at all,
   when it is one of the fourteen that PostScript printers came to
   have (Times, Helvetica, Courier...). Then [glyph] is [Missing], the
   renderer draws our stroke font, and the widths are the standard
   ones (Standard_widths).

   Not done: composite fonts with a named CMap (the East Asian
   encodings), and vertical writing.

   Reference: ISO 32000-1:2008, section 9.6 to 9.10. *)
(* ix: from mini-chrome's libs/pdf/Pdf_font.mli
 * (docs/plans/done/plan_pdf.md) *)

type glyph =
  | Shape of Outline.t (* in an em of 1, y up, the pen starting at (0, 0) *)
  | Program of string (* a Type 3 font's glyph: drawing operators, in the font's own units *)
  | Missing (* there is no font file, so no outline can be had *)

type t = {
  name : string;
  wide : bool; (* codes of two bytes *)
  width : int -> float; (* a code's advance, in an em of 1; negative if not known *)
  glyph : int -> glyph;
  unicode : int -> int list; (* a code's characters; none if not known *)
  matrix : float list; (* a Type 3 font's units to the em *)
  resources : Pdf_object.t; (* a Type 3 font's resources, which its programs name *)
}

(* reads a font dictionary, and its file with it. The glyphs are made
 * when they are asked for, and kept *)
val load : Pdf.t -> Pdf_object.t -> t

(* reads a /ToUnicode stream's text into each code's characters.
 * "1 beginbfchar <0041> <00660069> endbfchar" says code 0x41 reads "fi" *)
val to_unicode : string -> (int, int list) Hashtbl.t
