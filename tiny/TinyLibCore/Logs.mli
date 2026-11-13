(* Logs: lib_core's module (and opam's), for tiny-ml's programs. A
 * message has a level, and it is shown when its level is the one set or
 * below it (Warning by default). A program writes the same call as in
 * OCaml,
 *
 *     Logs.debug (fun m -> m "%s: %s" file (show_item it))
 *
 * and tiny-ml reads m's format as it reads Printf.sprintf's
 * (TinyML/Parser.ml), so that here m takes the message already made.
 * Like Printf, this module is not a subset of OCaml's. The reporter
 * decides where a message goes; on tiny-kernel it is TinyLibSystem's,
 * which writes to stderr, after the program's name. The options -v,
 * -debug and -quiet set the level (TinyLibSystem.logging). *)

type level = App | Error | Warning | Info | Debug

(* [set_level (Some l)] shows the levels up to l; None shows nothing *)
val set_level : level option -> unit

val app : ((string -> unit) -> unit) -> unit
val err : ((string -> unit) -> unit) -> unit
val warn : ((string -> unit) -> unit) -> unit
val info : ((string -> unit) -> unit) -> unit
val debug : ((string -> unit) -> unit) -> unit

(* where a shown message goes, with its level (by default, to stdout,
 * as a line) *)
val set_reporter : (level -> string -> unit) -> unit
