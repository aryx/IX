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

(* Fat's refusal, as the kernel's *)
let failing f = try f () with Failure m -> raise (Error m)

(* a channel's file, as it is on the disk now (another channel may
 * have written it), and its directory's path *)
let file (c : chan) =
  if c.qid.path = 0 then (Fat.root (fat_of c), 0)
  else begin
    let e, parent = try Hashtbl.find seen (c.devno, c.qid.path) with Not_found -> raise (Error enonexist) in
    let e = failing (fun () -> Fat.refresh (fat_of c) e) in
    Hashtbl.replace seen (c.devno, c.qid.path) (e, parent);
    e, parent
  end

let qid_of (e : Fat.entry) = { path = e.Fat.where; vers = 0; typ = (if e.Fat.is_dir then Qt_dir else Qt_file) }

let dir_of (c : chan) (e : Fat.entry) =
  let d = Dev.mkdir c e.Fat.name (qid_of e) (if e.Fat.is_dir then 0 else e.Fat.size)
            (if e.Fat.is_dir then 0o777 else if e.Fat.read_only then 0o444 else 0o666) in
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
    let c = dev.Dev.open_ c { access = Ordwr; trunc = false; cexec = false; rclose = false } in
    (* (a read or a write of the disk's may be of fewer bytes than asked: the rest again) *)
    let read at n =
      let b = Buffer.create n in
      let rec go () = if Buffer.length b < n then (let s = dev.Dev.read c (n - Buffer.length b) (at + Buffer.length b) in if s <> "" then begin Buffer.add_string b s; go () end) in
      go (); Buffer.contents b in
    let write at s =
      let rec go o = if o < String.length s then go (o + dev.Dev.write c (String.sub s o (String.length s - o)) (at + o)) in
      go 0 in
    let f = failing (fun () -> Fat.make read (Some write)) in
    attached := !attached @ [ part, f ];
    f

(* the time, for what is written: the kernel's date and its clock
 * (seconds past 2^30 are negative in a Pi1's int: 2^31 more) *)
let now () =
  let f = float_of_int (Dev.now ()) in
  if f < 0.0 then f +. 2147483648.0 else f

let init () =
  Fat.clock := now;
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
      let e, parent = file c in
      if (e.Fat.is_dir || e.Fat.read_only) && (m.access <> Oread || m.trunc) then raise (Error eperm);
      (* (opened with OTRUNC: emptied) *)
      if m.trunc then Hashtbl.replace seen (c.devno, c.qid.path) (failing (fun () -> Fat.truncate (fat_of c) e), parent);
      c);
    Dev.read = (fun c n off -> let e, _ = file c in Fat.read (fat_of c) e off n);
    Dev.write = (fun c s off ->
      let e, parent = file c in
      Hashtbl.replace seen (c.devno, c.qid.path) (failing (fun () -> Fat.write (fat_of c) e off s), parent);
      String.length s);
    (* the directory's channel becomes the new file's *)
    (* (a directory: DMDIR, the permissions' sign: Systab's perm_arg) *)
    Dev.create = (fun c name _ perm ->
      let d, _ = file c in
      let e = failing (fun () -> Fat.create (fat_of c) d name (perm < 0)) in
      Hashtbl.replace seen (c.devno, e.Fat.where) (e, c.qid.path);
      c.qid <- qid_of e);
    Dev.remove = (fun c ->
      let e, _ = file c in
      failing (fun () -> Fat.remove (fat_of c) e);
      Hashtbl.remove seen (c.devno, c.qid.path));
    (* what of an entry may change (-1, "": unchanged): the permissions
     * (FAT's one: a file nobody may write is read only), the time, and
     * the name, in its directory. A file renamed is at another place:
     * its identity changes, here and for those reached through it. *)
    Dev.wstat = (fun c d ->
      let fat = fat_of c in
      let e, parent = file c in
      let keep e = Hashtbl.replace seen (c.devno, c.qid.path) (e, parent); e in
      let e = if d.d_perm <> -1 && not e.Fat.is_dir then keep (failing (fun () -> Fat.set_read_only fat e (d.d_perm land 0o222 = 0))) else e in
      let e = if d.d_mtime <> -1 then keep (failing (fun () -> Fat.set_mtime fat e (let f = float_of_int d.d_mtime in if f < 0.0 then f +. 2147483648.0 else f))) else e in
      if d.d_name <> "" && d.d_name <> e.Fat.name then begin
        let dir = if parent = 0 then Fat.root fat else fst (Hashtbl.find seen (c.devno, parent)) in
        let e' = failing (fun () -> Fat.rename fat dir e d.d_name) in
        let old = c.qid.path in
        let inside = Hashtbl.fold (fun (dev, path) (x, p) l -> if dev = c.devno && p = old then (path, x) :: l else l) seen [] in
        List.iter (fun (path, x) -> Hashtbl.replace seen (c.devno, path) (x, e'.Fat.where)) inside;
        Hashtbl.remove seen (c.devno, old);
        Hashtbl.replace seen (c.devno, e'.Fat.where) (e', parent);
        c.qid <- qid_of e'
      end);
    Dev.close = (fun _ -> ());
  }
