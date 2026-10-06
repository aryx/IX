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
 * Not here yet: a text stored (Store, Close), the scanner. *)

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
val write_int : writer -> int -> unit
