(* To_ixdoc writes any document, whatever read it, in the new format
 * (Ixdoc.mli: Markdown's lines and \name[options]{text}), so that
 *
 *   mini-troff -T md tr.1 > tr.md
 *
 * converts a manual page. Each thing of Doc.t has one spelling, and
 * what is written is read back as the same words in the same order
 * (checked on the 553 pages of principia's manual by md.sh). A line
 * that would be read as something other than words is guarded by a
 * backslash, and lines are cut at 72 letters, never inside what is
 * typed.
 *
 * What is lost on the way:
 *   - a hanging paragraph's width, when it is not a whole number of
 *     columns;
 *   - a paragraph's first line set in;
 *   - tab stops;
 *   - a table's rules other than the one under its heading, and its
 *     cells that go across columns;
 *   - a picture, which becomes the lines and words it was drawn as;
 *   - a picture from a file, which has its file's name as its words.
 *)

(* [print paper d] writes d in the format. [paper] says which lengths
 * d was read with. *)
val print : bool -> Doc.t -> string
