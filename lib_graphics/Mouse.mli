(* The mouse (Plan 9's /dev/mouse; libdraw's mouse.c; xix's
 * lib_graphics/input): each change of it a message, its place on the
 * screen and its buttons. The device is read by a Source: a thread
 * receives, and may choose between the mouse and something else. *)

(* buttons: 1 the left one, 2 the middle, 4 the right; their sum when
 * several are down *)
type state = { pos : Point.t; buttons : int; msec : int }

type t

val init : < Cap.mouse; Cap.fork; .. > -> t
(* the next change *)
val receive : t -> state Event.event
