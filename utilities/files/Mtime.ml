(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-mtime: Plan 9's mtime (principia's utilities/files/mtime.c):
 * when each file was last written, seconds since 1970, and its name
 * (for a script: mk's own question). *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.tl (Array.to_list argv) with
  | a :: _ when String.length a > 1 && a.[0] = '-' -> Console.eprint caps "usage: mtime file...\n"; Exit.Err "usage"
  | files ->
      let errors = ref false in
      List.iter (fun file ->
        match Sys_plan9.dirstat caps file with
        | (d : Sys_plan9.dir) -> Console.print caps (Printf.sprintf "%11.0f %s\n" d.mtime file)
        | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "stat %s: %s\n" file (Unix.error_message e)); errors := true) files;
      if !errors then Exit.Err "errors" else Exit.OK

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
