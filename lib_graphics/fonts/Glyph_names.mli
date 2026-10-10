(* Glyph_names: the names of letters -- PostScript's, by which a font
   finds a glyph and a reader knows what a glyph is.

   Before Unicode, a font did not number its glyphs by character: it
   *named* them -- "A", "eacute", "fi", "quotedblleft" -- and an
   encoding said which name each of the 256 codes of a byte was. The
   same font served several encodings; a document could ask for its
   own. PDF kept this: a simple font's codes are names (Pdf_font.mli).

   Here: the three encodings a PDF names (Adobe's standard one,
   Windows' and the Macintosh's), CFF's list of 391 names that a font
   need not spell, and the part of Adobe's glyph list (name to
   Unicode) that these and common mathematics need. A name not in the
   list may spell its character: "uni0041", "u1F600".

   The tables were made by a program from files of the machine this
   was written on: Adobe's glyph list (glyphlist.txt), the standard
   encoding as dvips has it (8a.enc), CFF's strings as Ghostscript
   has them; the two others from the code pages 1252 and Mac Roman.

   References: Adobe Glyph List Specification; ISO 32000-1:2008,
   annex D (the encodings). *)
(* ix: mini-chrome's libs/fonts/Glyph_names.mli (docs/plans/plan_pdf.md) *)

(* a code's glyph name in Adobe's standard encoding, "" for none *)
val standard_encoding : string array

(* a code's character (Unicode) in Windows' encoding and the Macintosh's, 0 for none *)
val win_ansi : int array

val mac_roman : int array

(* CFF's standard strings, by number *)
val cff_strings : string array

(* a name's character: "eacute" is 0xE9; "uni0041", 0x41; "A.swash", "A"'s *)
val unicode : string -> int option

(* a character's name *)
val name : int -> string option
