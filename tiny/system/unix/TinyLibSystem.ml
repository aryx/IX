(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See ../TinyLibSystem.mli; this is the host's, over OCaml's Unix *)

open Fpath_.Operators

(* See TinyLibSystem.mli for the types' names *)
type pid = int
type fd = int
type status = string
type stat = { st_dir : bool; st_size : int }
type seconds = int
type milliseconds = int

(* a descriptor is a number, on Unix *)
let fd (n : int) : Unix.file_descr = Obj.magic n
let number (f : Unix.file_descr) : int = Obj.magic f

(* [reason f]: f's result, or Failure with the system's message *)
let reason f =
  try f () with
  | Unix.Unix_error (e, _, _) -> failwith (Unix.error_message e)
  | Sys_error m -> failwith m

(* (Err's words as a Failure's, the same on both systems: not
 * Exit.exit's, which logs them) *)
let main (name : string) (f : Cap.all_caps -> string array -> Exit.t) : unit =
  Cap.main (fun caps ->
    Logging.setup caps ~name;
    let said m =
      flush_all (); Console.eprint caps (name ^ ": " ^ m ^ "\n"); 1 in
    CapStdlib.exit caps
      (try
         match f caps (CapSys.argv caps) with
         | Exit.OK -> 0
         | Exit.Err m -> said m
         | Exit.Code n -> n
       with
       | Failure m -> said m
       | Exit.ExitCode n -> n))

let logging args =
  List.filter (fun a ->
    match a with
    | "-v" -> Logs.set_level (Some Logs.Info); false
    | "-debug" -> Logs.set_level (Some Logs.Debug); false
    | "-quiet" -> Logs.set_level None; false
    | _ -> true) args

let environment (caps : < Cap.env; .. >) =
  Procs.split_env (CapUnix.environment caps ())
let getpid (caps : < Cap.env; .. >) = CapUnix.getpid caps ()

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

let print (caps : < Cap.stdout; .. >) s = Console.print caps s
let eprint (caps : < Cap.stderr; .. >) s = Console.eprint caps s
let flush (_ : < Cap.stdout; Cap.stderr; .. >) = flush_all ()
let read_line (caps : < Cap.stdin; .. >) =
  try Some (input_line (Console.stdin caps)) with End_of_file -> None
let isatty n = Unix.isatty (fd n)

(* (a handler, unlike an ignored signal, is not inherited through exec) *)
let ignore_interrupt (_ : < Cap.signal; .. >) =
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> ()))

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

let open_in (caps : < Cap.open_in; .. >) (file : Fpath.t) =
  reason (fun () -> number (FS.open_in_fd caps !!file))
let open_out (caps : < Cap.open_out; .. >) (file : Fpath.t) =
  reason (fun () -> number (FS.open_out_fd caps !!file 0o666))
let open_append (caps : < Cap.open_out; .. >) (file : Fpath.t) =
  reason (fun () -> number (FS.open_append_fd caps !!file 0o666))
let close n = Unix.close (fd n)

let open_rw (caps : < Cap.open_in; Cap.open_out; .. >) (file : Fpath.t) =
  reason (fun () ->
    if not (Sys.file_exists !!file) then
      Unix.close (FS.create_fd caps !!file 0o666);
    number (FS.open_rw_fd caps !!file))
let seek n off = ignore (reason (fun () -> Unix.lseek (fd n) off Unix.SEEK_SET))
let seek_end n = reason (fun () -> Unix.lseek (fd n) 0 Unix.SEEK_END)
let read_file (caps : < Cap.open_in; .. >) (file : Fpath.t) =
  reason (fun () -> FS.read caps file)
let read_all n = Procs.read_all (fd n)
let with_open_in (caps : < Cap.open_in; .. >) f (file : Fpath.t) =
  reason (fun () -> FS.with_open_in caps f file)
let with_open_out (caps : < Cap.open_out; .. >) f (file : Fpath.t) =
  reason (fun () -> FS.with_open_out caps f file)
let with_open_append (caps : < Cap.open_out; .. >) f (file : Fpath.t) =
  (* (the file named, as FS.with_open_in's Sys_error does) *)
  let fd =
    try FS.open_append_fd caps !!file 0o666
    with Unix.Unix_error (e, _, _) ->
      failwith (!!file ^ ": " ^ Unix.error_message e) in
  let oc = Unix.out_channel_of_descr fd in
  let chan : Chan.o = { oc; dest = OutFile file } in
  reason (fun () ->
    Fun.protect ~finally:(fun () -> close_out oc) (fun () -> f chan))
let stdin (caps : < Cap.stdin; .. >) : Chan.i =
  { ic = Console.stdin caps; origin = Stdin }
let readdir (_ : < Cap.readdir; .. >) (dir : Fpath.t) =
  try Array.to_list (Sys.readdir !!dir) with Sys_error _ -> []
let is_directory (_ : < Cap.readdir; .. >) (file : Fpath.t) =
  try Sys.is_directory !!file with Sys_error _ -> false
let chdir (caps : < Cap.chdir; .. >) (dir : Fpath.t) =
  reason (fun () -> CapUnix.chdir caps !!dir)

let read n max =
  let buf = Bytes.create max in
  let k = reason (fun () -> Unix.read (fd n) buf 0 max) in
  Bytes.sub_string buf 0 k

let write n s =
  let rec go at =
    if at < String.length s then
      go (at + reason (fun () ->
        Unix.write_substring (fd n) s at (String.length s - at)))
  in
  go 0
let write_file (caps : < Cap.open_out; .. >) (file : Fpath.t) s =
  let fd = open_out caps file in
  write fd s;
  close fd

let stat (_ : < Cap.open_in; .. >) (file : Fpath.t) : stat =
  reason (fun () ->
    (* (Unix's labels: ours have the same prefix) *)
    let (st : Unix.stats) = Unix.stat !!file in
    { st_dir = st.st_kind = Unix.S_DIR; st_size = st.st_size })
let links (_ : < Cap.open_in; .. >) (file : Fpath.t) =
  reason (fun () -> (Unix.stat !!file).st_nlink)
let mtime (_ : < Cap.open_in; .. >) (file : Fpath.t) =
  reason (fun () -> int_of_float (Unix.stat !!file).st_mtime - 946684800)
let mkdir (caps : < Cap.open_out; .. >) (dir : Fpath.t) =
  reason (fun () -> FS.mkdir caps !!dir 0o777)
let remove (caps : < Cap.open_out; .. >) (file : Fpath.t) =
  reason (fun () -> FS.remove_any caps !!file)
let rename (_caps : < Cap.open_out; .. >) (a : Fpath.t) (b : Fpath.t) =
  reason (fun () -> Unix.rename !!a !!b)
let link (_caps : < Cap.open_out; .. >) (a : Fpath.t) (b : Fpath.t) =
  reason (fun () -> Unix.link !!a !!b)

let is_executable (_ : < Cap.open_in; .. >) (file : Fpath.t) =
  try (Unix.stat !!file).st_perm land 0o100 <> 0
  with Unix.Unix_error _ -> false
let set_executable (_caps : < Cap.open_out; .. >) (file : Fpath.t) x =
  reason (fun () -> Unix.chmod !!file (if x then 0o755 else 0o644))

(* (utimes with two zeros: now) *)
let touch (caps : < Cap.open_in; Cap.open_out; .. >) (file : Fpath.t) =
  reason (fun () ->
    if Sys.file_exists !!file then Unix.utimes !!file 0.0 0.0
    else Unix.close (FS.create_fd caps !!file 0o666))

let getcwd (caps : < Cap.env; .. >) = Fpath.v (CapSys.getcwd caps ())
(* (946684800: 2000-01-01 in Unix's seconds) *)
let time (caps : < Cap.clock; .. >) =
  int_of_float (CapUnix.time caps ()) - 946684800
let sleep (caps : < Cap.clock; .. >) ms =
  CapUnix.sleepf caps (float_of_int ms /. 1000.0)
let millis (caps : < Cap.clock; .. >) =
  int_of_float (CapUnix.gettimeofday caps () *. 1000.0)

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

let save n =
  try Some (number (Unix.dup ~cloexec:true (fd n)))
  with Unix.Unix_error _ -> None
let dup2 a b = Unix.dup2 (fd a) (fd b)
let pipe (caps : < Cap.pipe; .. >) =
  let r, w = CapUnix.pipe caps ~cloexec:true () in number r, number w

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

let fork (caps : < Cap.fork; .. >) : pid option =
  reason (fun () -> match CapUnix.fork caps () with 0 -> None | p -> Some p)

let kill (caps : < Cap.kill; .. >) pid =
  try CapUnix.kill caps pid Sys.sigkill; true with Unix.Unix_error _ -> false

let exec (caps : < Cap.exec; .. >) (file : Fpath.t) (argv : string list)
    (env : string list) : string =
  try CapUnix.execve caps !!file (Array.of_list argv) (Array.of_list env); ""
  with Unix.Unix_error (e, _, _) -> Unix.error_message e

(* a signal by rc's name for it; OCaml numbers its own from -1: abrt,
 * alrm, fpe, hup, ill, int, kill, pipe, quit, segv, term
 * old: "signal " ^ string_of_int n, OCaml's number (-6 for an interrupt) *)
let signals =
  [| "sys: abort"; "alarm"; "sys: fp: trap"; "hangup";
     "sys: illegal instruction"; "interrupt"; "sys: kill";
     "sys: write on closed pipe"; "quit"; "sys: segmentation violation";
     "kill" |]

let status = function
  | Unix.WEXITED 0 -> ""
  | Unix.WEXITED n -> string_of_int n
  | Unix.WSIGNALED n | Unix.WSTOPPED n ->
    "signal: "
    ^ if n < 0 && -n <= Array.length signals then signals.(-n - 1)
      else string_of_int n

let wait (caps : < Cap.wait; .. >) pid = status (Procs.waitpid caps pid)
let wait_any (caps : < Cap.wait; .. >) =
  Option.map (fun (pid, st) -> pid, status st) (Procs.wait_any caps)

let shell (caps : < Cap.fork; Cap.exec; Cap.env; Cap.stdout; Cap.stderr; .. >) vars
    script =
  let env =
    List.map (fun (k, v) -> k ^ "=" ^ String.concat " " v) vars
    @ Array.to_list (CapUnix.environment caps ())
  in
  flush_all ();
  match CapUnix.fork caps () with
  | 0 ->
    (try
       CapUnix.execve caps "/bin/sh" [| "sh"; "-e"; "-c"; script |]
         (Array.of_list env)
     with _ -> ());
    Unix._exit 127
  | pid -> Some pid
  | exception Unix.Unix_error _ -> None

let exit (caps : < Cap.exit; Cap.stderr; .. >) (e : Exit.t) =
  Unix._exit
    (match e with
     | Exit.OK -> 0
     | Exit.Err m -> Console.eprint caps (m ^ "\n"); 1
     | Exit.Code n -> n)
