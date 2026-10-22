(* Text_field: a line of text being edited -- its caret and its
 * selection, the keys' and the mouse's edits of it, and the part of it
 * that shows. The browser's two: mini-netscape's Location field, and
 * the page's text fields (Tab keeps the caret of the one in focus).
 *
 *     https://en.wikipedia.org/wiki/OCaml
 *             ^anchor          ^caret       the selection between
 *             [================]            them, blue under the text
 *
 * A click puts the caret, a drag selects from where the button went
 * down, a double click selects all (the Location field at rest: a
 * click selects all, the address to be typed over). Shift and the
 * arrows, Home and End move the caret and select; Ctrl and A selects
 * all, Ctrl and C copies the selection, Ctrl and X cuts it, Ctrl and V
 * pastes (Netscape), a pasted text's first line only.
 *
 * The positions are bytes of the text, each at a character's first
 * (UTF-8: a letter with an accent is two). What shows is measured in
 * the field's letters (a function from a text to its width), which
 * are not all as wide: when the text is longer than the field, the
 * part that shows keeps the caret, and the end when it can.
 *
 * ix: the author's mini-chrome's libs/gui/Gui_field.ml and the editing
 * keys of its src/chrome/Omnibox.ml (its 8af888e), in one module; its
 * cells of a monospace font are a width measured here, its characters
 * bytes.
 *
 * terminology:
 * The caret is the insertion point (the Macintosh's word, 1984); the
 * anchor is where a selection was started from, which Shift and an
 * arrow keep (a text widget's word, Tk's and the DOM's
 * Selection.anchorNode). *)

type t = { text : string; caret : int; anchor : int }

(* the field clicked at rest: all of [text] selected *)
val focused : string -> t

val select_all : t -> t
val selected : t -> string

(* [typed s f]: [s] in place of the selection, the caret after it *)
val typed : string -> t -> t

(* the selection gone; with none, the character before the caret, or
 * after it *)
val backspace : t -> t
val delete : t -> t

type move = Left | Right | Home | End

(* the caret moved, the selection with it if [select] (Shift held),
 * else gone -- Left and Right then first go to its nearer end *)
val moved : select:bool -> move -> t -> t

(* the caret and the anchor within the text, at a character's first
 * byte: the text may have changed under them (a page's script) *)
val clamped : t -> t

(* the caret put at a byte (a click), the anchor kept if [select] (a
 * drag) *)
val caret_at : select:bool -> int -> t -> t

(* [key ~shift name f]: the keys that edit without Ctrl (Backspace,
 * Delete, ArrowLeft, ArrowRight, Home, End: the playground's names);
 * None for another *)
val key : shift:bool -> string -> t -> t option

(* [command copy paste letter f]: Ctrl and A, C, X or V; [copy] given
 * the selection, [paste] asked for the clipboard's text. None for
 * another letter *)
val command : (string -> unit) -> (unit -> string) -> string -> t -> t option

(* [first_shown measure f ~room]: the byte the part that shows starts
 * at, in [room] of the field's width *)
val first_shown : (string -> float) -> t -> room:float -> int

(* [place measure f ~room i]: how far from the text's left the byte
 * [i] is drawn, within [room] *)
val place : (string -> float) -> t -> room:float -> int -> float

(* [index_at measure f ~room x]: the place of the caret nearest to [x]
 * from the text's left, for caret_at *)
val index_at : (string -> float) -> t -> room:float -> float -> int
