(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-unmount: Plan 9's unmount (principia's kernel/files/user/unmount.c):
 * unmount dir, what was bound or mounted on dir is no longer there;
 * unmount new dir, only new, of dir's union (the arguments in mount's
 * and bind's order). Plan 9's own (Sys_plan9.unmount). *)

type caps = < Cap.mount; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let unmount name old =
    match Sys_plan9.unmount caps name old with
    | () -> Exit.OK
    | exception Unix.Unix_error (e, _, _) ->
        let why = Printf.sprintf "%s: %s" old (Unix.error_message e) in
        Console.eprint caps (Printf.sprintf "%s: %s\n" argv.(0) why); Exit.Err why in
  match List.tl (Array.to_list argv) with
  | [ old ] -> unmount None old
  | [ name; old ] -> unmount (Some name) old
  | _ -> Console.eprint caps "usage: unmount mountpoint\n       unmount mounted mountpoint\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
