(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Unix.mli *)

(*****************************************************************************)
(* The system call *)
(*****************************************************************************)

(* the call's number (Plan 9's: libc's sys.h) and six arguments, each an
 * int, or a string or bytes (their address); the kernel's answer, -1
 * when it fails (the runtime's unix_syscall, libc's _syscall6) *)
external syscall : int -> Obj.t array -> int = "unix_syscall"
(* exec, its arguments as C's (the third is Unix's environment: not Plan 9's) *)
external exec : string -> string array -> string array -> int = "unix_execve"

let i (n : int) = Obj.repr n
let s (x : string) = Obj.repr x
let z = Obj.repr 0
let sys nr a b c d e = syscall nr [| a; b; c; d; e; z |]

let rfork = 1 and exits = 3 and await = 4 and open_ = 6 and close_ = 7 and dup_ = 8 and fd2path = 9 and pread = 10
and pwrite = 11 and seek = 12 and create = 13 and remove = 14 and chdir_ = 15 and stat_ = 16 and fstat_ = 17 and sleep = 23
and pipe_ = 27 and errstr = 39

(* a C string in b, to its 0 *)
let cstring b = let t = Bytes.to_string b in match String.index_opt t '\000' with Some e -> String.sub t 0 e | None -> t

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

(* the kernel's words (a part of them), the errno a program matches *)
let errors = [
  "does not exist", ENOENT; "not found", ENOENT; "permission denied", EACCES; "interrupted", EINTR;
  "no living children", ECHILD; "already exists", EEXIST; "is a directory", EISDIR; "not a directory", ENOTDIR;
  "bad fd", EBADF; "fd out of range", EBADF; "exec header invalid", ENOEXEC; "closed pipe", EPIPE; "i/o on hungup", EPIPE;
  "bad arg", EINVAL; "no free", ENOMEM; "in use", EBUSY ]

let contains msg part =
  let n = String.length part in
  let rec at k = k + n <= String.length msg && (String.sub msg k n = part || at (k + 1)) in
  at 0

(* the last failed call's string *)
let last = ref ""
let error_message (_ : error) = !last

(* a call's answer, or its error raised: the function's name, its
 * argument. A note that came meanwhile: its handler is run first
 * (../Unix.ml's check). The kernel's string is asked of it (errstr
 * gives it for the buffer's). *)
let check fn arg r =
  run_signals ();
  if r >= 0 then r
  else begin
    let b = Bytes.make 128 '\000' in
    ignore (sys errstr (s b) (i 128) z z z);
    last := cstring b;
    let e = match List.find_opt (fun (part, _) -> contains !last part) errors with Some (_, e) -> e | None -> EUNKNOWNERR 0 in
    raise (Unix_error (e, fn, arg))
  end
let unit fn arg r = ignore (check fn arg r)
(* (Sys_plan9's: a call by its number, checked) *)
let plan9_call fn arg nr args = check fn arg (syscall nr args)

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

type file_descr = int
let stdin = 0 and stdout = 1 and stderr = 2

type open_flag =
  | O_RDONLY | O_WRONLY | O_RDWR | O_NONBLOCK | O_APPEND | O_CREAT | O_TRUNC | O_EXCL | O_NOCTTY | O_DSYNC | O_SYNC
  | O_RSYNC | O_SHARE_DELETE | O_CLOEXEC | O_KEEPEXEC
type file_perm = int

(* Unix's close-on-exec is a descriptor's, lost by dup2; Plan 9's
 * (OCEXEC) is the open file's, kept by dup: a shell's redirection
 * (opened so, then dup2 to 1) would be closed at exec. So it is kept
 * here: the descriptors to close, closed by execv and execve. *)
let cloexec : file_descr list ref = ref []
let keep fd on = cloexec := List.filter (fun d -> d <> fd) !cloexec; if on then cloexec := fd :: !cloexec

(* Plan 9's modes: OREAD 0, OWRITE 1, ORDWR 2, and OTRUNC, OEXCL *)
let mode_of flags =
  List.fold_left (fun a f -> a lor (match f with O_WRONLY -> 1 | O_RDWR -> 2 | O_TRUNC -> 16 | O_EXCL -> 0x1000 | _ -> 0)) 0 flags

type seek_command = SEEK_SET | SEEK_CUR | SEEK_END

(* seek's answer is 64 bits, written where its first argument says; the
 * offset is two words (here an int's, and its sign) *)
let lseek fd off cmd =
  let b = Bytes.create 8 in
  unit "lseek" "" (sys seek (s b) (i fd) (i off) (i (if off < 0 then -1 else 0)) (i (match cmd with SEEK_SET -> 0 | SEEK_CUR -> 1 | SEEK_END -> 2)));
  Int64.to_int (Bytes.get_int64_le b 0)

let openfile path flags perm =
  let has f = List.mem f flags in
  let mode = mode_of flags in
  let make () = sys create (s path) (i (mode land lnot 16)) (i perm) z z in
  let fd =
    if has O_CREAT && (has O_TRUNC || has O_EXCL) then make ()
    else begin
      let fd = sys open_ (s path) (i mode) z z z in
      if fd < 0 && has O_CREAT then make () else fd
    end in
  let fd = check "open" path fd in
  if has O_APPEND then ignore (lseek fd 0 SEEK_END);
  keep fd (has O_CLOEXEC);
  fd
let close fd = keep fd false; unit "close" "" (sys close_ (i fd) z z z z)

let bounds fn buf ofs len = if ofs < 0 || len < 0 || ofs > Bytes.length buf - len then invalid_arg ("Unix." ^ fn)

(* pread and pwrite at the offset -1 (its two words): where the file
 * is. The bytes go through a buffer of their own when not at buf's
 * start: the call takes an address, and only a block's is known here *)
let read fd buf ofs len =
  bounds "read" buf ofs len;
  let b = if ofs = 0 then buf else Bytes.create len in
  let n = check "read" "" (sys pread (i fd) (s b) (i len) (i (-1)) (i (-1))) in
  if ofs <> 0 then Bytes.blit b 0 buf ofs n;
  n

let write fd buf ofs len =
  bounds "write" buf ofs len;
  let b = if ofs = 0 then buf else Bytes.sub buf ofs len in
  check "write" "" (sys pwrite (i fd) (s b) (i len) (i (-1)) (i (-1)))
let write_substring = write

type file_kind = S_REG | S_DIR | S_CHR | S_BLK | S_LNK | S_FIFO | S_SOCK
type stats = {
  st_dev : int; st_ino : int; st_kind : file_kind; st_perm : file_perm; st_nlink : int; st_uid : int; st_gid : int;
  st_rdev : int; st_size : int; st_atime : float; st_mtime : float; st_ctime : float;
}

(* a directory entry as 9P has it: its size (2 bytes), the device's
 * type (2: its letter) and number (4), the qid (its type 1, version 4,
 * path 8), the mode (4: the top bit a directory's), the two times (4
 * each), the length (8), then the names *)
let stats_of b =
  let u32 o = Int64.to_float (Int64.logand (Int64.of_int32 (Bytes.get_int32_le b o)) 0xffffffffL) in
  let dir = Char.code (Bytes.get b 24) land 0x80 <> 0 in
  let kind = if dir then S_DIR else match Bytes.get b 2 with '|' -> S_FIFO | 'c' -> S_CHR | _ -> S_REG in
  { st_dev = Bytes.get_uint16_le b 4; st_ino = Bytes.get_uint16_le b 13; st_kind = kind;
    st_perm = Bytes.get_uint16_le b 21 land 0o777; st_nlink = 1; st_uid = 0; st_gid = 0; st_rdev = 0;
    st_size = Int64.to_int (Bytes.get_int64_le b 33); st_atime = u32 25; st_mtime = u32 29; st_ctime = u32 29 }

let stat path = let b = Bytes.create 512 in unit "stat" path (sys stat_ (s path) (s b) (i 512) z z); stats_of b
let fstat fd = let b = Bytes.create 512 in unit "fstat" "" (sys fstat_ (i fd) (s b) (i 512) z z); stats_of b

(* the descriptor's file, by its name *)
let isatty fd =
  let b = Bytes.make 64 '\000' in
  sys fd2path (i fd) (s b) (i 64) z z >= 0 && (match cstring b with "/dev/cons" | "#c/cons" -> true | _ -> false)

(* dup's second argument: the descriptor wanted, or -1 for any *)
let dup ~cloexec fd = let d = check "dup" "" (sys dup_ (i fd) (i (-1)) z z z) in keep d cloexec; d
let dup2 src dst = if src <> dst then begin unit "dup2" "" (sys dup_ (i src) (i dst) z z z); keep dst false end

let pipe ~cloexec () =
  let b = Bytes.create 8 in
  unit "pipe" "" (sys pipe_ (s b) z z z z);
  let r = Int32.to_int (Bytes.get_int32_le b 0) and w = Int32.to_int (Bytes.get_int32_le b 4) in
  keep r cloexec; keep w cloexec;
  r, w

external in_channel_of_descr : file_descr -> in_channel = "caml_open_descriptor"
external out_channel_of_descr : file_descr -> out_channel = "caml_open_descriptor"

let chdir path = unit "chdir" path (sys chdir_ (s path) z z z z)

(* a directory is made by create, its permissions with DMDIR: bit 31,
 * past arm's int, so an Int32 (the runtime passes its 32 bits) *)
let mkdir path perm =
  let fd = check "mkdir" path (sys create (s path) z (Obj.repr (Int32.logor Int32.min_int (Int32.of_int perm))) z z) in
  ignore (sys close_ (i fd) z z z z)
(* remove: a file, or a directory that is empty *)
let unlink path = unit "unlink" path (sys remove (s path) z z z z)
let rmdir = unlink
(* libc's getwd: "." opened, and the name the kernel has for it *)
let getcwd () =
  let fd = check "getcwd" "." (sys open_ (s ".") z z z z) and b = Bytes.make 512 '\000' in
  let r = sys fd2path (i fd) (s b) (i 512) z z in
  ignore (sys close_ (i fd) z z z z);
  unit "getcwd" "." r;
  cstring b

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

(* a whole file, a small one *)
let contents path =
  let fd = openfile path [ O_RDONLY ] 0 and all = Buffer.create 256 and b = Bytes.create 4096 in
  let rec go () = let n = read fd b 0 4096 in if n > 0 then begin Buffer.add_subbytes all b 0 n; go () end in
  (try go () with e -> close fd; raise e);
  close fd;
  Buffer.contents all

let put flags path text =
  let fd = openfile path (O_WRONLY :: flags) 0o666 in
  (try ignore (write_substring fd text 0 (String.length text)) with e -> close fd; raise e);
  close fd

(* /env: a file a variable, its words ended by a 0 each; a function
 * (fn#name) is its text *)
let is_fn name = String.length name > 3 && String.sub name 0 3 = "fn#"

(* the variables environment found: those execve empties when not given *)
let found = ref []

let environment () =
  let names = try Array.to_list (Sys.readdir "/env") with Sys_error _ -> [] in
  found := names;
  Array.of_list (List.filter_map (fun name ->
    match contents ("/env/" ^ name) with
    | exception Unix_error _ -> None
    | "" -> None (* (a variable unset: execve's) *)
    | v when is_fn name -> Some (name ^ "=" ^ v)
    | v ->
        let v = if v <> "" && v.[String.length v - 1] = '\000' then String.sub v 0 (String.length v - 1) else v in
        Some (name ^ "=" ^ String.map (fun c -> if c = '\000' then '\001' else c) v)) (List.sort compare names))

(* Plan 9's fork: RFPROC, with RFFDG (the descriptors copied) and
 * RFREND. Not RFENVG: the environment stays one for a shell and its
 * children, as Plan 9's rc has it (a child writing to /env/y, by a
 * redirection, writes the shell's) *)
let fork () = check "fork" "" (sys rfork (i (16 lor 4 lor 0x2000)) z z z z)

let exec_as fn prog args =
  List.iter (fun fd -> ignore (sys close_ (i fd) z z z z)) !cloexec;
  cloexec := [];
  raise (Unix_error ((try ignore (check fn prog (exec prog args [||])); EUNKNOWNERR 0 with Unix_error (e, _, _) -> e), fn, prog))
let execv prog args = exec_as "execv" prog args

(* /env made the environment given, first: each variable written, and
 * one that environment found and is not given emptied (unset:
 * environment skips it). Every one, at every exec: simple, and what a
 * child wrote meanwhile is put right. A file the program does not
 * know stays (one written by a redirection); so does a variable set
 * after the start and unset since: Plan 9's rc, which keeps /env
 * itself, empties it (plan_rio.md, stage 2's notes). *)
let execve prog args env =
  let given = Array.to_list env |> List.filter_map (fun kv ->
    match String.index_opt kv '=' with
    | Some k -> Some (String.sub kv 0 k, String.sub kv (k + 1) (String.length kv - k - 1))
    | None -> None) in
  let set name v = try put [ O_CREAT; O_TRUNC ] ("/env/" ^ name) v with Unix_error _ -> () in
  List.iter (fun (name, v) -> set name (if is_fn name then v else String.map (fun c -> if c = '\001' then '\000' else c) v ^ "\000")) given;
  List.iter (fun name -> if not (List.mem_assoc name given) then set name "") !found;
  exec_as "execve" prog args

type process_status = WEXITED of int | WSIGNALED of int | WSTOPPED of int
type wait_flag = WNOHANG | WUNTRACED

(* a note's name that ends a process, as Sys's signal *)
let notes = [ "interrupt", Sys.sigint; "hangup", Sys.sighup; "kill", Sys.sigkill; "alarm", Sys.sigalrm ]

(* await's line: the pid, three times, then the process's last words,
 * quoted when they have a space: none, or "name pid: words" *)
let status_of msg =
  let msg = match String.rindex_opt msg ':' with Some k -> String.trim (String.sub msg (k + 1) (String.length msg - k - 1)) | None -> msg in
  if msg = "" then WEXITED 0
  else match int_of_string_opt msg with
    | Some n -> WEXITED n
    | None -> (match List.assoc_opt msg notes with Some sg -> WSIGNALED sg | None -> WEXITED 1)

(* each child's last words, kept for last_words (the newest first; 64
 * of them) *)
let words = ref []
let last_words pid = match List.assoc_opt pid !words with Some m -> m | None -> ""
let times = ref []
let last_times pid = match List.assoc_opt pid !times with Some t -> t | None -> 0, 0, 0

let await_one fn =
  let b = Bytes.make 256 '\000' in
  let n = check fn "" (sys await (s b) (i 255) z z z) in
  let line = Bytes.sub_string b 0 n in
  let after rest = match String.index_opt rest ' ' with Some j -> String.sub rest (j + 1) (String.length rest - j - 1) | None -> "" in
  let msg = after (after (after (after line))) in
  let msg = if String.length msg >= 2 && msg.[0] = '\'' then String.sub msg 1 (String.length msg - 2) else msg in
  let pid = int_of_string (String.sub line 0 (String.index line ' ')) in
  words := (pid, msg) :: List.filteri (fun k (p, _) -> k < 63 && p <> pid) !words;
  (* (and its three times, in milliseconds: the line's second, third and fourth words) *)
  let number rest = match int_of_string_opt (String.sub rest 0 (match String.index_opt rest ' ' with Some j -> j | None -> String.length rest)) with Some v -> v | None -> 0 in
  times := (pid, (number (after line), number (after (after line)), number (after (after (after line))))) :: List.filteri (fun k (p, _) -> k < 63 && p <> pid) !times;
  pid, status_of msg

(* the children that ended while another was waited for *)
let ended = ref []

let wait () =
  match !ended with
  | first :: rest -> ended := rest; first
  | [] -> await_one "wait"

let rec waitpid flags pid =
  if pid = -1 then wait ()
  else match List.assoc_opt pid !ended with
    | Some st -> ended := List.filter (fun (p, _) -> p <> pid) !ended; pid, st
    | None ->
        let p, st = await_one "waitpid" in
        if p = pid then p, st else begin ended := !ended @ [ p, st ]; waitpid flags pid end

(* a note to oneself has come when kill is back: its handler run *)
let kill pid sg =
  let note = match List.find_opt (fun (_, sg') -> sg' = sg) notes with Some (n, _) -> n | None -> "sys: signal " ^ string_of_int sg in
  (try put [] ("/proc/" ^ string_of_int pid ^ "/note") note with Unix_error (e, _, _) -> raise (Unix_error (e, "kill", "")));
  run_signals ()

let getpid () = int_of_string (String.trim (contents "#c/pid"))
(* exits: no string when all went well, else the number's digits *)
let _exit n = ignore (sys exits (if n = 0 then z else s (string_of_int n)) z z z z); exit n

(*****************************************************************************)
(* Time *)
(*****************************************************************************)

(* /dev/bintime: the nanoseconds since 1970, 8 bytes, the high one
 * first (libc's time reads it too) *)
let gettimeofday () =
  let fd = openfile "/dev/bintime" [ O_RDONLY ] 0 and b = Bytes.create 8 in
  let n = try read fd b 0 8 with e -> close fd; raise e in
  close fd;
  if n < 8 then 0.0 else Int64.to_float (Bytes.get_int64_be b 0) /. 1e9

let time () = floor (gettimeofday ())

type tm = {
  tm_sec : int; tm_min : int; tm_hour : int; tm_mday : int; tm_mon : int; tm_year : int; tm_wday : int; tm_yday : int;
  tm_isdst : bool;
}

(* (../Unix.ml's: the day's date by counting from March 1st of year 0,
 * in periods of 400 years) *)
let gmtime t =
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

(* sleep, in milliseconds *)
let sleepf t = ignore (sys sleep (i (int_of_float (t *. 1000.))) z z z z)
