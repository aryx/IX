(* The commands by their names: what M-x asks for. A file of commands
 * ends with the list of its own, given to [define_all] (efuns marks
 * each with [@@interactive], which a preprocessor reads). *)

val define : string -> Efuns.action -> unit
val define_all : (string * Efuns.action) list -> unit

val find_opt : string -> Efuns.action option
