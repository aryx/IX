(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-cp: Plan 9's cp (principia's utilities/files/cp.c): cp from to,
 * a file's bytes in another, made with its permissions or emptied; cp
 * from ... dir, each in the directory under its own name. A directory
 * is not copied. Not cp.c's -g, -u and -x (the new file with the old
 * one's group, owner, time and mode): they are a wstat, which ix's
 * Unix does not have. *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stderr >

(* what could not be copied is said, and the next file tried *)
exception Failed of string

let reason e = Unix.error_message e

let copy1 from_fd to_fd from dest =
  let buf = Bytes.create 8192 in
  let rec go () =
    match Unix.read from_fd buf 0 8192 with
    | 0 -> ()
    | n ->
        (match Unix.write to_fd buf 0 n with
         | m when m = n -> go ()
         | _ -> raise (Failed (Printf.sprintf "error writing %s: short write" dest))
         | exception Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "error writing %s: %s" dest (reason e))))
    | exception Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "error reading %s: %s" from (reason e))) in
  go ()

let copy (caps : < caps; .. >) from dest =
  let stat : Sys_plan9.dir = try Sys_plan9.dirstat caps from with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't stat %s: %s" from (reason e))) in
  if stat.mode_type land Sys_plan9.dmdir <> 0 then raise (Failed (from ^ " is a directory"));
  (* the same file by its identity for its server, not by its name:
   * emptying it to copy it would lose it *)
  (match Sys_plan9.dirstat caps dest with
   | (d : Sys_plan9.dir) when d.qid_type = stat.qid_type && d.qid_path = stat.qid_path && d.qid_vers = stat.qid_vers && d.dev = stat.dev && d.dev_type = stat.dev_type ->
       raise (Failed (Printf.sprintf "%s and %s are the same file" from dest))
   | _ -> ()
   | exception Unix.Unix_error _ -> ());
  let from_fd = try FS.open_in_fd caps from with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't open %s: %s" from (reason e))) in
  Fun.protect ~finally:(fun () -> Unix.close from_fd) (fun () ->
    let to_fd = try FS.open_out_fd caps dest stat.perm with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't create %s: %s" dest (reason e))) in
    Fun.protect ~finally:(fun () -> Unix.close to_fd) (fun () -> copy1 from_fd to_fd from dest))

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  let usage () = Console.eprint caps "usage:\tcp fromfile tofile\n\tcp fromfile ... todir\n"; Exit.Err "usage" in
  match List.rev (List.tl (Array.to_list argv)) with
  | a :: _ when String.length a > 1 && a.[0] = '-' -> usage ()
  | dest :: (_ :: _ as sources) when not (List.exists (fun a -> String.length a > 1 && a.[0] = '-') sources) ->
      let todir = match Sys_plan9.dirstat caps dest with (d : Sys_plan9.dir) -> d.mode_type land Sys_plan9.dmdir <> 0 | exception Unix.Unix_error _ -> false in
      if List.length sources > 1 && not todir then begin
        Console.eprint caps (Printf.sprintf "cp: %s not a directory\n" dest); Exit.Err "bad usage"
      end
      else begin
        let failed = ref false in
        List.iter (fun from ->
          (* in a directory: under the name's last part *)
          let last = match String.rindex_opt from '/' with Some k -> String.sub from (k + 1) (String.length from - k - 1) | None -> from in
          try copy caps from (if todir then dest ^ "/" ^ last else dest)
          with Failed msg -> Console.eprint caps ("cp: " ^ msg ^ "\n"); failed := true) (List.rev sources);
        if !failed then Exit.Err "errors" else Exit.OK
      end
  | _ -> usage ()

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
