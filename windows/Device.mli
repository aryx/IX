(* A file of a window's directory (rio's are the cases of its xfid.c;
 * xix's Device): its name, and what opening, reading, writing and
 * closing it do to its window. A file more is a value of this type,
 * and a line of Fileserver's list.
 *
 * These run in the file server's thread, which must not wait: what
 * touches a window's state is a message to its thread (Window.send),
 * and a read answered when there is something to read raises
 * P9_server.Later. One that refuses raises P9_server.Error. *)

type t = {
  name : string;
  perm : int;
  (* opened, with 9P's mode (0 to read, 1 to write, 2 both) *)
  opened : Window.t -> int -> unit;
  (* a read's offset and count; a file whose text changes under its
   * reader (the mouse) answers each read whole, whatever the offset *)
  read : Window.t -> int -> int -> string;
  write : Window.t -> string -> unit;
  (* closed, by what had it open *)
  closed : Window.t -> unit;
}

(* a file that does nothing: read empty, what is written dropped *)
val default : t
(* a read of a text: what it has from an offset, count bytes at most *)
val part : string -> int -> int -> string
(* a read answered by the window's thread, when it can: the message
 * for it, given how to answer *)
val later : Window.t -> ((string -> bool) -> Window.message) -> 'a
