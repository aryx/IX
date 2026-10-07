(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-pwd: Plan 9's pwd (principia's utilities/files/pwd.c; xix's
 * utilities/files/pwd.ml): the directory the process is in, as the
 * kernel names it (the name it was reached by: a bind does not show). *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (_ : string array) : Exit.t =
  match FS.getcwd caps () with
  | dir -> Console.print caps (dir ^ "\n"); Exit.OK
  | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "pwd: %s\n" (Unix.error_message e)); Exit.Err "getwd"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
