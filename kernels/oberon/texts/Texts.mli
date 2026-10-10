(* Texts (Oberon's Texts): a text is a sequence of characters, each
 * with its looks (a font, a colour, an offset from the base line),
 * that is read at any position and changed by inserting and deleting
 * stretches of it.
 *
 * It is a list of pieces. A piece is a stretch of a file, with one
 * looks: a text just opened is one piece, its file; what is typed is
 * appended to a file of the writer's and becomes a piece of it;
 * deleting cuts pieces and inserting puts pieces between others. No
 * character is ever moved or copied: a buffer, what was deleted or is
 * to be inserted, is pieces too, and the text of a megabyte is edited
 * as fast as an empty one.
 *
 * Oberon's pieces are a ring of records changed in place, with a
 * cache of the last one found; here a list of values, cut and joined.
 *
 * A text opened on a file F of 11 characters, then two changes (a
 * piece: its file, where it starts there, how many characters):
 *
 *     F: Hello world                     W: (the writer's, empty)
 *     the text: (F, 0, 11)                        Hello world
 *
 *     "big " typed at position 6: the four characters go to the end
 *     of W, and the piece that has position 6 is cut in two
 *     W: big
 *     the text: (F, 0, 6) (W, 0, 4) (F, 6, 5)     Hello big world
 *
 *     the first six deleted, into a buffer
 *     the text: (W, 0, 4) (F, 6, 5)               big world
 *     the buffer: (F, 0, 6)                       to be put back, or
 *                                                 inserted elsewhere
 *
 * F is never written, and W only at its end. Characters typed one
 * after the other stay one piece (join, in Texts.ml: the new piece
 * goes on in W where the last ends, in the same looks). What a text
 * costs is the number of its pieces, that is of the changes made
 * since it was opened: finding position n walks the list. Storing
 * the text writes the pieces' characters in order to a new file,
 * and it is one piece again.
 *
 * A piece has one looks, so the same list is the text's formatting:
 * changing a stretch's font cuts at its two ends and changes the
 * pieces between. A text's file has the looks as runs (a font, a
 * colour, an offset, a length) before the characters.
 *
 * cs-history:
 * The piece table is from Bravo, the first editor that showed a
 * text in its fonts as it would print (Butler Lampson and Charles
 * Simonyi, Xerox PARC, 1974, on the Alto); the structure itself is
 * credited to J Strother Moore (from memory). It suited a machine
 * whose memory held less than a document: the characters stay on
 * the disk. Simonyi took it to Microsoft Word; Wirth and Gutknecht
 * met it at PARC, and Gutknecht's editors for the Lilith and Ceres
 * have it.
 *
 * others:
 * The gap buffer, Emacs's: the text in one array with a hole where
 * the cursor is, typed characters filling the hole, the hole moved
 * (a copy) when the cursor jumps. Simpler, and it needs the text in
 * memory. A list or an array of lines, as mini-ed's Text and vi:
 * good when commands are by line. A balanced tree of pieces (a
 * rope; the piece tree of today's editors) answers the walk of the
 * list above. ed.c's text in a temporary file (mini-ed's Text.mli
 * tells why) is the piece table's other half: the append-only file
 * without the pieces.
 *
 * design:
 * Nothing is overwritten, so nothing needs to be copied to be
 * remembered: a buffer of deleted text is pieces, undo would be a
 * list of old lists (Oberon has none), and several readers may walk
 * a text while it changes. The same idea, values never changed and
 * a new version sharing the old one's parts, is a log-structured
 * file system's and a functional language's lists'; here OCaml's
 * lists make it literal.
 *
 * References: "Project Oberon", chapter 5, "The text system" (the
 * piece list and its operations, drawn). Charles Crowley, "Data
 * Structures for Text Sequences" (1998): the gap, the lines, the
 * pieces and others, compared. Butler Lampson, "Bravo Manual" (in
 * the Alto User's Handbook, Xerox PARC, 1976-1979; from memory).
 * Texts.Mod of Project Oberon 2013.
 *
 * Not here: real numbers (the scanner's, the writers'), a colour's
 * and an offset's change. *)

type piece
type op = Replace | Insert | Delete | Unmark

type t = {
  mutable pieces : piece list;
  mutable len : int;
  mutable changed : bool;
  (* told of each change: what, and from where to where (the text frames' way to know) *)
  mutable notify : t -> op -> int -> int -> unit;
}

(* the text of that file: its bytes in the default font, or, when it
 * starts with Oberon's tag, the runs of looks it says; an empty text
 * when there is no such file *)
val open_ : string -> t
(* the text written as a file of that name, with its looks (Oberon's
 * format, which open_ reads), and the file put in the directory *)
val close : t -> string -> unit

(* A buffer: a stretch of text outside any text *)
type buffer = { mutable stretch : piece list; mutable blen : int }
val open_buf : unit -> buffer
(* [save t beg end_ b]: that stretch of t added to b *)
val save : t -> int -> int -> buffer -> unit
(* [copy src dst]: src's added to dst *)
val copy : buffer -> buffer -> unit
(* [insert t pos b]: b's stretch in t at pos; b is emptied *)
val insert : t -> int -> buffer -> unit
val append : t -> buffer -> unit
(* [delete t beg end_ b]: that stretch out of t, and in b *)
val delete : t -> int -> int -> buffer -> unit
(* [change_looks t beg end_ font]: that stretch in another font *)
val change_looks : t -> int -> int -> Fonts.t -> unit
(* the font at a position (the default's at the end) *)
val attributes : t -> int -> Fonts.t

(* A reader: the characters from a position, one after the other, each
 * with its looks; past the last, eot and a character 0 *)
type reader = {
  mutable eot : bool;
  mutable fnt : Fonts.t;
  mutable col : int;
  mutable voff : int;
  mutable ahead : piece list;      (* the piece being read, and those after *)
  mutable off : int;               (* where in that piece *)
  mutable at : int;                (* the position of the next character *)
}
val open_reader : t -> int -> reader
val read : reader -> char
val pos : reader -> int

(* A writer: what is written is kept, in the writer's looks, as its
 * buffer, for insert or append to put in a text *)
type writer = { mutable buf : buffer; mutable wfnt : Fonts.t; mutable wcol : int; mutable wvoff : int; file : Files.t }
val open_writer : unit -> writer
val write : writer -> char -> unit
val write_string : writer -> string -> unit
val write_ln : writer -> unit
(* [write_int w n width]: in at least that many characters *)
val write_int : writer -> int -> int -> unit

(* A scanner: the text's symbols from a position, for a command to
 * read its parameters: a name (letters, digits and dots: System.Tool),
 * a string in quotes, a number (decimal, or hexadecimal with an H
 * after it), any other character alone. Spaces, tabs and line ends
 * are skipped, the line ends counted. *)
type symbol = Name of string | String of string | Int of int | Char of char
type scanner = { reader : reader; mutable next_ch : char; mutable line : int; mutable sym : symbol }
val open_scanner : t -> int -> scanner
(* the next symbol, in [sym] *)
val scan : scanner -> unit
