(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* lib_core's Unix on .NET, in its place (mini-ml -dotnet -L takes
 * dotnet/'s unit of a name over lib_core's): its system calls by their
 * numbers (system/Unix.ml's unix_syscall) have no .NET form, so its
 * functions fail, by their names, where a program calls them; those a
 * .NET program has by Sys are Sys's (getcwd, chdir, unlink, rename,
 * mkdir). So the units over Unix compile (commons/'s FS, Console,
 * Procs...), and what of them a program uses without Unix runs: FS's
 * files by channels, Console's by Pervasives'. Its types those of
 * system/Unix.mli, which is its interface; a descriptor an int.
 * Generated from Unix.mli, then edited by hand. *)

let no (f : string) : 'a = failwith ("Unix." ^ f ^ ": no system calls on .NET")

type error =
  | E2BIG | EACCES | EAGAIN | EBADF | EBUSY | ECHILD | EDEADLK | EDOM | EEXIST | EFAULT | EFBIG | EINTR | EINVAL | EIO
  | EISDIR | EMFILE | EMLINK | ENAMETOOLONG | ENFILE | ENODEV | ENOENT | ENOEXEC | ENOLCK | ENOMEM | ENOSPC | ENOSYS
  | ENOTDIR | ENOTEMPTY | ENOTTY | ENXIO | EPERM | EPIPE | ERANGE | EROFS | ESPIPE | ESRCH | EXDEV | EWOULDBLOCK
  | EINPROGRESS | EALREADY | ENOTSOCK | EDESTADDRREQ | EMSGSIZE | EPROTOTYPE | ENOPROTOOPT | EPROTONOSUPPORT
  | ESOCKTNOSUPPORT | EOPNOTSUPP | EPFNOSUPPORT | EAFNOSUPPORT | EADDRINUSE | EADDRNOTAVAIL | ENETDOWN | ENETUNREACH
  | ENETRESET | ECONNABORTED | ECONNRESET | ENOBUFS | EISCONN | ENOTCONN | ESHUTDOWN | ETOOMANYREFS | ETIMEDOUT
  | ECONNREFUSED | EHOSTDOWN | EHOSTUNREACH | ELOOP | EOVERFLOW
  | EUNKNOWNERR of int
exception Unix_error of error * string * string
let error_message (_ : error) : string = "a system error"
type file_descr = int
let stdin : file_descr = 0
let stdout : file_descr = 1
let stderr : file_descr = 2
type open_flag =
  | O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_APPEND | O_CREAT | O_TRUNC | O_EXCL | O_NOCTTY | O_DSYNC | O_SYNC
  | O_RSYNC | O_SHARE_DELETE | O_CLOEXEC | O_KEEPEXEC
type file_perm = int
let openfile _ _ _ = no "openfile"
let close _ = no "close"
let read _ _ _ _ = no "read"
let write _ _ _ _ = no "write"
let write_substring _ _ _ _ = no "write_substring"
type seek_command = SEEK_SET | SEEK_CUR | SEEK_END
let lseek _ _ _ = no "lseek"
let ftruncate _ _ = no "ftruncate"
type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}
let stat _ = no "stat"
let lstat _ = no "lstat"
let fstat _ = no "fstat"
let isatty _ = no "isatty"
module LargeFile = struct
  let lseek _ _ _ = no "lseek"
  type stats = {
    st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
    st_rdev : int; st_size : int64; st_atime : float; st_mtime : float; st_ctime : float;
  }
  let stat _ = no "stat"
  let lstat _ = no "lstat"
  let fstat _ = no "fstat"
end
let unlink (f : string) : unit = Sys.remove f
let link _ _ = no "link"
let rename (a : string) (b : string) : unit = Sys.rename a b
let chmod _ _ = no "chmod"
let fchmod _ _ = no "fchmod"
type access_permission = R_OK | W_OK | X_OK | F_OK
let access _ _ = no "access"
let readlink _ = no "readlink"
let realpath _ = no "realpath"
let utimes _ _ _ = no "utimes"
let dup ~cloexec:(_ : bool) _ = no "dup"
let dup2 _ _ = no "dup2"
let set_nonblock _ = no "set_nonblock"
let clear_nonblock _ = no "clear_nonblock"
let set_close_on_exec _ = no "set_close_on_exec"
let pipe ~cloexec:(_ : bool) _ = no "pipe"
let in_channel_of_descr _ = no "in_channel_of_descr"
let out_channel_of_descr _ = no "out_channel_of_descr"
let mkdir (d : string) (p : file_perm) : unit = Sys.mkdir d p
let mkfifo _ _ = no "mkfifo"
let rmdir _ = no "rmdir"
let chdir (d : string) : unit = Sys.chdir d
let getcwd () : string = Sys.getcwd ()
type dir_handle = int
let opendir _ = no "opendir"
let readdir _ = no "readdir"
let closedir _ = no "closedir"
let fork _ = no "fork"
let execv _ _ = no "execv"
let execve _ _ _ = no "execve"
let create_process _ _ _ _ _ = no "create_process"
type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED
let wait _ = no "wait"
let waitpid _ _ = no "waitpid"
let kill _ _ = no "kill"
let getpid _ = no "getpid"
let getppid _ = no "getppid"
let _exit _ = no "_exit"
let environment _ = no "environment"
let gethostname _ = no "gethostname"
let time _ = no "time"
let gettimeofday _ = no "gettimeofday"
let sleepf _ = no "sleepf"
type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}
let gmtime _ = no "gmtime"
type socket_domain = PF_UNIX | PF_INET | PF_INET6
type socket_type = SOCK_STREAM | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET
type inet_addr = string
let inet_addr_any : inet_addr = "0.0.0.0"
let inet_addr_loopback : inet_addr = "127.0.0.1"
let inet_addr_of_string _ = no "inet_addr_of_string"
let string_of_inet_addr _ = no "string_of_inet_addr"
type sockaddr = ADDR_UNIX of string | ADDR_INET of inet_addr * int
let socket _ _ _ = no "socket"
let socketpair _ _ _ = no "socketpair"
let bind _ _ = no "bind"
let listen _ _ = no "listen"
let getsockname _ = no "getsockname"
type socket_bool_option = SO_REUSEADDR
let setsockopt _ _ _ = no "setsockopt"
let accept _ = no "accept"
let connect _ _ = no "connect"
type msg_flag = MSG_OOB | MSG_DONTROUTE | MSG_PEEK
let recvfrom _ _ _ _ _ = no "recvfrom"
let sendto_substring _ _ _ _ _ _ = no "sendto_substring"
type shutdown_command = SHUTDOWN_RECEIVE | SHUTDOWN_SEND | SHUTDOWN_ALL
let shutdown _ _ = no "shutdown"
type addr_info = { ai_family : socket_domain; ai_socktype : socket_type; ai_protocol : int; ai_addr : sockaddr; ai_canonname : string }
type getaddrinfo_option =
  | AI_FAMILY of socket_domain | AI_SOCKTYPE of socket_type | AI_PROTOCOL of int | AI_NUMERICHOST | AI_CANONNAME | AI_PASSIVE
let getaddrinfo _ _ _ = no "getaddrinfo"
let select _ _ _ _ = no "select"
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
let tcgetattr _ = no "tcgetattr"
let tcsetattr _ _ _ = no "tcsetattr"
type interval_timer = ITIMER_REAL | ITIMER_VIRTUAL | ITIMER_PROF
type interval_timer_status = { it_interval : float; it_value : float }
let setitimer _ _ = no "setitimer"
