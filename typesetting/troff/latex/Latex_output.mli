(* Latex_output: the document Latex makes, a piece at a time.
 *
 *   text, put, space      the paragraph being filled (Latex_state.out)
 *   par                   it is ended: a block
 *   block, emit           a block after a blank, or as it is
 *
 * and a text read apart, where a command wants its argument's words
 * and not the paragraph around it: a heading's title, a caption, a
 * table's cell, a footnote. The argument is put on the input as a
 * text at whose end the reading stops (Latex_input), read by the
 * state's [run], and what it made is taken. *)

val fresh : unit -> Latex_state.out
val mono_of : Doc.style -> Doc.style

(* the document's lengths are in ens, a source's in a terminal's
 * columns, ten to the inch: 1.44 ens of a text of 10 points *)
val cols : Latex_state.t -> float -> float
(* what a blank line is: a line on a terminal, less on paper *)
val gap : Latex_state.t -> float

(* what is not understood, with its place; only in the second reading *)
val say : Latex_state.t -> string -> unit
(* (once: a book has the same command a thousand times) *)
val say_once : Latex_state.t -> string -> unit

(* letters in the look of the moment *)
val text : Latex_state.t -> string -> unit
val put : Latex_state.t -> Doc.inline -> unit
(* a space, unless the line is at its start or has one *)
val space : Latex_state.t -> unit
val emit : Latex_state.t -> Doc.block -> unit
(* a block after a blank, when it is not the first *)
val block : Latex_state.t -> Doc.block -> unit
val blank_line : Doc.inline list -> bool
(* the paragraph being filled is ended, its footnotes after it *)
val par : Latex_state.t -> unit

(* [lines_as_they_are t size lines]: lines not filled, with the tab
 * stops of the typed font at that size: a display, a chunk *)
val lines_as_they_are : Latex_state.t -> int -> Doc.inline list list -> Doc.block

(* a text read where it is written: what it makes goes where the
 * rest does *)
val capture : Latex_state.t -> string -> unit
(* a text read apart: its words (of several paragraphs, all of them) *)
val inlines_of : Latex_state.t -> string -> Doc.inline list
(* the same, in a look said *)
val with_look : Latex_state.t -> Latex_state.look -> string -> Doc.inline list
