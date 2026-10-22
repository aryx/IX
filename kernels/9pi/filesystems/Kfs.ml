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

let is_dir fs i = Xv6fs.kind fs i = Xv6fs.Dir
let qid_of fs i = { path = i; vers = 0; typ = (if is_dir fs i then Qt_dir else Qt_file) }

(* xv6 keeps no permissions: what every file is said to have *)
let perm_of fs i = if is_dir fs i then 0o777 else 0o666

(*****************************************************************************)
(* An optimization: a cache of the device's bytes *)
(*****************************************************************************)

(* Xv6fs has no cache: each of a file's blocks is a read of the
 * device for its number (4 bytes) and one for its bytes, and a read
 * of the SD card is a command to it whatever its size. A program of
 * 650 KB started from the card took 1.7 s under QEMU so (plan_rio.md).
 * Here the device is read by pieces of 4 KB, kept: what is asked is
 * cut from them. A write changes the pieces it touches, and they are
 * written to the device later ([failing], below), each once and
 * whole: a file's block appended was five small writes (the bitmap's
 * byte, the block zeroed, its number, its bytes, the size and the
 * time), each a command to the card and, for less than its sector, a
 * read of it first; and each forgot a piece that the next read fetched
 * again. cp of 5.6 MB took 58 s under QEMU so (plan_self_hosting.md).
 * [cached] false: every read and write is the device's, as it was. *)
let cached = ref true
let piece = 4096
(* 8192 pieces, 32 MB, then all forgotten: simple, and what a build
 * reads again and again fits (mini-ml 2.7 MB, mini-mk, mini-rc,
 * mini-ld, lib_core.a 5.6 MB, the sources). 2 MB was less than
 * mini-ml: each compile read it from the card again, 40% of a
 * compile's time under QEMU (plan_self_hosting.md).
 * old: 512 pieces, 2 MB *)
let max_pieces = 8192
(* Each piece in a page of the processes' memory (Mmu.kalloc), with
 * its length (the device's last is shorter), not a string of the
 * kernel's heap: the kernel's malloc never takes back what it gave
 * (libc.c), and a cache of 32 MB of strings, made and dropped as the
 * card is read and written, took its heap from 15 MB to its 96 in
 * twenty minutes of a build, the kernel then stopped (out of memory).
 * old: let pieces : (int, string) Hashtbl.t = Hashtbl.create 512 *)
let pieces : (int, int * int) Hashtbl.t = Hashtbl.create max_pieces
(* how many (ocaml-light's Hashtbl.length counts them, its buckets
 * all looked at) *)
let npieces = ref 0
(* the pieces changed and not yet written, with how to write them, and
 * how many *)
let dirty : (int * (int -> string -> unit)) list ref = ref []
let ndirty = ref 0

let bytes_of (pa, len) = Machine.Phys.read pa len

let flush () =
  List.iter (fun (k, write) -> write (k * piece) (bytes_of (Hashtbl.find pieces k)))
    (List.rev !dirty);
  dirty := [];
  ndirty := 0

(* all forgotten, what was changed written first, their pages given back *)
let forget () =
  flush ();
  Hashtbl.iter (fun _ (pa, _) -> Mmu.kfree pa) pieces;
  Hashtbl.clear pieces;
  npieces := 0

(* piece [k], read from the device when it is not here *)
let piece_of (device : int -> int -> string) k =
  try Hashtbl.find pieces k
  with Not_found ->
    let bytes = device (k * piece) piece in
    if !npieces >= max_pieces then forget ();
    let pa = match Mmu.kalloc () with
      | Some pa -> pa
      | None ->
          forget ();
          (match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem)) in
    Machine.Phys.write pa bytes;
    let e = (pa, String.length bytes) in
    Hashtbl.replace pieces k e;
    incr npieces;
    e

let cache_read (device : int -> int -> string) at n =
  if not !cached then device at n
  else begin
    let b = Buffer.create n in
    while Buffer.length b < n do
      let pos = at + Buffer.length b in
      let k = pos / piece in
      let pa, len = piece_of device k in
      let o = pos - (k * piece) in
      (* (the device's end: a piece shorter than asked) *)
      if o >= len then Buffer.add_string b (String.make (n - Buffer.length b) '\000')
      else begin
        let m = min (len - o) (n - Buffer.length b) in
        Buffer.add_string b (Machine.Phys.read (pa + o) m)
      end
    done;
    Buffer.contents b
  end

(* old: the device written at once, the pieces forgotten:
 * let cache_written at n = if !cached then for k = at / piece to (at + n - 1) / piece do Hashtbl.remove pieces k done *)
let cache_write (device : int -> int -> string) (write : int -> string -> unit) at s =
  if not !cached then write at s
  else
    for k = at / piece to (at + String.length s - 1) / piece do
      let pa, len = piece_of device k in
      (* the part of s in this piece, and where *)
      let from = max at (k * piece)
      and upto = min (at + String.length s) ((k * piece) + len) in
      if upto > from then
        Machine.Phys.write_sub (pa + from - (k * piece)) s (from - at) (upto - from);
      if not (List.mem_assoc k !dirty) then begin
        dirty := (k, write) :: !dirty;
        incr ndirty
      end
    done

(* A call of the file system: its failure the kernel's error. What it
 * wrote stays in the pieces, written to the device with what the next
 * calls write, once 256 pieces (1 MB) are waiting or a second later
 * (the writer, below) or when a call fails: a file written in several
 * calls, and the pieces many files share (their inodes, the bitmap, a
 * directory), go to the card once. A build on the card wrote them at
 * each call: the card's writes, word by word, a fifth of a compile
 * under QEMU (plan_self_hosting.md). A machine stopped loses the last
 * second's writes, as Plan 9's file servers' caches do.
 * old: flush () at the end of each call *)
let failing f =
  let x = try f () with Failure m -> flush (); raise (Error m) | e -> flush (); raise e in
  if !ndirty >= 256 then flush ();
  x

(* the writer: a process of the kernel's own, the pieces waiting
 * written each second (between calls: the kernel runs one at a time) *)
let writer = ref false
let start_writer () =
  if not !writer then begin
    writer := true;
    Kproc.start (Proc.myproc ()) "kfs" (fun () ->
      while true do
        (try Proc.tsleep 1000 with Error _ -> ());
        (try if !dirty <> [] then flush () with Error _ | Failure _ -> ())
      done)
  end

(* (a file of mini-mkfs's has no time: the kernel's date, as a device's) *)
let dir_of (c : chan) i name =
  let fs = fs_of c in
  failing (fun () ->
    let d = Dev.mkdir c name (qid_of fs i) (if is_dir fs i then 0 else Xv6fs.size fs i) (perm_of fs i) in
    match Xv6fs.mtime fs i with 0 -> d | secs -> { d with d_mtime = secs })

(* the time, for what is written *)
let now = Dev.now

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
    let f = failing (fun () -> Xv6fs.make (cache_read read) (Some (cache_write read write))) in
    start_writer ();
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
