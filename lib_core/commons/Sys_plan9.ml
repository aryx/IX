(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Sys_plan9.mli: not Plan 9's *)

let last_words (_ : int) = ""
let exits words = exit (if words = "" then 0 else 1)

let rfnameg = 1 and rfenvg = 2 and rffdg = 4 and rfnoteg = 8 and rfproc = 16 and rfnowait = 64
let rfork (_ : < Cap.fork; .. >) (_ : int) = Unix.fork ()

let mrepl = 0 and mbefore = 1 and mafter = 2 and mcreate = 4 and mcache = 16
let bind (_ : < Cap.bind; .. >) (_ : string) old (_ : int) = raise (Unix.Unix_error (Unix.ENOSYS, "bind", old))
let mount (_ : < Cap.mount; .. >) (_ : Unix.file_descr) old (_ : int) (_ : string) = raise (Unix.Unix_error (Unix.ENOSYS, "mount", old))

type dir = {
  name : string; uid : string; gid : string; muid : string;
  dev_type : char; dev : int;
  qid_path : int64; qid_vers : int64; qid_type : int;
  mode_type : int; perm : int;
  atime : float; mtime : float; length : int;
}
let dmdir = 0x80 and dmappend = 0x40 and dmexcl = 0x20 and dmauth = 0x08 and dmtmp = 0x04

(* (a link that leads nowhere is itself) *)
let dir_of name path =
  let st : Unix.stats = try Unix.stat path with Unix.Unix_error _ -> Unix.lstat path in
  let t = if st.st_kind = Unix.S_DIR then dmdir else 0 in
  { name; uid = string_of_int st.st_uid; gid = string_of_int st.st_gid; muid = ""; dev_type = 'M'; dev = 0;
    qid_path = Int64.of_int st.st_ino; qid_vers = 0L; qid_type = t; mode_type = t; perm = st.st_perm land 0o777;
    atime = st.st_atime; mtime = st.st_mtime; length = st.st_size }

let dirstat (_ : < Cap.readdir; .. >) path = dir_of (if path = "/" then path else Filename.basename path) path
let dirread (_ : < Cap.readdir; .. >) path =
  let names = try Sys.readdir path with Sys_error m -> raise (Unix.Unix_error (Unix.ENOENT, "dirread", m)) in
  List.map (fun name -> dir_of name (Filename.concat path name)) (Array.to_list names)

let rename (_ : < Cap.open_out; .. >) path name = Unix.rename path (Filename.concat (Filename.dirname path) name)
let chmod (_ : < Cap.open_out; .. >) path (_ : int) perm = Unix.chmod path perm
let set_mtime (_ : < Cap.open_out; .. >) path secs = Unix.utimes path secs secs
