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

(* the arrows, as Plan 9's keyboard gives them (its runes: up 0xF00E,
 * down 0xF800, left 0xF011, right 0xF012) *)
val up : string
val down : string
val left : string
val right : string

(* The keys held (/dev/kbd, 9front's file, which mini-9pi's kernel and
 * mini-rio's windows have): the console gives what is typed, and no
 * key's release; this file says, each time a key goes down or comes up,
 * which keys are down. For a game, which asks whether left is held. *)
type held
(* (None: no such file here) *)
val held : < Cap.keyboard; Cap.fork; .. > -> held option
(* the next change, as the file gives it: k or K, the keys, a zero byte *)
val message : held -> string Event.event
(* a message's keys: the ones down now, each its character's bytes (a
 * letter is its small one, whatever Shift does) *)
val keys : string -> string list
(* Shift, Ctl and Alt, as keys (Plan 9's runes 0xF860, 0xF862, 0xF863) *)
val shift : string
val ctrl : string
val alt : string
