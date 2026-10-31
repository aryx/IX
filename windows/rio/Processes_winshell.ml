(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Processes_winshell.mli *)

let flags = Sys_plan9.(rfproc lor rffdg lor rfnameg lor rfenvg lor rfnoteg lor rfnowait)

(* the window system's files before /dev, as [spec] says them, and $wsys *)
let mount_files caps srv spec =
  let served = FS.open_rw_fd caps srv in
  (try Sys_plan9.mount caps served "/mnt/wsys" Sys_plan9.mrepl spec; Sys_plan9.bind caps "/mnt/wsys" "/dev" Sys_plan9.mbefore
   with Unix.Unix_error _ -> Sys_plan9.mount caps served "/dev" Sys_plan9.mbefore spec);
  (try Fpath.v "/env/wsys" |> FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc srv) with Sys_error _ -> ())

(* no descriptor left open but the three, then rc *)
let run_rc caps argv =
  for fd = 3 to 63 do (try Unix.close (Obj.magic fd : Unix.file_descr) with Unix.Unix_error _ -> ()) done;
  List.iter (fun rc -> try CapUnix.execv caps rc argv with Unix.Unix_error _ -> ()) [ "/bin/rc"; "/boot/rc" ]

let start (caps : < Cap.chdir; Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. >) (w : Window.t) srv ~cd command =
  match Sys_plan9.rfork caps flags with
  | 0 ->
      (try
         mount_files caps srv (string_of_int w.id);
         (* (a directory that is not there: the window system's, and rc says nothing) *)
         (if cd <> "" then try CapUnix.chdir caps cd with Unix.Unix_error _ -> ());
         (* its console the three descriptors *)
         let cons = FS.open_rw_fd caps "/dev/cons" in
         List.iter (Unix.dup2 cons) [ Unix.stdin; Unix.stdout; Unix.stderr ];
         run_rc caps (if command = "" then [| "rc"; "-i" |] else [| "rc"; "-c"; command |])
       with Unix.Unix_error (e, fn, _) -> prerr_string ("rio: a window's process: " ^ fn ^ ": " ^ Unix.error_message e ^ "\n"));
      Unix._exit 1
  | pid -> w.pid <- pid

let init (caps : < Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. >) srv command =
  match Sys_plan9.rfork caps flags with
  | 0 ->
      (try
         mount_files caps srv "";
         run_rc caps [| "rc"; "-c"; command |]
       with Unix.Unix_error (e, fn, _) -> prerr_string ("rio: -i: " ^ fn ^ ": " ^ Unix.error_message e ^ "\n"));
      Unix._exit 1
  | _ -> ()

let note (caps : < Cap.open_out; .. >) (w : Window.t) text =
  try Fpath.v (Printf.sprintf "/proc/%d/notepg" w.pid) |> FS.with_open_out caps (fun (chan : Chan.o) -> output_string chan.oc text) with Sys_error _ -> ()
