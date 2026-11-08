(* Logs, lib_core's (and opam's) for tiny-ml's programs: a message at a
 * level, said when the level is the one set or below it (Warning by
 * default). A program writes OCaml's call,
 *
 *     Logs.debug (fun m -> m "%s: %s" file (show_item it))
 *
 * and tiny-ml reads m's format as Printf.sprintf's (TinyMLParser), so
 * that here m takes the message made: like Printf's, not a subset of
 * OCaml's. Where it goes is the reporter's, TinyLibSystem's on
 * tiny-kernel (stderr, after the program's name); its -v, -debug and
 * -quiet set the level (TinyLibSystem.logging). *)

type level = App | Error | Warning | Info | Debug

(* what is said: the levels up to this one; None, nothing *)
val set_level : level option -> unit

val app : ((string -> unit) -> unit) -> unit
val err : ((string -> unit) -> unit) -> unit
val warn : ((string -> unit) -> unit) -> unit
val info : ((string -> unit) -> unit) -> unit
val debug : ((string -> unit) -> unit) -> unit

(* where a message said goes, with its level (by default stdout, a
 * line) *)
val set_reporter : (level -> string -> unit) -> unit
