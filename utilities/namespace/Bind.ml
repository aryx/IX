(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-bind: Plan 9's bind (principia's kernel/files/user/bind.c):
 * bind new old, old is now also new, in this process's namespace (and
 * of those that share it: the shell's). -b, -a: new goes before, or
 * after, what old already is (a union); -c: files may be created
 * there; -q: quiet when it fails. One system call, Plan 9's own
 * (Sys_plan9.bind): on another system it only fails.
 *
 *     bind -a $home/bin/rc /bin      /bin is the system's programs,
 *                                    then mine: no $PATH to search
 *     bind '#c' /dev                 a kernel's device, named by its
 *                                    letter, put in the tree
 *     bind -b /mnt/wsys /dev         a window's files before /dev's:
 *                                    /dev/cons is now the window
 *
 * plan9-is-cleaner:
 * On Unix the tree of names is the machine's: one for all, changed
 * by root alone (mount), since changing it changes what every
 * program sees, the set-user-id ones too. In Plan 9 a name space is
 * a process's, inherited or copied at rfork, so anyone may arrange
 * his own, and it does no harm to another. What Unix does with a
 * variable, a convention or a special call each time is then one
 * mechanism: $PATH is a union at /bin, a chroot is a name space with
 * less in it, a window's terminal is /dev/cons bound over
 * (Processes_winshell, Fileserver), another machine's devices are
 * its /dev mounted here.
 *
 * modern:
 * Linux has had a name space a process since 2002 (clone's
 * CLONE_NEWNS), bind mounts, and unions (overlayfs): the pieces a
 * container is made of. They came one at a time into a system whose
 * mount is still root's, so each needs a privilege or a helper
 * where Plan 9 needs nothing.
 *
 * References: bind(1) and bind(2); Rob Pike, Dave Presotto, Ken
 * Thompson, Howard Trickey and Phil Winterbottom, "The Use of Name
 * Spaces in Plan 9" (1992); the kernel's side is mini-9pi's. *)

type caps = < Cap.bind; Cap.readdir; Cap.stderr >

exception Usage


let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
  let flag = ref 0 and quiet = ref false in
  (* the options: letters after a -, in the first arguments *)
  let rec options = function
    | "--" :: rest -> rest
    | a :: rest when String.length a > 1 && a.[0] = '-' ->
        String.iteri (fun k c ->
          if k > 0 then match c with
            | 'a' -> flag := !flag lor Sys_plan9.mafter
            | 'b' -> flag := !flag lor Sys_plan9.mbefore
            | 'c' -> flag := !flag lor Sys_plan9.mcreate
            | 'q' -> quiet := true
            | _ -> raise Usage) a;
        options rest
    | rest -> rest in
  match options (List.tl (Array.to_list argv)) with
  | [ name; old ] when not (!flag land Sys_plan9.mafter <> 0 && !flag land Sys_plan9.mbefore <> 0) -> (
      match Sys_plan9.bind caps name old !flag with
      | () -> Exit.OK
      | exception Unix.Unix_error (e, _, _) ->
          if !quiet then Exit.OK
          else begin
            (* a less confusing error than the kernel's: which name is not there *)
            let why = Unix.error_message e in
            let missing f = match Sys_plan9.dirstat caps f with _ -> None | exception Unix.Unix_error (e, _, _) -> Some (Unix.error_message e) in
            (match missing name, missing old with
             | Some m, _ -> Console.eprint caps (Printf.sprintf "bind: %s: %s\n" name m)
             | None, Some m -> Console.eprint caps (Printf.sprintf "bind: %s: %s\n" old m)
             | None, None -> Console.eprint caps (Printf.sprintf "bind %s %s: %s\n" name old why));
            Exit.Err "bind"
          end)
  | _ -> raise Usage
  with Usage -> Console.eprint caps "usage: bind [-q] [-b|-a|-c|-bc|-ac] new old\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
