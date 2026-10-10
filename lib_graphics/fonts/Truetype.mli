(* Truetype: a TrueType font file read -- a glyph's outline, a
   character's glyph, how far the pen moves.

   The file is a directory of *tables*, each named by four letters;
   the ones a renderer needs:

     head, maxp   the em's size (2048 units, usually), how many glyphs
     loca, glyf   each glyph's place, and its outline
     cmap         a character's glyph number
     hhea, hmtx   each glyph's advance

   A glyph (in "glyf") is contours of points, each *on* the curve or
   *off* it:

       on --- on          a line
       on - off - on      a quadratic curve, the off point its control
       on - off - off - on   two curves: between two off points an on
                             point is meant, halfway -- so that a
                             circle is eight points, not sixteen

   The coordinates are steps from the point before, in one byte or
   two or none (the same as before), a flag saying which. A glyph may
   instead be *composite*: other glyphs, each moved and
   scaled -- an "e" and an acute accent.

   "cmap" has several tables, for several worlds: Windows and Unicode
   (platform 3, encoding 1), a font of symbols (3, 0), the Macintosh's
   own 256 characters (1, 0), each in one of several layouts (runs of
   characters with a shift: format 4, the usual).

   Not used: the instructions. Each glyph carries a program, for a
   small stack machine, that moves its points onto the pixel grid at
   a given size (hinting): what made TrueType sharp on the screens of
   1991 and what, with smoothed edges and screens of twice the dots,
   a renderer can leave out.

   An OpenType font with PostScript outlines is the same file with a
   table "CFF " instead of "glyf" ([cff]; Cff.mli).

   cs-history:
   Apple, for System 7 (1991), designed from 1987 by Sampo Kaasila:
   an outline format of Apple's own, so as not to pay Adobe for Type
   1 and its secret hints. Apple licensed it to Microsoft, and
   Windows 3.1 (1992) had it: the "font wars", which Adobe
   answered by publishing Type 1 (Type1.mli) and which ended in 1996
   with OpenType, one file for both. The web's fonts (@font-face,
   WOFF) are these files, compressed.

   The directory, where every reading starts (numbers big-endian, the
   Macintosh's processor's):

     version(4)  how many tables(2)  three numbers to search them(6)
     then a table a line of 16 bytes:
       tag(4)  checksum(4)  offset in the file(4)  length(4)
       "glyf"     ...            00 00 12 A4       00 01 9C 30   (say)

   so a reader goes to a table by its name and skips those it does
   not know: the file's way to grow, as PNG's chunks (Png.mli) and
   an ELF file's sections. "loca" is an index of the same kind
   inside: glyph n's outline is the bytes of "glyf" from loca's
   entry n to its entry n + 1, and a glyph with nothing to draw (the
   space) is two entries that are equal.

   Where it stands in ix: read for the fonts a PDF file carries
   (Pdf_font, which also asks [cmap] for a simple font's codes); the
   outline goes to Outline and from there to Fill. The draw device's
   text does not come here: its font is pictures (Font).

   References: Apple, TrueType Reference Manual; Microsoft, the
   OpenType specification (the tables head, maxp, loca, glyf, cmap,
   hhea, hmtx). *)
(* ix: mini-chrome's libs/fonts/Truetype.mli; outline has no depth to give (docs/plans/plan_pdf.md) *)

type t

(* fails (Failure) on what is no font file *)
val of_string : string -> t

(* the em, in the font's units *)
val units : t -> int

val glyphs : t -> int

(* a glyph's outline by its number, in the font's units; empty for one that draws nothing *)
val outline : t -> int -> Outline.t

(* a glyph's advance, in the font's units *)
val advance : t -> int -> int

(* [cmap t ~platform ~encoding]: the font's table for that world, if
 * it has it: a character's glyph number, 0 for none *)
val cmap : t -> platform:int -> encoding:int -> (int -> int) option

(* the bytes of its "CFF " table, if its outlines are PostScript's *)
val cff : t -> string option
