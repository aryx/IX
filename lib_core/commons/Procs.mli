(* What the builder and the shell both do with children and pipes. These
 * are the loops around Unix's calls that would otherwise break on an
 * interrupt (EINTR) or on a reader that quit (EPIPE). *)

(* Writes all of the string to the descriptor. If the reader quits,
 * what it left unread is dropped. *)
val write_all : Unix.file_descr -> string -> unit

(* Reads all that the descriptor gives, up to its end *)
val read_all : Unix.file_descr -> string

(* Waits for the child to end *)
val waitpid : < Cap.wait; .. > -> int -> Unix.process_status

(* Waits for any child to end; None when there is no child *)
val wait_any : < Cap.wait; .. > -> (int * Unix.process_status) option

(* Splits an environment's NAME=value entries at the first =. The
 * entries without one are dropped. *)
val split_env : string array -> (string * string) list

(* Starts a child running [prog] (looked up in $PATH when it has no '/')
 * with [args] after it, and returns its pid. Its standard input and
 * output are the descriptors given, and its standard error is ours. A
 * program that cannot be run exits 127 with a message, as a shell's
 * child does. *)
val spawn : < Cap.fork; Cap.exec; .. > -> string -> string list -> stdin:Unix.file_descr -> stdout:Unix.file_descr -> int

(* The same, by Unix.create_process, which does not fork in OCaml 5 (it
 * uses posix_spawn). A program that has spawned a domain uses this,
 * because OCaml 5's Unix.fork fails after one; mini-netscape's helpers
 * are run this way, since its worker is a domain. A program that
 * cannot be run raises Unix_error, in the calling program. *)
val create_process : < Cap.exec; .. > -> string -> string list -> stdin:Unix.file_descr -> stdout:Unix.file_descr -> int
