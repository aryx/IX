(* ix: Unix's functions given a capability (see Cap), the ones ix uses *)

val fork : < .. > -> unit -> int
val execv : < .. > -> string -> string array -> 'a
val execve : < .. > -> string -> string array -> string array -> 'a
val wait : < .. > -> unit -> int * Unix.process_status
val waitpid : < .. > -> Unix.wait_flag list -> int -> int * Unix.process_status
val kill : < .. > -> int -> int -> unit
val chdir : < .. > -> string -> unit
val environment : < .. > -> unit -> string array

(* the clock (Cap.clock): the time, read or waited for *)
val gettimeofday : < .. > -> unit -> float
val time : < .. > -> unit -> float
val sleepf : < .. > -> float -> unit

(* Cap.pipe *)
val pipe : < .. > -> cloexec:bool -> unit -> Unix.file_descr * Unix.file_descr

(* Cap.env: what the process is told about where it runs *)
val getpid : < .. > -> unit -> int
val getcwd : < .. > -> unit -> string
(* (not socketpair, getppid, gethostname: plan9/Unix has none, and this
 * file is both systems') *)
