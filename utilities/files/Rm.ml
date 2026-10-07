(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-rm: Plan 9's rm (principia's utilities/files/rm.c): each file
 * removed, or directory when it is empty. -r: a directory with all
 * that is in it; -f: nothing said of what could not be removed, and
 * the status then says all went well. *)

type caps = < Cap.open_out; Cap.readdir; Cap.stderr >

exception Usage

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  try
    let recurse = ref false and quiet = ref false and last = ref None in
    let rec options = function
      | "--" :: rest -> rest
      | a :: rest when String.length a > 1 && a.[0] = '-' ->
          String.iteri (fun k c -> if k > 0 then match c with 'r' -> recurse := true | 'f' -> quiet := true | _ -> raise Usage) a;
          options rest
      | rest -> rest in
    let files = options (List.tl (Array.to_list argv)) in
    (* the system's reason, which is also the process's last words *)
    let err f e =
      if not !quiet then begin
        let why = Unix.error_message e in
        Console.eprint caps (Printf.sprintf "rm: %s: %s\n" f why);
        last := Some why
      end in
    let is_dir (d : Sys_plan9.dir) = d.qid_type land Sys_plan9.dmdir <> 0 in
    (* a directory that is not empty: what is in it first. Each entry is
     * tried as it is (an empty directory goes as a file does); the
     * directories that stayed are then gone into, as rm.c does. *)
    let rec rmdir f =
      match Sys_plan9.dirread caps f with
      | exception Unix.Unix_error (e, _, _) -> err f e
      | entries ->
          let full (d : Sys_plan9.dir) = f ^ "/" ^ d.name in
          let stayed = List.filter (fun (d : Sys_plan9.dir) ->
            match FS.remove_any caps (full d) with
            | () -> false
            | exception Unix.Unix_error (e, _, _) -> if is_dir d then true else begin err (full d) e; false end) entries in
          List.iter (fun d -> rmdir (full d)) stayed;
          (try FS.remove_any caps f with Unix.Unix_error (e, _, _) -> err f e) in
    List.iter (fun f ->
      try FS.remove_any caps f
      with Unix.Unix_error (e, _, _) ->
        (* (rm.c's words are of its last call that failed: the stat's) *)
        match Sys_plan9.dirstat caps f with
        | (d : Sys_plan9.dir) when !recurse && is_dir d -> rmdir f
        | _ -> err f e
        | exception Unix.Unix_error (e', _, _) -> err f (if !recurse then e' else e)) files;
    (match !last with None -> Exit.OK | Some why -> Exit.Err why)
  with Usage -> Console.eprint caps "usage: rm [-fr] file ...\n"; Exit.Err "usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
