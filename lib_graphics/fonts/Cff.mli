(* Cff reads a CFF font, which is one of Adobe's PostScript fonts made
   compact, and runs the glyph programs it is written in.

   A Type 1 font (Type1.mli) is a PostScript program, in text, and
   ciphered. CFF, the Compact Font Format, is the same font as
   tables:

     a header
     INDEX of names          an INDEX is a count, offsets, and the
     INDEX of dictionaries   things themselves: the format's one
     INDEX of strings        structure
     INDEX of subroutines
     ... and, found from the font's dictionary:
     the glyphs' programs (an INDEX), their names (the "charset"),
     the code of each (the "encoding"), a private dictionary with
     subroutines of its own

   A dictionary is numbers and operators in a byte code (a byte from 32
   to 246 is itself minus 139, and other bytes start longer numbers).
   Names are numbers too: the first 391 are a list every reader knows
   (Glyph_names.cff_strings: "A", "eacute", "fi"...), and the others
   are the file's strings.

   A glyph's program (a "Type 2 charstring") is the code of a stack
   machine:

     100 0 rmoveto   50 hlineto   0 80 30 -20 40 0 rrcurveto   endchar

   Numbers are pushed, then an operator moves the pen by them. It draws
   lines and cubic curves, all as steps from where the pen is. To be
   short, the format has a dozen operators that take fewer numbers
   (hlineto only goes across; hvcurveto draws a curve that starts
   across and ends vertical; some draw several curves after one
   operator). It also has subroutines, shared by the glyphs (the serif
   of every letter is written once). The hints, which say where the
   stems are so as to fit them to the pixels, are stepped over.

   A font for many glyphs (East Asian) is "CID-keyed": its glyphs are
   named by number, it has several private dictionaries, and a table
   says which glyph uses which.

   cs-history:
   Adobe made it in the late 1990s, to hold a Type 1 font in less than
   half the bytes. It is the outline format of OpenType's PostScript
   flavour (.otf) and of PDF's "Type 1C" fonts, which is where most
   CFF fonts are met today.

   References: Adobe Technical Notes #5176, The Compact Font Format
   Specification, and #5177, The Type 2 Charstring Format. *)
(* ix: copied from libs/fonts/Cff.mli in mini-chrome
 * (docs/plans/done/plan_pdf.md) *)

type t

(* It fails (Failure) on bytes that are not a CFF font. *)
val of_string : string -> t

val glyphs : t -> int

(* a glyph's outline by its number, in the font's units (thousandths of
 * an em, unless [matrix] says otherwise) *)
val outline : t -> int -> Outline.t

(* the matrix from the font's units to the em, [a b c d e f]; it is
 * usually 0.001 0 0 0.001 0 0 *)
val matrix : t -> float list

(* the glyph of a code, by the font's own encoding *)
val encoding : t -> int -> int

(* the glyph of a name ("eacute"), in a font that names its glyphs *)
val glyph_of_name : t -> string -> int option

(* whether its glyphs are named by number (CID), and the glyph of a
 * number *)
val is_cid : t -> bool

val glyph_of_cid : t -> int -> int
