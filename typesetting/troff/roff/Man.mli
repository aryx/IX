(* Man reads a manual page. It reads the macros of man(6), Plan 9's
 * tmac.an, each one as what it means and not as the troff it was
 * written in.
 *
 *   .TH TR 1                    header "TR(1)"
 *   .SH NAME                    Heading 1 "NAME"
 *   tr \- translate characters  Para "tr - translate characters"
 *   .SH DESCRIPTION
 *   .PP                         Space 1, a new paragraph
 *   .TP                         a paragraph that hangs from its tag,
 *   .B -c                       the next line: Tagged "-c"
 *   Complement
 *   .IR string1 :               fonts in turn, no space between
 *   .RS / .RE                   what is between, further right
 *   .EX / .EE                   lines as they are (an example)
 *
 * The package keeps two numbers, as tmac.an does: how far right the
 * text is (its .RS), and how far right of that a paragraph's body
 * hangs from its tag (.TP 10, which stays for the tags that follow).
 * From them each paragraph gets a place, and the tree is made from the
 * places at the end: an [Indent] or a [Tagged] where the text goes
 * right, closed where it comes back. So a page may also move its
 * margin by hand (.in +2), and it comes out right in the same way.
 *
 * It is the same for a typesetter, with tmac.an's other numbers. The
 * text is 3.6 ems from the margin instead of 5 letters, there are 0.4
 * lines between two paragraphs instead of one, and .L and .B are set
 * in the font of what is typed where a terminal shows quotes.
 *
 * Man also reads what the pages write between the macros: .br .sp .nf
 * .fi .in .ti .ta .ft .ce (these are Fill's). A table is read by Tbl,
 * and a picture by Pic. An equation is not read yet (.EQ is skipped,
 * and reported).
 *
 * The rules of troff's own that the look of a page depends on are in
 * Fill (Fill.mli lists them). Here are tmac.an's, found in the same
 * way, by setting principia's 553 pages beside troff's output
 * (tests/man.sh):
 *
 *   - .B and .I end no sentence, because tmac.an writes six arguments,
 *     and the blanks between the missing ones are at the line's end;
 *   - a tag's body starts on the tag's line if the tag is shorter
 *     than the width by at least half a letter (tmac.an's 3 points);
 *   - .PD 0 closes a list up until the next .SH.
 *
 * Where troff's output is an accident (a heading lost, or a macro's own
 * request printed; see docs/plans/bugs/goken.md, 37 and 38), this
 * module gives what the page's author wrote.
 *
 * cs-history:
 * The manual is as old as Unix. The first edition's pages, of November
 * 1971, already had NAME, SYNOPSIS, DESCRIPTION, FILES, SEE ALSO,
 * DIAGNOSTICS and BUGS, typed with roff's own requests. The macros,
 * -man, came with the seventh edition (1979), and they have been the
 * format of a Unix page since then. Plan 9's macros are those, with
 * .EX and .L added, and with bold replaced by the font of what is
 * typed.
 *
 * others:
 * BSD's mdoc (1990) names what a word is (.Fl for a flag, .Ar for an
 * argument) where man names its font. mandoc (Kristaps Dzonsons,
 * 2008) reads both into a tree, as this module does, with no troff
 * under it. *)

(* reads a page's text. What was not understood is kept in the Roff.t
 * ([Roff.complaints]). *)
val read : Roff.t -> Doc.t
