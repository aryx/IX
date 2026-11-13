(* ix: a poor man's logging library for mini-ml, like xix's own
 * (lib_core/commons/Logs). It has the interface of logs, the library of
 * Daniel Bünzli (https://erratique.ch/software/logs), for the part that
 * ix's programs use, written again in a few lines. It is bundled here
 * just for mini-ml: dune's builds of ix take the real library (this
 * directory is not dune's). The real library has sources, tags, and a
 * reporter that is a record of polymorphic functions with optional
 * arguments. There is none of that here: a reporter is only a printer
 * for the header and a formatter.
 *
 * A message is written by a function that is given the printer to
 * call, as in Logs.debug (fun m -> m "read %a" Fpath.pp file), so that
 * nothing is formatted when the level says not to report it. *)

type level = App | Error | Warning | Info | Debug

(* Sets what is reported: the levels up to this one, or nothing for
 * None. The level is Warning at first. *)
val set_level : level option -> unit

(* "quiet" (None), "app", "error", "warning", "info", "debug" *)
val level_of_string : string -> (level option, string) result
val level_to_string : level option -> string

type 'a msgf = (('a, Format.formatter, unit) format -> 'a) -> unit
type 'a log = 'a msgf -> unit

val app : 'a log
val err : 'a log
val warn : 'a log
val info : 'a log
val debug : 'a log

(* A reporter says where the messages go, and what header comes before
 * each one (Logs_fmt.reporter makes one). At first nothing is reported,
 * as with the real library. *)
type reporter = { pp_header : Format.formatter -> level * string option -> unit; dst : Format.formatter }
val set_reporter : reporter -> unit
