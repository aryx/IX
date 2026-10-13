(* Ms: a paper read -- the macros of ms(6), Plan 9's tmac.s, each as
 * what it means and not as the troff it was written in.
 *
 *   .TL                       the title: its lines centered, bold
 *   The Use of Name Spaces
 *   .AU                       the authors, .AI where they are
 *   Rob Pike
 *   .AB  ...  .AE             the abstract, set in from both sides
 *   .NH                       a numbered heading: "1. Introduction"
 *   Introduction              (.NH 2: "1.1."); .SH: one with no number
 *   .PP                       a paragraph, its first line indented
 *   .LP                       one that is not
 *   .IP (1) 5                 one that hangs from a tag
 *   .RS / .RE                 what is between, further right
 *   .QP                       a quotation, set in from both sides
 *   .DS / .DE                 a display: lines as they are, kept on one
 *   .P1 / .P2                 sheet; a program's text, in its font
 *   .KS / .KE                 what is between, kept on one sheet
 *   .FS / .FE                 a footnote, said in the middle of a
 *                             sentence, written at the sheet's foot
 *   .I word .  (            the word in italic, a dot after it in the
 *                             font there was, a parenthesis before;
 *   .I                        alone: italic from here on, until .R
 *
 * It keeps what tmac.s keeps: the paragraph's indent (\n(PI), the
 * space between two (\n(PD), which a paper may set (.nr PD 0), the
 * level of .RS and each level's indent, the sections' numbers.
 * Under the macros, what a paper writes of troff's own is Fill's.
 *
 * A table (.TS) is Tbl's, a picture (.PS) Pic's. Not read yet: an
 * equation (.EQ: passed over, and said); two columns (.2C: one here);
 * the cover sheets of Bell Labs' memoranda (.TM, .RP).
 *
 * cs-history:
 * ms is Mike Lesk's (Bell Labs, 1974): the first macro package made
 * for others to use, "manuscript" macros for the papers of the
 * Computing Science Research Center, where Unix was being written;
 * nearly every paper on Unix and on Plan 9 was typed in it. Its idea
 * is the one LaTeX has made familiar: say what a line is (a title, a
 * heading, a footnote) and let the package choose how it looks. Eric
 * Allman's -me (Berkeley, 1978) and the -mm of Bell Labs' other
 * departments are its rivals of the time. *)

(* a paper's text read; what was not understood is the Roff.t's to say *)
val read : Roff.t -> Doc.t
