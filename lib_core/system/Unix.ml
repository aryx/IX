(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Unix.mli *)

(*****************************************************************************)
(* The system call *)
(*****************************************************************************)

(* the call's number, its six arguments: each an int, a string or bytes
 * (their address), an int32 or an int64 (their value); the kernel's
 * answer, a negative errno when it fails *)
external syscall : int -> Obj.t array -> int = "unix_syscall"
external exec : string -> string array -> string array -> int = "unix_execve"

let arm64 = Sys.word_size = 64
let i (n : int) = Obj.repr n
let s (x : string) = Obj.repr x
let z = Obj.repr 0

(* nr: the call's numbers, arm's (EABI) and arm64's *)
let sys (a32, a64) a b c d e f = syscall (if arm64 then a64 else a32) [| a; b; c; d; e; f |]

(* the directory a relative path is of: the current one *)
let cwd = i (-100)

(* a long of the kernel's, in a structure: 4 bytes on arm, 8 on arm64 *)
let long = if arm64 then 8 else 4
(* as an int64: the seconds since 1970 don't fit arm's int of 31 bits *)
let get_long b o = if arm64 then Bytes.get_int64_le b o else Int64.of_int32 (Bytes.get_int32_le b o)
let set_long b o (n : int64) = if arm64 then Bytes.set_int64_le b o n else Bytes.set_int32_le b o (Int64.to_int32 n)

(* seconds as a float, in a structure: the seconds, then their fraction
 * in units (10^9 for nanoseconds) *)
let set_time b o t units =
  set_long b o (Int64.of_float (floor t));
  set_long b (o + long) (Int64.of_float ((t -. floor t) *. units))
let u32 b o = Int64.to_int (Int64.logand (Int64.of_int32 (Bytes.get_int32_le b o)) 0xffffffffL)

(* a C string in b, from o to its 0 *)
let cstring b o = let e = try String.index_from b o '\000' with Not_found -> String.length b in String.sub b o (e - o)

(*****************************************************************************)
(* Errors *)
(*****************************************************************************)

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

(* Linux's errno, the error, its message (strerror's) *)
let errors = [
  1, EPERM, "Operation not permitted"; 2, ENOENT, "No such file or directory"; 3, ESRCH, "No such process";
  4, EINTR, "Interrupted system call"; 5, EIO, "Input/output error"; 6, ENXIO, "No such device or address";
  7, E2BIG, "Argument list too long"; 8, ENOEXEC, "Exec format error"; 9, EBADF, "Bad file descriptor";
  10, ECHILD, "No child processes"; 11, EAGAIN, "Resource temporarily unavailable"; 12, ENOMEM, "Cannot allocate memory";
  13, EACCES, "Permission denied"; 14, EFAULT, "Bad address"; 16, EBUSY, "Device or resource busy"; 17, EEXIST, "File exists";
  18, EXDEV, "Invalid cross-device link"; 19, ENODEV, "No such device"; 20, ENOTDIR, "Not a directory";
  21, EISDIR, "Is a directory"; 22, EINVAL, "Invalid argument"; 23, ENFILE, "Too many open files in system";
  24, EMFILE, "Too many open files"; 25, ENOTTY, "Inappropriate ioctl for device"; 27, EFBIG, "File too large";
  28, ENOSPC, "No space left on device"; 29, ESPIPE, "Illegal seek"; 30, EROFS, "Read-only file system";
  31, EMLINK, "Too many links"; 32, EPIPE, "Broken pipe"; 33, EDOM, "Numerical argument out of domain";
  34, ERANGE, "Numerical result out of range"; 35, EDEADLK, "Resource deadlock avoided"; 36, ENAMETOOLONG, "File name too long";
  37, ENOLCK, "No locks available"; 38, ENOSYS, "Function not implemented"; 39, ENOTEMPTY, "Directory not empty";
  40, ELOOP, "Too many levels of symbolic links"; 75, EOVERFLOW, "Value too large for defined data type";
  88, ENOTSOCK, "Socket operation on non-socket"; 89, EDESTADDRREQ, "Destination address required";
  90, EMSGSIZE, "Message too long"; 91, EPROTOTYPE, "Protocol wrong type for socket"; 92, ENOPROTOOPT, "Protocol not available";
  93, EPROTONOSUPPORT, "Protocol not supported"; 94, ESOCKTNOSUPPORT, "Socket type not supported";
  95, EOPNOTSUPP, "Operation not supported"; 96, EPFNOSUPPORT, "Protocol family not supported";
  97, EAFNOSUPPORT, "Address family not supported by protocol"; 98, EADDRINUSE, "Address already in use";
  99, EADDRNOTAVAIL, "Cannot assign requested address"; 100, ENETDOWN, "Network is down"; 101, ENETUNREACH, "Network is unreachable";
  102, ENETRESET, "Network dropped connection on reset"; 103, ECONNABORTED, "Software caused connection abort";
  104, ECONNRESET, "Connection reset by peer"; 105, ENOBUFS, "No buffer space available";
  106, EISCONN, "Transport endpoint is already connected"; 107, ENOTCONN, "Transport endpoint is not connected";
  108, ESHUTDOWN, "Cannot send after transport endpoint shutdown"; 109, ETOOMANYREFS, "Too many references: cannot splice";
  110, ETIMEDOUT, "Connection timed out"; 111, ECONNREFUSED, "Connection refused"; 112, EHOSTDOWN, "Host is down";
  113, EHOSTUNREACH, "No route to host"; 114, EALREADY, "Operation already in progress"; 115, EINPROGRESS, "Operation now in progress";
]

let error_message (e : error) =
  match e with
  | EUNKNOWNERR n -> "Unknown error " ^ string_of_int n
  | EWOULDBLOCK -> "Resource temporarily unavailable"
  | _ -> (match List.find_opt (fun (_, e', _) -> e' = e) errors with Some (_, _, m) -> m | None -> "Unknown error")

let error_of n = match List.find_opt (fun (n', _, _) -> n' = n) errors with Some (_, e, _) -> e | None -> EUNKNOWNERR n

(* a call's answer, or its error raised: the function's name, its argument *)
(* a signal noted meanwhile: its handler is run first, as OCaml does.
 * After every call, not only an interrupted one (EINTR): a signal that
 * comes between two calls interrupts none, and its handler never ran
 * (mini-rc's sigint, 1 run in 100 on a busy machine: bugs/ix.md).
 * old: if r = -4 then run_signals (); *)
let check fn arg r =
  run_signals ();
  if r < 0 then raise (Unix_error (error_of (-r), fn, arg)) else r
let unit fn arg r = ignore (check fn arg r)

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

type file_descr = int
let stdin = 0 and stdout = 1 and stderr = 2

type open_flag =
  | O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_APPEND | O_CREAT | O_TRUNC | O_EXCL | O_NOCTTY | O_DSYNC | O_SYNC
  | O_RSYNC | O_SHARE_DELETE | O_CLOEXEC | O_KEEPEXEC
type file_perm = int

let o_cloexec = 0o2000000
let flag = function
  | O_RDONLY -> 0 | O_WRONLY -> 1 | O_RDWR -> 2 | O_NONBLOCK -> 0o4000 | O_APPEND -> 0o2000 | O_CREAT -> 0o100
  | O_TRUNC -> 0o1000 | O_EXCL -> 0o200 | O_NOCTTY -> 0o400 | O_DSYNC -> 0o10000 | O_SYNC | O_RSYNC -> 0o4010000
  | O_CLOEXEC -> o_cloexec | O_SHARE_DELETE | O_KEEPEXEC -> 0

(* openat; on arm O_LARGEFILE, for a file of more than 2 GB *)
let open_bits fn path bits perm = check fn path (sys (322, 56) cwd (s path) (i (bits lor (if arm64 then 0 else 0o400000))) (i perm) z z)
let openfile path flags perm = open_bits "open" path (List.fold_left (fun a f -> a lor flag f) 0 flags) perm
let close fd = unit "close" "" (sys (6, 57) (i fd) z z z z z)

let bounds fn buf ofs len = if ofs < 0 || len < 0 || ofs > Bytes.length buf - len then invalid_arg ("Unix." ^ fn)

(* the bytes go through a buffer of their own when not at buf's start:
 * the call takes an address, and only a block's is known here *)
let read fd buf ofs len =
  bounds "read" buf ofs len;
  let b = if ofs = 0 then buf else Bytes.create len in
  let n = check "read" "" (sys (3, 63) (i fd) (s b) (i len) z z z) in
  if ofs <> 0 then Bytes.blit b 0 buf ofs n;
  n

let rec write fd buf ofs len =
  bounds "write" buf ofs len;
  if len = 0 then 0
  else begin
    let n = check "write" "" (sys (4, 64) (i fd) (s (if ofs = 0 then buf else Bytes.sub buf ofs len)) (i len) z z z) in
    if n < len then n + write fd buf (ofs + n) (len - n) else n
  end
let write_substring = write

type seek_command = SEEK_SET | SEEK_CUR | SEEK_END
let whence = function SEEK_SET -> 0 | SEEK_CUR -> 1 | SEEK_END -> 2

(* arm's lseek takes 32 bits: _llseek, the offset's two halves, the
 * answer in 8 bytes *)
let lseek64 fd (off : int64) cmd : int64 =
  if arm64 then Int64.of_int (check "lseek" "" (sys (19, 62) (i fd) (Obj.repr off) (i (whence cmd)) z z z))
  else begin
    let res = Bytes.create 8 in
    unit "lseek" "" (syscall 140 [| i fd; Obj.repr (Int64.to_int32 (Int64.shift_right off 32)); Obj.repr (Int64.to_int32 off); s res; i (whence cmd); z |]);
    Bytes.get_int64_le res 0
  end
let lseek fd off cmd = Int64.to_int (lseek64 fd (Int64.of_int off) cmd)
let ftruncate fd len = unit "ftruncate" "" (sys (93, 46) (i fd) (i len) z z z z)

type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}

(* statx: one structure for every machine (stat's is each machine's) *)
let statx fn fd path flags =
  let b = Bytes.create 256 in
  unit fn path (sys (397, 291) fd (s path) (i flags) (i 0x7ff) (s b) z);
  b

let kind mode =
  match mode land 0o170000 with
  | 0o100000 -> S_REG | 0o040000 -> S_DIR | 0o020000 -> S_CHR | 0o060000 -> S_BLK | 0o120000 -> S_LNK | 0o010000 -> S_FIFO
  | _ -> S_SOCK

(* a device's number of its two halves, as glibc's makedev *)
let dev b o = let major = u32 b o and minor = u32 b (o + 4) in (major lsl 8) lor (minor land 0xff) lor ((minor lsr 8) lsl 20)
let stamp b o = Int64.to_float (Bytes.get_int64_le b o) +. (Float.of_int (u32 b (o + 8)) /. 1e9)

(* what the two stats (the size an int, or an int64) have in common *)
let common b =
  let mode = Bytes.get_uint16_le b 28 in
  dev b 136, Int64.to_int (Bytes.get_int64_le b 32), kind mode, mode land 0o7777, u32 b 16, u32 b 20, u32 b 24, dev b 128,
  stamp b 64, stamp b 112, stamp b 96

let stats_of b : stats =
  let st_dev, st_ino, st_kind, st_perm, st_nlink, st_uid, st_gid, st_rdev, st_atime, st_mtime, st_ctime = common b in
  { st_dev; st_ino; st_kind; st_perm; st_nlink; st_uid; st_gid; st_rdev; st_size = Int64.to_int (Bytes.get_int64_le b 40);
    st_atime; st_mtime; st_ctime }

let stat path = stats_of (statx "stat" cwd path 0)
let lstat path = stats_of (statx "lstat" cwd path 0x100)
let fstat fd = stats_of (statx "fstat" (i fd) "" 0x1000)

(* a terminal answers the ioctl that reads its settings *)
let isatty fd = sys (54, 29) (i fd) (i 0x5401) (s (Bytes.create 64)) z z z >= 0

module LargeFile = struct
  let lseek = lseek64
  type stats = {
    st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
    st_rdev : int; st_size : int64; st_atime : float; st_mtime : float; st_ctime : float;
  }
  let large b : stats =
    let st_dev, st_ino, st_kind, st_perm, st_nlink, st_uid, st_gid, st_rdev, st_atime, st_mtime, st_ctime = common b in
    { st_dev; st_ino; st_kind; st_perm; st_nlink; st_uid; st_gid; st_rdev; st_size = Bytes.get_int64_le b 40; st_atime; st_mtime;
      st_ctime }
  let stat path = large (statx "stat" cwd path 0)
  let lstat path = large (statx "lstat" cwd path 0x100)
  let fstat fd = large (statx "fstat" (i fd) "" 0x1000)
end

let unlink path = unit "unlink" path (sys (328, 35) cwd (s path) z z z z)
let rename a b = unit "rename" a (sys (382, 276) cwd (s a) cwd (s b) z z)
let chmod path perm = unit "chmod" path (sys (333, 53) cwd (s path) (i perm) z z z)
let fchmod fd perm = unit "fchmod" "" (sys (94, 52) (i fd) (i perm) z z z z)

type access_permission = R_OK | W_OK | X_OK | F_OK
let access path perms =
  let mode = List.fold_left (fun a p -> a lor (match p with R_OK -> 4 | W_OK -> 2 | X_OK -> 1 | F_OK -> 0)) 0 perms in
  unit "access" path (sys (334, 48) cwd (s path) (i mode) z z z)

let readlink path =
  let b = Bytes.create 4096 in
  String.sub b 0 (check "readlink" path (sys (332, 78) cwd (s path) (s b) (i 4096) z z))

(* the file opened as a path only (O_PATH), its name asked of /proc *)
let realpath path =
  let fd = open_bits "realpath" path (0o10000000 lor o_cloexec) 0 in
  let p = try readlink ("/proc/self/fd/" ^ string_of_int fd) with e -> unit "close" "" (sys (6, 57) (i fd) z z z z z); raise e in
  close fd;
  p

(* utimensat: two times, each seconds and nanoseconds *)
let utimes path atime mtime =
  let b = Bytes.create (4 * long) in
  set_time b 0 atime 1e9;
  set_time b (2 * long) mtime 1e9;
  unit "utimes" path (sys (348, 88) cwd (s path) (if atime = 0.0 && mtime = 0.0 then z else s b) z z z)

let fcntl fd cmd arg = check "fcntl" "" (sys (55, 25) (i fd) (i cmd) (i arg) z z z)
let dup ~cloexec fd = if cloexec then fcntl fd 1030 0 else check "dup" "" (sys (41, 23) (i fd) z z z z z)
let dup2 src dst = if src <> dst then unit "dup2" "" (sys (358, 24) (i src) (i dst) z z z z)
let set_nonblock fd = ignore (fcntl fd 4 (fcntl fd 3 0 lor 0o4000))
let clear_nonblock fd = ignore (fcntl fd 4 (fcntl fd 3 0 land lnot 0o4000))
let set_close_on_exec fd = ignore (fcntl fd 2 1)

let pipe ~cloexec () =
  let b = Bytes.create 8 in
  unit "pipe" "" (sys (359, 59) (s b) (i (if cloexec then o_cloexec else 0)) z z z z);
  Int32.to_int (Bytes.get_int32_le b 0), Int32.to_int (Bytes.get_int32_le b 4)

external in_channel_of_descr : file_descr -> in_channel = "caml_open_descriptor"
external out_channel_of_descr : file_descr -> out_channel = "caml_open_descriptor"

(*****************************************************************************)
(* Directories *)
(*****************************************************************************)

let mkdir path perm = unit "mkdir" path (sys (323, 34) cwd (s path) (i perm) z z z)
let rmdir path = unit "rmdir" path (sys (328, 35) cwd (s path) (i 0x200) z z z)
let chdir path = unit "chdir" path (sys (12, 49) (s path) z z z z z)
let getcwd () = let b = Bytes.create 4096 in unit "getcwd" "" (sys (183, 17) (s b) (i 4096) z z z z); cstring b 0

(* the entries read by getdents64, a buffer at a time; pos in the len
 * bytes read *)
type dir_handle = { fd : file_descr; buf : Bytes.t; mutable pos : int; mutable len : int }
let opendir path = { fd = open_bits "opendir" path (0o40000 lor o_cloexec) 0; buf = Bytes.create 4096; pos = 0; len = 0 }
let readdir d =
  if d.pos >= d.len then begin
    d.len <- check "readdir" "" (sys (217, 61) (i d.fd) (s d.buf) (i 4096) z z z);
    d.pos <- 0;
    if d.len = 0 then raise End_of_file
  end;
  (* an entry: its length at 16, its name at 19 *)
  let o = d.pos in
  d.pos <- o + Bytes.get_uint16_le d.buf (o + 16);
  cstring d.buf (o + 19)
let closedir d = close d.fd

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* the environment, as the kernel shows it: NAME=value, each ended by 0 *)
let environment () =
  let fd = openfile "/proc/self/environ" [ O_RDONLY ] 0 and all = Buffer.create 4096 and b = Bytes.create 4096 in
  let rec go () = let n = read fd b 0 4096 in if n > 0 then begin Buffer.add_subbytes all b 0 n; go () end in
  go ();
  close fd;
  Array.of_list (List.filter (fun v -> v <> "") (String.split_on_char '\000' (Buffer.contents all)))

(* clone with SIGCHLD only: fork (arm64 has no other) *)
let fork () = check "fork" "" (sys (120, 220) (i 17) z z z z z)
let exec_as fn prog args env = raise (Unix_error (error_of (- (exec prog args env)), fn, prog))
let execve prog args env = exec_as "execve" prog args env
let execv prog args = exec_as "execv" prog args (environment ())

(* Sys's signals (negative, the same on every system) and Linux's *)
let to_linux = Sys.system_signal
let of_linux n = match List.find_opt (fun (_, n') -> n' = n) Sys.system_signals with Some (sg, _) -> sg | None -> n

type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED

let wait4 fn flags pid =
  let b = Bytes.make 4 '\000' in
  let opts = List.fold_left (fun a f -> a lor (match f with WNOHANG -> 1 | WUNTRACED -> 2)) 0 flags in
  let r = check fn "" (sys (114, 260) (i pid) (s b) (i opts) z z z) in
  let st = Int32.to_int (Bytes.get_int32_le b 0) in
  r, (if st land 0x7f = 0 then WEXITED ((st lsr 8) land 0xff)
      else if st land 0xff = 0x7f then WSTOPPED (of_linux ((st lsr 8) land 0xff))
      else WSIGNALED (of_linux (st land 0x7f)))
let waitpid flags pid = wait4 "waitpid" flags pid
let wait () = wait4 "wait" [] (-1)

(* a signal to oneself has come when kill is back: its handler run *)
let kill pid sg = unit "kill" "" (sys (37, 129) (i pid) (i (to_linux sg)) z z z z); run_signals ()
let getpid () = sys (20, 172) z z z z z z
let getppid () = sys (64, 173) z z z z z z
let _exit n = ignore (sys (248, 94) (i n) z z z z z); exit n

(* uname: six names of 65 bytes, the node's the second *)
let gethostname () = let b = Bytes.make 390 '\000' in unit "gethostname" "" (sys (122, 160) (s b) z z z z z); cstring b 65

(*****************************************************************************)
(* Time *)
(*****************************************************************************)

let gettimeofday () =
  let b = Bytes.create (2 * long) in
  unit "gettimeofday" "" (sys (78, 169) (s b) z z z z z);
  Int64.to_float (get_long b 0) +. (Int64.to_float (get_long b long) /. 1e6)
let time () = floor (gettimeofday ())

let sleepf d =
  let b = Bytes.create (2 * long) in
  set_time b 0 d 1e9;
  unit "sleepf" "" (sys (162, 101) (s b) z z z z z)

type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}

(* the day's date by counting from March 1st of year 0, in periods of
 * 400 years (146097 days): a leap day is then a period's last *)
let gmtime t =
  (* by floats: the seconds don't fit arm's int *)
  let days = Float.to_int (floor (t /. 86400.0)) in
  let secs = Float.to_int (floor t -. (Float.of_int days *. 86400.0)) in
  let d = days + 719468 in
  let era = (if d >= 0 then d else d - 146096) / 146097 in
  let doe = d - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let month = if mp < 10 then mp + 3 else mp - 9 in
  let year = yoe + (era * 400) + (if month <= 2 then 1 else 0) in
  let leap = (year mod 4 = 0 && year mod 100 <> 0) || year mod 400 = 0 in
  let before = [| 0; 31; 59; 90; 120; 151; 181; 212; 243; 273; 304; 334 |] in
  { tm_sec = secs mod 60; tm_min = secs / 60 mod 60; tm_hour = secs / 3600; tm_mday = doy - (((153 * mp) + 2) / 5) + 1;
    tm_mon = month - 1; tm_year = year - 1900; tm_wday = (((days mod 7) + 11) mod 7);
    tm_yday = before.(month - 1) + (doy - (((153 * mp) + 2) / 5)) + (if leap && month > 2 then 1 else 0); tm_isdst = false }

(*****************************************************************************)
(* Sockets *)
(*****************************************************************************)

type socket_domain = PF_UNIX | PF_INET | PF_INET6
type socket_type = SOCK_STREAM | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET
(* an IPv4 address: its 4 bytes *)
type inet_addr = string
type sockaddr = ADDR_UNIX of string | ADDR_INET of inet_addr * int

let inet_addr_any = "\000\000\000\000"
let inet_addr_loopback = "\127\000\000\001"
let string_of_inet_addr (a : inet_addr) = String.concat "." (List.init 4 (fun k -> string_of_int (Char.code a.[k])))
let inet_addr_of_string s : inet_addr =
  match List.map int_of_string_opt (String.split_on_char '.' s) with
  | [ Some a; Some b; Some c; Some d ] when List.for_all (fun n -> n >= 0 && n < 256) [ a; b; c; d ] ->
      String.init 4 (fun k -> Char.chr (List.nth [ a; b; c; d ] k))
  | _ -> failwith "inet_addr_of_string"

let domain = function PF_UNIX -> 1 | PF_INET -> 2 | PF_INET6 -> 10
let socktype = function SOCK_STREAM -> 1 | SOCK_DGRAM -> 2 | SOCK_RAW -> 3 | SOCK_SEQPACKET -> 5

(* the kernel's sockaddr: the family in 2 bytes, then a path ended by 0,
 * or a port (the high byte first) and the address *)
let pack = function
  | ADDR_UNIX path -> "\001\000" ^ path ^ "\000"
  | ADDR_INET (a, port) -> "\002\000" ^ String.make 1 (Char.chr (port lsr 8)) ^ String.make 1 (Char.chr (port land 0xff)) ^ a ^ String.make 8 '\000'
let unpack b len =
  if len >= 8 && Bytes.get_uint16_le b 0 = 2 then ADDR_INET (String.sub b 4 4, Bytes.get_uint16_be b 2)
  else ADDR_UNIX (if len > 2 then cstring (String.sub b 0 len ^ "\000") 2 else "")

let socket d t proto = check "socket" "" (sys (281, 198) (i (domain d)) (i (socktype t)) (i proto) z z z)
let socketpair d t proto =
  let b = Bytes.create 8 in
  unit "socketpair" "" (sys (288, 199) (i (domain d)) (i (socktype t)) (i proto) (s b) z z);
  Int32.to_int (Bytes.get_int32_le b 0), Int32.to_int (Bytes.get_int32_le b 4)
let bind fd addr = let a = pack addr in unit "bind" "" (sys (282, 200) (i fd) (s a) (i (String.length a)) z z z)
let connect fd addr = let a = pack addr in unit "connect" "" (sys (283, 203) (i fd) (s a) (i (String.length a)) z z z)
let listen fd n = unit "listen" "" (sys (284, 201) (i fd) (i n) z z z z)
let accept fd =
  let b = Bytes.make 112 '\000' and len = Bytes.create 4 in
  Bytes.set_int32_le len 0 112l;
  let c = check "accept" "" (sys (285, 202) (i fd) (s b) (s len) z z z) in
  c, unpack b (Int32.to_int (Bytes.get_int32_le len 0))
type shutdown_command = SHUTDOWN_RECEIVE | SHUTDOWN_SEND | SHUTDOWN_ALL
let shutdown fd how = unit "shutdown" "" (sys (293, 210) (i fd) (i (match how with SHUTDOWN_RECEIVE -> 0 | SHUTDOWN_SEND -> 1 | SHUTDOWN_ALL -> 2)) z z z z)

type addr_info = { ai_family : socket_domain; ai_socktype : socket_type; ai_protocol : int; ai_addr : sockaddr; ai_canonname : string }
type getaddrinfo_option =
  | AI_FAMILY of socket_domain | AI_SOCKTYPE of socket_type | AI_PROTOCOL of int | AI_NUMERICHOST | AI_CANONNAME | AI_PASSIVE

(* /etc/hosts' lines: an address, then its names *)
let hosts name =
  try
    let ic = open_in "/etc/hosts" in
    let rec go acc = match input_line ic with
      | l -> (
          match List.filter (fun w -> w <> "") (String.split_on_char ' ' (String.map (fun c -> if c = '\t' then ' ' else c) l)) with
          | a :: names when List.mem name names -> go (a :: acc)
          | _ -> go acc)
      | exception End_of_file -> close_in ic; List.rev acc in
    go []
  with Sys_error _ -> []

let getaddrinfo host service opts =
  let port = match int_of_string_opt service, List.assoc_opt service [ "", 0; "http", 80; "https", 443; "ssh", 22; "git", 9418 ] with
    | Some p, _ | None, Some p -> Some p
    | None, None -> None in
  let addrs = List.filter_map (fun a -> try Some (inet_addr_of_string a) with Failure _ -> None)
    (if host = "" || host = "localhost" then [ "127.0.0.1" ] else host :: hosts host) in
  let ai_socktype = List.fold_left (fun t o -> match o with AI_SOCKTYPE t -> t | _ -> t) SOCK_STREAM opts in
  match port with
  | Some port -> List.map (fun a -> { ai_family = PF_INET; ai_socktype; ai_protocol = 0; ai_addr = ADDR_INET (a, port); ai_canonname = "" }) addrs
  | None -> []

(* ppoll: a descriptor's 8 bytes, its number, what is asked, what is so *)
let select r w e timeout =
  let all = List.map (fun fd -> fd, 1) r @ List.map (fun fd -> fd, 4) w @ List.map (fun fd -> fd, 2) e in
  let b = Bytes.make ((8 * List.length all) + 8) '\000' in
  List.iteri (fun k (fd, ev) -> Bytes.set_int32_le b (8 * k) (Int32.of_int fd); Bytes.set_uint16_le b ((8 * k) + 4) ev) all;
  let ts = Bytes.create (2 * long) in
  if timeout >= 0.0 then set_time ts 0 timeout 1e9;
  unit "select" "" (sys (336, 73) (s b) (i (List.length all)) (if timeout >= 0.0 then s ts else z) z (i 8) z);
  (* ready: what was asked, or an error or a hangup (to be read then) *)
  let ready ev fds base = List.filteri (fun k _ -> Bytes.get_uint16_le b ((8 * (base + k)) + 6) land (ev lor 0x18) <> 0) fds in
  ready 1 r 0, ready 4 w (List.length r), ready 2 e (List.length r + List.length w)

(*****************************************************************************)
(* Terminals *)
(*****************************************************************************)

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

(* the kernel's termios: four words of flags (input, output, control,
 * local) at 0, 4, 8, 12, the line at 16, the characters from 17 *)
let termios fn fd = let b = Bytes.make 64 '\000' in unit fn "" (sys (54, 29) (i fd) (i 0x5401) (s b) z z z); b
let speeds = [ 0o1, 50; 0o2, 75; 0o3, 110; 0o4, 134; 0o5, 150; 0o6, 200; 0o7, 300; 0o10, 600; 0o11, 1200; 0o12, 1800; 0o13, 2400;
               0o14, 4800; 0o15, 9600; 0o16, 19200; 0o17, 38400; 0o10001, 57600; 0o10002, 115200; 0o10003, 230400 ]

let tcgetattr fd =
  let b = termios "tcgetattr" fd in
  let bit o m = u32 b o land m <> 0 and cc k = Bytes.get b (17 + k) in
  let baud = match List.assoc_opt (u32 b 8 land 0o10017) speeds with Some n -> n | None -> 0 in
  { c_ignbrk = bit 0 0o1; c_brkint = bit 0 0o2; c_ignpar = bit 0 0o4; c_parmrk = bit 0 0o10; c_inpck = bit 0 0o20;
    c_istrip = bit 0 0o40; c_inlcr = bit 0 0o100; c_igncr = bit 0 0o200; c_icrnl = bit 0 0o400; c_ixon = bit 0 0o2000;
    c_ixoff = bit 0 0o10000; c_opost = bit 4 0o1; c_obaud = baud; c_ibaud = baud; c_csize = 5 + ((u32 b 8 land 0o60) lsr 4);
    c_cstopb = (if bit 8 0o100 then 2 else 1); c_cread = bit 8 0o200; c_parenb = bit 8 0o400; c_parodd = bit 8 0o1000;
    c_hupcl = bit 8 0o2000; c_clocal = bit 8 0o4000; c_isig = bit 12 0o1; c_icanon = bit 12 0o2; c_noflsh = bit 12 0o200;
    c_echo = bit 12 0o10; c_echoe = bit 12 0o20; c_echok = bit 12 0o40; c_echonl = bit 12 0o100; c_vintr = cc 0; c_vquit = cc 1;
    c_verase = cc 2; c_vkill = cc 3; c_veof = cc 4; c_veol = cc 11; c_vmin = Char.code (cc 6); c_vtime = Char.code (cc 5);
    c_vstart = cc 8; c_vstop = cc 9 }

(* the settings read again, the record's bits put in them: what the
 * record doesn't say (the speeds, the kernel's other bits) stays *)
let tcsetattr fd w (t : terminal_io) =
  let b = termios "tcsetattr" fd in
  let set o m on = Bytes.set_int32_le b o (Int32.of_int (if on then u32 b o lor m else u32 b o land lnot m)) in
  List.iter (fun (o, m, on) -> set o m on)
    [ 0, 0o1, t.c_ignbrk; 0, 0o2, t.c_brkint; 0, 0o4, t.c_ignpar; 0, 0o10, t.c_parmrk; 0, 0o20, t.c_inpck; 0, 0o40, t.c_istrip;
      0, 0o100, t.c_inlcr; 0, 0o200, t.c_igncr; 0, 0o400, t.c_icrnl; 0, 0o2000, t.c_ixon; 0, 0o10000, t.c_ixoff; 4, 0o1, t.c_opost;
      8, 0o60, false; 8, (t.c_csize - 5) lsl 4, true; 8, 0o100, t.c_cstopb = 2; 8, 0o200, t.c_cread; 8, 0o400, t.c_parenb;
      8, 0o1000, t.c_parodd; 8, 0o2000, t.c_hupcl; 8, 0o4000, t.c_clocal; 12, 0o1, t.c_isig; 12, 0o2, t.c_icanon;
      12, 0o200, t.c_noflsh; 12, 0o10, t.c_echo; 12, 0o20, t.c_echoe; 12, 0o40, t.c_echok; 12, 0o100, t.c_echonl ];
  List.iter (fun (k, c) -> Bytes.set b (17 + k) c)
    [ 0, t.c_vintr; 1, t.c_vquit; 2, t.c_verase; 3, t.c_vkill; 4, t.c_veof; 11, t.c_veol; 6, Char.chr t.c_vmin; 5, Char.chr t.c_vtime;
      8, t.c_vstart; 9, t.c_vstop ];
  unit "tcsetattr" "" (sys (54, 29) (i fd) (i (match w with TCSANOW -> 0x5402 | TCSADRAIN -> 0x5403 | TCSAFLUSH -> 0x5404)) (s b) z z z)

(*****************************************************************************)
(* Timers *)
(*****************************************************************************)

type interval_timer = ITIMER_REAL | ITIMER_VIRTUAL | ITIMER_PROF
type interval_timer_status = { it_interval : float; it_value : float }

(* two times, each seconds and microseconds: the interval, the value *)
let setitimer which (t : interval_timer_status) =
  let b = Bytes.create (4 * long) and old = Bytes.make (4 * long) '\000' in
  set_time b 0 t.it_interval 1e6;
  set_time b (2 * long) t.it_value 1e6;
  unit "setitimer" "" (sys (104, 103) (i (match which with ITIMER_REAL -> 0 | ITIMER_VIRTUAL -> 1 | ITIMER_PROF -> 2)) (s b) (s old) z z z);
  let time o = Int64.to_float (get_long old o) +. (Int64.to_float (get_long old (o + long)) /. 1e6) in
  { it_interval = time 0; it_value = time (2 * long) }
