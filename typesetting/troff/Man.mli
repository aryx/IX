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
 * Also read, being what the pages write between the macros: .br .sp
 * .nf .fi .in .ti .ta .ft .ce. Not read yet: a table, a picture, an
 * equation (.TS, .PS, .EQ: passed over, and said).
 *
 * What a page looks like depends on rules of troff's that no page
 * says and every page counts on. Those found by setting principia's
 * 553 pages beside troff's own output (tests/man.sh), each a line or
 * two here:
 *
 *   - a line's end is a space; two after a sentence (a dot, ? or !,
 *     and a quote or a parenthesis closing after it); one when the
 *     line ended with a blank, which is why "e.g. " is written with
 *     one, and why .B and .I end no sentence (tmac.an writes six
 *     arguments, the blanks between the missing ones at the end);
 *   - a tag has its body on its line if it is shorter than the width
 *     by half a letter (tmac.an's 3 points);
 *   - .PD 0 closes a list up until the next .SH; .ns takes the space
 *     of the next request, unless a line was being filled;
 *   - a tab in a filled line is as wide as it would be from the start
 *     of the line as written, not from where its words end up, and
 *     the line before may end in front of it;
 *   - a terminal has whole columns: 0.75i is 7, and 2.5 columns to the
 *     left of 12.5 is 9.
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
