(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-cleanname: Plan 9's cleanname (principia's utilities/misc/cleanname.c):
 * each name as its shortest form (FS.cleanname: no "." nor empty part,
 * no ".." a name before it answers); -d pwd: a name that does not
 * start at the root is taken from that directory. For a script.
 *
 *     cleanname a//b/./c/../d            a/b/d
 *     cleanname ../../x                  ../../x
 *     cleanname /../x                    /x
 *     cleanname ''                       .
 *     cleanname -d /usr/glenda lib/../bin     /usr/glenda/bin
 *
 * plan9-is-cleaner:
 * No file is looked at: a name is cleaned as text. On Unix that
 * would be wrong, since a/b/.. is not a when b is a symbolic link to
 * another place, and realpath must ask the kernel at each part.
 * Plan 9 has no symbolic link, and its kernel takes .. on the name
 * the same way (Pwd tells why, and names Rob Pike's paper), so the
 * text's answer is the system's. *)

type caps = < Cap.stdout; Cap.stderr >

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let usage () = Console.eprint caps "usage: cleanname [-d pwd] name...\n"; Exit.Err "usage" in
  let clean dir names =
    List.iter (fun name ->
      let full = match dir with Some d when name = "" || name.[0] <> '/' -> d ^ "/" ^ name | _ -> name in
      Console.print caps (FS.cleanname full ^ "\n")) names;
    Exit.OK in
  match List.tl (Array.to_list argv) with
  | "-d" :: dir :: (_ :: _ as names) -> clean (Some dir) names
  | a :: (_ :: _ as names) when String.length a > 2 && String.sub a 0 2 = "-d" -> clean (Some (String.sub a 2 (String.length a - 2))) names
  | a :: _ when String.length a > 1 && a.[0] = '-' -> usage ()
  | [] -> usage ()
  | names -> clean None names

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
