(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-pwd is Plan 9's pwd (principia's utilities/files/pwd.c; xix's
 * utilities/files/pwd.ml). It writes the directory the process is in,
 * as the kernel names it: by the name it was reached by, so a bind
 * does not show.
 *
 * cs-history:
 * Unix's kernel did not know a process's directory by name, only
 * which directory it was. pwd found the name by walking: it did a stat
 * of ".", opened "..", and read it for the entry with the same number,
 * which is the last part of the name; then it did the same from "..",
 * up to the root. It could fail half way (at a directory that is not
 * readable), and a symbolic link made the answer differ from the path
 * one had typed.
 *
 * plan9-is-cleaner:
 * With a name space made of bind and mount, walking up is not even
 * defined: which of the directories bound at /bin is the parent of
 * /bin/ls? So the kernel keeps, with each open file, the name it was
 * opened by, cleaned as text (a/b/.. is a), and .. is taken on the
 * name: pwd is one call. That is Rob Pike's "Lexical File Names in
 * Plan 9, or Getting Dot-Dot Right" (USENIX, 2000). *)

type caps = < Cap.readdir; Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (_ : string array) : Exit.t =
  match FS.getcwd caps () with
  | dir -> Console.print caps (dir ^ "\n"); Exit.OK
  | exception Unix.Unix_error (e, _, _) -> Console.eprint caps (Printf.sprintf "pwd: %s\n" (Unix.error_message e)); Exit.Err "getwd"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
