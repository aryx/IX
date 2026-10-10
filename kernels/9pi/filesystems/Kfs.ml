(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Kfs.mli *)

open Types
open Errors

(* the file systems attached so far, by their partitions' names: a
 * channel's device number is its place here *)
let attached : (string * Xv6fs.t) list ref = ref []

(* the files seen, by device number and inode: the name each was
 * walked to by, and its directory's inode. A channel has only its qid
 * (the inode), and xv6's files do not know their names. *)
let seen : (int * int, string * int) Hashtbl.t = Hashtbl.create 64

let fs_of (c : chan) = snd (List.nth !attached c.devno)
let failing f = try f () with Failure m -> raise (Error m)

let is_dir fs i = Xv6fs.kind fs i = Xv6fs.Dir
let qid_of fs i = { path = i; vers = 0; typ = (if is_dir fs i then Qt_dir else Qt_file) }

(* xv6 keeps no permissions: what every file is said to have *)
let perm_of fs i = if is_dir fs i then 0o777 else 0o666

(* (a file of mini-mkfs's has no time: the kernel's date, as a device's) *)
let dir_of (c : chan) i name =
  let fs = fs_of c in
  failing (fun () ->
    let d = Dev.mkdir c name (qid_of fs i) (if is_dir fs i then 0 else Xv6fs.size fs i) (perm_of fs i) in
    match Xv6fs.mtime fs i with 0 -> d | secs -> { d with d_mtime = secs })

(* the time, for what is written *)
let now = Dev.now

(*****************************************************************************)
(* An optimization: a cache of the device's bytes *)
(*****************************************************************************)

(* Xv6fs has no cache: each of a file's blocks is a read of the
 * device for its number (4 bytes) and one for its bytes, and a read
 * of the SD card is a command to it whatever its size. A program of
 * 650 KB started from the card took 1.7 s under QEMU so (plan_rio.md).
 * Here the device is read by pieces of 4 KB, kept: what is asked is
 * cut from them. A write goes to the device at once, as before, and
 * the pieces it touches are forgotten. [cached] false: every read is
 * the device's, as it was. *)
let cached = ref true
let piece = 4096
(* 512 pieces, 2 MB, then all forgotten: simple, and a program read
 * whole fits *)
let pieces : (int, string) Hashtbl.t = Hashtbl.create 512

let cache_read (device : int -> int -> string) at n =
  if not !cached then device at n
  else begin
    let b = Buffer.create n in
    while Buffer.length b < n do
      let pos = at + Buffer.length b in
      let k = pos / piece in
      let bytes =
        try Hashtbl.find pieces k
        with Not_found ->
          let bytes = device (k * piece) piece in
          if Hashtbl.length pieces >= 512 then Hashtbl.clear pieces;
          Hashtbl.replace pieces k bytes;
          bytes in
      let o = pos - (k * piece) in
      (* (the device's end: a piece shorter than asked) *)
      if o >= String.length bytes then Buffer.add_string b (String.make (n - Buffer.length b) '\000')
      else Buffer.add_string b (String.sub bytes o (min (String.length bytes - o) (n - Buffer.length b)))
    done;
    Buffer.contents b
  end

let cache_written at n = if !cached then for k = at / piece to (at + n - 1) / piece do Hashtbl.remove pieces k done

(* the partition's file system: the disk's device read and written
 * from here (as Kdos) *)
let fs part =
  try List.assoc part !attached
  with Not_found ->
    let p = Proc.myproc () in
    let c = Kchan.namec p ("#S/sdM0/" ^ part) in
    let dev = Dev.find c.dev in
    let c = dev.Dev.open_ c { access = Ordwr; trunc = false; cexec = false; rclose = false } in
    let read at n =
      let b = Buffer.create n in
      let rec go () = if Buffer.length b < n then (let s = dev.Dev.read c (n - Buffer.length b) (at + Buffer.length b) in if s <> "" then begin Buffer.add_string b s; go () end) in
      go (); Buffer.contents b in
    let write at s =
      let rec go o = if o < String.length s then go (o + dev.Dev.write c (String.sub s o (String.length s - o)) (at + o)) in
      go 0 in
    (* old: Xv6fs.make read (Some write): each read the device's *)
    let f = failing (fun () -> Xv6fs.make (cache_read read) (Some (fun at s -> write at s; cache_written at (String.length s)))) in
    attached := !attached @ [ part, f ];
    f

let init () =
  let d = Dev.default 'x' "xv6fs" in
  Dev.register { d with
    Dev.attach = (fun spec ->
      let part = if spec = "" then "other" else spec in
      ignore (fs part);
      let rec index i = function (p, _) :: more -> if p = part then i else index (i + 1) more | [] -> 0 in
      let c = Dev.attach 'x' (index 0 !attached) { path = Xv6fs.root; vers = 0; typ = Qt_dir } in
      c.cname <- "#x" ^ spec;
      c);
    Dev.walk = (fun c _ name ->
      let fs = fs_of c in
      failing (fun () ->
        if not (is_dir fs c.qid.path) then raise (Error enotdir);
        match Xv6fs.lookup fs c.qid.path name with
        | Some i -> if name <> ".." && name <> "." then Hashtbl.replace seen (c.devno, i) (name, c.qid.path); qid_of fs i
        | None -> raise (Error enonexist)));
    Dev.stat = (fun c -> dir_of c c.qid.path (try fst (Hashtbl.find seen (c.devno, c.qid.path)) with Not_found -> "/"));
    Dev.dirs = (fun c ->
      let l = failing (fun () -> Xv6fs.entries (fs_of c) c.qid.path) in
      List.map (fun (name, i) -> Hashtbl.replace seen (c.devno, i) (name, c.qid.path); dir_of c i name) l);
    Dev.open_ = (fun c m ->
      let fs = fs_of c in
      failing (fun () ->
        if is_dir fs c.qid.path && (m.access <> Oread || m.trunc) then raise (Error eperm);
        if m.trunc then begin Xv6fs.truncate fs c.qid.path; Xv6fs.set_mtime fs c.qid.path (now ()) end);
      c);
    Dev.read = (fun c n off -> failing (fun () -> Xv6fs.read (fs_of c) c.qid.path off n));
    Dev.write = (fun c s off ->
      failing (fun () -> Xv6fs.write (fs_of c) c.qid.path off s; Xv6fs.set_mtime (fs_of c) c.qid.path (now ()));
      String.length s);
    (* the directory's channel becomes the new file's *)
    (* (a directory: DMDIR, the permissions' sign: Systab's perm_arg) *)
    Dev.create = (fun c name _ perm ->
      let fs = fs_of c in
      let i = failing (fun () -> Xv6fs.create fs c.qid.path name (if perm < 0 then Xv6fs.Dir else Xv6fs.File)) in
      failing (fun () -> Xv6fs.set_mtime fs i (now ()));
      Hashtbl.replace seen (c.devno, i) (name, c.qid.path);
      c.qid <- qid_of fs i);
    Dev.remove = (fun c ->
      let name, parent = try Hashtbl.find seen (c.devno, c.qid.path) with Not_found -> raise (Error eperm) in
      failing (fun () -> Xv6fs.remove (fs_of c) parent name);
      Hashtbl.remove seen (c.devno, c.qid.path));
    (* what of an entry may change (-1, "": unchanged): the name, in its
     * directory, and the time; permissions only to what they are *)
    Dev.wstat = (fun c d ->
      let fs = fs_of c in
      if d.d_perm <> -1 && d.d_perm land 0o777 <> perm_of fs c.qid.path then raise (Error "xv6's file system keeps no permissions");
      if d.d_mtime <> -1 then failing (fun () -> Xv6fs.set_mtime fs c.qid.path d.d_mtime);
      let name, parent = try Hashtbl.find seen (c.devno, c.qid.path) with Not_found -> "/", 0 in
      if d.d_name <> "" && d.d_name <> name then begin
        if parent = 0 then raise (Error eperm);
        failing (fun () -> Xv6fs.rename fs parent name d.d_name);
        Hashtbl.replace seen (c.devno, c.qid.path) (d.d_name, parent)
      end);
    Dev.close = (fun _ -> ());
  }
