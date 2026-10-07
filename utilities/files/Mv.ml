(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-mv: Plan 9's mv (principia's utilities/files/mv.c): mv from to,
 * a file under another name; mv from ... dir, each in the directory.
 * In the same directory it is the name changed (a wstat: the file
 * stays, a directory too); in another, the file is copied there and
 * the old one removed: 9P has no way to move one, and a directory is
 * then refused. What is at the new name is removed first. *)

type caps = < Cap.open_in; Cap.open_out; Cap.readdir; Cap.stderr >

(* what could not be moved is said, and the next file tried; [Fatal]:
 * mv ends there *)
exception Failed of string
exception Fatal of string

let reason e = Unix.error_message e

(* a name's directory and its last part *)
let split name =
  match String.rindex_opt name '/' with
  | Some k -> String.sub name 0 k, String.sub name (k + 1) (String.length name - k - 1)
  | None -> if name = ".." then "..", "." else ".", name

let stat (caps : < caps; .. >) name : Sys_plan9.dir option = match Sys_plan9.dirstat caps name with d -> Some d | exception Unix.Unix_error _ -> None
let is_dir (d : Sys_plan9.dir) = d.mode_type land Sys_plan9.dmdir <> 0

(* the same file by its identity for its server, not by its name *)
let samefile (caps : < caps; .. >) a b =
  a = b
  || match stat caps a, stat caps b with
     | Some (x : Sys_plan9.dir), Some (y : Sys_plan9.dir) ->
         x.qid_type = y.qid_type && x.qid_path = y.qid_path && x.qid_vers = y.qid_vers && x.dev = y.dev && x.dev_type = y.dev_type
     | _ -> false

let hardremove (caps : < caps; .. >) name =
  try FS.remove_any caps name with Unix.Unix_error (e, _, _) -> raise (Fatal (Printf.sprintf "can't remove %s: %s" name (reason e)))

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

(* [toelem]: the new name's last part; None: the old one's *)
let mv (caps : < caps; .. >) from todir toelem =
  let d : Sys_plan9.dir = try Sys_plan9.dirstat caps from with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't stat %s: %s" from (reason e))) in
  let fromdir, fromelem = split from in
  let toelem = match toelem with Some e -> e | None -> fromelem in
  if toelem = "" then raise (Failed ("null last name element moving " ^ from));
  let dest = todir ^ "/" ^ toelem in
  let renamed =
    samefile caps fromdir todir && begin
      if samefile caps from dest then raise (Failed (Printf.sprintf "%s and %s are the same" from dest));
      if stat caps dest <> None then hardremove caps dest;
      match Sys_plan9.rename caps from toelem with
      | () -> true
      | exception Unix.Unix_error (e, _, _) ->
          if is_dir d then raise (Failed (Printf.sprintf "can't rename directory %s: %s" from (reason e)));
          false
    end in
  (* the name could not be changed: a copy, and the old one removed *)
  if not renamed then begin
    if is_dir d then raise (Failed (Printf.sprintf "%s is a directory, not copied to %s" from dest));
    let from_fd = try FS.open_in_fd caps from with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't open %s: %s" from (reason e))) in
    Fun.protect ~finally:(fun () -> Unix.close from_fd) (fun () ->
      let to_fd = try FS.open_out_fd caps dest d.perm with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't create %s: %s" dest (reason e))) in
      Fun.protect ~finally:(fun () -> Unix.close to_fd) (fun () -> copy1 from_fd to_fd from dest);
      (* (with the old one's time, where the server takes it) *)
      (try Sys_plan9.set_mtime caps dest d.mtime with Unix.Unix_error _ -> ());
      try FS.remove_any caps from with Unix.Unix_error (e, _, _) -> raise (Failed (Printf.sprintf "can't remove %s: %s" from (reason e))))
  end

let main (caps : < caps; .. >) (argv : string array) : Exit.t =
  match List.rev_map FS.cleanname (List.tl (Array.to_list argv)) with
  | last :: (_ :: _ as sources) -> (
      let sources = List.rev sources in
      (* into a directory under the old name, but for a directory alone, which takes the new one *)
      let into = match stat caps last, sources with
        | Some d, [ one ] when is_dir d -> (match stat caps one with Some o when is_dir o -> false | _ -> true)
        | Some d, _ -> is_dir d
        | None, _ -> false in
      let todir, toelem = if into then last, None else let dir, elem = split last in dir, Some elem in
      if List.length sources > 1 && toelem <> None then begin
        Console.eprint caps (Printf.sprintf "mv: %s not a directory\n" last); Exit.Err "bad usage"
      end
      else
        try
          let failed = ref false in
          List.iter (fun from -> try mv caps from todir toelem with Failed msg -> Console.eprint caps ("mv: " ^ msg ^ "\n"); failed := true) sources;
          if !failed then Exit.Err "failure" else Exit.OK
        with Fatal msg -> Console.eprint caps ("mv: " ^ msg ^ "\n"); Exit.Err "mv")
  | _ -> Console.eprint caps "usage: mv fromfile tofile\n   mv fromfile ... todir\n"; Exit.Err "bad usage"

let () = Cap.main (fun caps -> Exit.exit caps (Exit.catch (fun () -> main caps (CapSys.argv caps))))
