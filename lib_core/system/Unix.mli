(* ix: the part of OCaml's Unix library that ix's programs use, for
 * mini-ml (dune's builds take OCaml's, because this directory is not
 * dune's). Its names, types and behaviour are those of OCaml's Unix
 * (unix.mli), but it is written again, in OCaml. Each function is a
 * system call of Linux (on arm and arm64), made by one primitive of the
 * runtime, and the kernel's structures are packed and read as bytes
 * here. So there is no C for it and no libc under it, and it works the
 * same with goken's libc and with glibc. A label that is optional in
 * OCaml's Unix (?cloexec) must be given here.
 *
 * A system call is the one door between a program and everything
 * outside its memory. The program asks with a number and up to six
 * words, and the kernel does the thing. Here is a call's way down, and
 * back:
 *
 *     Unix.openfile "notes" [ O_RDONLY ] 0
 *       |   the flags become bits, the path becomes an address
 *       v
 *     syscall 322 [| -100; "notes"; bits; 0; 0; 0 |]      openat: 322 on
 *       |   the runtime's one primitive                 arm, 56 on arm64;
 *       v                                               -100: from the
 *     the kernel, entered by the processor's trap       current directory
 *       |
 *       v
 *     3, a descriptor;  or -2, and here
 *     Unix_error (ENOENT, "open", "notes")
 *
 * So the whole interface of the system is a table of numbers, a
 * convention for the arguments, and the layout of a few structures
 * (stat's, a directory's entries, a time), all in the .ml. That is the
 * lowest layer of a C library, read in one file. An error is the
 * kernel's negative number turned into an exception. C's errno, a
 * global variable to look at after a -1, is the library's doing, not
 * the kernel's.
 *
 * Two things differ by machine. The first is the numbers: Linux gave
 * arm64 a new and shorter table, with no open (openat does it), no fork
 * (clone does it) and no pipe (pipe2 does it). The second is the int:
 * on arm it has 31 bits, so a file's size, its offset (LargeFile, in
 * int64) and the seconds since 1970 (floats, read from the kernel's
 * words as int64) do not go through an int.
 *
 * Where it stands: it is under every program of ix that mini-ml
 * compiles for Linux. Console, FS and Procs call it, with a capability
 * (Cap). The same interface over Plan 9's system calls is the Unix of
 * the plan9 directory, for mini-9pi, where the kernel that answers is
 * ix's own.
 *
 * others:
 * Go does the same on Linux: its runtime makes the system calls itself
 * and links no C library. Most languages go through libc, and on
 * systems other than Linux they must, because the numbers are not a
 * promise there: the C library is the interface, and the kernel's door
 * behind it may change at any release.
 *
 * References: syscall(2) and syscalls(2) of Linux's manual, for the
 * convention of each machine and the list of calls; OCaml's unix.mli,
 * whose comments say what each function does. *)

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

(* An int, as in the system, but abstract, as in OCaml. *)
type file_descr
val stdin : file_descr
val stdout : file_descr
val stderr : file_descr

type open_flag =
  | O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_APPEND | O_CREAT | O_TRUNC | O_EXCL | O_NOCTTY | O_DSYNC | O_SYNC
  | O_RSYNC | O_SHARE_DELETE | O_CLOEXEC | O_KEEPEXEC
type file_perm = int

val openfile : string -> open_flag list -> file_perm -> file_descr
val close : file_descr -> unit

(* read reads what is there, up to len bytes, into buf at ofs. write
 * writes all len bytes. *)
val read : file_descr -> bytes -> int -> int -> int
val write : file_descr -> bytes -> int -> int -> int
val write_substring : file_descr -> string -> int -> int -> int

type seek_command = SEEK_SET | SEEK_CUR | SEEK_END
val lseek : file_descr -> int -> seek_command -> int
val ftruncate : file_descr -> int -> unit

type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}
val stat : string -> stats
val lstat : string -> stats
val fstat : file_descr -> stats
val isatty : file_descr -> bool

(* The same functions, with a size and an offset of 64 bits. *)
module LargeFile : sig
  val lseek : file_descr -> int64 -> seek_command -> int64
  type stats = {
    st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
    st_rdev : int; st_size : int64; st_atime : float; st_mtime : float; st_ctime : float;
  }
  val stat : string -> stats
  val lstat : string -> stats
  val fstat : file_descr -> stats
end

val unlink : string -> unit
val link : string -> string -> unit
val rename : string -> string -> unit
val chmod : string -> file_perm -> unit
val fchmod : file_descr -> file_perm -> unit
type access_permission = R_OK | W_OK | X_OK | F_OK
val access : string -> access_permission list -> unit
val readlink : string -> string
val realpath : string -> string
(* When both times are 0.0, the file gets the current time. *)
val utimes : string -> float -> float -> unit

val dup : cloexec:bool -> file_descr -> file_descr
val dup2 : file_descr -> file_descr -> unit
val set_nonblock : file_descr -> unit
val clear_nonblock : file_descr -> unit
val set_close_on_exec : file_descr -> unit
val pipe : cloexec:bool -> unit -> file_descr * file_descr

val in_channel_of_descr : file_descr -> in_channel
val out_channel_of_descr : file_descr -> out_channel

(* directories *)

val mkdir : string -> file_perm -> unit
val mkfifo : string -> file_perm -> unit
val rmdir : string -> unit
val chdir : string -> unit
val getcwd : unit -> string
type dir_handle
val opendir : string -> dir_handle
(* The next name (. and .. included), or End_of_file after the last
 * one. *)
val readdir : dir_handle -> string
val closedir : dir_handle -> unit

(* processes *)

val fork : unit -> int
val execv : string -> string array -> 'a
val execve : string -> string array -> string array -> 'a
val create_process : string -> string array -> file_descr -> file_descr -> file_descr -> int
type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED
val wait : unit -> int * process_status
val waitpid : wait_flag list -> int -> int * process_status
(* The signal is one of Sys's (Sys.sigint...), or the system's
 * number. *)
val kill : int -> int -> unit
val getpid : unit -> int
val getppid : unit -> int
val _exit : int -> 'a
(* The environment as "NAME=value" strings, read from
 * /proc/self/environ. *)
val environment : unit -> string array
val gethostname : unit -> string

(* time *)

val time : unit -> float
val gettimeofday : unit -> float
val sleepf : float -> unit
type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}
val gmtime : float -> tm

(* sockets *)

type socket_domain = PF_UNIX | PF_INET | PF_INET6
type socket_type = SOCK_STREAM | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET
(* an IPv4 address *)
type inet_addr
val inet_addr_any : inet_addr
val inet_addr_loopback : inet_addr
(* The address of "a.b.c.d", or Failure; and the string of an
 * address. *)
val inet_addr_of_string : string -> inet_addr
val string_of_inet_addr : inet_addr -> string
type sockaddr = ADDR_UNIX of string | ADDR_INET of inet_addr * int

val socket : socket_domain -> socket_type -> int -> file_descr
val socketpair : socket_domain -> socket_type -> int -> file_descr * file_descr
val bind : file_descr -> sockaddr -> unit
val listen : file_descr -> int -> unit
(* The socket's own address. It gives the port that the system chose
 * after a bind to port 0. *)
val getsockname : file_descr -> sockaddr
(* OCaml's Unix has ten options. Here there is only the one that lets a
 * server bind again to the port it just left. *)
type socket_bool_option = SO_REUSEADDR
val setsockopt : file_descr -> socket_bool_option -> bool -> unit
val accept : file_descr -> file_descr * sockaddr
val connect : file_descr -> sockaddr -> unit
(* recvfrom reads a datagram with the address of its sender, and
 * sendto_substring sends one to an address. They are for a socket that
 * is not connected (a UDP server's). *)
type msg_flag = MSG_OOB | MSG_DONTROUTE | MSG_PEEK
val recvfrom : file_descr -> bytes -> int -> int -> msg_flag list -> int * sockaddr
val sendto_substring : file_descr -> string -> int -> int -> msg_flag list -> sockaddr -> int
type shutdown_command = SHUTDOWN_RECEIVE | SHUTDOWN_SEND | SHUTDOWN_ALL
val shutdown : file_descr -> shutdown_command -> unit

(* The addresses of a host. Here the host is a numeric address,
 * "localhost", or a name in /etc/hosts; there is no resolver, so
 * another name gives []. The service is a number or one of a few
 * names. *)
type addr_info = { ai_family : socket_domain; ai_socktype : socket_type; ai_protocol : int; ai_addr : sockaddr; ai_canonname : string }
type getaddrinfo_option =
  | AI_FAMILY of socket_domain | AI_SOCKTYPE of socket_type | AI_PROTOCOL of int | AI_NUMERICHOST | AI_CANONNAME | AI_PASSIVE
val getaddrinfo : string -> string -> getaddrinfo_option list -> addr_info list

(* Of the descriptors given, the ones ready to be read, the ones ready
 * to be written, and the ones in error, after at most that many seconds
 * (a negative number means no limit). *)
val select : file_descr list -> file_descr list -> file_descr list -> float -> file_descr list * file_descr list * file_descr list

(* The settings of a terminal. (This is OCaml's record; the speeds are
 * read but not set.) *)

type terminal_io = {
  mutable c_ignbrk : bool; mutable c_brkint : bool; mutable c_ignpar : bool; mutable c_parmrk : bool; mutable c_inpck : bool;
  mutable c_istrip : bool; mutable c_inlcr : bool; mutable c_igncr : bool; mutable c_icrnl : bool; mutable c_ixon : bool;
  mutable c_ixoff : bool; mutable c_opost : bool; mutable c_obaud : int; mutable c_ibaud : int; mutable c_csize : int;
  mutable c_cstopb : int; mutable c_cread : bool; mutable c_parenb : bool; mutable c_parodd : bool; mutable c_hupcl : bool;
  mutable c_clocal : bool; mutable c_isig : bool; mutable c_icanon : bool; mutable c_noflsh : bool; mutable c_echo : bool;
  mutable c_echoe : bool; mutable c_echok : bool; mutable c_echonl : bool; mutable c_vintr : char; mutable c_vquit : char;
  mutable c_verase : char; mutable c_vkill : char; mutable c_veof : char; mutable c_veol : char; mutable c_vmin : int;
  mutable c_vtime : int; mutable c_vstart : char; mutable c_vstop : char;
}
type setattr_when = TCSANOW | TCSADRAIN | TCSAFLUSH
val tcgetattr : file_descr -> terminal_io
val tcsetattr : file_descr -> setattr_when -> terminal_io -> unit

(* A timer that sends a signal, SIGALRM for ITIMER_REAL. *)

type interval_timer = ITIMER_REAL | ITIMER_VIRTUAL | ITIMER_PROF
type interval_timer_status = { it_interval : float; it_value : float }
val setitimer : interval_timer -> interval_timer_status -> interval_timer_status
