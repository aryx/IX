(* mini-troff typesets a document (a manual page, a paper or a book)
 * for a terminal or as a PDF file.
 *
 *   mini-troff tr.1                  the page as text, on the standard output
 *   mini-troff < tr.1
 *   mini-troff -T pdf tr.1 > tr.pdf  its pages, to print or for mini-page
 *   mini-troff -ms names.ms          a paper (ms(6)'s macros)
 *   mini-troff manual.md             a document in Markdown's lines
 *   mini-troff -T md tr.1 > tr.md    a manual page written in them
 *   mini-troff -T pdf Make.nw > Make.pdf   a book: simple LaTeX and
 *                                    noweb's chunks of code
 *
 * It has troff's name and reads what was written for troff, but it is
 * not troff. It knows the macros of a package (Man, Ms), not the
 * requests they were made of. What it does not know, it reports on the
 * standard error with the line; nothing is left out silently. Here is
 * the whole path of a page:
 *
 *   the file --Roff--> lines --Man, Ms (on Fill; Tbl, Pic)--+
 *   the file --Ixdoc (Markdown's lines)---------------------+--> Doc.t
 *   the file --Latex (and Bib: its references)--------------+
 *
 *   Doc.t --Layout--> lines of words, each at its place
 *              --To_text--> the terminal's page
 *              --To_pdf---> the file's pages
 *   Doc.t --Ixdoc--> the document in Markdown's lines
 *
 * Still to come (docs/plans/done/plan_typesetting.md): the equations
 * of the papers.
 *
 * cs-history:
 * Joe Ossanna wrote troff (Bell Labs, 1973) for the Graphic Systems
 * C/A/T, a phototypesetter that flashed letters through a spinning
 * disc of film. It had four fonts mounted at a time, which is why \f
 * takes a digit from 1 to 4. After Ossanna's death in 1977, Brian
 * Kernighan rewrote troff so that it did not depend on one typesetter
 * (ditroff, 1979). With others, he also wrote the programs that come
 * before it in a pipe: eqn (with Lorinda Cherry, 1974), tbl (Mike
 * Lesk, 1975) and pic (1981). Plan 9's troff is that program, with
 * Unicode added. It is the oldest code in the system, and it reads
 * like it.
 *
 * others:
 * TeX (Donald Knuth, 1978 and 1982) breaks a paragraph as a whole, and
 * sets mathematics as no program had done before. LaTeX (Leslie
 * Lamport, 1984) is to TeX what -ms is to troff. groff (James Clark,
 * 1990) is troff written again in C++, and it is what Linux systems
 * have. Typst (2023) is a new language with the same aim. *)

type caps = < Cap.open_in ; Cap.stdin ; Cap.stdout ; Cap.stderr >

(* Words: the page is read as for the PDF file (a page may say one
 * thing to a typesetter and another to a terminal, with .if t and .if
 * n) and written as text. It shows what the file's words are, so that
 * a test can compare them with what a reader of the file finds in it. *)
(* Source: the document is written in the new format (Ixdoc), read as
 * for the PDF file. *)
type way = Text | Pdf | Words | Source

type package = Man | Ms | Md | Tex

(* (When no package is given, the file is in the new format if its
 * name ends with .md or .ixd, or if its first line is a \title. It is
 * LaTeX if the name ends with .tex or .nw. Otherwise it is a manual
 * page if the file has a .TH, and a paper if not.) *)
(* [typeset way package load name source] returns a page's text for a
 * terminal, or a PDF file's bytes, and what was not understood in it,
 * each one as "name:line: what". [load] reads a file that the document
 * names (.so, a picture kept apart, \input); it returns None if the
 * file may not be read. *)
val typeset : way -> package option -> (string -> string option) -> string -> string -> string * string list

val main : < caps ; .. > -> string array -> Exit.t
