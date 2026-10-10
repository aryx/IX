(* Cff: a CFF font read -- Adobe's PostScript fonts made compact, and
   the glyph programs they are written in.

   A Type 1 font (Type1.mli) is a PostScript program, in text,
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

   A dictionary is numbers and operators in a byte code (a byte 32 to
   246 is itself less 139; other bytes start longer numbers). Names
   are numbers too: the first 391 are a list every reader knows
   (Glyph_names.cff_strings: "A", "eacute", "fi"...), the others are
   the file's strings.

   A glyph's program (a "Type 2 charstring") is a stack machine's:

     100 0 rmoveto   50 hlineto   0 80 30 -20 40 0 rrcurveto   endchar

   numbers pushed, an operator that moves the pen by them; lines and
   cubic curves, all as steps from where the pen is. To be short it
   has a dozen operators that say less (hlineto: across only;
   hvcurveto: a curve that starts across and ends up; several curves
   after one operator) and subroutines, shared by the glyphs (the
   serif of every letter, once). The hints -- where the stems are, to
   fit them to the pixels -- are stepped over.

   A font for many glyphs (East Asian) is "CID-keyed": glyphs named
   by number, several private dictionaries, a table saying which
   glyph uses which.

   cs-history:
   Adobe, in the late 1990s: a Type 1 font in less than half the
   bytes. It is the outline format of OpenType's PostScript flavour (.otf) and
   of PDF's "Type 1C" fonts, which is where most are met today.

   References: Adobe Technical Notes #5176, The Compact Font Format
   Specification, and #5177, The Type 2 Charstring Format. *)
(* ix: mini-chrome's libs/fonts/Cff.mli (docs/plans/plan_pdf.md) *)

type t

(* fails (Failure) on what is no CFF *)
val of_string : string -> t

val glyphs : t -> int

(* a glyph's outline by its number, in the font's units (thousandths of an em, unless [matrix] says) *)
val outline : t -> int -> Outline.t

(* the font's units to the em: [a b c d e f], 0.001 0 0 0.001 0 0 usually *)
val matrix : t -> float list

(* a code's glyph, by the font's own encoding *)
val encoding : t -> int -> int

(* a name's glyph ("eacute"), in a font that names them *)
val glyph_of_name : t -> string -> int option

(* whether its glyphs are named by number (CID); and a number's glyph *)
val is_cid : t -> bool

val glyph_of_cid : t -> int -> int
