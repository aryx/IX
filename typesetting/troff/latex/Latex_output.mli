(* Latex_output: the document that Latex makes, a piece at a time.
 *
 *   text, put, space      the paragraph being filled (Latex_state.out)
 *   par                   the paragraph is ended, and becomes a block
 *   block, emit           a block after a blank, or as it is
 *
 * It also has the text read apart, for a command that wants the words
 * of its argument and not the paragraph around it: a heading's title,
 * a caption, a table's cell, a footnote. The argument is put on the
 * input as a text at whose end the reading stops (Latex_input), it is
 * read by the state's [run], and what it made is taken. *)

val fresh : unit -> Latex_state.out
val mono_of : Doc.style -> Doc.style

(* turns a source's length, in a terminal's columns (ten to the inch),
 * into the document's ens; on paper a column is 1.44 ens of a text of
 * 10 points *)
val cols : Latex_state.t -> float -> float
(* how much space a blank line is: a line on a terminal, less on
 * paper *)
val gap : Latex_state.t -> float

(* reports what is not understood, with its place, only in the second
 * reading *)
val say : Latex_state.t -> string -> unit
(* (reports it only once, because a book has the same command a
 * thousand times) *)
val say_once : Latex_state.t -> string -> unit

(* letters in the current look *)
val text : Latex_state.t -> string -> unit
val put : Latex_state.t -> Doc.inline -> unit
(* a space, unless the line is at its start or already ends with one *)
val space : Latex_state.t -> unit
val emit : Latex_state.t -> Doc.block -> unit
(* a block after a blank, when it is not the first *)
val block : Latex_state.t -> Doc.block -> unit

(* [anchor t name lettered] puts a place whose page number is asked
 * for (Doc.Anchor) here, or before the paragraph when inside one. *)
val anchor : Latex_state.t -> string -> bool -> unit

val blank_line : Doc.inline list -> bool
(* ends the paragraph being filled, with its footnotes after it *)
val par : Latex_state.t -> unit

(* [lines_as_they_are t size lines]: lines that are not filled, with
 * the tab stops of the typed font at that size, for a display or a
 * chunk *)
val lines_as_they_are : Latex_state.t -> int -> Doc.inline list list -> Doc.block

(* reads a text where it is written: what it makes goes where the rest
 * goes *)
val capture : Latex_state.t -> string -> unit
(* reads a text apart, and returns its words (all of them, from all
 * its paragraphs) *)
val inlines_of : Latex_state.t -> string -> Doc.inline list
(* the same, in a given look *)
val with_look : Latex_state.t -> Latex_state.look -> string -> Doc.inline list
