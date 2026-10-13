(* Latex: a document written in simple LaTeX, and noweb's chunks of
 * code in it -- the books of principia, read as their .nw files.
 *
 *   \documentclass{report}              the preamble: what is defined
 *   \input{../docs/latex/Macros}        is kept, the rest passed over
 *   \newcommand{\plan}{Plan~9\xspace}
 *   \begin{document}
 *   \chapter{Rules}                     numbered: 3, 3.1, 3.1.2
 *   \label{chap:rules}
 *   A {\em rule} of \plan's [[mk]] is   a paragraph: lines to a blank
 *   read by [<parse()>]~\cite{mk}.      one, filled; [[code]] is noweb's
 *                                       and [<name>] syncweb's
 *   <<function [[addrule]]>>=           a chunk of code: lines as they
 *   void addrule(char *head) {          are, to a line with @ alone;
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
 * No \catcode, no \def with a pattern, no .sty file read: a package
 * is the few commands of it that the table has. A command that is
 * not in the table is said, once, with its line, and what follows it
 * is read as text.
 *
 * A chunk is given a number, in the order of the file; its name is
 * written with the number of the chunk that first defines it, here
 * and wherever another chunk names it, and the first of its
 * definitions says where it is used and where it goes on:
 *
 *   <function addrule 41>=   (used in 12; more in 44)
 *
 * (noweb says these with the page's number and a letter, 12b: a page
 * is not known when a document is read, only when it is laid out.)
 * \nowebindex is the chunks by name. The document is read twice, the
 * first time for what is named before it is there: a \ref, the table
 * of contents, a chunk used above its definition, the citations.
 *
 * What is not done, and said when met: a picture from a file
 * (\includegraphics: its name is written), tikz, a page's number
 * (\pageref). Mathematics is as far as words go: letters in italic,
 * what is raised and lowered, the symbols the PDF's fonts have, a
 * word for the others (alpha, <=): the books have 352 lines with a $
 * and no fraction. One column; a table whose cells are blocks (a
 * minipage each) is its cells one after the other.
 *
 * cs-history:
 * TeX is Donald Knuth's (1978), written because the second edition
 * of his own books had come back from the new phototypesetters ugly.
 * It is a macro expander: a document is a program whose running
 * leaves boxes on pages, which is why nothing but TeX reads all of
 * TeX. LaTeX is Leslie Lamport's (1984): macros over it that say what
 * a part of a document is, a section, an item, a figure, and not
 * what it looks like -- Scribe's idea (Brian Reid, 1980). That part
 * is a format one can read without being TeX, as here and as every
 * converter does (pandoc, LaTeX2HTML); what a document does with
 * TeX's own primitives is lost.
 * Literate programming is Knuth's too (WEB, 1981, for TeX itself): a
 * program written as a text for a person, its code in chunks named
 * and ordered for the explanation, from which one tool makes the
 * program (tangle) and another the document (weave). noweb is Norman
 * Ramsey's (1989): the same with two marks, <<name>>= and @, and any
 * language. syncweb is the author's: the chunks kept the same in the
 * document and in the program's files, whichever was edited.
 *
 * others:
 * noweave writes a .tex file of its own commands (\nwbegincode,
 * \sublabel) for the 976 lines of noweb.sty; this reads the .nw
 * instead, so a chunk is a thing of the document and not what its
 * macros leave. *)

(* [read paper load source]: the document, and what was not
 * understood, each with its line (and its file, when it is not the
 * one read). [paper]: the lengths are a typesetter's (ens of a text
 * of 10 points) and not a terminal's columns; [load] reads a file
 * the document names (\input, #include, \bibliography, a file shown
 * as it is), none if it may not *)
val read : bool -> (string -> string option) -> string -> Doc.t * (int * string) list
