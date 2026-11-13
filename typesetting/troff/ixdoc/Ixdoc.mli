(* Ixdoc reads the new format: a document written in Markdown's lines,
 * with one form, \name[options]{text}, for everything that Markdown
 * does not have.
 *
 *   \title{tr}{1}{text}                 a manual page: its header, and
 *                                       its group (man 1 lists the
 *                                       section by groups)
 *
 *   # SYNOPSIS                          a heading
 *   **tr** [ **-cds** ] *string1*       bold, italic; `typed` is in the
 *                                       font of what is typed
 *   # DESCRIPTION
 *   *Tr* copies the standard input      a paragraph: the lines up to a
 *   to the standard output.\footnote{   blank one, filled
 *   Runes, not bytes.}
 *
 *   **-c**                              a paragraph that hangs from a
 *   :    Complement *string1*.          term, the line before a colon.
 *        Its lines after the first      Its text is at the column where
 *        are set in.                    the colon's line has it (here
 *                                       5, as troff's .TP 5)
 *   - an item                           a list is the same thing, with
 *   1. another                          a bullet or a number as its term
 *
 *   > set in                            what is to the right of the rest
 *
 *   | Test | Plan 9 |  IRIX |           a table: the second line gives
 *   |:-----|-------:|------:|           the side of each column
 *   | fork |   2 ms |  5 ms |
 *
 *   ```                                 lines as they are, in the font
 *   cat file                            of what is typed; ```pic is a
 *   ```                                 picture, in pic's words;
 *                                       ```lines is lines as they are,
 *                                       with their marks read
 *   \figure[label=fig:way]{             a command that starts a line and
 *   ...                                 ends it with { has as its text
 *   Its legend.                         the lines up to a } alone
 *   }
 *
 * A blank line is a space in the document, and no blank line means no
 * space: a list whose items touch is closed up, as with troff's .PD 0.
 *
 * Inside a line, there are:
 *   - *italic* or _italic_, **bold**, `typed`;
 *   - [words](where), of which only the words are kept, because paper
 *     goes nowhere;
 *   - $mathematics$, in italic until equations are read;
 *   - a backslash before a character that would otherwise be a mark,
 *     and a backslash at the end of a line to end the line there.
 * The commands inside a line are \emph \strong \code \roman \small
 * \big \up \down (what the marks say, and what they cannot say),
 * \footnote, \label and \ref (a section by its title, a figure by its
 * number), \cite, and \man{rc}{1}. The commands that start a line are
 * \title, \author, \newcommand{\plan}{Plan 9} (a text put in place of
 * a name, with #1 as its first argument; nothing is computed),
 * \include, \figure, \keep, \center, \indent[columns], \space[lines]
 * and \footnote.
 *
 * This is not the whole of Markdown, only what ix's own 164 files use
 * of it, as counted by typesetting/tests/md.sh. What is not read: a
 * line under a heading in place of its # marks, links kept apart
 * ([name]: where), HTML (which is reported), and a rule across the
 * page. The next line of a paragraph must not be set in less than its
 * item (there is no "lazy" line).
 *
 * A picture from a file, ![words](file), is a PNG, a JPEG or a GIF
 * (Doc_image). It is put after the paragraph that names it, in the
 * middle of the line, at 96 of its pixels to the inch and no wider
 * than the line. A file that is not there, or is not a picture, is
 * reported, and its words are written in its place.
 *
 * To_ixdoc goes the other way: it writes any document, whatever read
 * it, in these words. Ixdoc_syntax has what the two share: a text's
 * marks, and what kind of line a line is.
 *
 * others:
 * John Gruber made Markdown (2004) out of the conventions of
 * plain-text mail. It has no way to say what it did not foresee (a
 * footnote, a figure, a reference), so each of its dialects added
 * these in its own way; the hanging paragraph's colon comes from
 * pandoc's dialect (John MacFarlane, 2006). LaTeX has such a way, one
 * form for everything, but it is heavy for what Markdown does in one
 * character. This format takes the two, each for what it is good at.
 * Typst (2023) is the format nearest in aim. Most of Typst is its
 * programming language, which this format does not have: a document
 * that must compute something is written by a program. *)

(* [read paper load source] returns the document, and what was not
 * understood, each with its line. When [paper] is true, the lengths
 * are a typesetter's (ens of a text of 10 points) and not a terminal's
 * columns. [load] reads a file that the document names (\include, a
 * picture's copy); it gives None if the file may not be read. *)
val read : bool -> (string -> string option) -> string -> Doc.t * (int * string) list
