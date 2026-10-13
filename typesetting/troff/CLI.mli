(* mini-troff: a document typeset -- a manual page, a paper or a book,
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
 * not troff: the macros of a package (Man, Ms) are what it
 * knows, not the requests they were made of, and what it does not
 * know it says, with the line, on the standard error; nothing is
 * left out in silence. The whole way of a page:
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
 * To come (docs/plans/plan_typesetting.md): the papers'
 * equations.
 *
 * cs-history:
 * troff is Joe Ossanna's (Bell Labs, 1973), for the Graphic Systems
 * C/A/T, a phototypesetter that flashed letters through a spinning
 * disc of film: four fonts mounted at a time, which is why \f takes a
 * digit from 1 to 4. After his death in 1977 Brian Kernighan rewrote
 * it not to know its typesetter (ditroff, 1979), and wrote with
 * others the programs that go before it in a pipe: eqn (with Lorinda
 * Cherry, 1974), tbl (Mike Lesk, 1975), pic (1981). Plan 9's troff
 * is that program, with Unicode; it is the oldest code in the system,
 * and reads like it.
 *
 * others:
 * TeX (Donald Knuth, 1978 and 1982) breaks a paragraph as a whole and
 * sets mathematics as no program had; LaTeX (Leslie Lamport, 1984)
 * is to it what -ms is to troff. groff (James Clark, 1990) is troff
 * again, in C++, and what a Linux has. Typst (2023) is a new language
 * with the same aim. *)

type caps = < Cap.open_in ; Cap.stdin ; Cap.stdout ; Cap.stderr >

(* Words: the page read as for the PDF file (a page may say one thing
 * to a typesetter and another to a terminal, .if t and .if n) and
 * written as text: what the file's words are, for a test to compare
 * with what a reader of the file finds in it *)
(* Source: the document written in the new format (Ixdoc), read as
 * for the PDF file *)
type way = Text | Pdf | Words | Source

(* [typeset way name source]: a page's text for a terminal, or a PDF
 * file's bytes, and what was not understood in it, each "name:line:
 * what" *)
type package = Man | Ms | Md | Tex

(* (no package said: the new format if the file's name ends with .md
 * or .ixd, LaTeX if with .tex or .nw; else a manual page if the file
 * has a .TH, else a paper) *)
(* [typeset way package load name source]; [load] reads a file the
 * document names (.so, a picture kept apart, \input), none if it may
 * not *)
val typeset : way -> package option -> (string -> string option) -> string -> string -> string * string list

val main : < caps ; .. > -> string array -> Exit.t
