(* ix: OCaml's Unix library on Plan 9, for mini-ml (see plan_rio.md,
 * which runs ix's programs on mini-9pi). It takes the place of
 * ../Unix.ml, which is for Linux. It has the part that a shell needs
 * (files, pipes, processes, the environment), with OCaml's names and
 * types, and each function is a system call of Plan 9 made by one
 * primitive of the runtime. What is not here, Plan 9 does not have, or
 * not yet: a program that names it does not compile for Plan 9.
 *
 * Where Plan 9 is not Unix:
 * - An error is a string from the kernel. [error_message] gives back
 *   the string of the last call that failed, and the error in
 *   [Unix_error] is the errno that a program may match (ENOENT, EINTR,
 *   ECHILD...), or EUNKNOWNERR 0.
 * - A process ends with a string. No string gives [WEXITED 0]; a string
 *   that ends in a number ("3", "ls 12: 3") gives that number; the name
 *   of a note gives [WSIGNALED]; any other string gives [WEXITED 1].
 *   [_exit n] ends with the digits of n.
 * - The environment is the files of /env, each holding the words of a
 *   list, each word ended by a 0. Here a variable is "name=value", as
 *   plan9port's rc has it on Unix, with the words separated by a \001.
 *   [execve] writes its environment there.
 * - A signal is a note: [kill] writes the note's name to
 *   /proc/pid/note. *)

type error =
  | E2BIG | EACCES | EAGAIN | EBADF | EBUSY | ECHILD | EDEADLK | EDOM | EEXIST | EFAULT | EFBIG | EINTR | EINVAL | EIO
  | EISDIR | EMFILE | EMLINK | ENAMETOOLONG | ENFILE | ENODEV | ENOENT | ENOEXEC | ENOLCK | ENOMEM | ENOSPC | ENOSYS
  | ENOTDIR | ENOTEMPTY | ENOTTY | ENXIO | EPERM | EPIPE | ERANGE | EROFS | ESPIPE | ESRCH | EXDEV | EWOULDBLOCK
  | EINPROGRESS | EALREADY | ENOTSOCK | EDESTADDRREQ | EMSGSIZE | EPROTOTYPE | ENOPROTOOPT | EPROTONOSUPPORT
  | ESOCKTNOSUPPORT | EOPNOTSUPP | EPFNOSUPPORT | EAFNOSUPPORT | EADDRINUSE | EADDRNOTAVAIL | ENETDOWN | ENETUNREACH
  | ENETRESET | ECONNABORTED | ECONNRESET | ENOBUFS | EISCONN | ENOTCONN | ESHUTDOWN | ETOOMANYREFS | ETIMEDOUT
  | ECONNREFUSED | EHOSTDOWN | EHOSTUNREACH | ELOOP | EOVERFLOW
  | EUNKNOWNERR of int

(* The error, the name of the function, and its argument (a file's name)
 * or "". *)
exception Unix_error of error * string * string
val error_message : error -> string

(* files *)

type file_descr
val stdin : file_descr
val stdout : file_descr
val stderr : file_descr

(* O_CREAT with O_TRUNC is Plan 9's create. O_CREAT alone opens the
 * file, or creates it. O_APPEND seeks to the end, once. *)
type open_flag =
  | O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_APPEND | O_CREAT | O_TRUNC | O_EXCL | O_NOCTTY | O_DSYNC | O_SYNC
  | O_RSYNC | O_SHARE_DELETE | O_CLOEXEC | O_KEEPEXEC
type file_perm = int
val openfile : string -> open_flag list -> file_perm -> file_descr
val close : file_descr -> unit
val read : file_descr -> bytes -> int -> int -> int
val write : file_descr -> bytes -> int -> int -> int
val write_substring : file_descr -> string -> int -> int -> int
type seek_command = SEEK_SET | SEEK_CUR | SEEK_END
val lseek : file_descr -> int -> seek_command -> int

(* lseek with an offset of 64 bits (for an address of /proc/$pid/mem
 * above 2^30). *)
module LargeFile : sig
  val lseek : file_descr -> int64 -> seek_command -> int64
end

(* A pipe is S_FIFO, and the console is S_CHR. The fields that Plan 9
 * does not have are 0. *)
type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}
val stat : string -> stats
val fstat : file_descr -> stats
(* Whether the descriptor is the console. *)
val isatty : file_descr -> bool

(* (cloexec and O_CLOEXEC are kept here, in a list of the descriptors
 * that execv and execve close. Plan 9's own flag belongs to the open
 * file, and dup keeps it.) *)
val dup : cloexec:bool -> file_descr -> file_descr
val dup2 : file_descr -> file_descr -> unit
val pipe : cloexec:bool -> unit -> file_descr * file_descr
val in_channel_of_descr : file_descr -> in_channel
val out_channel_of_descr : file_descr -> out_channel
val chdir : string -> unit
(* mkdir makes a directory. unlink and rmdir remove a file or an empty
 * directory (Plan 9's remove is one call for both). getcwd tells where
 * the process is. *)
val mkdir : string -> file_perm -> unit
val unlink : string -> unit
val rmdir : string -> unit
val getcwd : unit -> string

(* processes *)

(* An rfork that copies the descriptors. The two processes share one
 * environment, as Plan 9's rc and its children do. *)
val fork : unit -> int
val execv : string -> string array -> 'a
val execve : string -> string array -> string array -> 'a
type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED
val wait : unit -> int * process_status
(* (Plan 9 has none of the flags.) *)
val waitpid : wait_flag list -> int -> int * process_status
(* This is not OCaml's; it is for Sys_plan9. It gives the last words of
 * a child that was waited for, as the kernel gave them. *)
val last_words : int -> string
(* (And the time the child took, which the kernel gives with its last
 * words: in the program, in the kernel for it, and from its start to
 * its end, in milliseconds.) *)
val last_times : int -> int * int * int
val kill : int -> int -> unit
val getpid : unit -> int
val _exit : int -> 'a
val create_process : string -> string array -> file_descr -> file_descr -> file_descr -> int
val environment : unit -> string array

(* time *)

val time : unit -> float
(* The seconds, with their fraction. *)
val gettimeofday : unit -> float
(* Sets the time when a file was written. The time when it was read
 * (the first argument) is not kept, so it is ignored. With 0. and 0.,
 * the time set is now. *)
val utimes : string -> float -> float -> unit
val sleepf : float -> unit
type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}
val gmtime : float -> tm

(* This is not OCaml's; it is for Sys_plan9. It makes a system call of
 * Plan 9 by its number, with its six arguments (each an int, or the
 * address of a string or of bytes). It returns the kernel's answer, or
 * raises Unix_error with the function's name and argument it is
 * given. *)
val plan9_call : string -> string -> int -> Obj.t array -> int

(* A timer that sends a signal. Here it sends the note "alarm" once,
 * after [it_value] seconds (0 means none). The note is ignored, so that
 * the program goes on, and the system call it interrupts fails with
 * EINTR. *)
type interval_timer = ITIMER_REAL | ITIMER_VIRTUAL | ITIMER_PROF
type interval_timer_status = { it_interval : float; it_value : float }
val setitimer : interval_timer -> interval_timer_status -> interval_timer_status

(* A named pipe, and the sockets. Plan 9 has neither (it dials through
 * /net). The types are OCaml's, so that a function written for both
 * systems (in CapUnix) can name them. Each call fails with Unix_error
 * (ENOSYS), as OCaml's Unix does on Windows for what Windows lacks. *)
val mkfifo : string -> file_perm -> unit
type socket_domain = PF_UNIX | PF_INET | PF_INET6
type socket_type = SOCK_STREAM | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET
type inet_addr
type sockaddr = ADDR_UNIX of string | ADDR_INET of inet_addr * int
val socket : socket_domain -> socket_type -> int -> file_descr
val bind : file_descr -> sockaddr -> unit
val listen : file_descr -> int -> unit
val accept : file_descr -> file_descr * sockaddr
val connect : file_descr -> sockaddr -> unit
type addr_info = {
  ai_family : socket_domain; ai_socktype : socket_type; ai_protocol : int;
  ai_addr : sockaddr; ai_canonname : string }
type getaddrinfo_option =
  | AI_FAMILY of socket_domain | AI_SOCKTYPE of socket_type
  | AI_PROTOCOL of int | AI_NUMERICHOST | AI_CANONNAME | AI_PASSIVE
val getaddrinfo : string -> string -> getaddrinfo_option list -> addr_info list
