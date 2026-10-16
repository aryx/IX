(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibSystem.mli; this is the host's *)

(* a descriptor is a number, on Unix *)
let fd (n : int) : Unix.file_descr = Obj.magic n
let number (f : Unix.file_descr) : int = Obj.magic f

(* [reason f]: f's result, or Failure with the system's message *)
let reason f = try f () with Unix.Unix_error (e, _, _) -> failwith (Unix.error_message e) | Sys_error m -> failwith m

let main (name : string) (f : Cap.all_caps -> int) : unit =
  Cap.main (fun caps -> Logging.setup caps ~name; CapStdlib.exit caps (f caps))

let argv (caps : < Cap.argv; .. >) = Array.to_list (CapSys.argv caps)
let environment (caps : < Cap.env; .. >) = Procs.split_env (CapUnix.environment caps ())
let getpid () = Unix.getpid ()

(*****************************************************************************)
(* The terminal *)
(*****************************************************************************)

let print (caps : < Cap.stdout; .. >) s = Console.print caps s
let eprint (caps : < Cap.stderr; .. >) s = Console.eprint caps s
let flush () = flush_all ()
let read_line (caps : < Cap.stdin; .. >) = try Some (input_line (Console.stdin caps)) with End_of_file -> None
let isatty n = Unix.isatty (fd n)

(* (a handler, unlike an ignored signal, is not inherited through exec) *)
let ignore_interrupt () = Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ -> ()))

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

let open_in (caps : < Cap.open_in; .. >) file = reason (fun () -> number (FS.open_in_fd caps file))
let open_out (caps : < Cap.open_out; .. >) file = reason (fun () -> number (FS.open_out_fd caps file 0o666))
let open_append (caps : < Cap.open_out; .. >) file = reason (fun () -> number (FS.open_append_fd caps file 0o666))
let close n = Unix.close (fd n)
let read_file (caps : < Cap.open_in; .. >) file = reason (fun () -> FS.read caps (Fpath.v file))
let read_all n = Procs.read_all (fd n)
let readdir dir = try Array.to_list (Sys.readdir dir) with Sys_error _ -> []
let is_directory file = try Sys.is_directory file with Sys_error _ -> false
let chdir (caps : < Cap.chdir; .. >) dir = reason (fun () -> CapUnix.chdir caps dir)

let read n max =
  let buf = Bytes.create max in
  let k = reason (fun () -> Unix.read (fd n) buf 0 max) in
  Bytes.sub_string buf 0 k

let write n s =
  let rec go at = if at < String.length s then go (at + reason (fun () -> Unix.write_substring (fd n) s at (String.length s - at))) in
  go 0

let stat file = reason (fun () -> let st = Unix.stat file in st.st_kind = Unix.S_DIR, st.st_size)
let mkdir (caps : < Cap.open_out; .. >) dir = reason (fun () -> FS.mkdir caps dir 0o777)
let remove (caps : < Cap.open_out; .. >) file = reason (fun () -> FS.remove_any caps file)
let rename (_caps : < Cap.open_out; .. >) a b = reason (fun () -> Unix.rename a b)
let link (_caps : < Cap.open_out; .. >) a b = reason (fun () -> Unix.link a b)

(* (utimes with two zeros: now) *)
let touch (caps : < Cap.open_out; .. >) file =
  reason (fun () -> if Sys.file_exists file then Unix.utimes file 0.0 0.0 else Unix.close (FS.create_fd caps file 0o666))

let getcwd (caps : < Cap.readdir; .. >) = FS.getcwd caps ()
let sleep ms = Unix.sleepf (float_of_int ms /. 1000.0)

(*****************************************************************************)
(* Descriptors *)
(*****************************************************************************)

let save n = try Some (number (Unix.dup ~cloexec:true (fd n))) with Unix.Unix_error _ -> None
let dup2 a b = Unix.dup2 (fd a) (fd b)
let pipe () = let r, w = Unix.pipe ~cloexec:true () in number r, number w

(*****************************************************************************)
(* Processes *)
(*****************************************************************************)

let fork (caps : < Cap.fork; .. >) = CapUnix.fork caps ()

let exec (caps : < Cap.exec; .. >) file (argv : string list) (env : string list) : string =
  try CapUnix.execve caps file (Array.of_list argv) (Array.of_list env); ""
  with Unix.Unix_error (e, _, _) -> Unix.error_message e

(* a signal by rc's name for it; OCaml numbers its own from -1: abrt,
 * alrm, fpe, hup, ill, int, kill, pipe, quit, segv, term
 * old: "signal " ^ string_of_int n, OCaml's number (-6 for an interrupt) *)
let signals =
  [| "sys: abort"; "alarm"; "sys: fp: trap"; "hangup"; "sys: illegal instruction"; "interrupt"; "sys: kill";
     "sys: write on closed pipe"; "quit"; "sys: segmentation violation"; "kill" |]

let wait (caps : < Cap.wait; .. >) pid =
  match Procs.waitpid caps pid with
  | Unix.WEXITED 0 -> ""
  | Unix.WEXITED n -> string_of_int n
  | Unix.WSIGNALED n | Unix.WSTOPPED n -> "signal: " ^ if n < 0 && -n <= Array.length signals then signals.(-n - 1) else string_of_int n

let exit n = Unix._exit n
