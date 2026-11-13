(* Type1 reads a PostScript Type 1 font. These are the outline fonts of
   the LaserWriter, and they are ciphered twice.

   The file is a PostScript program in two parts:

     %!PS-AdobeFont-1.0: CMR10        plain: the name, the em
     /FontMatrix [0.001 0 0 0.001 0 0] readonly def
     /Encoding 256 array ... dup 65 /A put ...     a code's glyph
     currentfile eexec
     <the rest, ciphered>             the glyphs' programs, by name:
                                      /A 73 RD <73 bytes> ND
                                      and subroutines they share

   The cipher is a toy: each byte is added to a running key of 16
   bits (which starts at 55665), and the first four bytes are noise.
   Inside, each glyph's program is ciphered again the same way (with a
   key starting at 4330). The cipher was there to keep the format
   Adobe's, not to keep a secret.

   A glyph's program (a "charstring") is the code of a stack machine,
   as in CFF after it (Cff.mli): numbers, then an operator.

     hsbw         the glyph's left edge and its width: always first
     rmoveto rlineto rrcurveto closepath   the outline, in steps
     hstem vstem  hints: where the stems are (stepped over here)
     callsubr     a shared piece
     seac         an accented letter: two other glyphs, the accent
                  moved -- "eacute" is "e" and "acute"
     callothersubr   a call out to PostScript: used for *flex*, a
                  shallow curve written as seven moves so that a
                  small size can draw it as a line

   The glyphs are found by name, never by number.

   cs-history:
   Adobe made the format in 1984, along with PostScript, and it came
   with Apple's LaserWriter (1985). These are the fonts that made
   desktop publishing. Adobe sold the fonts and kept the format and its
   hinting secret. When Apple and Microsoft answered with TrueType
   (Truetype.mli), Adobe published it (Adobe Type 1 Font Format, 1990,
   the "black book"). Computer Modern, as every TeX document carries
   it, is in Type 1: these fonts are still what a PDF from pdfTeX
   embeds.

   Reference: Adobe Systems, Adobe Type 1 Font Format, Addison-Wesley,
   1990. *)
(* ix: copied from libs/fonts/Type1.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md). The clear argument of of_string must
 * be given (0 when it is not known), where it was optional, and glyph
 * has no depth argument. *)

type t

(* [of_string ~clear bytes] reads a font's file (a PDF's /FontFile, or
 * a .pfb with its segments). Its first [clear] bytes are the plain
 * part; when [clear] is 0, the plain part is found by "eexec". *)
val of_string : clear:int -> string -> t

(* the glyph name of each code, "" for none *)
val encoding : t -> string array

(* the matrix from the font's units to the em *)
val matrix : t -> float list

val has : t -> string -> bool

(* a glyph by its name: its outline in the font's units, and its width *)
val glyph : t -> string -> Outline.t * float

(* [decrypt key noise bytes] undoes Adobe's cipher and drops the first
 * [noise] bytes. The file's second part uses 55665 and 4, and a
 * glyph's program uses 4330 and (usually) 4. *)
val decrypt : int -> int -> string -> string
