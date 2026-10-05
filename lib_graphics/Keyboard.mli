(* The keyboard (Plan 9's /dev/cons, raw: libdraw's keyboard.c; xix's
 * lib_graphics/input): what is typed, as it is typed (no line kept by
 * the kernel, no echo), each read a message. Read by a Source. *)

type t

(* the console made raw (/dev/consctl's "rawon", for as long as the
 * program runs) *)
val init : < Cap.keyboard; Cap.fork; .. > -> t
(* the next keys: a read's bytes (a key is a character, of several
 * bytes when it is not ASCII: UTF-8) *)
val receive : t -> string Event.event
