(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* testing:
 * OCaml builds this file too, on the host, where it is tested with a
 * disk of bytes in memory (tests/KFS_tests/Host.ml)
 *)


(*****************************************************************************)
(* The disk, and the kernel's memory the file system works in *)
(*****************************************************************************)

(* a file's number: a tree's (0 the live one), an inode's in it *)
type tree = int
type inode = int

(* an inode's type: a directory or a file (1 and 2 on the disk, as in
 * the entries the kernel gives ls; old: the numbers, at the
 * interface too) *)
type file_kind = Fs_dir | Fs_file
let kind_code k = match k with Fs_dir -> 1 | Fs_file -> 2

(* The transfer of block b to memory at a, or from it: the kernel's is
 * its disk device's (its commands 1 and 2), the tests' a string of
 * bytes. *)
type disk_io = Disk_read | Disk_write

let fs_bsize = 1024

(* The memory, from 10 MB up, is the kernel's area that nothing else uses.
 * It holds buffers of a block each, for any disk (a call works on one at
 * a time): 0 to 2 for the levels of a write, 3 for a read, 4 for a block
 * of inodes, 5 for following pointers, 6 for a text to write, 7 for the
 * disk's own block 0, 8 to 13 for marking; then the inode being worked
 * on (14). Each disk mounted has its own superblock and map of the
 * blocks (a byte each, for 64 K blocks at most) after them: the first
 * disk's at buffer 15, each next one 128 KB higher. *)
let fs_mem = 0xa00000
let fs_buf k = fs_mem + (k * fs_bsize)
let fs_ino = fs_buf 14
let fs_max = 65536

(* the words are 4 bytes, the low byte first, as the machine's *)
let fs_get a =
  KRaw.peekb a lor (KRaw.peekb (a + 1) lsl 8) lor (KRaw.peekb (a + 2) lsl 16)
  lor (KRaw.peekb (a + 3) lsl 24)
let fs_set a v =
  KRaw.pokeb a (v land 255);
  KRaw.pokeb (a + 1) ((v lsr 8) land 255);
  KRaw.pokeb (a + 2) ((v lsr 16) land 255);
  KRaw.pokeb (a + 3) ((v lsr 24) land 255)

(* The superblock's words: the magic number, the disk's size in blocks,
 * the boots counted, the snapshots kept. Then the roots, an inode each:
 * root 0 is the live tree, roots 1 to 14 the snapshots, the newest
 * first. A root is the inode of a tree's inode file. *)
let fs_magic = 0x32534654

(* A file system, a disk mounted, which each function of it is given, as
 * Linux's super_block: its disk's number and transfers; where its
 * superblock and
 * its map are in memory; its size in blocks; how many blocks are free;
 * the blocks written since the last commit (fresh: they may be written
 * again in place); whether anything changed since; where to look for a
 * free block first. *)
type fs = {
  disk : int;
  io : int -> int -> disk_io -> unit;
  sb : int; map : int;
  mutable blocks : int;
  mutable nfree : int;
  mutable fresh : int list;
  mutable changed : bool;
  mutable next : int;
}
let fs_disk fs = fs.disk
let fs_read fs b a = fs.io b a Disk_read
let fs_write fs b a = fs.io b a Disk_write
let fs_root fs r = fs.sb + 16 + (64 * r)
let fs_nsnaps fs = fs_get (fs.sb + 12)

exception Disk_full

(*****************************************************************************)
(* Inodes and their blocks *)
(*****************************************************************************)

(* An inode is 16 words: its type (0 free, 1 a directory, 2 a file), its
 * size in bytes, its links, its date (the last write's, seconds since
 * 2000), then 10 direct blocks, an indirect one and a double indirect
 * one; a block of pointers has 256. [fs_slot i] says where block i of
 * a file hangs: the inode's word, how many levels of pointers are under
 * that word, and the index under them. *)
let fs_slot i =
  if i < 10 then 4 + i, 0, i
  else if i < 266 then 14, 1, i - 10
  else 15, 2, i - 266

(* the date a write or a new file gets: the kernel's clock (the tests'
 * own) *)
let fs_clock = ref (fun () -> 0)

(* the block under ptr at index i, levels deep (0: a hole) *)
let rec fs_find fs ptr level i =
  if ptr = 0 || level = 0 then ptr
  else begin
    let s = if level = 1 then 1 else 256 in
    fs_read fs ptr (fs_buf 5);
    fs_find fs (fs_get (fs_buf 5 + (4 * (i / s)))) (level - 1) (i mod s)
  end

(* block i of the inode at ino *)
let fs_block fs ino i =
  let k, level, j = fs_slot i in
  fs_find fs (fs_get (ino + (4 * k))) level j

(* Marking: the blocks a tree uses, from an inode at ino, each one no
 * longer free. A block already
 * marked is skipped with what is under it (the trees share most of
 * theirs). When [leaf], the inode's file is an inode file: its data
 * blocks hold inodes, whose trees are marked in turn. Each depth has its
 * own buffer, so a block is still there when the marking comes back. *)
let rec fs_mark fs ptr level d leaf =
  if ptr > 0 && ptr < fs.blocks && KRaw.peekb (fs.map + ptr) <> 1 then begin
    if KRaw.peekb (fs.map + ptr) = 0 then begin
      KRaw.pokeb (fs.map + ptr) 1;
      fs.nfree <- fs.nfree - 1
    end;
    if level > 0 || leaf then begin
      let a = fs_buf (8 + d) in
      fs_read fs ptr a;
      if level > 0 then
        for k = 0 to 255 do
          fs_mark fs (fs_get (a + (4 * k))) (level - 1) (d + 1) leaf
        done
      else for k = 0 to 15 do fs_mark_inode fs (a + (64 * k)) (d + 1) false done
    end
  end

and fs_mark_inode fs ino d leaf =
  if fs_get ino <> 0 then
    for k = 4 to 15 do
      fs_mark fs (fs_get (ino + (4 * k))) (if k < 14 then 0 else k - 13) d leaf
    done

(* The collection: a block is free when no tree uses it. The trees are
 * the live one, the snapshots, and the tree of the last commit on the
 * disk (a crash would come back to it). A fresh block stays used even
 * when no tree has it yet: a write may be halfway through linking it. *)
let fs_gc fs =
  fs.nfree <- 0;
  for b = 1 to fs.blocks - 1 do
    if KRaw.peekb (fs.map + b) <> 2 then begin
      KRaw.pokeb (fs.map + b) 0;
      fs.nfree <- fs.nfree + 1
    end
  done;
  fs_read fs 0 (fs_buf 7);
  fs_mark_inode fs (fs_buf 7 + 16) 0 true;
  for r = 0 to fs_nsnaps fs do fs_mark_inode fs (fs_root fs r) 0 true done

(* a free block, now fresh; the collection runs when there is none left *)
let rec fs_alloc fs again =
  let n = fs.blocks in
  let rec look b left =
    if left = 0 then 0
    else if KRaw.peekb (fs.map + b) = 0 then b
    else look (if b + 1 >= n then 1 else b + 1) (left - 1)
  in
  let b = look fs.next (n - 1) in
  if b = 0 then (if again then (fs_gc fs; fs_alloc fs false) else raise Disk_full)
  else (
    KRaw.pokeb (fs.map + b) 2;
    fs.fresh <- b :: fs.fresh;
    fs.next <- b;
    fs.nfree <- fs.nfree - 1;
    b)

(* Room for n new blocks, and 8 more. Even a removal needs new blocks,
 * for the copies of the directory and of the inodes on their way to the
 * root: so what makes files (a write, a creation) must leave a few to
 * what removes them, or a full disk could not be emptied (ZFS keeps such
 * a reserve too). *)
let fs_room fs n =
  if fs.nfree < n + 8 then (
    fs_gc fs;
    if fs.nfree < n + 8 then raise Disk_full)

(* The block ptr in memory at a, and the block it may be written back to:
 * itself when it is fresh, a new one when a commit has it (copy on
 * write). A hole (0) is a block of zeros. *)
let fs_own fs ptr a =
  if ptr = 0 then (KRaw.row_fill a 0 fs_bsize; fs_alloc fs true)
  else begin
    fs_read fs ptr a;
    if KRaw.peekb (fs.map + ptr) = 2 then ptr else fs_alloc fs true
  end

(* [fs_store ptr level i f]: block i under ptr changed by f, which is
 * given its address in memory. Each block on the way down is owned
 * first, so the change goes up as new pointers to the copies. It returns
 * where ptr now is. *)
let rec fs_store fs ptr level i f =
  let a = fs_buf level in
  let b = fs_own fs ptr a in
  if level = 0 then f a
  else begin
    let s = if level = 1 then 1 else 256 in
    let slot = a + (4 * (i / s)) in
    fs_set slot (fs_store fs (fs_get slot) (level - 1) (i mod s) f)
  end;
  fs_write fs b a;
  fs.changed <- true;
  b

(* block i of the inode at ino changed by f *)
let fs_put fs ino i f =
  let k, level, j = fs_slot i in
  let w = ino + (4 * k) in
  fs_set w (fs_store fs (fs_get w) level j f)

(* Inode n of tree r, loaded at fs_ino; saved into the live tree. An
 * inode file is a file like the others: an inode's change is a write to
 * it, and goes up to the root in the superblock. *)
let fs_load fs r n =
  let b = fs_block fs (fs_root fs r) (n / 16) in
  if b = 0 then KRaw.row_fill fs_ino 0 64
  else (
    fs_read fs b (fs_buf 4);
    KRaw.row_copy fs_ino (fs_buf 4 + (64 * (n mod 16))) 64)
let fs_save fs n =
  fs_put fs (fs_root fs 0) (n / 16) (fun a ->
      KRaw.row_copy (a + (64 * (n mod 16))) fs_ino 64)

let fs_word k = fs_get (fs_ino + (4 * k))
let fs_setw k v = fs_set (fs_ino + (4 * k)) v

(* a new inode of a type, its links 0: a free one, or one more at the
 * end of the inode file (whose size counts its inodes) *)
let fs_new fs typ =
  fs_room fs 4;
  let count = fs_get (fs_root fs 0 + 4) in
  let rec free n =
    if n >= count then n
    else (fs_load fs 0 n; if fs_word 0 = 0 then n else free (n + 1))
  in
  let n = free 2 in
  if n >= count then fs_set (fs_root fs 0 + 4) (n + 1);
  KRaw.row_fill fs_ino 0 64;
  fs_setw 0 typ;
  fs_setw 3 (!fs_clock ());
  fs_save fs n;
  n

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

(* the type, the size and the links of inode n of tree r; its date *)
let fs_kind fs (r : tree) (n : inode) : file_kind * int * int =
  fs_load fs r n;
  (if fs_word 0 = 1 then Fs_dir else Fs_file), fs_word 1, fs_word 2
let fs_date fs r n = fs_load fs r n; fs_word 3
let fs_is_dir fs r n = fs_load fs r n; fs_word 0 = 1

(* Up to len bytes of inode n of tree r, from off, to memory at a; how
 * many there were. A hole reads as zeros. *)
let fs_read_at fs r n off a len =
  fs_load fs r n;
  let len = max 0 (min len (fs_word 1 - off)) in
  let rec go d =
    if d < len then begin
      let o = (off + d) mod fs_bsize in
      let k = min (len - d) (fs_bsize - o) in
      let b = fs_block fs fs_ino ((off + d) / fs_bsize) in
      if b = 0 then KRaw.row_fill (a + d) 0 k
      else (fs_read fs b (fs_buf 3); KRaw.row_copy (a + d) (fs_buf 3 + o) k);
      go (d + k)
    end in
  go 0;
  len

(* len bytes from memory at a, written to inode n of the live tree at off
 * (fs_write_in: whatever room it takes, for a directory's entries) *)
let fs_write_in fs n off a len =
  fs_load fs 0 n;
  let rec go d =
    if d < len then begin
      let o = (off + d) mod fs_bsize in
      let k = min (len - d) (fs_bsize - o) in
      fs_put fs fs_ino ((off + d) / fs_bsize)
        (fun b -> KRaw.row_copy (b + o) (a + d) k);
      go (d + k)
    end in
  go 0;
  if off + len > fs_word 1 then fs_setw 1 (off + len);
  fs_setw 3 (!fs_clock ());
  fs_save fs n

let fs_write_at fs n off a len =
  fs_room fs ((len / fs_bsize) + 6); fs_write_in fs n off a len

(* a string written to inode n at off, a block at a time *)
let fs_write_string fs n off s =
  let rec go d =
    if d < String.length s then begin
      let k = min fs_bsize (String.length s - d) in
      KRaw.row_bytes s d (fs_buf 6) k;
      fs_write_in fs n (off + d) (fs_buf 6) k;
      go (d + k)
    end in
  go 0

(* its size 0; its blocks are left to the collection *)
let fs_truncate fs n =
  fs_load fs 0 n;
  fs_setw 1 0;
  fs_setw 3 (!fs_clock ());
  for k = 4 to 15 do fs_setw k 0 done;
  fs_save fs n

(* the whole of inode n of tree r, as a string *)
let fs_read_string fs r n off len =
  KRaw.row_string (fs_buf 6) (fs_read_at fs r n off (fs_buf 6) (min len fs_bsize))

let fs_contents fs r n =
  let size = (fs_load fs r n; fs_word 1) in
  let rec go at acc =
    if at >= size then String.concat "" (List.rev acc)
    else (
      let k = fs_read_at fs r n at (fs_buf 6) fs_bsize in
      go (at + k) (KRaw.row_string (fs_buf 6) k :: acc)) in
  go 0 []

(*****************************************************************************)
(* Directories *)
(*****************************************************************************)

(* A directory is a file of entries of 68 bytes: a name (64 bytes, ended
 * by zeros when shorter) and an inode's number. There is no "." or
 * "..": the kernel resolves ".." by the path's text. *)
let fs_bytes n =
  String.concat ""
    (List.map (fun k -> String.make 1 (Char.chr ((n lsr k) land 255)))
       [ 0; 8; 16; 24 ])
let fs_entry name n =
  name ^ String.make (64 - String.length name) '\000' ^ fs_bytes n

let fs_entries fs r d =
  let s = fs_contents fs r d in
  let rec go i acc =
    if i + 68 > String.length s then List.rev acc
    else begin
      let rec len k = if k < 64 && s.[i + k] <> '\000' then len (k + 1) else k in
      let n =
        String.get_uint16_le s (i + 64)
        + (String.get_uint16_le s (i + 66) lsl 16) in
      go (i + 68) ((String.sub s i (len 0), n) :: acc)
    end in
  go 0 []

(* the inode under a name in directory d of tree r *)
let fs_lookup fs (r : tree) (d : inode) name : inode option =
  List.assoc_opt name (fs_entries fs r d)

(* one more name for inode n, in directory d *)
let fs_link fs d name n =
  fs_write_string fs d (fs_load fs 0 d; fs_word 1) (fs_entry name n);
  fs_load fs 0 n;
  fs_setw 2 (fs_word 2 + 1);
  fs_save fs n

(* a new file or directory under a name in d *)
let fs_create fs (d : inode) name (k : file_kind) : inode =
  let n = fs_new fs (kind_code k) in fs_link fs d name n; n

(* A name removed from d, the directory written again without it. The
 * inode is freed with its last name. (A program that still has it open
 * reads what is there next: Unix keeps it until the last close.) *)
let fs_unlink fs d name =
  let l = fs_entries fs 0 d in
  let n = fs_lookup fs 0 d name in
  fs_truncate fs d;
  fs_write_string fs d 0
    (String.concat ""
       (List.map (fun (m, k) -> fs_entry m k)
          (List.filter (fun (m, _) -> m <> name) l)));
  match n with
  | Some n ->
      fs_load fs 0 n;
      fs_setw 2 (fs_word 2 - 1);
      if fs_word 2 <= 0 then KRaw.row_fill fs_ino 0 64;
      fs_save fs n
  | None -> ()

(*****************************************************************************)
(* Commits, snapshots, the mount *)
(*****************************************************************************)

(* The commit: the superblock written, in one block. Before it the disk
 * has the last commit's tree whole, after it the new one. The fresh
 * blocks are now the commit's: a change copies them again. *)
let fs_commit fs =
  if fs.changed then begin
    fs_write fs 0 fs.sb;
    List.iter (fun b -> KRaw.pokeb (fs.map + b) 1) fs.fresh;
    fs.fresh <- [];
    fs.changed <- false
  end

(* a new file system: the inode file, with inode 0 unused and inode 1
 * the root directory *)
let fs_format fs n =
  KRaw.row_fill fs.sb 0 fs_bsize;
  fs_set fs.sb fs_magic;
  fs_set (fs.sb + 4) n;
  fs_set (fs_root fs 0) 2;
  fs_set (fs_root fs 0 + 4) 2;
  KRaw.row_fill fs_ino 0 64;
  fs_setw 0 1;
  fs_setw 2 1;
  fs_save fs 1

(* whether two roots are the same tree (their third word, the boot, aside) *)
let fs_same fs r q =
  let rec go k =
    k >= 16
    || ((k = 2 || fs_get (fs_root fs r + (4 * k)) = fs_get (fs_root fs q + (4 * k)))
        && go (k + 1))
  in
  go 0

(* The mount, at the boot, on a disk of n blocks: a blank disk is
 * formatted (and a file system keeps the size it was made with);
 * otherwise the free blocks are found by a collection, and
 * the tree the last boot left becomes a snapshot (unless it is the
 * snapshot before it again), the oldest of 14 dropped. The live tree's
 * third word is this boot's number. A disk is mounted by its number,
 * k (0 the first, 1 the second: where its superblock and its map are),
 * and its transfers, io; mounted again, a reboot of the tests, it is
 * the same k. *)
let fs_mounted : (int * fs) list ref = ref []
let fs_mount io k n =
  let n = min n fs_max in
  let sb = fs_buf 15 + (k * 0x20000) in
  let fs = { disk = k; io = io; sb = sb; map = sb + fs_bsize; blocks = 0; nfree = 0;
             fresh = []; changed = false; next = 1 } in
  fs_mounted := (k, fs) :: List.remove_assoc k !fs_mounted;
  KRaw.row_fill fs.map 0 n;
  KRaw.pokeb fs.map 1;
  fs_read fs 0 fs.sb;
  if fs_get fs.sb <> fs_magic then (fs.blocks <- n; fs.nfree <- n - 1; fs_format fs n)
  else begin
    (* the disk's size now, its blocks past the recorded size free: a
     * disk made bigger (truncate -s) is used whole, as resize2fs does *)
    fs.blocks <- n;
    fs_set (fs.sb + 4) n;
    fs_gc fs;
    let k = fs_nsnaps fs in
    if k = 0 || not (fs_same fs 0 1) then begin
      let k = min k 13 in
      for r = k downto 1 do
        KRaw.row_copy (fs_root fs (r + 1)) (fs_root fs r) 64
      done;
      KRaw.row_copy (fs_root fs 1) (fs_root fs 0) 64;
      fs_set (fs.sb + 12) (k + 1)
    end
  end;
  fs_set (fs.sb + 8) (fs_get (fs.sb + 8) + 1);
  fs_set (fs_root fs 0 + 8) (fs_get (fs.sb + 8));
  fs.changed <- true;
  fs_commit fs;
  fs

(* every disk mounted committed: the kernel's after each call and at
 * its halt, as Unix's sync *)
let fs_sync () = List.iter (fun (_, fs) -> fs_commit fs) !fs_mounted

(* the snapshots: each its root and the boot it was the live tree of *)
let fs_snapshots fs =
  List.init (fs_nsnaps fs) (fun i -> i + 1, fs_get (fs_root fs (i + 1) + 8))


(* the free blocks, counted after a collection *)
let fs_free fs = fs_gc fs; fs.nfree
