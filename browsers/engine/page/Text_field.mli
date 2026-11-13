(* Text_field: a line of text being edited, with its caret and its
 * selection, the edits that the keys and the mouse make to it, and the
 * part of it that shows. The browser has two such fields:
 * mini-netscape's Location field, and the page's text fields (Tab
 * keeps the caret of the one in focus).
 *
 *     https://en.wikipedia.org/wiki/OCaml
 *             ^anchor          ^caret       the selection between
 *             [================]            them, blue under the text
 *
 * A click puts the caret, a drag selects from where the button went
 * down, and a double click selects all (and when the Location field is
 * at rest, a click selects all, so the address can be typed over).
 * Shift with the arrows, Home and End moves the caret and selects. Ctrl
 * and A selects all, Ctrl and C copies the selection, Ctrl and X cuts
 * it, and Ctrl and V pastes (as in Netscape), only the first line of a
 * pasted text.
 *
 * The positions are bytes of the text, each at the first byte of a
 * character (in UTF-8, a letter with an accent is two bytes). What
 * shows is measured in the field's letters (by a function from a text
 * to its width), which are not all as wide. When the text is longer
 * than the field, the part that shows keeps the caret, and the end
 * when it can.
 *
 * ix: copied from libs/gui/Gui_field.ml and the editing keys of
 * src/chrome/Omnibox.ml in the author's mini-chrome (its commit
 * 8af888e), in one module. Where mini-chrome counts cells of a
 * monospace font, here a width is measured, and where it counts
 * characters, here it counts bytes.
 *
 * terminology:
 * The caret is the insertion point (the Macintosh's word, 1984). The
 * anchor is where a selection was started from, which Shift and an
 * arrow keep (a text widget's word, as in Tk and in the DOM's
 * Selection.anchorNode). *)

type t = { text : string; caret : int; anchor : int }

(* the field clicked at rest: all of [text] is selected *)
val focused : string -> t

val select_all : t -> t
val selected : t -> string

(* [typed s f]: [s] in place of the selection, with the caret after
 * it *)
val typed : string -> t -> t

(* the selection removed; when there is none, the character before the
 * caret is removed, or the one after it *)
val backspace : t -> t
val delete : t -> t

type move = Left | Right | Home | End

(* the caret moved, with the selection following it if [select] (Shift
 * is held), or else the selection gone; Left and Right then first go to
 * the selection's nearer end *)
val moved : select:bool -> move -> t -> t

(* the caret and the anchor put within the text, at the first byte of a
 * character, because the text may have changed under them (by a page's
 * script) *)
val clamped : t -> t

(* the caret put at a byte (by a click), with the anchor kept if
 * [select] (by a drag) *)
val caret_at : select:bool -> int -> t -> t

(* [key ~shift name f]: the keys that edit without Ctrl (Backspace,
 * Delete, ArrowLeft, ArrowRight, Home, End: the playground's names);
 * None for another key *)
val key : shift:bool -> string -> t -> t option

(* [command copy paste letter f]: Ctrl and A, C, X or V. [copy] is
 * given the selection, and [paste] is asked for the clipboard's text.
 * None for another letter *)
val command : (string -> unit) -> (unit -> string) -> string -> t -> t option

(* [first_shown measure f ~room]: the byte where the part that shows
 * starts, in [room] of the field's width *)
val first_shown : (string -> float) -> t -> room:float -> int

(* [place measure f ~room i]: how far from the text's left the byte
 * [i] is drawn, within [room] *)
val place : (string -> float) -> t -> room:float -> int -> float

(* [index_at measure f ~room x]: the place of the caret nearest to [x],
 * from the text's left, for caret_at *)
val index_at : (string -> float) -> t -> room:float -> float -> int
