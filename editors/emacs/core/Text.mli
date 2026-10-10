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
 * out of the text is Invalid_argument.
 *
 * In memory, the structure is three fields (Text.ml's bytes, gap
 * and gap_len); "hello,world" with the gap after the comma:
 *
 *     bytes:   h e l l o , _ _ _ w o r l d       gap = 6, gap_len = 3
 *     pos:     0 1 2 3 4 5       6 7 8 9 10      length = 14 - 3 = 11
 *
 *     get t pos = bytes.[pos]             if pos < gap
 *                 bytes.[pos + gap_len]   otherwise
 *
 * A gap that is full is made again, the text copied to a place a
 * quarter larger: a long text typed in is copied a number of times
 * that is its logarithm.
 *
 * The points are what make it an editor's text and not a string
 * builder: a frame's cursor and first line, the mark, the place a
 * buffer was left at are each a point, and the text moves them all
 * at each change (Emacs calls them markers, and has the gap too).
 *
 * cs-history:
 * The gap is as old as display editing: TECO's buffer at MIT had it,
 * EMACS was written in TECO and kept it, and GNU Emacs's insdel.c
 * still moves one. It fits how a text is typed: a thousand changes
 * at one place, then a jump. And it fits a machine: the text is two
 * runs of bytes, so a search or a file's write goes over memory in
 * order.
 *
 * others:
 * The other structures, and what each is good at. An array of lines
 * (ed, vi; the Text of mini-ed, Turbo_edit): a change touches one
 * short line, and a line's number is an index, but a change across
 * lines is a special case everywhere. A piece table (Bravo and Word;
 * lib_gui's Text_edit): the file's text never changed, what is typed
 * appended elsewhere, and the document a list of pieces of the two;
 * an old version is an old list, so undo keeps lists. A rope (Boehm,
 * Atkinson and Plass, 1995): a balanced tree of small strings, where
 * every change is logarithmic wherever it is. efuns' Text and this
 * one are gap buffers: the cost shows only when one types at the
 * start of a large file after typing at its end, once.
 *
 * modern:
 * VS Code's text is a piece table kept as a balanced tree (2018),
 * and several newer editors use ropes: with many cursors, changes
 * coming from a language server or another person, and files of
 * hundreds of megabytes, a change no longer happens where the last
 * one did, which is all a gap bets on.
 *
 * wib:
 * No table of where the lines start (efuns keeps one): [line]
 * counts newlines from the start, [bol] scans back. A frame keeps
 * where its first line is, so drawing is near; what costs is that
 * line's number, for the status line: counted from the text's start
 * each time the frame's rows are made again, so at each character
 * typed at the end of a large file. And a search copies the text
 * whole for Regex, which wants a string.
 *
 * References: Craig Finseth, "The Craft of Text Editing" (1991),
 * chapter 6, the buffer's structures compared; Charles
 * Crowley, "Data Structures for Text Sequences" (1998), the same
 * with measures, and the piece table; Hans Boehm, Russ Atkinson and
 * Michael Plass, "Ropes: an Alternative to Strings" (Software --
 * Practice and Experience, 1995); efuns' book, "Text Management". *)

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
