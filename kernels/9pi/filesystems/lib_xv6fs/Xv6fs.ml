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
  mutable ihint : int;          (* and for a free inode: none is free below *)
  (* the blocks whose numbers were read (inodes, blocks of numbers, the
   * bitmap), and the names looked for in directories: below *)
  numbers : (int, Bytes.t) Hashtbl.t;
  names : (int * string, int option) Hashtbl.t;
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
(* IX'S THIRD EXTENSION: a directory's entries of 64 bytes, names of
 * 62 characters (xv6: 16 and 14) *)
let dirent = 64               (* ix's extension *)
let dirsiz = dirent - 2

let pread (t : t) at n = let s = t.pread at n in if String.length s < n then failwith "i/o error" else s

(* The blocks numbers are read from, kept (Unix's inodes in core, xv6's
 * icache, and its buffers of blocks of numbers): a file's read of a
 * block read its size and the block's number from the disk again,
 * each a read of 4 bytes through the device's cache, a string made
 * (mini-9pi's Kfs: plan_9pi_self_speed.md, 2026-11-23). Kept as they
 * are on the disk: every write goes through pwrite, which changes a
 * kept block too, so none is ever stale. Up to 4,096 blocks (4 MB of
 * 1 KB ones), then all forgotten.
 * old: get16 t at = le16 (pread t at 2) 0, get32 likewise, a byte of
 * the bitmap by pread t at 1 *)
let max_numbers = 4096
let block_of (t : t) b =
  try Hashtbl.find t.numbers b
  with Not_found ->
    if Hashtbl.length t.numbers >= max_numbers then Hashtbl.reset t.numbers;
    let s = Bytes.of_string (pread t (b * t.bsize) t.bsize) in
    Hashtbl.add t.numbers b s;
    s

let pwrite (t : t) at s =
  (match t.pwrite with Some w -> w at s | None -> failwith "read only file system");
  let n = String.length s in
  for b = at / t.bsize to (at + n - 1) / t.bsize do
    match Hashtbl.find_opt t.numbers b with
    | Some kept ->
        let from = max at (b * t.bsize) and upto = min (at + n) ((b + 1) * t.bsize) in
        Bytes.blit_string s (from - at) kept (from - (b * t.bsize)) (upto - from)
    | None -> ()
  done

let le16 s o = Char.code s.[o] lor (Char.code s.[o + 1] lsl 8)
let le32 s o = le16 s o lor (le16 s (o + 2) lsl 16)
let b8 v = String.make 1 (Char.chr (v land 0xff))
let b16 v = b8 v ^ b8 (v lsr 8)
let b32 v = b16 v ^ b16 (v lsr 16)

(* a number of 8, 16 or 32 bits of the disk, at a byte: read (from its
 * block, kept), written. (A number is never across two blocks: they
 * are at even places, 4 for 32 bits) *)
let get8 t at = Char.code (Bytes.get (block_of t (at / t.bsize)) (at mod t.bsize))
let get16 t at = get8 t at lor (get8 t (at + 1) lsl 8)
let get32 t at = get16 t at lor (get16 t (at + 2) lsl 16)
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
    inodestart = le32 sb 24; bmapstart = le32 sb 28; hint = 0; ihint = 1;
    numbers = Hashtbl.create 1021; names = Hashtbl.create 1021 }

(*****************************************************************************)
(* Blocks *)
(*****************************************************************************)

(* a block's bit in the bitmap: the byte's place, the bit *)
let bit (t : t) b = (t.bmapstart * t.bsize) + (b / 8), 1 lsl (b mod 8)
let taken t b = let at, m = bit t b in get8 t at land m <> 0
let mark t b on = let at, m = bit t b in let v = get8 t at in pwrite t at (b8 (if on then v lor m else v land lnot m))

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
  (* opti: the search for a free block goes back to the lowest one
   * freed, no further: none is free below the hint otherwise.
   * old: t.hint <- 0 at the end, and the next block looked for from
   * the device's first, a read of the bitmap for each one taken *)
  let free b = if b <> 0 then begin mark t b false; if b < t.hint then t.hint <- b end in
  (* a block of numbers: what each names (by [each]), then itself *)
  let numbers at each = let b = get32 t at in if b <> 0 then begin for k = 0 to n - 1 do each ((b * t.bsize) + (4 * k)) done; free b; set32 t at 0 end in
  for k = 0 to ndirect - 1 do let at = d + 20 + (4 * k) in free (get32 t at); set32 t at 0 done;
  numbers (d + 20 + (4 * ndirect)) (fun at -> free (get32 t at));
  (* ix's extension: the second block of numbers, its blocks of numbers, what they name *)
  numbers (d + double_at) (fun at -> numbers at (fun at -> free (get32 t at)));
  set32 t (d + 16) 0

(* a free inode taken, of a type: the lowest.
 * opti: looked for from where the last one was found, or from one
 * freed since (remove): none is free below. A file made on a card of
 * 5,000 files was 12 ms, a read for each of their inodes (make
 * self-quick on mini-9pi, plan_9pi_self_speed.md).
 * old: let rec look i = ... look (i + 1) in let i = look 1 *)
let ialloc (t : t) k =
  let rec look i = if i >= t.ninodes then failwith "no more inodes" else if get16 t (dinode t i) = 0 then i else look (i + 1) in
  let i = look (max 1 t.ihint) in
  t.ihint <- i + 1;
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
  List.init (String.length s / dirent) (fun k ->
    let o = dirent * k in
    let name = String.sub s (o + 2) dirsiz in
    let rec len j = if j < dirsiz && name.[j] <> '\000' then len (j + 1) else j in
    o, le16 s o, String.sub name 0 (len 0))

let entries t dir = List.filter_map (fun (_, i, name) -> if i = 0 || name = "." || name = ".." then None else Some (name, i)) (slots t dir)
(* opti: a name looked for, and a free entry, in the directory's bytes
 * as they are: every open walks a path's directories, and a file made
 * looks twice in its own. slots made a list of all the entries, two
 * strings each, for one of them.
 * old: lookup: match List.filter (fun (_, i, n) -> i <> 0 && n = name) (slots t dir) with (_, i, _) :: _ -> Some i | [] -> None
 *      link: match List.filter (fun (_, i, _) -> i = 0) (slots t dir) with (o, _, _) :: _ -> o | [] -> size t dir *)
let bytes_of (t : t) dir =
  if kind t dir <> Dir then failwith "not a directory";
  read t dir 0 (size t dir)

let lookup_ t dir name =
  let s = bytes_of t dir and n = String.length name in
  let rec same o j = if j = n then n = dirsiz || s.[o + 2 + n] = '\000' else s.[o + 2 + j] = name.[j] && same o (j + 1) in
  let rec go o =
    if o + dirent > String.length s || n > dirsiz then None
    else if le16 s o <> 0 && same o 0 then Some (le16 s o)
    else go (o + dirent) in
  go 0

(* The names looked for, found or not (Linux's dentries, negative ones
 * too; BSD's namei cache): an open walks each directory of its path,
 * and the build's opens are mostly the same paths, many of them a
 * name that is not there (a compiler looking for a unit in each of its
 * directories, rc for a command along its path). A name changes only
 * by link, remove and rename, below, which set it here. Up to 8,192,
 * then all forgotten.
 * old: lookup_ alone, the directory's bytes read at each *)
let max_names = 8192
let lookup t dir name =
  try Hashtbl.find t.names (dir, name)
  with Not_found ->
    let r = lookup_ t dir name in
    if Hashtbl.length t.names >= max_names then Hashtbl.reset t.names;
    Hashtbl.replace t.names (dir, name) r;
    r
let named (t : t) dir name r = Hashtbl.replace t.names (dir, name) r

(* a name for an inode, in a directory's first free entry, or at its end *)
let link (t : t) dir name i =
  let s = bytes_of t dir in
  let rec free o = if o + dirent > String.length s then size t dir else if le16 s o = 0 then o else free (o + dirent) in
  let at = free 0 in
  write t dir at (b16 i ^ name ^ String.make (dirsiz - String.length name) '\000');
  named t dir name (Some i);
  set16 t (dinode t i + 6) (nlink t i + 1)

(* a name a directory may take: well made, and not there *)
let fresh (t : t) dir name =
  let bad = ref (name = "" || name = "." || name = ".." || String.length name > dirsiz) in
  for j = 0 to String.length name - 1 do if name.[j] = '/' || name.[j] = '\000' then bad := true done;
  if !bad then failwith (if String.length name > dirsiz then "file name too long (" ^ string_of_int dirsiz ^ " characters at most)" else "bad file name");
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
      write t dir o (String.make dirent '\000');
      named t dir name None;
      (* (a directory's own two names are not counted against it) *)
      let left = nlink t i - 1 in
      if left <= 0 || (is_dir && left <= 1) then begin
        if is_dir then set16 t (dinode t dir + 6) (nlink t dir - 1);
        truncate t i;
        set16 t (dinode t i) 0;
        (* (a directory gone: its own two names too, its number another's later) *)
        if is_dir then begin named t i "." None; named t i ".." None end;
        if i < t.ihint then t.ihint <- i
      end
      else set16 t (dinode t i + 6) left

(* a name changed, in its directory: its entry's characters *)
let rename (t : t) dir name new_name =
  match List.filter (fun (_, i, n) -> i <> 0 && n = name) (slots t dir) with
  | [] -> failwith "file does not exist"
  | (o, i, _) :: _ ->
      if name = "." || name = ".." then failwith "permission denied";
      fresh t dir new_name;
      write t dir (o + 2) (new_name ^ String.make (dirsiz - String.length new_name) '\000');
      named t dir name None;
      named t dir new_name (Some i)

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
