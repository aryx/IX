(* The text of a buffer: its bytes with a gap where one types, the
 * points that move with it, what was done to undo it, a regexp
 * searched (docs/plans/plan_emacs.md, stage 1). The idea and the names
 * are efuns' Text (Fabrice Le Fessant, INRIA, 1998), which also keeps
 * a table of the lines and a color for each character; here a line is
 * found by scanning and the colors are a highlighter's.
 *
 * {b The gap.} A text typed in is changed where the cursor is, again
 * and again. So the bytes are kept in two parts with a hole between
 * them, at the place of the last change:
 *
 *     "hello world", the gap after "hello":   h e l l o _ _ _ _   w o r l d
 *     insert 5 ","  : a byte of the gap       h e l l o , _ _ _   w o r l d
 *     delete 0 1    : the gap moved to 0      _ _ _ _ e l l o ,   w o r l d
 *
 * A character typed costs one byte written; a change elsewhere first
 * moves the gap there, which copies the bytes between the two places
 * (Emacs's buffers are this, since TECO's).
 *
 * A position is a byte's offset, from 0 to [length]; a character of
 * UTF-8 is several bytes, which is the commands' to know. A position
 * out of the text is Invalid_argument. *)

type t

val create : string -> t
val to_string : t -> string
val length : t -> int

(* a number that changes when the text does: what was computed from
 * the text (its colors) is good while it is the same *)
val version : t -> int

val get : t -> int -> char
(* [sub t pos len] *)
val sub : t -> int -> int -> string

(*****************************************************************************)
(* {1 Changes} *)
(*****************************************************************************)

(* [insert t pos s]: s before the byte at pos *)
val insert : t -> int -> string -> unit

(* [delete t pos len]: the bytes taken out *)
val delete : t -> int -> int -> string

(*****************************************************************************)
(* {1 Points} *)
(*****************************************************************************)

(* A point is a position that follows its byte as the text changes
 * before it: a frame's cursor, the mark. A point after an insertion
 * moves right by its length, and one at the insertion stays (so two
 * frames at the same place: one types, the other stays before what
 * was typed); a point after a deletion moves left, and one in what is
 * deleted comes to its start. *)
type point

(* [new_point t pos]; the text keeps it until [remove_point] *)
val new_point : t -> int -> point
val remove_point : t -> point -> unit

val get_position : point -> int
(* (a position out of the text: its nearest end) *)
val set_position : t -> point -> int -> unit

(*****************************************************************************)
(* {1 Lines} *)
(*****************************************************************************)

(* Found by scanning for newlines from the position given: a frame
 * keeps where its first line starts, and what it asks is near. *)

(* the start of pos's line, and its end (its newline's position, or
 * the text's end) *)
val bol : t -> int -> int
val eol : t -> int -> int

(* [forward_line t pos n]: the start of the line n lines after pos's
 * (before it, n negative); of the last or the first line if there are
 * fewer *)
val forward_line : t -> int -> int -> int

(* pos's line, from 0: the newlines before it, counted from the start;
 * [newlines t from upto]: those between two positions *)
val line : t -> int -> int
val newlines : t -> int -> int -> int

(*****************************************************************************)
(* {1 Undo} *)
(*****************************************************************************)

(* Each change is recorded with what undoes it. A command is undone as
 * a whole: what runs the commands calls [boundary] between two.
 *
 *     insert t 0 "ab"; boundary t; insert t 2 "c"; ignore (delete t 0 1)
 *     undo t = Some 2      the text is "ab" again
 *     undo t = Some 0      ""
 *     undo t = None
 *
 * What is undone is not recorded (Emacs's undo is, and can be undone:
 * here there is no redo). *)
val boundary : t -> unit

(* the changes since the last boundary, undone; the position after the
 * last of them (where a cursor goes), or None: nothing to undo *)
val undo : t -> int option

(*****************************************************************************)
(* {1 Search} *)
(*****************************************************************************)

(* Regex's answers (the match's span, then its groups') over the whole
 * text, which is copied for it.
 * [search_forward t re pos]: the first match that starts at pos or
 * after; [search_backward]: the last one that starts before pos. *)
val search_forward : t -> Regex.t -> int -> (int * int) array option
val search_backward : t -> Regex.t -> int -> (int * int) array option
