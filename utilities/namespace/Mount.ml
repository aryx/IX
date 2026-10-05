(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-mount: Plan 9's mount (principia's kernel/files/user/mount.c):
 * mount /srv/service dir [spec], dir is now the tree a 9P server gives
 * on the service's file (a pipe posted in /srv, a connection). bind's
 * -a, -b, -c, and -C (cached), -q (quiet when it fails). Without the
 * authentication: mount's -n always (no factotum to talk to), -n and
 * -k taken and unused. Plan 9's own (Sys_plan9.mount). *)

type caps = < Cap.mount; Cap.open_in; Cap.open_out; Cap.stderr >

exception Usage


let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
  let flag = ref 0 and quiet = ref false in
  let rec options = function
    | "--" :: rest -> rest
    | "-k" :: _ :: rest -> options rest
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        String.iteri (fun k c ->
          if k > 0 then match c with
            | 'a' -> flag := !flag lor Sys_plan9.mafter
            | 'b' -> flag := !flag lor Sys_plan9.mbefore
            | 'c' -> flag := !flag lor Sys_plan9.mcreate
            | 'C' -> flag := !flag lor Sys_plan9.mcache
            | 'n' -> ()
            | 'q' -> quiet := true
            | _ -> raise Usage) a;
        options rest
    | rest -> rest in
  let service, dir, spec = match options (List.tl (Array.to_list argv)) with
    | [ service; dir ] -> service, dir, ""
    | [ service; dir; spec ] -> service, dir, spec
    | _ -> raise Usage in
  if !flag land Sys_plan9.mafter <> 0 && !flag land Sys_plan9.mbefore <> 0 then raise Usage;
  let fail what msg words = if !quiet then Exit.OK else begin Console.eprint caps (Printf.sprintf "%s: %s: %s\n" argv.(0) what msg); Exit.Err words end in
  match FS.open_rw_fd caps service with
  | exception Unix.Unix_error (e, _, _) -> fail ("can't open " ^ service) (Unix.error_message e) "open"
  | fd -> (
      match Sys_plan9.mount caps fd dir !flag spec with
      | () -> Exit.OK
      | exception Unix.Unix_error (e, _, _) -> fail ("mount " ^ dir) (Unix.error_message e) "mount")
  with Usage -> Console.eprint caps "usage: mount [-a|-b] [-cnq] [-k keypattern] /srv/service dir [spec]\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
