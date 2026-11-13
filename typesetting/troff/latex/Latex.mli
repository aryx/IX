(* Latex reads a document written in simple LaTeX, with noweb's chunks
 * of code in it. These are the books of principia, read as their .nw
 * files.
 *
 *   \documentclass{report}              the preamble: what is defined
 *   \input{../docs/latex/Macros}        is kept, the rest is skipped
 *   \newcommand{\plan}{Plan~9\xspace}
 *   \begin{document}
 *   \chapter{Rules}                     numbered: 3, 3.1, 3.1.2
 *   \label{chap:rules}
 *   A {\em rule} of \plan's [[mk]] is   a paragraph: the lines up to a
 *   read by [<parse()>]~\cite{mk}.      blank one, filled; [[code]] is
 *                                       noweb's and [<name>] syncweb's
 *   <<function [[addrule]]>>=           a chunk of code: lines as they
 *   void addrule(char *head) {          are, up to a line with @ alone;
 *       <<[[addrule()]] locals>>        another chunk named in it
 *   }
 *   @
 *   \l could be shorter                 the author's notes to himself
 *   #include "Make_extra.nw"            a file put here (syncweb's)
 *   \bibliography{../docs/latex/Principia}
 *   \end{document}
 *
 * It is a table of commands over a small expander, and not TeX:
 *
 *   the text      a file; a macro's text put in its place, with its
 *                 arguments for #1, #2; an argument read apart
 *   the expander  \newcommand, \renewcommand, \def (no pattern),
 *                 \newenvironment, \newif and its \ifxxx ... \else
 *                 ... \fi, \input, groups { }
 *   the table     the parts (\chapter to \subsubsection, numbered),
 *                 the looks (\em \bf \tt \sc, \emph{}, the sizes),
 *                 itemize, enumerate, description, figure and table
 *                 with their \caption, tabular (l c r p{}, \hline and
 *                 booktabs' rules, \multicolumn), verbatim and the
 *                 environments defined as one, quote, center,
 *                 abstract, \footnote, \label and \ref, \cite and
 *                 \bibliography (Bib), \tableofcontents, \url,
 *                 \verb, the title
 *
 * Each of its parts is a module:
 *   - Latex_state: what is being read and what is being made;
 *   - Latex_input: the text, read a character at a time, and an
 *     argument;
 *   - Latex_output: the document, made a piece at a time, and a text
 *     read apart;
 *   - Latex_names: the commands that are one line of the table;
 *   - Noweb: a chunk;
 *   - Latex_math, Latex_table;
 *   - Bib: the file of the references.
 * This module has the reading and the commands.
 *
 * There is no \catcode, no \def with a pattern, and no .sty file is
 * read: a package is the few of its commands that the table has. A
 * command that is not in the table is reported, once, with its line,
 * and what follows it is read as text.
 *
 * Each chunk is given a number, in the order of the file. Its name is
 * written with the number of the chunk that first defines it, both
 * here and wherever another chunk names it. The first of its
 * definitions says where it is used and where it goes on:
 *
 *   <function addrule 41>=   (used in 12; more in 44)
 *
 * On paper the number is noweb's: the sheet's number, with a letter
 * when the sheet has several chunks (<function addrule 12b>=). The
 * sheet is not known when the document is read, so the chunk is an
 * anchor and its number is a Doc.Page, which To_pdf writes when the
 * sheets are cut. The numbers of the table of contents and of
 * \pageref are done the same way. On a terminal, which has no sheets,
 * a chunk has its own number, the table of contents has no numbers,
 * and \pageref gives a ?.
 * \nowebindex lists the chunks by name. The document is read twice;
 * the first time is for what is named before it is there: a \ref, the
 * table of contents, a chunk used above its definition, the citations.
 *
 * A picture from a file (\includegraphics[width=...]{file}) is a PNG,
 * a JPEG or a GIF (Doc_image). It is found as it is named, or with the
 * end of the name that LaTeX leaves out. It is as wide as width= or
 * scale= say, or else a pixel is a point. Some things are not done,
 * and are reported when met: a picture that is a PDF file (the books'
 * lineage diagrams; its name is written instead), and tikz.
 * Mathematics goes only as far as words go: letters in italic, what is
 * raised and lowered, the symbols that the PDF's fonts have, and a
 * word for the others (alpha, <=). The books have 352 lines with a $
 * and no fraction. There is one column only, and a table whose cells
 * are blocks (a minipage each) is shown as its cells one after the
 * other.
 *
 * cs-history:
 * Donald Knuth wrote TeX (1978) because the second edition of his own
 * books had come back ugly from the new phototypesetters. It is a
 * macro expander: a document is a program whose running leaves boxes
 * on pages, which is why nothing but TeX reads all of TeX. Leslie
 * Lamport wrote LaTeX (1984): macros over TeX that say what a part of
 * a document is (a section, an item, a figure) and not what it looks
 * like, which was Scribe's idea (Brian Reid, 1980). That part is a
 * format that can be read without being TeX, as here and as every
 * converter does (pandoc, LaTeX2HTML); what a document does with
 * TeX's own primitives is lost.
 * Literate programming is Knuth's idea too (WEB, 1981, for TeX
 * itself). A program is written as a text for a person, with its code
 * in chunks that are named and ordered for the explanation. One tool
 * makes the program from it (tangle), and another makes the document
 * (weave). Norman Ramsey wrote noweb (1989): the same idea with two
 * marks, <<name>>= and @, and for any language. syncweb is the
 * author's: it keeps the chunks the same in the document and in the
 * program's files, whichever one was edited.
 *
 * others:
 * noweave writes a .tex file of its own commands (\nwbegincode,
 * \sublabel) for the 976 lines of noweb.sty. This module reads the .nw
 * instead, so a chunk is a thing of the document and not what its
 * macros leave behind. *)

(* [read paper load source] returns the document, and what was not
 * understood, each with its line (and its file, when it is not the one
 * read). When [paper] is true, the lengths are a typesetter's (ens of
 * a text of 10 points) and not a terminal's columns. [load] reads a
 * file that the document names (\input, #include, \bibliography, a
 * file shown as it is); it gives None if the file may not be read. *)
val read : bool -> (string -> string option) -> string -> Doc.t * (int * string) list
