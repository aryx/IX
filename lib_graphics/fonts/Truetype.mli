(* Truetype reads a TrueType font file: a glyph's outline, a
   character's glyph, and how far the pen moves after each glyph.

   The file is a directory of *tables*, each named by four letters.
   These are the ones a renderer needs:

     head, maxp   the em's size (2048 units, usually), how many glyphs
     loca, glyf   each glyph's place, and its outline
     cmap         a character's glyph number
     hhea, hmtx   each glyph's advance

   A glyph (in "glyf") is made of contours of points, and each point is
   *on* the curve or *off* it:

       on --- on          a line
       on - off - on      a quadratic curve, the off point its control
       on - off - off - on   two curves: between two off points an on
                             point is meant, halfway -- so that a
                             circle is eight points, not sixteen

   The coordinates are steps from the point before, each in one byte,
   in two, or in none (the same as before), and a flag says which. A
   glyph may instead be *composite*: it is made of other glyphs, each
   moved and scaled, such as an "e" and an acute accent.

   "cmap" has several tables, for several worlds: Windows and Unicode
   (platform 3, encoding 1), a font of symbols (3, 0), and the
   Macintosh's own 256 characters (1, 0). Each table is in one of
   several layouts (the usual one, format 4, has runs of characters
   with a shift).

   The instructions are not used. Each glyph carries a program, for a
   small stack machine, that moves its points onto the pixel grid at
   a given size (hinting). It is what made TrueType sharp on the
   screens of 1991, and what a renderer can leave out now that edges
   are smoothed and screens have twice the dots.

   An OpenType font with PostScript outlines is the same file with a
   table "CFF " instead of "glyf" ([cff]; Cff.mli).

   cs-history:
   Apple made it for System 7 (1991); Sampo Kaasila designed it from
   1987. It was an outline format of Apple's own, so as not to pay
   Adobe for Type 1 and its secret hints. Apple licensed it to
   Microsoft, and Windows 3.1 (1992) had it. These were the "font
   wars": Adobe answered by publishing Type 1 (Type1.mli), and they
   ended in 1996 with OpenType, one file for both. The web's fonts
   (@font-face, WOFF) are these files, compressed.

   Every reading starts at the directory (its numbers are big-endian,
   as the Macintosh's processor had them):

     version(4)  how many tables(2)  three numbers to search them(6)
     then a table a line of 16 bytes:
       tag(4)  checksum(4)  offset in the file(4)  length(4)
       "glyf"     ...            00 00 12 A4       00 01 9C 30   (say)

   So a reader goes to a table by its name and skips the tables it does
   not know. That is how the file grows, as with PNG's chunks (Png.mli)
   and an ELF file's sections. "loca" is an index of the same kind
   inside: glyph n's outline is the bytes of "glyf" from loca's entry
   n to its entry n + 1, and a glyph with nothing to draw (the space)
   has two equal entries.

   Where it stands in ix: it reads the fonts a PDF file carries
   (Pdf_font, which also asks [cmap] for a simple font's codes). The
   outline goes to Outline and from there to Fill. The draw device's
   text does not come here, because its font is made of pictures
   (Font).

   References: Apple, TrueType Reference Manual; Microsoft, the
   OpenType specification (the tables head, maxp, loca, glyf, cmap,
   hhea, hmtx). *)
(* ix: copied from libs/fonts/Truetype.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md). Its outline has no depth argument. *)

type t

(* It fails (Failure) on bytes that are not a font file. *)
val of_string : string -> t

(* the em, in the font's units *)
val units : t -> int

val glyphs : t -> int

(* a glyph's outline by its number, in the font's units; it is empty
 * for a glyph that draws nothing *)
val outline : t -> int -> Outline.t

(* a glyph's advance, in the font's units *)
val advance : t -> int -> int

(* [cmap t ~platform ~encoding] is the font's table for that world, if
 * it has one: it gives a character's glyph number, 0 for none *)
val cmap : t -> platform:int -> encoding:int -> (int -> int) option

(* the bytes of its "CFF " table, if its outlines are PostScript's *)
val cff : t -> string option
