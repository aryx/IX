(* A file of a window's directory (rio's files are the cases of its
 * xfid.c; xix's Device): its name, and what opening, reading, writing
 * and closing it do to its window. Adding a file means adding a value
 * of this type and a line to Fileserver's list.
 *
 * These functions run in the file server's thread, which must not
 * wait. So whatever touches a window's state is sent as a message to
 * the window's thread (Window.send), and a read that is answered only
 * when there is something to read raises P9_server.Later. A function
 * that refuses raises P9_server.Error. *)

type t = {
  name : string;
  perm : int;
  (* called when the file is opened, with 9P's mode (0 to read, 1 to
   * write, 2 for both) *)
  opened : Window.t -> int -> unit;
  (* called with a read's offset and count. A file whose text changes
   * under its reader (the mouse) answers each read with all of its
   * text, whatever the offset. *)
  read : Window.t -> int -> int -> string;
  write : Window.t -> string -> unit;
  (* called when the file is closed by whoever had it open *)
  closed : Window.t -> unit;
}

(* a file that does nothing: a read gets nothing, and what is written
 * is dropped *)
val default : t
(* a read of a text: the part of it from an offset, count bytes at most *)
val part : string -> int -> int -> string
(* a read that the window's thread answers when it can. The function
 * makes the message for that thread, given how to answer. *)
val later : Window.t -> ((string -> bool) -> Window.message) -> 'a
