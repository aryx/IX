(* Type1: a PostScript Type 1 font read -- the outline fonts of the
   LaserWriter, ciphered twice.

   The file is a PostScript program in two parts:

     %!PS-AdobeFont-1.0: CMR10        plain: the name, the em
     /FontMatrix [0.001 0 0 0.001 0 0] readonly def
     /Encoding 256 array ... dup 65 /A put ...     a code's glyph
     currentfile eexec
     <the rest, ciphered>             the glyphs' programs, by name:
                                      /A 73 RD <73 bytes> ND
                                      and subroutines they share

   The cipher is a toy: each byte is added to a running key of 16
   bits (start 55665), and the first four bytes are noise. Inside,
   each glyph's program is ciphered again the same way (start 4330).
   It was there to keep the format Adobe's, not to keep a secret.

   A glyph's program (a "charstring") is a stack machine's, as CFF's
   after it (Cff.mli): numbers, then an operator.

     hsbw         the glyph's left edge and its width: always first
     rmoveto rlineto rrcurveto closepath   the outline, in steps
     hstem vstem  hints: where the stems are (stepped over here)
     callsubr     a shared piece
     seac         an accented letter: two other glyphs, the accent
                  moved -- "eacute" is "e" and "acute"
     callothersubr   a call out to PostScript: used for *flex*, a
                  shallow curve written as seven moves so that a
                  small size can draw it as a line

   and the glyphs are found by name, never by number.

   cs-history:
   Adobe, 1984, with PostScript and Apple's LaserWriter (1985): the
   fonts that made desktop publishing. Adobe sold the fonts and kept
   the format and its hinting secret; when Apple and Microsoft
   answered with TrueType (Truetype.mli), Adobe published it (Adobe
   Type 1 Font Format, 1990, the "black book"). Computer Modern as
   every TeX document carries it is Type 1: these fonts are still
   what a PDF from pdfTeX embeds.

   Reference: Adobe Systems, Adobe Type 1 Font Format, Addison-Wesley,
   1990. *)
(* ix: mini-chrome's libs/fonts/Type1.mli; of_string's clear is said (0: not known), where it was optional; glyph has no depth to give (docs/plans/plan_pdf.md) *)

type t

(* [of_string ~clear bytes]: a font's file (a PDF's /FontFile, or a
 * .pfb with its segments); its first [clear] bytes are the plain
 * part, found by "eexec" if it is 0 *)
val of_string : clear:int -> string -> t

(* each code's glyph name, "" for none *)
val encoding : t -> string array

(* the font's units to the em *)
val matrix : t -> float list

val has : t -> string -> bool

(* a glyph by its name: its outline in the font's units, and its width *)
val glyph : t -> string -> Outline.t * float

(* Adobe's cipher undone: [decrypt key noise bytes], the first [noise]
 * bytes dropped. 55665 and 4 for the file's second part, 4330 and
 * (usually) 4 for a glyph's program *)
val decrypt : int -> int -> string -> string
