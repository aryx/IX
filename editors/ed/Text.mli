(* The buffer: numbered lines, a current line (dot) and a last one.
 *
 *     index   0      1          2           3        ($ = dol = 3)
 *             (0)   "int x;"   "int y;"    "}"
 *                               ^ dot = 2
 *
 * Line 0 is not a line: it is where 0a appends, before the first. An
 * empty buffer has dol = 0 and dot = 0.
 *
 * {b A line has an identity.} ed.c keeps the text in a temporary file
 * and the buffer as offsets into it, stealing the low bit of each for
 * g's marks. Here a line is a record in memory, and the record is the
 * line. A mark (k) holds the record, so it follows its line through a
 * move, and is gone with it after a delete. [global] is g's mark. s
 * makes a new record, moves the old one's marks to it, and keeps both
 * for u.
 *
 *     let t = create () in
 *     append t 0 [ "x1"; "y"; "x2" ];      dol t = 3, dot t = 3
 *     mark t 'a' 2;  move t 1 2 3;          lines: x2 x1 y
 *     find_mark t 'a' = Some 3              the mark followed y
 *
 * cs-history:
 * Why ed.c's text is in a file. A PDP-11's addresses are 16 bits: a
 * program had 64 kilobytes at most, less than a file one would edit.
 * So ed writes each line it is given at the end of a temporary file
 * (/tmp/e and a number) and keeps in memory only one integer for each
 * line, which says where the line is in that file:
 *
 *     ed.c's zero:   | off 0 | off 1 | off 2 | off 3 |      dol = 3
 *                              |       |        '----.
 *     its tfile:     int x;\n  int y;\n  (an old line 3)  }\n
 *
 * A delete or a move shuffles integers; an s writes the new line at
 * the file's end and changes one integer. The file only grows, and the
 * old lines stay in it unused. The buffer is an array of lines, and
 * the lines themselves are immutable and out of the way. Text here is
 * the same, with the garbage collector in place of the temporary
 * file.
 *
 * wib:
 * Every change makes a new array here (append, delete and move copy
 * the lines' records, not their text): a line appended to a buffer of
 * n lines costs n words, where ed.c moves only the integers after it.
 * A script that appends ten thousand lines, one per command, would
 * feel it. But a command appends all its lines at once, and no file
 * edited with ed is that long.
 *
 * others:
 * An editor's text is kept in three ways in ix:
 * - lines in an array, here and in mini-turbopascal's Turbo_edit, for
 *   an editor that thinks in lines (5d, the line an error is on);
 * - one sequence of bytes with a gap where one types, the Text of
 *   mini-emacs, for an editor that thinks in characters, a newline
 *   being one of them;
 * - pieces of two texts that are never changed, lib_gui's Text_edit
 *   (mini-drscheme's), for when the old versions are wanted, for
 *   undo. *)

type line = { text : string; mutable global : bool }

type t

val create : unit -> t

val dol : t -> int
val dot : t -> int
val set_dot : t -> int -> unit

(* [changed t]: whether the buffer was modified since the last write,
 * for q and e *)
val changed : t -> bool
val set_changed : t -> bool -> unit

val get : t -> int -> line
val text : t -> int -> string

(* [append t n texts] adds new lines after line n, and returns how many
 * it appended. Dot becomes the last of them (n when there are none).
 *)
val append : t -> int -> string list -> int

(* [delete t a b] deletes lines a..b. Dot becomes the line after them,
 * or the new last line. *)
val delete : t -> int -> int -> unit

(* [replace t n line] makes [line] line n (for s, j and u). It does not
 * count as a change by itself, since u is not one for ed.c. *)
val replace : t -> int -> line -> unit

(* makes the buffer empty again, with its marks and undo forgotten (e) *)
val clear : t -> unit

(* [move t a b n] moves lines a..b after line n (which is outside
 * a..b). Dot becomes the last line moved. *)
val move : t -> int -> int -> int -> unit

(* [delete_global t] deletes every line with [global] set, in one pass
 * (g/re/d) *)
val delete_global : t -> unit

(* marks, for k and 'x. [find_mark] is None when the line is gone. *)
val mark : t -> char -> int -> unit
val find_mark : t -> char -> int option

(* [renamed t old new] moves the marks on [old] to [new] (for s) *)
val renamed : t -> line -> line -> unit

(* the undo pair of the last s: the line before it and the line after
 * it *)
val undo : t -> (line * line) option
val set_undo : t -> (line * line) option -> unit

(* [index t line] is where [line] is, if it is still in the buffer *)
val index : t -> line -> int option
