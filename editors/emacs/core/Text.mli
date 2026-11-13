(* The text of a buffer: its bytes with a gap where one types, the
 * points that move with it, what was done (to undo it), and the search
 * of a regexp (docs/plans/done/plan_emacs.md, stage 1). The idea and
 * the names are those of efuns' Text (Fabrice Le Fessant, INRIA,
 * 1998), which also keeps a table of the lines and a color for each
 * character. Here a line is found by scanning, and the colors come
 * from a highlighter.
 *
 * {b The gap.} A text being typed in is changed where the cursor is,
 * again and again. So the bytes are kept in two parts with a hole
 * between them, at the place of the last change:
 *
 *     "hello world", the gap after "hello":   h e l l o _ _ _ _   w o r l d
 *     insert 5 ","  : a byte of the gap       h e l l o , _ _ _   w o r l d
 *     delete 0 1    : the gap moved to 0      _ _ _ _ e l l o ,   w o r l d
 *
 * A character typed costs one byte written. A change elsewhere first
 * moves the gap there, which copies the bytes between the two places
 * (Emacs's buffers have worked this way since TECO's).
 *
 * A position is a byte's offset, from 0 to [length]. A UTF-8
 * character is several bytes, and it is for the commands to know
 * that. A position out of the text raises Invalid_argument.
 *
 * In memory, the structure is three fields (bytes, gap and gap_len in
 * Text.ml). Here is "hello,world" with the gap after the comma:
 *
 *     bytes:   h e l l o , _ _ _ w o r l d       gap = 6, gap_len = 3
 *     pos:     0 1 2 3 4 5       6 7 8 9 10      length = 14 - 3 = 11
 *
 *     get t pos = bytes.[pos]             if pos < gap
 *                 bytes.[pos + gap_len]   otherwise
 *
 * When the gap is full it is made again: the text is copied to a
 * place a quarter larger, so a long text typed in is copied a number
 * of times that is its logarithm.
 *
 * The points are what make it an editor's text and not a string
 * builder. A frame's cursor and first line, the mark, and the place a
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
 * Here are the other structures, and what each is good at.
 * - An array of lines (ed, vi; the Text of mini-ed, Turbo_edit): a
 *   change touches one short line, and a line's number is an index,
 *   but a change across lines is a special case everywhere.
 * - A piece table (Bravo and Word; lib_gui's Text_edit): the file's
 *   text is never changed, what is typed is appended elsewhere, and
 *   the document is a list of pieces of the two. An old version is an
 *   old list, so undo keeps lists.
 * - A rope (Boehm, Atkinson and Plass, 1995): a balanced tree of small
 *   strings, where every change is logarithmic wherever it is.
 * efuns' Text and this one are gap buffers. Their cost shows only
 * when one types at the start of a large file after typing at its
 * end, and then only once.
 *
 * modern:
 * VS Code's text is a piece table kept as a balanced tree (2018),
 * and several newer editors use ropes. With many cursors, changes
 * coming from a language server or from another person, and files of
 * hundreds of megabytes, a change no longer happens where the last
 * one did, and that is all a gap bets on.
 *
 * wib:
 * There is no table of where the lines start (efuns keeps one): [line]
 * counts newlines from the start, and [bol] scans back. A frame keeps
 * where its first line is, so what drawing asks is near. What costs
 * is that line's number, for the status line: it is counted from the
 * text's start each time the frame's rows are made again, so at each
 * character typed at the end of a large file. And a search copies the
 * whole text for Regex, which wants a string.
 *
 * References: Craig Finseth, "The Craft of Text Editing" (1991),
 * chapter 6, which compares the buffer's structures; Charles Crowley,
 * "Data Structures for Text Sequences" (1998), the same with
 * measures, and the piece table; Hans Boehm, Russ Atkinson and
 * Michael Plass, "Ropes: an Alternative to Strings" (Software --
 * Practice and Experience, 1995); efuns' book, "Text Management". *)

type t

val create : string -> t
val to_string : t -> string
val length : t -> int

(* a number that changes when the text does: what was computed from
 * the text (its colors) is good while the number is the same *)
val version : t -> int

val get : t -> int -> char
(* [sub t pos len] *)
val sub : t -> int -> int -> string

(*****************************************************************************)
(* {1 Changes} *)
(*****************************************************************************)

(* [insert t pos s] inserts s before the byte at pos *)
val insert : t -> int -> string -> unit

(* [delete t pos len] takes the bytes out and returns them *)
val delete : t -> int -> int -> string

(*****************************************************************************)
(* {1 Points} *)
(*****************************************************************************)

(* A point is a position that follows its byte as the text changes
 * before it: a frame's cursor, or the mark. A point after an
 * insertion moves right by the insertion's length, and a point at the
 * insertion stays. So when two frames are at the same place and one
 * types, the other stays before what was typed. A point after a
 * deletion moves left, and a point in what is deleted comes to its
 * start. *)
type point

(* [new_point t pos]; the text keeps the point until [remove_point] *)
val new_point : t -> int -> point
val remove_point : t -> point -> unit

val get_position : point -> int
(* (a position out of the text goes to the text's nearest end) *)
val set_position : t -> point -> int -> unit

(*****************************************************************************)
(* {1 Lines} *)
(*****************************************************************************)

(* Lines are found by scanning for newlines from the position given:
 * a frame keeps where its first line starts, so what it asks is
 * near. *)

(* the start of pos's line, and its end (its newline's position, or
 * the text's end) *)
val bol : t -> int -> int
val eol : t -> int -> int

(* [forward_line t pos n] gives the start of the line n lines after
 * pos's line (before it, when n is negative), or of the last or first
 * line if there are fewer lines *)
val forward_line : t -> int -> int -> int

(* [line] gives pos's line, from 0: the newlines before it, counted
 * from the start. [newlines t from upto] counts the newlines between
 * two positions. *)
val line : t -> int -> int
val newlines : t -> int -> int -> int

(*****************************************************************************)
(* {1 Undo} *)
(*****************************************************************************)

(* Each change is recorded with what undoes it. A command is undone as
 * a whole: what runs the commands calls [boundary] between two of
 * them.
 *
 *     insert t 0 "ab"; boundary t; insert t 2 "c"; ignore (delete t 0 1)
 *     undo t = Some 2      the text is "ab" again
 *     undo t = Some 0      ""
 *     undo t = None
 *
 * What is undone is not recorded (Emacs's undo is recorded, and can
 * itself be undone; here there is no redo). *)
val boundary : t -> unit

(* undoes the changes since the last boundary, and gives the position
 * after the last of them (where a cursor goes), or None when there is
 * nothing to undo *)
val undo : t -> int option

(*****************************************************************************)
(* {1 Search} *)
(*****************************************************************************)

(* These give Regex's answers (the match's span, then its groups'
 * spans) over the whole text, which is copied for it.
 * [search_forward t re pos] gives the first match that starts at pos
 * or after; [search_backward] the last one that starts before pos. *)
val search_forward : t -> Regex.t -> int -> (int * int) array option
val search_backward : t -> Regex.t -> int -> (int * int) array option
