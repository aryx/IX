(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-mount: Plan 9's mount (principia's kernel/files/user/mount.c):
 * mount /srv/service dir [spec], dir is now the tree a 9P server gives
 * on the service's file (a pipe posted in /srv, a connection). bind's
 * -a, -b, -c, and -C (cached), -q (quiet when it fails). Without the
 * authentication: mount's -n always (no factotum to talk to), -n and
 * -k taken and unused. Plan 9's own (Sys_plan9.mount).
 *
 *     a program: open, read, write on a name under dir
 *         |
 *     the kernel: each call made a 9P message (walk, open, read...)
 *         |       written on the service's pipe or connection
 *     the server: any program that answers them
 *
 * plan9-is-cleaner:
 * Unix's mount puts a disk's file system, code of the kernel, in the
 * tree, and is root's. Here what is mounted is a conversation: the
 * server is a program like another (mini-rio serves its windows'
 * files so: Fileserver), on this machine or behind a connection, and
 * since the name space is the process's own (Bind) anyone may mount.
 * So a new kind of thing with names needs no new system call and no
 * code in the kernel: a server, and mount.
 *
 * modern:
 * FUSE (in Linux since 2005) is the same idea brought to Unix: the
 * kernel passes a mounted tree's calls to a program. sshfs and the
 * like are made with it.
 *
 * References: mount(1), bind(2), intro(5) for 9P; "The Use of Name
 * Spaces in Plan 9" (see Bind). *)

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
