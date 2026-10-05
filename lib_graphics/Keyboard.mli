(* The keyboard (Plan 9's /dev/cons, raw: libdraw's keyboard.c; xix's
 * lib_graphics/input): what is typed, as it is typed (no line kept by
 * the kernel, no echo), each read a message. Read by a Source. *)

type t

(* the console made raw (/dev/consctl's "rawon", for as long as the
 * program runs) *)
val init : < Cap.keyboard; Cap.fork; .. > -> t
(* the next keys: a read's characters, each its bytes (one for ASCII,
 * more for the others: UTF-8), whole (none, when a read ended inside
 * one: it comes with the next) *)
val receive : t -> string list Event.event

(* the up and down arrows, as Plan 9's keyboard gives them (its runes
 * 0xF00E and 0xF800) *)
val up : string
val down : string
