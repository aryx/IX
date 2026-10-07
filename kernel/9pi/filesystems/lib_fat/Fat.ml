(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Fat.mli *)

(* the table is kept in pieces of 512 bytes: a piece changed is one
 * string made again and one write, not the whole table (a string is
 * not changed in place: the compilers of this file do not agree on
 * how) *)
let piece = 512

type t = {
  pread : int -> int -> string;   (* the device: n bytes at an offset *)
  pwrite : (int -> string -> unit) option;
  cluster : int;                (* bytes *)
  bits : int;                   (* a FAT entry's: 12, 16 or 32 *)
  fat : string array;           (* the first FAT, whole, in pieces *)
  fat_at : int;                 (* where it is, how long one is, how many there are *)
  fat_size : int;
  nfats : int;
  clusters : int;               (* how many, from number 2 *)
  root_at : int;                (* FAT12, 16: the root directory's bytes, where and how many *)
  root_size : int;
  root_cluster : int;           (* FAT32: its first cluster *)
  data_at : int;                (* cluster 2's byte *)
  mutable dirty : int list;     (* the table's pieces changed and not written *)
  mutable hint : int;           (* where to look for a free cluster *)
}

type entry = { name : string; is_dir : bool; read_only : bool; first : int; size : int; mtime : float; where : int; longs : int list }

let clock = ref (fun () -> 0.0)

let pread (t : t) at n = t.pread at n
let pwrite (t : t) at s = match t.pwrite with Some w -> w at s | None -> failwith "read only file system"

(* numbers of two and four bytes, the low one first: read, and made *)
let le16 s o = Char.code s.[o] lor (Char.code s.[o + 1] lsl 8)
let le32 s o = le16 s o lor (le16 s (o + 2) lsl 16)
let b8 v = String.make 1 (Char.chr (v land 0xff))
let b16 v = b8 v ^ b8 (v lsr 8)
let b32 v = b16 v ^ b16 (v lsr 16)
(* s with some of its bytes replaced, from o *)
let splice s o bytes = String.sub s 0 o ^ bytes ^ String.sub s (o + String.length bytes) (String.length s - o - String.length bytes)

let make read_at write_at =
  let boot = read_at 0 512 in
  if String.length boot < 512 || le16 boot 510 <> 0xaa55 then failwith "not a FAT file system: no boot sector";
  let sector = le16 boot 11 and per_cluster = Char.code boot.[13] and reserved = le16 boot 14 and nfats = Char.code boot.[16] in
  let root_entries = le16 boot 17 in
  let total = if le16 boot 19 <> 0 then le16 boot 19 else le32 boot 32 in
  let fat_sectors = if le16 boot 22 <> 0 then le16 boot 22 else le32 boot 36 in
  if sector < 512 || per_cluster = 0 || nfats = 0 || fat_sectors = 0 then failwith "not a FAT file system: its geometry";
  let root_sectors = ((root_entries * 32) + sector - 1) / sector in
  let data_sector = reserved + (nfats * fat_sectors) + root_sectors in
  (* the size is the clusters' number's: MS-DOS's rule *)
  let clusters = (total - data_sector) / per_cluster in
  let bits = if clusters < 4085 then 12 else if clusters < 65525 then 16 else 32 in
  let fat_size = fat_sectors * sector in
  let whole = read_at (reserved * sector) fat_size in
  if String.length whole < fat_size then failwith "not a FAT file system: its table is cut short";
  { pread = read_at; pwrite = write_at; cluster = per_cluster * sector; bits = bits;
    fat = Array.init (fat_size / piece) (fun i -> String.sub whole (i * piece) piece);
    fat_at = reserved * sector; fat_size = fat_size; nfats = nfats; clusters = clusters;
    root_at = (reserved + (nfats * fat_sectors)) * sector;
    root_size = root_entries * 32; root_cluster = (if bits = 32 then le32 boot 44 else 0); data_at = data_sector * sector;
    dirty = []; hint = 2 }

(*****************************************************************************)
(* The table *)
(*****************************************************************************)

let fat_byte (t : t) o = Char.code t.fat.(o / piece).[o mod piece]
let fat16 t o = fat_byte t o lor (fat_byte t (o + 1) lsl 8)

(* a cluster's number in the table: the next one of its file, 0 when
 * it is free, a number past [last] at a file's end *)
let slot (t : t) c =
  match t.bits with
  | 12 -> let v = fat16 t (c * 3 / 2) in if c land 1 = 1 then v lsr 4 else v land 0xfff
  | 16 -> fat16 t (2 * c)
  | _ -> (fat16 t (4 * c) lor (fat16 t ((4 * c) + 2) lsl 16)) land 0x0fffffff
let last (t : t) = match t.bits with 12 -> 0xff8 | 16 -> 0xfff8 | _ -> 0x0ffffff8

(* the cluster after c in its file, or None at the file's end *)
let next (t : t) c = let n = slot t c in if n < 2 || n >= last t then None else Some n

(* a file's clusters, from its first *)
let rec chain t c = if c < 2 then [] else c :: (match next t c with Some n -> chain t n | None -> [])

let set_fat_byte (t : t) o v =
  let i = o / piece in
  t.fat.(i) <- splice t.fat.(i) (o mod piece) (b8 v);
  if not (List.mem i t.dirty) then t.dirty <- i :: t.dirty

(* a cluster's number changed (FAT12's shares a byte with its
 * neighbour's; FAT32's top four bits are not its own) *)
let set_slot (t : t) c v =
  match t.bits with
  | 12 ->
      let o = c * 3 / 2 in
      let old = fat16 t o in
      let w = if c land 1 = 1 then (old land 0x000f) lor ((v land 0xfff) lsl 4) else (old land 0xf000) lor (v land 0xfff) in
      set_fat_byte t o w; set_fat_byte t (o + 1) (w lsr 8)
  | 16 -> set_fat_byte t (2 * c) v; set_fat_byte t ((2 * c) + 1) (v lsr 8)
  | _ ->
      let o = 4 * c in
      set_fat_byte t o v; set_fat_byte t (o + 1) (v lsr 8); set_fat_byte t (o + 2) (v lsr 16);
      set_fat_byte t (o + 3) ((fat_byte t (o + 3) land 0xf0) lor ((v lsr 24) land 0x0f))

(* the pieces changed, written in each copy of the table *)
let flush (t : t) =
  List.iter (fun i -> for k = 0 to t.nfats - 1 do pwrite t (t.fat_at + (k * t.fat_size) + (i * piece)) t.fat.(i) done) t.dirty;
  t.dirty <- []

(* a free cluster taken: a file's last, until it is linked *)
let alloc (t : t) =
  let top = t.clusters + 2 in
  let rec look c n = if n = 0 then failwith "file system full" else if slot t c = 0 then c else look (if c + 1 >= top then 2 else c + 1) (n - 1) in
  let c = look (if t.hint < 2 || t.hint >= top then 2 else t.hint) t.clusters in
  set_slot t c 0x0fffffff;
  t.hint <- c + 1;
  c

let cluster_at (t : t) c = t.data_at + ((c - 2) * t.cluster)

(*****************************************************************************)
(* Directories *)
(*****************************************************************************)

let root (t : t) = { name = "/"; is_dir = true; read_only = false; first = t.root_cluster; size = 0; mtime = 0.0; where = 0; longs = [] }

(* a directory's bytes, in pieces: where each one is on the disk *)
let dir_pieces (t : t) (d : entry) =
  if d.where = 0 && t.bits <> 32 then [ t.root_at, pread t t.root_at t.root_size ]
  else List.map (fun c -> cluster_at t c, pread t (cluster_at t c) t.cluster) (chain t d.first)

(* days since 1970 of a date (the inverse of Unix.gmtime's count) *)
let days_of year month day =
  let y = if month <= 2 then year - 1 else year in
  let era = (if y >= 0 then y else y - 399) / 400 in
  let yoe = y - (era * 400) in
  let doy = (((153 * (month + (if month > 2 then -3 else 9))) + 2) / 5) + day - 1 in
  (era * 146097) + (yoe * 365) + (yoe / 4) - (yoe / 100) + doy - 719468

(* FAT's date and time (years from 1980, two seconds a unit), as seconds since 1970 (GMT) *)
let seconds date time =
  let days = days_of (1980 + (date lsr 9)) ((date lsr 5) land 15) (date land 31) in
  (float_of_int days *. 86400.0) +. float_of_int ((((time lsr 11) * 60) + ((time lsr 5) land 63)) * 60 + ((time land 31) * 2))

(* and back: seconds since 1970 as FAT's date and time (not before 1980) *)
let stamp secs =
  let secs = if secs < 315532800.0 then 315532800.0 else secs in
  let days = int_of_float (secs /. 86400.0) in
  let rem = int_of_float (secs -. (float_of_int days *. 86400.0)) in
  let z = days + 719468 in
  let era = z / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let day = doy - (((153 * mp) + 2) / 5) + 1 in
  let month = if mp < 10 then mp + 3 else mp - 9 in
  let year = yoe + (era * 400) + (if month <= 2 then 1 else 0) in
  ((year - 1980) lsl 9) lor (month lsl 5) lor day, ((rem / 3600) lsl 11) lor (((rem mod 3600) / 60) lsl 5) lor ((rem mod 60) / 2)

(* a character of a long name (16 bits) as UTF-8 *)
let utf8 b c =
  if c < 0x80 then Buffer.add_char b (Char.chr c)
  else if c < 0x800 then begin Buffer.add_char b (Char.chr (0xc0 lor (c lsr 6))); Buffer.add_char b (Char.chr (0x80 lor (c land 0x3f))) end
  else begin
    Buffer.add_char b (Char.chr (0xe0 lor (c lsr 12)));
    Buffer.add_char b (Char.chr (0x80 lor ((c lsr 6) land 0x3f)));
    Buffer.add_char b (Char.chr (0x80 lor (c land 0x3f)))
  end

(* and back: a name's characters, 16 bits each (one past that: '_') *)
let utf16 s =
  let rec go o =
    if o >= String.length s then []
    else begin
      let b = Char.code s.[o] in
      let n = if b < 0x80 then 1 else if b < 0xe0 then 2 else if b < 0xf0 then 3 else 4 in
      let n = min n (String.length s - o) in
      let r = ref (if n = 1 then b else b land (0xff lsr (n + 1))) in
      for i = 1 to n - 1 do r := (!r lsl 6) lor (Char.code s.[o + i] land 0x3f) done;
      (if !r > 0xffff then Char.code '_' else !r) :: go (o + n)
    end in
  go 0

(* where a long name's 13 characters are in its entry *)
let long_places = [ 1; 3; 5; 7; 9; 14; 16; 18; 20; 22; 24; 28; 30 ]

(* a long name's part: 13 characters in three places of its entry, to a 0 *)
let long_part s o =
  let b = Buffer.create 26 in
  let rec chars = function
    | k :: more -> let c = le16 s (o + k) in if c <> 0 && c <> 0xffff then begin utf8 b c; chars more end
    | [] -> () in
  chars long_places;
  Buffer.contents b

(* the 8 and 3 characters as a name, in the case it was written with:
 * they are kept in capitals, with two bits (Windows NT's) that say
 * "the name was in small letters", "its extension was" (a name of both
 * cases has a long name beside it). Not as Plan 9's dossrv, which
 * shows the capitals always (the author: "if the filename was using
 * some uppercase letters, then display them", and not otherwise). *)
let short_name s o =
  let flags = Char.code s.[o + 12] in
  let part at n small = let p = String.trim (String.sub s (o + at) n) in if small then String.lowercase_ascii p else p in
  let base = part 0 8 (flags land 0x08 <> 0) and ext = part 8 3 (flags land 0x10 <> 0) in
  (* (0xe5 by its number: the kernel's compiler has no "\x" in a string) *)
  let base = if base <> "" && base.[0] = '\005' then String.make 1 (Char.chr 0xe5) ^ String.sub base 1 (String.length base - 1) else base in
  if ext = "" then base else base ^ "." ^ ext

(* an entry's 32 bytes at o of s, a file's or a directory's (not a
 * long name's part, not a label), with the name found for it *)
let decode (t : t) s o name where longs =
  let attr = Char.code s.[o + 11] in
  { name = name; is_dir = attr land 0x10 <> 0; read_only = attr land 0x01 <> 0;
    first = le16 s (o + 26) lor (if t.bits = 32 then le16 s (o + 20) lsl 16 else 0); size = le32 s (o + 28);
    mtime = seconds (le16 s (o + 24)) (le16 s (o + 22)); where = where; longs = longs }

let entries (t : t) (d : entry) =
  let found = ref [] and long = ref "" and longs = ref [] and ended = ref false in
  List.iter (fun (at, bytes) ->
    let n = String.length bytes / 32 in
    for k = 0 to n - 1 do
      let o = 32 * k in
      let b0 = Char.code bytes.[o] and attr = Char.code bytes.[o + 11] in
      if !ended || b0 = 0 then ended := true
      else if b0 = 0xe5 then begin long := ""; longs := [] end
      else if attr land 0x3f = 0x0f then begin
        long := long_part bytes o ^ (if b0 land 0x40 <> 0 then "" else !long);
        longs := (if b0 land 0x40 <> 0 then [] else !longs) @ [ (at + o) / 32 ]
      end
      else if attr land 0x08 <> 0 then begin long := ""; longs := [] end
      else begin
        let short = short_name bytes o in
        let name = if !long <> "" then !long else short in
        if short <> "." && short <> ".." then found := decode t bytes o name ((at + o) / 32) !longs :: !found;
        long := ""; longs := []
      end
    done) (dir_pieces t d);
  List.rev !found

let refresh (t : t) (e : entry) =
  if e.where = 0 then e
  else begin
    let s = pread t (e.where * 32) 32 in
    if String.length s < 32 || Char.code s.[0] = 0xe5 || Char.code s.[0] = 0 then failwith "file does not exist";
    decode t s 0 e.name e.where e.longs
  end

(*****************************************************************************)
(* Files *)
(*****************************************************************************)

let read (t : t) (f : entry) offset count =
  let count = max 0 (min count (f.size - offset)) in
  let b = Buffer.create count in
  (* the clusters from the offset's, each one's part *)
  let rec go clusters at =
    match clusters with
    | c :: more when Buffer.length b < count ->
        if at + t.cluster > offset then begin
          let skip = max 0 (offset - at) in
          Buffer.add_string b (pread t (cluster_at t c + skip) (min (t.cluster - skip) (count - Buffer.length b)))
        end;
        go more (at + t.cluster)
    | _ -> () in
  if count > 0 then go (chain t f.first) 0;
  Buffer.contents b

(* bytes written over a file's clusters, from an offset of the file *)
let put (t : t) clusters offset data =
  let n = String.length data in
  let rec go clusters at =
    match clusters with
    | c :: more when at < offset + n ->
        if at + t.cluster > offset then begin
          let skip = max 0 (offset - at) in
          let from = max 0 (at - offset) in
          pwrite t (cluster_at t c + skip) (String.sub data from (min (t.cluster - skip) (n - from)))
        end;
        go more (at + t.cluster)
    | _ -> () in
  if n > 0 then go clusters 0

(* a file's entry on the disk changed: its first cluster, its length, the time *)
let update (t : t) (e : entry) first size =
  let date, time = stamp (!clock ()) in
  let o = e.where * 32 in
  let s = pread t o 32 in
  let s = splice s 20 (b16 (if t.bits = 32 then first lsr 16 else 0)) in
  let s = splice s 22 (b16 time ^ b16 date ^ b16 first ^ b32 size) in
  pwrite t o s;
  { e with first = first; size = size; mtime = seconds date time }

(* a file's clusters, with as many more as it takes to have [need]:
 * each new one linked after the last *)
let extend (t : t) clusters need =
  let rec go l tail n =
    if n <= 0 then l
    else begin
      let c = alloc t in
      (match tail with Some p -> set_slot t p c | None -> ());
      go (l @ [ c ]) (Some c) (n - 1)
    end in
  go clusters (match List.rev clusters with c :: _ -> Some c | [] -> None) (need - List.length clusters)

let write (t : t) (e : entry) offset data =
  let e = refresh t e in
  if e.is_dir then failwith "is a directory";
  if e.where = 0 then failwith "permission denied";
  let size = max e.size (offset + String.length data) in
  let clusters = extend t (chain t e.first) ((size + t.cluster - 1) / t.cluster) in
  (* (written past the end: zeros between) *)
  if offset > e.size then put t clusters e.size (String.make (offset - e.size) '\000');
  put t clusters offset data;
  flush t;
  update t e (match clusters with c :: _ -> c | [] -> 0) size

let truncate (t : t) (e : entry) =
  let e = refresh t e in
  if e.is_dir || e.where = 0 then failwith "is a directory";
  let clusters = chain t e.first in
  let e = update t e 0 0 in
  List.iter (fun c -> set_slot t c 0) clusters;
  flush t;
  e

(*****************************************************************************)
(* Names made *)
(*****************************************************************************)

(* (the kernel's compiler's String has no contains) *)
let has s c = let rec go i = i < String.length s && (s.[i] = c || go (i + 1)) in go 0

(* a name's part as its 8 or 3 characters would have it: in capitals,
 * what MS-DOS does not take a '_' *)
let dos_part s n =
  let ok c = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || has "_-~!#$%&'()@^`{}" c in
  let s = String.map (fun c -> if ok c then c else '_') (String.uppercase_ascii s) in
  if String.length s > n then String.sub s 0 n else s

let pad s n = s ^ String.make (n - String.length s) ' '

(* a name as its 11 characters, its two bits of case, and whether that
 * says all of it (else it has a long name, and these are an alias) *)
let short_of name =
  (* (the last '.', not the first character's) *)
  let rec dot i = if i <= 0 then 0 else if name.[i] = '.' then i else dot (i - 1) in
  let i = dot (String.length name - 1) in
  let base, ext = if i > 0 then String.sub name 0 i, String.sub name (i + 1) (String.length name - i - 1) else name, "" in
  let one_case s = s = String.lowercase_ascii s || s = String.uppercase_ascii s in
  let fits s n = String.length s <= n && dos_part s n = String.uppercase_ascii s && one_case s in
  let small s = if s <> String.uppercase_ascii s then 1 else 0 in
  let whole = base <> "" && fits base 8 && fits ext 3 in
  pad (dos_part base 8) 8 ^ pad (dos_part ext 3) 3, (if whole then (small base * 0x08) lor (small ext * 0x10) else 0), whole

(* the 11 characters of the names a directory has *)
let shorts (t : t) (d : entry) =
  let l = ref [] and ended = ref false in
  List.iter (fun (_, bytes) ->
    for k = 0 to (String.length bytes / 32) - 1 do
      let b0 = Char.code bytes.[32 * k] in
      if b0 = 0 then ended := true
      else if not !ended && b0 <> 0xe5 && Char.code bytes.[(32 * k) + 11] land 0x3f <> 0x0f then l := String.sub bytes (32 * k) 11 :: !l
    done) (dir_pieces t d);
  !l

(* an alias no other file of the directory has: NAME~1.EXT, ~2... *)
let alias taken short =
  let rec go n =
    let tail = "~" ^ string_of_int n in
    let base = String.trim (String.sub short 0 8) in
    let base = if String.length base + String.length tail > 8 then String.sub base 0 (8 - String.length tail) else base in
    let s = pad (base ^ tail) 8 ^ String.sub short 8 3 in
    if List.mem s taken then go (n + 1) else s in
  go 1

(* the number a long name's entries carry of their short one *)
let checksum short =
  let sum = ref 0 in
  for i = 0 to String.length short - 1 do sum := ((((!sum land 1) lsl 7) lor (!sum lsr 1)) + Char.code short.[i]) land 0xff done;
  !sum

(* a long name's entries, in the order they are on the disk: the last part first *)
let long_entries name short =
  let units = utf16 name in
  let n = (List.length units + 12) / 13 in
  let units = Array.of_list units in
  let part k =
    (* the 13 characters of part k (from 1): the name's, then a 0, then 0xffff *)
    let chars = String.concat "" (List.init 13 (fun i ->
      let j = ((k - 1) * 13) + i in
      b16 (if j < Array.length units then units.(j) else if j = Array.length units then 0 else 0xffff))) in
    b8 (k lor (if k = n then 0x40 else 0)) ^ String.sub chars 0 10 ^ b8 0x0f ^ b8 0 ^ b8 (checksum short)
    ^ String.sub chars 10 12 ^ b16 0 ^ String.sub chars 22 4 in
  List.init n (fun i -> part (n - i))

(* the places of [n] free entries one after the other in a directory
 * (taken away, or past its end), in entries of 32 bytes; a cluster
 * more for the directory when it has none (not FAT12's and 16's root,
 * whose size is fixed) *)
let rec room (t : t) (d : entry) n =
  let run = ref [] and found = ref None and ended = ref false in
  List.iter (fun (at, bytes) ->
    for k = 0 to (String.length bytes / 32) - 1 do
      if !found = None then begin
        let b0 = Char.code bytes.[32 * k] in
        if b0 = 0 then ended := true;
        if !ended || b0 = 0xe5 then begin
          run := !run @ [ (at + (32 * k)) / 32 ];
          if List.length !run = n then found := Some !run
        end
        else run := []
      end
    done) (dir_pieces t d);
  match !found with
  | Some places -> places
  | None ->
      if d.where = 0 && t.bits <> 32 then failwith "directory full";
      let clusters = chain t d.first in
      let c = alloc t in
      pwrite t (cluster_at t c) (String.make t.cluster '\000');
      (match List.rev clusters with p :: _ -> set_slot t p c | [] -> failwith "directory has no cluster");
      flush t;
      room t d n

(* a name a directory may take (well made, and no other file's: [self]
 * is the place of the one being renamed, 0 for a new one): its 11
 * characters, its bits of case, its long name's entries *)
let fresh (t : t) (d : entry) name self =
  if not d.is_dir then failwith "not a directory";
  if name = "" || name = "." || name = ".." || has name '/' || String.length name > 255 then failwith "bad file name";
  let wanted = String.lowercase_ascii name in
  if List.exists (fun (e : entry) -> e.where <> self && String.lowercase_ascii e.name = wanted) (entries t d) then failwith "file already exists";
  let short, case, whole = short_of name in
  let short = if whole then short else alias (shorts t d) short in
  short, case, (if whole then [] else long_entries name short)

let create (t : t) (d : entry) name is_dir =
  let d = if d.where = 0 then d else refresh t d in
  let short, case, longs = fresh t d name 0 in
  let places = room t d (List.length longs + 1) in
  let date, time = stamp (!clock ()) in
  (* a directory has a cluster from the start, with its two first
   * entries: itself, and the one it is in (0: the root) *)
  let first =
    if not is_dir then 0
    else begin
      let c = alloc t in
      let dots name first = pad name 11 ^ b8 0x10 ^ String.make 8 '\000' ^ b16 (if t.bits = 32 then first lsr 16 else 0) ^ b16 time ^ b16 date ^ b16 first ^ b32 0 in
      pwrite t (cluster_at t c) (dots "." c ^ dots ".." (if d.where = 0 then 0 else d.first) ^ String.make (t.cluster - 64) '\000');
      c
    end in
  flush t;
  let own = short ^ b8 (if is_dir then 0x10 else 0x20) ^ b8 case ^ b8 0 ^ b16 time ^ b16 date ^ b16 date
            ^ b16 (if t.bits = 32 then first lsr 16 else 0) ^ b16 time ^ b16 date ^ b16 first ^ b32 0 in
  (* the long name's entries first, the file's own last: it is there when all of it is *)
  List.iter2 (fun place bytes -> pwrite t (place * 32) bytes) places (longs @ [ own ]);
  let where = List.nth places (List.length places - 1) in
  decode t own 0 name where (List.filter (fun p -> p <> where) places)

let remove (t : t) (e : entry) =
  let e = refresh t e in
  if e.where = 0 then failwith "permission denied";
  if e.is_dir && entries t e <> [] then failwith "directory not empty";
  let clusters = chain t e.first in
  (* the entries first (a file with no entry is clusters lost, not a file broken) *)
  List.iter (fun place -> pwrite t (place * 32) (b8 0xe5)) (e.where :: e.longs);
  List.iter (fun c -> set_slot t c 0) clusters;
  flush t

(* a file's name changed, in its directory: new entries for it (its
 * long name's, and its own with the rest of what the old one says),
 * then the old ones taken away; so its place, its identity, changes *)
let rename (t : t) (d : entry) (e : entry) name =
  let d = if d.where = 0 then d else refresh t d in
  let e = refresh t e in
  if e.where = 0 then failwith "permission denied";
  let short, case, longs = fresh t d name e.where in
  let places = room t d (List.length longs + 1) in
  let old = pread t (e.where * 32) 32 in
  let own = short ^ String.sub old 11 1 ^ b8 case ^ String.sub old 13 19 in
  List.iter2 (fun place bytes -> pwrite t (place * 32) bytes) places (longs @ [ own ]);
  List.iter (fun place -> pwrite t (place * 32) (b8 0xe5)) (e.where :: e.longs);
  let where = List.nth places (List.length places - 1) in
  decode t own 0 name where (List.filter (fun p -> p <> where) places)

(* a file's time written, as the caller says it *)
let set_mtime (t : t) (e : entry) secs =
  let e = refresh t e in
  if e.where = 0 then failwith "permission denied";
  let date, time = stamp secs in
  pwrite t ((e.where * 32) + 22) (b16 time ^ b16 date);
  { e with mtime = seconds date time }

(* FAT's one permission: a file that is only read *)
let set_read_only (t : t) (e : entry) on =
  let e = refresh t e in
  if e.where = 0 then failwith "permission denied";
  let at = (e.where * 32) + 11 in
  let attr = Char.code (pread t at 1).[0] in
  pwrite t at (b8 (if on then attr lor 1 else attr land lnot 1));
  { e with read_only = on }
