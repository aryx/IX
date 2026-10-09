(* TinyLib: lib_core/system/Logs_fmt, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* ix: logs' Logs_fmt, for mini-ml (see Logs): a reporter that writes
 * on dst each message after pp_header's header. Its two labels are
 * optional in the real library, and given here. *)

val reporter : pp_header:(Format.formatter -> Logs.level * string option -> unit) -> dst:Format.formatter -> unit -> Logs.reporter
