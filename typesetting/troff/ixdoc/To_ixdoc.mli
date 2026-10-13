(* To_ixdoc: any document, whatever read it, written in the new
 * format (Ixdoc.mli: Markdown's lines and \name[options]{text}); so
 * that
 *
 *   mini-troff -T md tr.1 > tr.md
 *
 * is a manual page converted. Each thing of Doc.t has one spelling,
 * and what is written is read back as the same words in the same
 * order (the 553 pages of principia's manual; md.sh): a line that
 * would be read as something else than words is guarded by a
 * backslash, and lines are cut at 72 letters, never inside what is
 * typed.
 *
 * Lost on the way: a hanging paragraph's width when it is not a
 * whole number of columns, a paragraph's first line set in, tab
 * stops, a table's rules other than its heading's and its cells that
 * go across columns, and a picture is the lines and words it was
 * drawn as. *)

(* [print paper d]: d written in the format; [paper] says which
 * lengths d was read with *)
val print : bool -> Doc.t -> string
