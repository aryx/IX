(* ix: the functions of Unix that ix uses, each given a capability (see
 * Cap). They ask for the capabilities that ocaml-caps (the library of
 * dune's builds) asks for. These are written for the reader, because
 * mini-ml does not look at the names in an object type. *)

val fork : < Cap.fork; .. > -> unit -> int
val execv : < Cap.exec; .. > -> string -> string array -> 'a
val execve : < Cap.exec; .. > -> string -> string array -> string array -> 'a
val wait : < Cap.wait; .. > -> unit -> int * Unix.process_status
val waitpid :
  < Cap.wait; .. > -> Unix.wait_flag list -> int -> int * Unix.process_status
val kill : < Cap.kill; .. > -> int -> int -> unit
val chdir : < Cap.chdir; .. > -> string -> unit
val environment : < Cap.env; .. > -> unit -> string array

(* The clock: these read the time, or wait for some time. *)
val gettimeofday : < Cap.clock; .. > -> unit -> float
val time : < Cap.clock; .. > -> unit -> float
val sleepf : < Cap.clock; .. > -> float -> unit

val pipe :
  < Cap.pipe; .. > -> cloexec:bool -> unit -> Unix.file_descr * Unix.file_descr

(* These tell the process about where it runs. *)
val getpid : < Cap.env; .. > -> unit -> int
val getcwd : < Cap.env; .. > -> unit -> string
(* (There is no socketpair, getppid or gethostname here, because
 * plan9/Unix has none of them, and this file serves both systems.) *)

(* setitimer sets a timer, which ends in a signal. _exit ends the
 * process at once (this is how a forked child leaves). mkfifo makes a
 * named pipe. *)
val setitimer :
  < Cap.signal; .. > ->
  Unix.interval_timer -> Unix.interval_timer_status ->
  Unix.interval_timer_status
val _exit : < Cap.exit; .. > -> int -> 'a
val mkfifo : < Cap.open_out; .. > -> string -> Unix.file_perm -> unit

(* The network. (Plan 9's Unix raises ENOSYS for these, because Plan 9
 * dials through /net.) *)
val getaddrinfo :
  < Cap.network; .. > ->
  string -> string -> Unix.getaddrinfo_option list -> Unix.addr_info list
val socket :
  < Cap.network; .. > -> Unix.socket_domain -> Unix.socket_type -> int ->
  Unix.file_descr
val connect : < Cap.network; .. > -> Unix.file_descr -> Unix.sockaddr -> unit
val bind : < Cap.network; .. > -> Unix.file_descr -> Unix.sockaddr -> unit
val listen : < Cap.network; .. > -> Unix.file_descr -> int -> unit
val accept :
  < Cap.network; .. > -> Unix.file_descr -> Unix.file_descr * Unix.sockaddr
