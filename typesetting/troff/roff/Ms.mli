(* Ms reads a paper. It reads the macros of ms(6), Plan 9's tmac.s,
 * each one as what it means and not as the troff it was written in.
 *
 *   .TL                       the title: its lines centered, bold
 *   The Use of Name Spaces
 *   .AU                       the authors, .AI where they are
 *   Rob Pike
 *   .AB  ...  .AE             the abstract, set in from both sides
 *   .NH                       a numbered heading: "1. Introduction"
 *   Introduction              (.NH 2: "1.1."); .SH: one with no number
 *   .PP                       a paragraph, its first line indented
 *   .LP                       a paragraph whose first line is not
 *   .IP (1) 5                 a paragraph that hangs from a tag
 *   .RS / .RE                 what is between, further right
 *   .QP                       a quotation, set in from both sides
 *   .DS / .DE                 a display: lines as they are, kept on one
 *   .P1 / .P2                 sheet; a program's text, in its font
 *   .KS / .KE                 what is between, kept on one sheet
 *   .FS / .FE                 a footnote, given in the middle of a
 *                             sentence, written at the sheet's foot
 *   .I word .  (              the word in italic, a dot after it in the
 *                             font there was, a parenthesis before;
 *   .I                        alone: italic from here on, until .R
 *
 * It keeps what tmac.s keeps: the paragraph's indent (\n(PI), the
 * space between two paragraphs (\n(PD), which a paper may set (.nr PD
 * 0), the level of .RS and the indent of each level, and the numbers
 * of the sections. Under the macros, what a paper writes in troff's
 * own requests is handled by Fill.
 *
 * A table (.TS) is read by Tbl, and a picture (.PS) by Pic. Some
 * things are not read yet: an equation (.EQ is skipped, and reported),
 * two columns (.2C gives one column here), and the cover sheets of
 * Bell Labs' memoranda (.TM, .RP).
 *
 * cs-history:
 * Mike Lesk wrote ms (Bell Labs, 1974). It was the first macro package
 * made for others to use: "manuscript" macros for the papers of the
 * Computing Science Research Center, where Unix was being written.
 * Nearly every paper on Unix and on Plan 9 was typed with it. Its idea
 * is the one that LaTeX has made familiar: say what a line is (a
 * title, a heading, a footnote) and let the package choose how it
 * looks. Eric Allman's -me (Berkeley, 1978) and the -mm of Bell Labs'
 * other departments were its rivals at the time. *)

(* reads a paper's text. What was not understood is kept in the
 * Roff.t. *)
val read : Roff.t -> Doc.t
