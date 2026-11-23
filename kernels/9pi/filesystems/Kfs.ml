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
(* A file's version, its qid's: how many times it was changed since the
 * boot (written, cut, made, removed), by its device and its number. The
 * card keeps none. Fault's kept texts are by it: a program made again
 * is not run from the text of the one before. *)
let versions : (int * int, int) Hashtbl.t = Hashtbl.create 64
let changed (c : chan) i =
  let k = (c.devno, i) in
  let v = try Hashtbl.find versions k with Not_found -> 0 in
  Hashtbl.remove versions k; Hashtbl.add versions k (v + 1)
let qid_of (c : chan) fs i =
  { path = i; vers = (try Hashtbl.find versions (c.devno, i) with Not_found -> 0); typ = (if is_dir fs i then Qt_dir else Qt_file) }

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
(* 32768 pieces at most, 128 MB, while the machine has pages to spare
 * (low_pages free, 64 MB; below, a piece is taken from the cache's
 * own), and one given back at a time, by a clock (below). 2 MB was
 * less than mini-ml: each compile read it from the card again, 40% of
 * a compile's time under QEMU (plan_self_hosting.md).
 * opti: the four-core build of ix on the card read and wrote 619,487
 * pieces with 32 MB all forgotten when full: the card's commands held
 * the kernel's lock 1,089 s of the build's 2,960
 * (plan_9pi_self_speed.md, 2026-11-23); what a build reads again and
 * again (mini-ml 2.7 MB, mini-mk, mini-rc, mini-ld, lib_core.a 5.6 MB,
 * the sources, four compiles' at once) was forgotten with the rest.
 * old: 512 pieces, 2 MB; then let max_pieces = 8192, and forget ()
 * when full: flush (), every page given back, the table cleared *)
let max_pieces = 32768
let low_pages = 16384
(* Each piece in a page of the processes' memory (Mmu.kalloc), with
 * its length (the device's last is shorter), not a string of the
 * kernel's heap: the kernel's malloc never takes back what it gave
 * (libc.c), and a cache of 32 MB of strings, made and dropped as the
 * card is read and written, took its heap from 15 MB to its 96 in
 * twenty minutes of a build, the kernel then stopped (out of memory).
 * old: let pieces : (int, string) Hashtbl.t = Hashtbl.create 512 *)
type entry = { pa : int; len : int; slot : int }
let pieces : (int, entry) Hashtbl.t = Hashtbl.create max_pieces
(* how many (ocaml-light's Hashtbl.length counts them, its buckets
 * all looked at) *)
let npieces = ref 0
(* the pieces changed and not yet written, with how to write them, and
 * how many *)
let dirty : (int * (int -> string -> unit)) list ref = ref []
let ndirty = ref 0

(* opti: the pieces in order, each run of neighbours of a device (up to
 * 64, 256 KB) one write: a command to the card costs about the same
 * whatever its size, and the build wrote 143,797 pieces one by one,
 * 167 s with the kernel's lock held (BSD's cluster_write, Linux's
 * merged requests).
 * old: List.iter (fun (k, write) -> write (k * piece) (its bytes)) (List.rev !dirty) *)
let flush () =
  let bytes k = let e = Hashtbl.find pieces k in Machine.Phys.read e.pa e.len in
  let rec go l =
    match l with
    | [] -> ()
    | (k, write) :: rest ->
        let rec run last n acc l =
          match l with
          | (k2, w) :: r when k2 = last + 1 && w == write && n < 64 -> run k2 (n + 1) (bytes k2 :: acc) r
          | _ -> String.concat "" (List.rev acc), l in
        let s, rest = run k 1 [ bytes k ] rest in
        write (k * piece) s;
        go rest in
  go (List.sort (fun (a, _) (b, _) -> compare a b) !dirty);
  dirty := [];
  ndirty := 0

(* The clock (the second chance: Multics' page replacement, and what
 * Plan 9's image cache and Linux's page cache do in their own ways):
 * each piece has a slot, with the piece's number and whether it was
 * used since the hand last passed. To give one back, the hand goes
 * round: a used one is let off once (no longer used), a changed one
 * not yet written is kept, the first other one given back. Two turns
 * without one: none to give. *)
let slots = Array.make max_pieces (-1)
let used = Array.make max_pieces false
let hand = ref 0
(* the slots given back, and the first never used *)
let free_slots = ref []
let fresh_slot = ref 0
let take_slot () =
  match !free_slots with
  | s :: rest -> free_slots := rest; s
  | [] -> let s = !fresh_slot in incr fresh_slot; s

(* (each given back counted: /dev/lockstat's "in kfs-evict") *)
let evict_part = Proc.part "kfs-evict"
let evict () =
  let t0 = Machine.timer_now () in
  let rec go tries =
    if tries > 0 && !npieces > 0 then begin
      let s = !hand in
      hand := (s + 1) mod max_pieces;
      let k = slots.(s) in
      if k < 0 then go (tries - 1)
      else if used.(s) then begin used.(s) <- false; go (tries - 1) end
      else if List.mem_assoc k !dirty then go (tries - 1)
      else begin
        Mmu.kfree (Hashtbl.find pieces k).pa;
        Hashtbl.remove pieces k;
        decr npieces;
        slots.(s) <- -1;
        free_slots := s :: !free_slots;
        Proc.part_add evict_part ((Machine.timer_now () - t0) land 0x3fffffff)
      end
    end in
  go (2 * max_pieces)

(* pages for the processes, when none is left (Mmu.on_empty, Fault's
 * too): a thousand pieces given back, those not changed *)
let () =
  let next = !Mmu.on_empty in
  Mmu.on_empty := (fun () -> for i = 1 to 1024 do ignore i; evict () done; next ())

(* piece [k]'s bytes kept; the cache full, or the machine short of
 * pages, one given back for it *)
let add k bytes =
  if !npieces >= max_pieces || Mmu.nfree () < low_pages then evict ();
  (* (all changed, none given back: written, and one again) *)
  if !npieces >= max_pieces then begin flush (); evict () end;
  let pa = match Mmu.kalloc () with
    | Some pa -> pa
    | None -> flush (); evict (); (match Mmu.kalloc () with Some pa -> pa | None -> raise (Error enovmem)) in
  Machine.Phys.write pa bytes;
  let s = take_slot () in
  slots.(s) <- k;
  used.(s) <- true;
  let e = { pa = pa; len = String.length bytes; slot = s } in
  Hashtbl.replace pieces k e;
  incr npieces;
  e

(* piece [k], read from the device when it is not here.
 * opti: read ahead, when the piece before is here (a file read in
 * order, a program loaded): the next ones not here too, up to 8 (32
 * KB), in one read of the device, a command to the card (Linux's
 * readahead, BSD's cluster_read; there the window grows and shrinks).
 * old: add k (device (k * piece) piece) *)
let piece_of (device : int -> int -> string) k =
  try let e = Hashtbl.find pieces k in used.(e.slot) <- true; e
  with Not_found ->
    let ahead = if Hashtbl.mem pieces (k - 1) then 8 else 1 in
    let rec count n = if n < ahead && not (Hashtbl.mem pieces (k + n)) then count (n + 1) else n in
    let n = count 1 in
    let bytes = device (k * piece) (n * piece) in
    let e = add k (String.sub bytes 0 (min piece (String.length bytes))) in
    for i = 1 to n - 1 do
      if i * piece < String.length bytes then
        ignore (add (k + i) (String.sub bytes (i * piece) (min piece (String.length bytes - (i * piece)))))
    done;
    e

let cache_read (device : int -> int -> string) at n =
  if not !cached then device at n
  else begin
    let b = Buffer.create n in
    while Buffer.length b < n do
      let pos = at + Buffer.length b in
      let k = pos / piece in
      let e = piece_of device k in
      let pa = e.pa and len = e.len in
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
(* (how many times: failing's, below) *)
let written = ref 0
let cache_write (device : int -> int -> string) (write : int -> string -> unit) at s =
  incr written;
  if not !cached then write at s
  else
    for k = at / piece to (at + String.length s - 1) / piece do
      let e = piece_of device k in
      let pa = e.pa and len = e.len in
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
(* opti: a call that fails writes the pieces only if it changed one
 * itself (written counts cache_write's calls). A name that is not
 * there is a call that fails, and it wrote all that waited: a compiler
 * looking for a unit's summary in each of its directories, rc for a
 * command along its path, each sent up to a megabyte to the card
 * before saying no, 20 to 118 ms for one open, the kernel's lock held
 * (3,500 such opens in lib_core's build on mini-9pi,
 * plan_9pi_self_speed.md).
 * old: with Failure m -> flush (); raise (Error m) | e -> flush (); raise e *)
let failing f =
  let before = !written in
  let wrote () = if !written <> before then flush () in
  let x = try f () with Failure m -> wrote (); raise (Error m) | e -> wrote (); raise e in
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
    let d = Dev.mkdir c name (qid_of c fs i) (if is_dir fs i then 0 else Xv6fs.size fs i) (perm_of fs i) in
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
        | Some i -> if name <> ".." && name <> "." then Hashtbl.replace seen (c.devno, i) (name, c.qid.path); qid_of c fs i
        | None -> raise (Error enonexist)));
    Dev.stat = (fun c -> dir_of c c.qid.path (try fst (Hashtbl.find seen (c.devno, c.qid.path)) with Not_found -> "/"));
    Dev.dirs = (fun c ->
      let l = failing (fun () -> Xv6fs.entries (fs_of c) c.qid.path) in
      List.map (fun (name, i) -> Hashtbl.replace seen (c.devno, i) (name, c.qid.path); dir_of c i name) l);
    Dev.open_ = (fun c m ->
      let fs = fs_of c in
      failing (fun () ->
        if is_dir fs c.qid.path && (m.access <> Oread || m.trunc) then raise (Error eperm);
        if m.trunc then begin Xv6fs.truncate fs c.qid.path; Xv6fs.set_mtime fs c.qid.path (now ()); changed c c.qid.path end);
      c);
    Dev.read = (fun c n off -> failing (fun () -> Xv6fs.read (fs_of c) c.qid.path off n));
    Dev.write = (fun c s off ->
      failing (fun () -> Xv6fs.write (fs_of c) c.qid.path off s; Xv6fs.set_mtime (fs_of c) c.qid.path (now ()));
      changed c c.qid.path;
      String.length s);
    (* the directory's channel becomes the new file's *)
    (* (a directory: DMDIR, the permissions' sign: Systab's perm_arg) *)
    Dev.create = (fun c name _ perm ->
      let fs = fs_of c in
      let i = failing (fun () -> Xv6fs.create fs c.qid.path name (if perm < 0 then Xv6fs.Dir else Xv6fs.File)) in
      failing (fun () -> Xv6fs.set_mtime fs i (now ()));
      Hashtbl.replace seen (c.devno, i) (name, c.qid.path);
      changed c i;
      c.qid <- qid_of c fs i);
    Dev.remove = (fun c ->
      let name, parent = try Hashtbl.find seen (c.devno, c.qid.path) with Not_found -> raise (Error eperm) in
      failing (fun () -> Xv6fs.remove (fs_of c) parent name);
      changed c c.qid.path;
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
