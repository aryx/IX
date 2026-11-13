(* ix: the Logs_fmt module of the logs library, for mini-ml (see Logs).
 * Its reporter writes each message on dst, after the header that
 * pp_header prints. Its two labels are optional in the real library,
 * and must be given here. *)

val reporter : pp_header:(Format.formatter -> Logs.level * string option -> unit) -> dst:Format.formatter -> unit -> Logs.reporter
