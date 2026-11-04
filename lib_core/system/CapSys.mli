(* ix: Sys's functions given a capability (see Cap), the ones ix uses *)

val argv : < .. > -> string array
val getenv : < .. > -> string -> string

(* the processor time used (Cap.clock), profiling's *)
val time : < .. > -> unit -> float
(* Cap.env *)
val getcwd : < .. > -> unit -> string
