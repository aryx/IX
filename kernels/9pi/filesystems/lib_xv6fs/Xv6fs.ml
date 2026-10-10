(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Xv6fs.mli *)

type t = {
  pread : int -> int -> string;
  pwrite : (int -> string -> unit) option;
  bsize : int;
  blocks : int;                 (* the device's, in all *)
  ninodes : int;
  inodestart : int;             (* the first block of the inodes; of the bitmap *)
  bmapstart : int;
  mutable hint : int;           (* where to look for a free block *)
}

type kind = Dir | File | Device

let magic = 0x10203040
let root = 1
(* an inode's own numbers of blocks, then one of a block of numbers:
 * xv6's. IX'S EXTENSION TO XV6'S FORMAT (Xv6fs.mli): one more, of a
 * block of blocks of numbers, at the inode's byte 8, which xv6 leaves
 * unused; below, what is the extension's is marked "ix's extension". *)
let ndirect = 58
let double_at = 8             (* ix's extension *)
(* IX'S SECOND EXTENSION: when the file was last written, seconds since
 * 1970, in the 4 bytes after (xv6: unused, 0: not known) *)
let mtime_at = 12             (* ix's extension *)
let dirsiz = 14

let pread (t : t) at n = let s = t.pread at n in if String.length s < n then failwith "i/o error" else s
let pwrite (t : t) at s = match t.pwrite with Some w -> w at s | None -> failwith "read only file system"

let le16 s o = Char.code s.[o] lor (Char.code s.[o + 1] lsl 8)
let le32 s o = le16 s o lor (le16 s (o + 2) lsl 16)
let b8 v = String.make 1 (Char.chr (v land 0xff))
let b16 v = b8 v ^ b8 (v lsr 8)
let b32 v = b16 v ^ b16 (v lsr 16)

(* a number of 16 or 32 bits of the disk, at a byte: read, written *)
let get16 t at = le16 (pread t at 2) 0
let get32 t at = le32 (pread t at 4) 0
let set16 t at v = pwrite t at (b16 v)
let set32 t at v = pwrite t at (b32 v)

(* the superblock's numbers, in the block after the first: the magic
 * number, the size, the data blocks, the inodes, the log's blocks and
 * its start, the inodes' start, the bitmap's *)
let make read_at write_at =
  let at bsize = let s = read_at bsize 32 in if String.length s = 32 && le32 s 0 = magic then Some s else None in
  let bsize, sb = match at 512, at 1024 with
    | Some s, _ -> 512, s
    | None, Some s -> 1024, s
    | None, None -> failwith "not an xv6 file system" in
  { pread = read_at; pwrite = write_at; bsize = bsize; blocks = le32 sb 4; ninodes = le32 sb 12;
    inodestart = le32 sb 24; bmapstart = le32 sb 28; hint = 0 }

(*****************************************************************************)
(* Blocks *)
(*****************************************************************************)

(* a block's bit in the bitmap: the byte's place, the bit *)
let bit (t : t) b = (t.bmapstart * t.bsize) + (b / 8), 1 lsl (b mod 8)
let taken t b = let at, m = bit t b in Char.code (pread t at 1).[0] land m <> 0
let mark t b on = let at, m = bit t b in let v = Char.code (pread t at 1).[0] in pwrite t at (b8 (if on then v lor m else v land lnot m))

(* a free block taken, zeroed *)
let balloc (t : t) =
  let rec look b n = if n = 0 then failwith "file system full" else if not (taken t b) then b else look (if b + 1 >= t.blocks then 0 else b + 1) (n - 1) in
  let b = look t.hint t.blocks in
  mark t b true;
  pwrite t (b * t.bsize) (String.make t.bsize '\000');
  t.hint <- b + 1;
  b

(*****************************************************************************)
(* Inodes *)
(*****************************************************************************)

(* an inode's 256 bytes: the type (2 bytes), the device's two numbers,
 * the count of names (at 6), [ix's extension: the block of blocks of
 * numbers (at 8) and the time written (at 12); xv6: unused], the size (at 16), the blocks' numbers (from 20: 58, then the
 * block of numbers) *)
let dinode (t : t) i =
  if i < 1 || i >= t.ninodes then failwith "bad inode number";
  ((t.inodestart + (i / (t.bsize / 256))) * t.bsize) + ((i mod (t.bsize / 256)) * 256)

let kind t i = match get16 t (dinode t i) with 1 -> Dir | 2 -> File | 3 -> Device | _ -> failwith "file does not exist"
let size t i = get32 t (dinode t i + 16)
let nlink t i = get16 t (dinode t i + 6)
(* ix's extension *)
let mtime t i = get32 t (dinode t i + mtime_at)
let set_mtime t i secs = set32 t (dinode t i + mtime_at) secs

(* the place on the disk of the number of a file's block of rank bn:
 * in the inode, in its block of numbers, or in one of the second's;
 * the blocks of numbers on the way are made when [alloc]. None: a hole
 * there, and no block to say so *)
let slot (t : t) i bn alloc =
  let n = t.bsize / 4 in
  let d = dinode t i in
  (* the block a number names, made if it is 0 *)
  let through at = let b = get32 t at in if b <> 0 then Some b else if alloc then (let b = balloc t in set32 t at b; Some b) else None in
  if bn < ndirect then Some (d + 20 + (4 * bn))
  else if bn < ndirect + n then (match through (d + 20 + (4 * ndirect)) with Some b -> Some ((b * t.bsize) + (4 * (bn - ndirect))) | None -> None)
  else if bn < ndirect + n + (n * n) then begin
    (* ix's extension: through the second block of numbers, then one of its blocks of numbers *)
    let k = bn - ndirect - n in
    match through (d + double_at) with
    | Some b -> (match through ((b * t.bsize) + (4 * (k / n))) with Some b -> Some ((b * t.bsize) + (4 * (k mod n))) | None -> None)
    | None -> None
  end
  else failwith "file too large"

(* a file's block of rank bn (0: a hole), made when [alloc] *)
let bmap t i bn alloc =
  match slot t i bn alloc with
  | None -> 0
  | Some at -> let b = get32 t at in if b <> 0 || not alloc then b else (let b = balloc t in set32 t at b; b)

let read (t : t) i offset count =
  let count = max 0 (min count (size t i - offset)) in
  let b = Buffer.create count in
  while Buffer.length b < count do
    let at = offset + Buffer.length b in
    let n = min (t.bsize - (at mod t.bsize)) (count - Buffer.length b) in
    let block = bmap t i (at / t.bsize) false in
    Buffer.add_string b (if block = 0 then String.make n '\000' else pread t ((block * t.bsize) + (at mod t.bsize)) n)
  done;
  Buffer.contents b

let write (t : t) i offset data =
  let n = String.length data in
  let o = ref 0 in
  while !o < n do
    let at = offset + !o in
    let k = min (t.bsize - (at mod t.bsize)) (n - !o) in
    pwrite t ((bmap t i (at / t.bsize) true * t.bsize) + (at mod t.bsize)) (String.sub data !o k);
    o := !o + k
  done;
  if offset + n > size t i then set32 t (dinode t i + 16) (offset + n)

(* a file's blocks given back, its size 0 *)
let truncate (t : t) i =
  let n = t.bsize / 4 and d = dinode t i in
  let free b = if b <> 0 then mark t b false in
  (* a block of numbers: what each names (by [each]), then itself *)
  let numbers at each = let b = get32 t at in if b <> 0 then begin for k = 0 to n - 1 do each ((b * t.bsize) + (4 * k)) done; free b; set32 t at 0 end in
  for k = 0 to ndirect - 1 do let at = d + 20 + (4 * k) in free (get32 t at); set32 t at 0 done;
  numbers (d + 20 + (4 * ndirect)) (fun at -> free (get32 t at));
  (* ix's extension: the second block of numbers, its blocks of numbers, what they name *)
  numbers (d + double_at) (fun at -> numbers at (fun at -> free (get32 t at)));
  set32 t (d + 16) 0;
  t.hint <- 0

(* a free inode taken, of a type *)
let ialloc (t : t) k =
  let rec look i = if i >= t.ninodes then failwith "no more inodes" else if get16 t (dinode t i) = 0 then i else look (i + 1) in
  let i = look 1 in
  pwrite t (dinode t i) (b16 (match k with Dir -> 1 | File -> 2 | Device -> 3) ^ String.make 254 '\000');
  i

(*****************************************************************************)
(* Directories *)
(*****************************************************************************)

(* a directory's entries, each its place in the directory, its inode
 * (0: a free one), its name *)
let slots (t : t) dir =
  if kind t dir <> Dir then failwith "not a directory";
  let s = read t dir 0 (size t dir) in
  List.init (String.length s / 16) (fun k ->
    let o = 16 * k in
    let name = String.sub s (o + 2) dirsiz in
    let rec len j = if j < dirsiz && name.[j] <> '\000' then len (j + 1) else j in
    o, le16 s o, String.sub name 0 (len 0))

let entries t dir = List.filter_map (fun (_, i, name) -> if i = 0 || name = "." || name = ".." then None else Some (name, i)) (slots t dir)
let lookup t dir name = match List.filter (fun (_, i, n) -> i <> 0 && n = name) (slots t dir) with (_, i, _) :: _ -> Some i | [] -> None

(* a name for an inode, in a directory's first free entry, or at its end *)
let link (t : t) dir name i =
  let at = match List.filter (fun (_, i, _) -> i = 0) (slots t dir) with (o, _, _) :: _ -> o | [] -> size t dir in
  write t dir at (b16 i ^ name ^ String.make (dirsiz - String.length name) '\000');
  set16 t (dinode t i + 6) (nlink t i + 1)

(* a name a directory may take: well made, and not there *)
let fresh (t : t) dir name =
  let bad = ref (name = "" || name = "." || name = ".." || String.length name > dirsiz) in
  for j = 0 to String.length name - 1 do if name.[j] = '/' || name.[j] = '\000' then bad := true done;
  if !bad then failwith (if String.length name > dirsiz then "file name too long (14 characters at most)" else "bad file name");
  if lookup t dir name <> None then failwith "file already exists"

let create (t : t) dir name k =
  fresh t dir name;
  let i = ialloc t k in
  (* a directory has its two first names: itself, and the one it is in *)
  if k = Dir then begin link t i "." i; link t i ".." dir end;
  link t dir name i;
  i

let remove (t : t) dir name =
  match List.filter (fun (_, i, n) -> i <> 0 && n = name) (slots t dir) with
  | [] -> failwith "file does not exist"
  | (o, i, _) :: _ ->
      if name = "." || name = ".." then failwith "permission denied";
      let is_dir = kind t i = Dir in
      if is_dir && entries t i <> [] then failwith "directory not empty";
      write t dir o (String.make 16 '\000');
      (* (a directory's own two names are not counted against it) *)
      let left = nlink t i - 1 in
      if left <= 0 || (is_dir && left <= 1) then begin
        if is_dir then set16 t (dinode t dir + 6) (nlink t dir - 1);
        truncate t i;
        set16 t (dinode t i) 0
      end
      else set16 t (dinode t i + 6) left

(* a name changed, in its directory: its entry's 14 characters *)
let rename (t : t) dir name new_name =
  match List.filter (fun (_, i, n) -> i <> 0 && n = name) (slots t dir) with
  | [] -> failwith "file does not exist"
  | (o, _, _) :: _ ->
      if name = "." || name = ".." then failwith "permission denied";
      fresh t dir new_name;
      write t dir (o + 2) (new_name ^ String.make (dirsiz - String.length new_name) '\000')

(*****************************************************************************)
(* A new one *)
(*****************************************************************************)

let format read_at write_at blocks bsize ninodes =
  if bsize <> 512 && bsize <> 1024 then failwith "a block is 512 or 1024 bytes";
  let inodeblocks = (ninodes / (bsize / 256)) + 1 in
  let bitmapblocks = (blocks / (bsize * 8)) + 1 in
  let inodestart = 2 in
  let bmapstart = inodestart + inodeblocks in
  let meta = bmapstart + bitmapblocks in
  if meta + 1 >= blocks then failwith "too small for a file system";
  (* the boot block, the superblock, the inodes and the bitmap: zeros, then the superblock's numbers *)
  for b = 0 to meta - 1 do write_at (b * bsize) (String.make bsize '\000') done;
  write_at bsize (b32 magic ^ b32 blocks ^ b32 (blocks - meta) ^ b32 ninodes ^ b32 0 ^ b32 2 ^ b32 inodestart ^ b32 bmapstart);
  let t = make read_at (Some write_at) in
  for b = 0 to meta - 1 do mark t b true done;
  t.hint <- meta;
  (* the root: the first inode (0 is "no inode"), in itself *)
  let r = ialloc t Dir in
  link t r "." r;
  link t r ".." r;
  t
