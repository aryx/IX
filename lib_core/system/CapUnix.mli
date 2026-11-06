(* ix: Unix's functions given a capability (see Cap), the ones ix uses;
 * the capabilities ocaml-caps' (dune's) asks for, written for the
 * reader: mini-ml does not look at an object type's names *)

val fork : < Cap.fork; .. > -> unit -> int
val execv : < Cap.exec; .. > -> string -> string array -> 'a
val execve : < Cap.exec; .. > -> string -> string array -> string array -> 'a
val wait : < Cap.wait; .. > -> unit -> int * Unix.process_status
val waitpid :
  < Cap.wait; .. > -> Unix.wait_flag list -> int -> int * Unix.process_status
val kill : < Cap.kill; .. > -> int -> int -> unit
val chdir : < Cap.chdir; .. > -> string -> unit
val environment : < Cap.env; .. > -> unit -> string array

(* the clock: the time, read or waited for *)
val gettimeofday : < Cap.clock; .. > -> unit -> float
val time : < Cap.clock; .. > -> unit -> float
val sleepf : < Cap.clock; .. > -> float -> unit

val pipe :
  < Cap.pipe; .. > -> cloexec:bool -> unit -> Unix.file_descr * Unix.file_descr

(* what the process is told about where it runs *)
val getpid : < Cap.env; .. > -> unit -> int
val getcwd : < Cap.env; .. > -> unit -> string
(* (not socketpair, getppid, gethostname: plan9/Unix has none, and this
 * file is both systems') *)

(* a timer, which ends in a signal; the end of the process, at once (a
 * forked child's way out); a named pipe made *)
val setitimer :
  < Cap.signal; .. > ->
  Unix.interval_timer -> Unix.interval_timer_status ->
  Unix.interval_timer_status
val _exit : < Cap.exit; .. > -> int -> 'a
val mkfifo : < Cap.open_out; .. > -> string -> Unix.file_perm -> unit

(* the network (Plan 9's Unix: ENOSYS, it dials by /net) *)
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
