(* ix: OCaml's Unix library on Plan 9, for mini-ml (plan_rio.md: ix's
 * programs on mini-9pi), in the place of ../Unix.ml, which is Linux's:
 * the part a shell asks (files, pipes, processes, the environment),
 * with OCaml's names and types, each function a system call of Plan
 * 9's made by one primitive of the runtime. What is not here Plan 9
 * has not, or not yet: a program that names it does not compile for
 * Plan 9.
 *
 * Where Plan 9 is not Unix:
 * - an error is a string of the kernel's: [error_message] gives it
 *   back for the last call that failed, and [Unix_error]'s error is
 *   the errno a program may match (ENOENT, EINTR, ECHILD...) or
 *   EUNKNOWNERR 0;
 * - a process ends with a string: none is [WEXITED 0], one that ends
 *   in a number ("3", "ls 12: 3") that number, a note's name
 *   [WSIGNALED], any other [WEXITED 1]; [_exit n] says n's digits;
 * - the environment is /env's files, a list's words ended by a 0
 *   each: here "name=value" as plan9port's rc has them on Unix, the
 *   words separated by a \001; [execve] writes its environment there;
 * - a signal is a note: [kill] writes its name to /proc/pid/note. *)

type error =
  | E2BIG | EACCES | EAGAIN | EBADF | EBUSY | ECHILD | EDEADLK | EDOM | EEXIST | EFAULT | EFBIG | EINTR | EINVAL | EIO
  | EISDIR | EMFILE | EMLINK | ENAMETOOLONG | ENFILE | ENODEV | ENOENT | ENOEXEC | ENOLCK | ENOMEM | ENOSPC | ENOSYS
  | ENOTDIR | ENOTEMPTY | ENOTTY | ENXIO | EPERM | EPIPE | ERANGE | EROFS | ESPIPE | ESRCH | EXDEV | EWOULDBLOCK
  | EINPROGRESS | EALREADY | ENOTSOCK | EDESTADDRREQ | EMSGSIZE | EPROTOTYPE | ENOPROTOOPT | EPROTONOSUPPORT
  | ESOCKTNOSUPPORT | EOPNOTSUPP | EPFNOSUPPORT | EAFNOSUPPORT | EADDRINUSE | EADDRNOTAVAIL | ENETDOWN | ENETUNREACH
  | ENETRESET | ECONNABORTED | ECONNRESET | ENOBUFS | EISCONN | ENOTCONN | ESHUTDOWN | ETOOMANYREFS | ETIMEDOUT
  | ECONNREFUSED | EHOSTDOWN | EHOSTUNREACH | ELOOP | EOVERFLOW
  | EUNKNOWNERR of int

(* the error, the function's name, its argument (a file's name) or "" *)
exception Unix_error of error * string * string
val error_message : error -> string

(* files *)

type file_descr
val stdin : file_descr
val stdout : file_descr
val stderr : file_descr

(* O_CREAT with O_TRUNC is Plan 9's create; O_CREAT alone opens the
 * file, or creates it; O_APPEND seeks to the end, once *)
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

(* a pipe is S_FIFO, the console S_CHR; the fields Plan 9 has not are 0 *)
type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}
val stat : string -> stats
val fstat : file_descr -> stats
(* the console *)
val isatty : file_descr -> bool

(* (cloexec, and O_CLOEXEC: kept here, the descriptors closed by execv
 * and execve; Plan 9's own is the open file's, kept by dup) *)
val dup : cloexec:bool -> file_descr -> file_descr
val dup2 : file_descr -> file_descr -> unit
val pipe : cloexec:bool -> unit -> file_descr * file_descr
val in_channel_of_descr : file_descr -> in_channel
val out_channel_of_descr : file_descr -> out_channel
val chdir : string -> unit
(* a directory made; a file, or an empty directory, removed (Plan 9's
 * remove is one call for the two); where the process is *)
val mkdir : string -> file_perm -> unit
val unlink : string -> unit
val rmdir : string -> unit
val getcwd : unit -> string

(* processes *)

(* rfork: the descriptors copied; the environment is one for the two,
 * as it is for Plan 9's rc and its children *)
val fork : unit -> int
val execv : string -> string array -> 'a
val execve : string -> string array -> string array -> 'a
type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED
val wait : unit -> int * process_status
(* (the flags: none of them is Plan 9's) *)
val waitpid : wait_flag list -> int -> int * process_status
(* not OCaml's (Sys_plan9's): a child waited for, its last words as
 * the kernel gave them *)
val last_words : int -> string
(* (and the time it took, as the kernel says with them: in the
 * program, in the kernel for it, and from its start to its end, in
 * milliseconds) *)
val last_times : int -> int * int * int
val kill : int -> int -> unit
val getpid : unit -> int
val _exit : int -> 'a
val environment : unit -> string array

(* time *)

val time : unit -> float
val sleepf : float -> unit
type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}
val gmtime : float -> tm

(* not OCaml's (Sys_plan9's): a system call of Plan 9's by its number,
 * with its six arguments (an int, or a string's or bytes' address);
 * its answer, or Unix_error (the function's name and argument given) *)
val plan9_call : string -> string -> int -> Obj.t array -> int
