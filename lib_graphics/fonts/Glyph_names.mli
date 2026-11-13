(* Glyph_names has the names of letters: PostScript's names, by which a
   font finds a glyph and a reader knows what a glyph is.

   Before Unicode, a font did not number its glyphs by character: it
   *named* them ("A", "eacute", "fi", "quotedblleft"), and an encoding
   said which name each of the 256 codes of a byte stood for. The same
   font served several encodings, and a document could ask for its
   own. PDF kept this: a simple font's codes are names (Pdf_font.mli).

   This module has:
   - the three encodings a PDF names (Adobe's standard one, Windows'
     and the Macintosh's);
   - CFF's list of 391 names, which a CFF font need not spell out;
   - the part of Adobe's glyph list (from a name to its Unicode
     character) that these encodings and common mathematics need.
   A name that is not in the list may spell its character: "uni0041",
   "u1F600".

   A program made the tables from files of the machine this was
   written on: Adobe's glyph list (glyphlist.txt), the standard
   encoding as dvips has it (8a.enc), and CFF's strings as Ghostscript
   has them. The two other encodings come from the code pages 1252 and
   Mac Roman.

   References: Adobe Glyph List Specification; ISO 32000-1:2008,
   annex D (the encodings). *)
(* ix: copied from libs/fonts/Glyph_names.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md) *)

(* the glyph name of each code in Adobe's standard encoding, "" for none *)
val standard_encoding : string array

(* the character (Unicode) of each code in Windows' encoding and in the
 * Macintosh's, 0 for none *)
val win_ansi : int array

val mac_roman : int array

(* CFF's standard strings, by number *)
val cff_strings : string array

(* the character of a name: "eacute" is 0xE9, "uni0041" is 0x41, and
 * "A.swash" is the character of "A" *)
val unicode : string -> int option

(* the name of a character *)
val name : int -> string option
