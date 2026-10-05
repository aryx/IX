(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-echo: Plan 9's echo (principia's shells/misc/echo.c). Its
 * arguments, a space between them, then a newline, in one write (rc's
 * echo is this program: a line written to a device's ctl file must be
 * one message). -n, the first argument: no newline. *)

type caps = < Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let nflag, args = match List.tl (Array.to_list argv) with "-n" :: rest -> true, rest | args -> false, args in
  let text = String.concat " " args ^ if nflag then "" else "\n" in
  (* (the descriptor: one write, and the system's reason when it fails) *)
  match Unix.write_substring (Console.stdout_fd caps) text 0 (String.length text) with
  | _ -> Exit.OK
  | exception Unix.Unix_error (e, _, _) ->
      Console.eprint caps (Printf.sprintf "echo: write error: %s\n" (Unix.error_message e));
      Exit.Err "write error"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
