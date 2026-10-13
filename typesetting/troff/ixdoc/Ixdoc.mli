(* Ixdoc: the new format -- a document written in Markdown's lines,
 * with one form, \name[options]{text}, for all that Markdown has not;
 * read, and written back from any document.
 *
 *   \title{tr}{1}                       a manual page: its header
 *
 *   # SYNOPSIS                          a heading
 *   **tr** [ **-cds** ] *string1*       bold, italic; `typed` is the
 *                                       font of what is typed
 *   # DESCRIPTION
 *   *Tr* copies the standard input      a paragraph: lines to a blank
 *   to the standard output.\footnote{   one, filled
 *   Runes, not bytes.}
 *
 *   **-c**                              a paragraph that hangs from a
 *   :    Complement *string1*.          term: the line before a colon;
 *        Its lines after the first      its text is at the column
 *        are set in.                    where the colon's line has it
 *                                       (here 5: troff's .TP 5)
 *   - an item                           a list is the same thing, its
 *   1. another                          term a bullet or a number
 *
 *   > set in                            what is to the right of the rest
 *
 *   | Test | Plan 9 |  IRIX |           a table: the second line says
 *   |:-----|-------:|------:|           each column's side
 *   | fork |   2 ms |  5 ms |
 *
 *   ```                                 lines as they are, in the font
 *   cat file                            of what is typed; ```pic: a
 *   ```                                 picture, in pic's words;
 *                                       ```lines: lines as they are, with
 *                                       their marks read
 *   \figure[label=fig:way]{             a command that starts a line and
 *   ...                                 ends it with { has the lines to
 *   Its legend.                         a } alone as its text
 *   }
 *
 * A blank line is a space in the document, and no blank line is none:
 * a list whose items touch is closed up, as troff's .PD 0.
 *
 * In a line: *italic* or _italic_, **bold**, `typed`, [words](where)
 * (the words: paper goes nowhere), $mathematics$ (in italic, until
 * equations are read), a backslash before a character that would be
 * a mark, a backslash at a line's end to end the line there. The
 * commands of a line: \emph \strong \code \roman \small \big \up
 * \down (what the marks say, and what they cannot), \footnote,
 * \label and \ref (a section by its title, a figure by its number),
 * \cite, \man{rc}{1}. Those that start a line: \title, \author,
 * \newcommand{\plan}{Plan 9} (a text put for a name, #1 its first
 * argument: nothing is computed), \include, \figure, \keep, \center,
 * \indent[columns], \space[lines], \footnote.
 *
 * Not Markdown's whole: what ix's own 164 files use of it, counted by
 * typesetting/tests/md.sh. Not read: a line under a heading in place
 * of its # marks, links kept apart ([name]: where), HTML (said), a
 * picture from a file (said, its words kept), a rule across the
 * page. A paragraph's next line must not be set in less than its
 * item (no "lazy" line).
 *
 * [print] is the other way: any document, whatever read it, in these
 * words; so that
 *
 *   mini-troff -T md tr.1 > tr.md
 *
 * is a manual page converted. Each thing of Doc.t has one spelling
 * here, and what is written is read back as the same words in the
 * same order (the 553 pages of principia's manual; md.sh). Lost on
 * the way: a hanging paragraph's width when it is not a whole number
 * of columns, a paragraph's first line set in, tab stops, a table's
 * rules other than its heading's and its cells that go across
 * columns, and a picture is the lines and words it was drawn as.
 *
 * others:
 * Markdown is John Gruber's (2004): the conventions of plain-text
 * mail, made a format. It has no way to say what it did not foresee
 * (a footnote, a figure, a reference), which each of its dialects
 * added in its own way: pandoc's (John MacFarlane, 2006) is where the
 * hanging paragraph's colon comes from. LaTeX has that way, one
 * form for everything, and is heavy for what Markdown does in a
 * character. This is the two, each for what it is good at. Typst
 * (2023) is the format nearest in aim; most of it is its programming
 * language, which this has not: a document that must compute is
 * written by a program. *)

(* [read paper load source]: the document, and what was not
 * understood, each with its line. [paper]: the lengths are a
 * typesetter's (ens of a text of 10 points) and not a terminal's
 * columns; [load] reads a file the document names (\include, a
 * picture's copy), none if it may not *)
val read : bool -> (string -> string option) -> string -> Doc.t * (int * string) list

(* [print paper d]: d written in the format; [paper] says which
 * lengths d was read with *)
val print : bool -> Doc.t -> string
