(* What the builder and the shell do alike with children and pipes:
 * the loops around Unix's calls that an interrupt (EINTR) or a
 * reader that quit (EPIPE) would otherwise break. *)

(* all of the string to the descriptor; what a reader that quit left
 * unread is dropped *)
val write_all : Unix.file_descr -> string -> unit

(* all the descriptor gives, to its end *)
val read_all : Unix.file_descr -> string

(* the child's end *)
val waitpid : < Cap.wait; .. > -> int -> Unix.process_status

(* any child's end; None when there is no child *)
val wait_any : < Cap.wait; .. > -> (int * Unix.process_status) option

(* an environment's NAME=value entries, split at the first =; the
 * entries without one dropped *)
val split_env : string array -> (string * string) list

(* a child running [prog] (looked up in $PATH when it has no '/') with
 * [args] after it, its standard input and output the descriptors
 * given, its standard error ours; its pid. A program that cannot be
 * run exits 127 with a message, as a shell's child does. *)
val spawn : < Cap.fork; Cap.exec; .. > -> string -> string list -> stdin:Unix.file_descr -> stdout:Unix.file_descr -> int

(* the same by Unix.create_process, with no fork in OCaml 5 (posix_spawn):
 * what a program that has spawned a domain runs, since OCaml 5's
 * Unix.fork fails after one (mini-netscape's helpers, its worker a
 * domain). A program that cannot be run: Unix_error, in OCaml's. *)
val create_process : < Cap.exec; .. > -> string -> string list -> stdin:Unix.file_descr -> stdout:Unix.file_descr -> int
