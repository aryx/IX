(* TinyLib: lib_core/system/CapUnix, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* ix: Unix's functions given a capability (see Cap), the ones ix uses *)

val fork : < .. > -> unit -> int
val execv : < .. > -> string -> string array -> 'a
val execve : < .. > -> string -> string array -> string array -> 'a
val wait : < .. > -> unit -> int * Unix.process_status
val waitpid : < .. > -> Unix.wait_flag list -> int -> int * Unix.process_status
val chdir : < .. > -> string -> unit
val environment : < .. > -> unit -> string array
