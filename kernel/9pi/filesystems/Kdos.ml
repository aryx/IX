(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Kdos.mli *)

open Types
open Errors

(* the file systems attached so far, by their partitions' names: a
 * channel's device number is its place here *)
let attached : (string * Fat.t) list ref = ref []

(* the files seen, by device number and qid path (an entry's place on
 * the disk: Fat's [where]): the entry, and its directory's path. A
 * channel has only its qid; the walk that found a file wrote it here. *)
let seen : (int * int, Fat.entry * int) Hashtbl.t = Hashtbl.create 64

let fat_of (c : chan) = snd (List.nth !attached c.devno)
let file (c : chan) =
  if c.qid.path = 0 then (Fat.root (fat_of c), 0)
  else try Hashtbl.find seen (c.devno, c.qid.path) with Not_found -> raise (Error enonexist)

let qid_of (e : Fat.entry) = { path = e.Fat.where; vers = 0; typ = (if e.Fat.is_dir then Qt_dir else Qt_file) }

let dir_of (c : chan) (e : Fat.entry) =
  let d = Dev.mkdir c e.Fat.name (qid_of e) (if e.Fat.is_dir then 0 else e.Fat.size)
            (if e.Fat.is_dir then 0o555 else 0o444) in
  (* (the files are bill's and trog's, as dossrv's) *)
  { d with d_mtime = int_of_float e.Fat.mtime; d_uid = "bill"; d_gid = "trog" }

(* a directory's entries, each remembered *)
let entries (c : chan) =
  let d, _ = file c in
  if not d.Fat.is_dir then raise (Error enotdir);
  let l = Fat.entries (fat_of c) d in
  List.iter (fun e -> Hashtbl.replace seen (c.devno, e.Fat.where) (e, c.qid.path)) l;
  l

(* the partition's file system: the disk's device read from here, as a
 * program would read #S/sdM0/dos *)
let fat part =
  try List.assoc part !attached
  with Not_found ->
    let p = Proc.myproc () in
    let c = Kchan.namec p ("#S/sdM0/" ^ part) in
    let dev = Dev.find c.dev in
    let c = dev.Dev.open_ c { access = Oread; trunc = false; cexec = false; rclose = false } in
    let f = try Fat.make (fun at n -> dev.Dev.read c n at) with Failure m -> raise (Error m) in
    attached := !attached @ [ part, f ];
    f

let init () =
  let d = Dev.default 'F' "fat" in
  Dev.register { d with
    Dev.attach = (fun spec ->
      let part = if spec = "" then "dos" else spec in
      ignore (fat part);
      let rec index i = function (p, _) :: more -> if p = part then i else index (i + 1) more | [] -> 0 in
      let c = Dev.attach 'F' (index 0 !attached) { path = 0; vers = 0; typ = Qt_dir } in
      c.cname <- "#F" ^ spec;
      c);
    Dev.walk = (fun c _ name ->
      let e, parent = file c in
      if not e.Fat.is_dir then raise (Error enotdir)
      else if name = ".." then (if parent = 0 then { path = 0; vers = 0; typ = Qt_dir } else qid_of (fst (Hashtbl.find seen (c.devno, parent))))
      else begin
        (* (a name is found whatever its letters' case, as dossrv) *)
        let wanted = String.lowercase_ascii name in
        match List.find_opt (fun x -> String.lowercase_ascii x.Fat.name = wanted) (entries c) with
        | Some x -> qid_of x
        | None -> raise (Error enonexist)
      end);
    Dev.stat = (fun c -> let e, _ = file c in dir_of c e);
    Dev.dirs = (fun c -> List.map (dir_of c) (entries c));
    Dev.open_ = (fun c m ->
      if (m.access <> Oread && m.access <> Oexec) || m.trunc then raise (Error eperm);
      c);
    Dev.read = (fun c n off -> let e, _ = file c in Fat.read (fat_of c) e off n);
    Dev.close = (fun _ -> ());
  }
