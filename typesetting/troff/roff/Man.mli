(* Man: a manual page read -- the macros of man(6), Plan 9's tmac.an,
 * each as what it means and not as the troff it was written in.
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
 * hangs from its tag (.TP 10; it stays for the tags that follow).
 * From them each paragraph has a place, and the tree is made of the
 * places at the end ([Indent] and [Tagged] where the text goes right,
 * closed where it comes back): a page may also move its margin by
 * hand (.in +2), and comes out right the same way.
 *
 * For a typesetter the same, with tmac.an's other numbers: the text
 * 3.6 ems from the margin where 5 letters, 0.4 lines between two
 * paragraphs where one, .L and .B in the font of what is typed where
 * a terminal has quotes.
 *
 * Also read, being what the pages write between the macros: .br .sp
 * .nf .fi .in .ti .ta .ft .ce (Fill's). A table is Tbl's, a picture
 * Pic's. Not read yet: an equation (.EQ: passed over, and said).
 *
 * The rules of troff's own that a page's look depends on are Fill's
 * (Fill.mli lists them). tmac.an's, found the same way, by setting
 * principia's 553 pages beside troff's output (tests/man.sh):
 *
 *   - .B and .I end no sentence: tmac.an writes six arguments, and the
 *     blanks between the missing ones are at the line's end;
 *   - a tag has its body on its line if it is shorter than the width
 *     by half a letter (tmac.an's 3 points);
 *   - .PD 0 closes a list up until the next .SH.
 *
 * Where troff's output is an accident (a heading lost, a macro's own
 * request printed: docs/plans/bugs/goken.md, 37 and 38), this has
 * what the page's author wrote.
 *
 * cs-history:
 * The manual is as old as Unix: the first edition's pages, of
 * November 1971, already had NAME, SYNOPSIS, DESCRIPTION, FILES, SEE
 * ALSO, DIAGNOSTICS and BUGS, typed with roff's own requests. The
 * macros came with the seventh edition (1979), -man, and have been
 * the format of a Unix page since; Plan 9's are those, with .EX and
 * .L added and bold replaced by the font of what is typed.
 *
 * others:
 * BSD's mdoc (1990) names what a word is (.Fl a flag, .Ar an
 * argument) where man names its font. mandoc (Kristaps Dzonsons,
 * 2008) reads both as this module does, into a tree, with no troff
 * under it. *)

(* a page's text read; what was not understood is the Roff.t's to say
 * ([Roff.complaints]) *)
val read : Roff.t -> Doc.t
