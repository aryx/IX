(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyKernelFS.ml on the host, by OCaml. The disk is a string of bytes,
 * the memory TinyMemory's. We make files and directories, write a file
 * big enough for the double indirect block, stop the machine before a
 * commit (a crash) and mount again, boot a few times for snapshots, and
 * fill the disk until the collector must give blocks back.
 * usage: Host.exe *)

let disk = ref (Bytes.make (1024 * 1024) '\000')
let () =
  TinyKernelFS.fs_io := (fun b a cmd ->
    if cmd = 1 then Bytes.blit !disk (b * 1024) TinyMemory.mem a 1024
    else Bytes.blit TinyMemory.mem a !disk (b * 1024) 1024)

(* a program's memory, where what is written comes from *)
let user = 0x100000

let write n off s =
  TinyMemory.row_bytes s 0 user (String.length s);
  TinyKernelFS.fs_write_at n off user (String.length s)

let cat r n = TinyKernelFS.fs_contents r n

(* the inode under a path from the root directory of tree r *)
let path r p =
  List.fold_left
    (fun d name -> if d = 0 then 0 else TinyKernelFS.fs_lookup r d name)
    1 (String.split_on_char '/' p)

let ls r d =
  String.concat " " (List.map (fun (name, n) ->
    let t, size, links = TinyKernelFS.fs_kind r n in
    Printf.sprintf "%s%s(%d,%d)" name (if t = 1 then "/" else "") size links)
    (TinyKernelFS.fs_entries r d))

let say fmt = Printf.printf (fmt ^^ "\n")

let () =
  (* a blank disk, formatted at the mount *)
  TinyKernelFS.fs_mount 1024;
  say "blank disk: %d blocks free, snapshots %d" (TinyKernelFS.fs_free ())
    (List.length (TinyKernelFS.fs_snapshots ()));
  let notes = TinyKernelFS.fs_create 1 "notes" 2 in
  write notes 0 "hello";
  let d = TinyKernelFS.fs_create 1 "d" 1 in
  let f = TinyKernelFS.fs_create d "f" 2 in
  write f 0 "in d";
  TinyKernelFS.fs_commit ();
  say "root: %s" (ls 0 1);
  say "d: %s" (ls 0 d);
  say "notes: %s; d/f: %s" (cat 0 notes) (cat 0 (path 0 "d/f"));
  (* a write in the middle, one past the end (a hole between) *)
  write notes 1 "ELL";
  write notes 8 "!";
  say "notes: %S" (cat 0 notes);
  (* a second name: the same file *)
  TinyKernelFS.fs_link d "g" notes;
  write (path 0 "d/g") 0 "J";
  say "linked: notes %S, d/g %S, links %d" (cat 0 notes) (cat 0 (path 0 "d/g"))
    (let _, _, l = TinyKernelFS.fs_kind 0 notes in l);
  TinyKernelFS.fs_unlink 1 "notes";
  say "unlinked notes: root %s; d %s" (ls 0 1) (ls 0 d);
  TinyKernelFS.fs_commit ();

  (* a file of 300 KB: 11 direct blocks, 256 under the indirect one, the
   * rest under the double indirect one *)
  let big = TinyKernelFS.fs_create 1 "big" 2 in
  let line i = Printf.sprintf "%07d\n" i in
  let text = String.concat "" (List.init 38400 line) in
  for k = 0 to 299 do write big (k * 1024) (String.sub text (k * 1024) 1024) done;
  TinyKernelFS.fs_commit ();
  let s = cat 0 big in
  say "big: %d bytes, the same: %b; at 11 KB %S, at 267 KB %S"
    (String.length s) (s = text) (String.sub s (11 * 1024) 8)
    (String.sub s (267 * 1024) 8);
  say "free: %d" (TinyKernelFS.fs_free ());

  (* a crash: changes written, but no commit. The disk is mounted again
   * as it is: it has the last commit's tree *)
  write (path 0 "d/f") 0 "CHANGED";
  ignore (TinyKernelFS.fs_create 1 "lost" 2);
  TinyKernelFS.fs_mount 1024;
  say "after the crash: root %s; d/f %S" (ls 0 1) (cat 0 (path 0 "d/f"));

  (* boots: each one's tree a snapshot at the next; a boot that changed
   * nothing leaves none *)
  write (path 0 "d/f") 0 "boot 2";
  TinyKernelFS.fs_commit ();
  TinyKernelFS.fs_mount 1024;
  TinyKernelFS.fs_mount 1024;
  TinyKernelFS.fs_unlink 1 "big";
  TinyKernelFS.fs_commit ();
  TinyKernelFS.fs_mount 1024;
  say "snapshots: %s"
    (String.concat " "
       (List.map (fun (r, boot) -> Printf.sprintf "%d:boot%d" r boot)
          (TinyKernelFS.fs_snapshots ())));
  List.iter (fun (r, boot) ->
      say "boot %d: root %s; d/f %S" boot (ls r 1) (cat r (path r "d/f")))
    (TinyKernelFS.fs_snapshots ());
  say "live: root %s" (ls 0 1);
  say "free: %d" (TinyKernelFS.fs_free ());

  (* a small disk filled: the collector takes back what the live tree
   * replaced, then the disk is full; removed, the file's blocks come
   * back at the next collection *)
  disk := Bytes.make (64 * 1024) '\000';
  TinyKernelFS.fs_mount 64;
  let full = TinyKernelFS.fs_create 1 "full" 2 in
  let rec fill k =
    match write full (k * 1024) (String.make 1024 'x') with
    | () -> fill (k + 1)
    | exception TinyKernelFS.Disk_full -> k
  in
  let k = fill 0 in
  say "small disk: full after %d KB" k;
  TinyKernelFS.fs_commit ();
  for i = 1 to 20 do
    write full 0 (Printf.sprintf "rewrite %d" i);
    TinyKernelFS.fs_commit ()
  done;

  say "rewritten 20 times: %S" (String.sub (cat 0 full) 0 10);
  TinyKernelFS.fs_unlink 1 "full";
  TinyKernelFS.fs_commit ();
  say "removed: %d free" (TinyKernelFS.fs_free ());
  let again = TinyKernelFS.fs_create 1 "again" 2 in
  write again 0 (String.make (20 * 1024) 'y');
  TinyKernelFS.fs_commit ();
  say "again: %d bytes" (String.length (cat 0 again))
