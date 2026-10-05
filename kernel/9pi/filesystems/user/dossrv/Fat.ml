(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Fat.mli *)

type t = {
  fd : Unix.file_descr;
  cluster : int;                (* bytes *)
  bits : int;                   (* a FAT entry's: 12, 16 or 32 *)
  fat : string;                 (* the first FAT, whole *)
  root_at : int;                (* FAT12, 16: the root directory's bytes, where and how many *)
  root_size : int;
  root_cluster : int;           (* FAT32: its first cluster *)
  data_at : int;                (* cluster 2's byte *)
}

type entry = { name : string; is_dir : bool; read_only : bool; first : int; size : int; mtime : float; where : int }

(* n bytes of the device at an offset (fewer at its end) *)
let pread (t : t) at n =
  ignore (Unix.lseek t.fd at Unix.SEEK_SET);
  let b = Bytes.create n in
  let rec go o = if o = n then o else match Unix.read t.fd b o (n - o) with 0 -> o | k -> go (o + k) in
  Bytes.sub_string b 0 (go 0)


let of_fd fd =
  let boot = let t = { fd; cluster = 0; bits = 0; fat = ""; root_at = 0; root_size = 0; root_cluster = 0; data_at = 0 } in pread t 0 512 in
  if String.length boot < 512 || Binary.le16 boot 510 <> 0xaa55 then failwith "not a FAT file system: no boot sector";
  let sector = Binary.le16 boot 11 and per_cluster = Char.code boot.[13] and reserved = Binary.le16 boot 14 and nfats = Char.code boot.[16] in
  let root_entries = Binary.le16 boot 17 in
  let total = if Binary.le16 boot 19 <> 0 then Binary.le16 boot 19 else Binary.le32 boot 32 in
  let fat_sectors = if Binary.le16 boot 22 <> 0 then Binary.le16 boot 22 else Binary.le32 boot 36 in
  if sector < 512 || per_cluster = 0 || nfats = 0 || fat_sectors = 0 then failwith "not a FAT file system: its geometry";
  let root_sectors = ((root_entries * 32) + sector - 1) / sector in
  let data_sector = reserved + (nfats * fat_sectors) + root_sectors in
  (* the size is the clusters' number's: MS-DOS's rule *)
  let clusters = (total - data_sector) / per_cluster in
  let bits = if clusters < 4085 then 12 else if clusters < 65525 then 16 else 32 in
  let t = { fd; cluster = per_cluster * sector; bits; fat = ""; root_at = (reserved + (nfats * fat_sectors)) * sector;
            root_size = root_entries * 32; root_cluster = (if bits = 32 then Binary.le32 boot 44 else 0); data_at = data_sector * sector } in
  { t with fat = pread t (reserved * sector) (fat_sectors * sector) }

(* the cluster after c in its file, or None at the file's end *)
let next (t : t) c =
  let n, last = match t.bits with
    | 12 -> let v = Binary.le16 t.fat (c * 3 / 2) in (if c land 1 = 1 then v lsr 4 else v land 0xfff), 0xff8
    | 16 -> Binary.le16 t.fat (2 * c), 0xfff8
    | _ -> Binary.le32 t.fat (4 * c) land 0x0fffffff, 0x0ffffff8 in
  if n < 2 || n >= last then None else Some n

(* a file's clusters, from its first *)
let rec chain t c = if c < 2 then [] else c :: (match next t c with Some n -> chain t n | None -> [])

let cluster_at (t : t) c = t.data_at + ((c - 2) * t.cluster)

let root (t : t) = { name = "/"; is_dir = true; read_only = false; first = t.root_cluster; size = 0; mtime = 0.0; where = 0 }

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

(* a character of a long name (16 bits) as UTF-8 *)
let utf8 b c =
  if c < 0x80 then Buffer.add_char b (Char.chr c)
  else if c < 0x800 then begin Buffer.add_char b (Char.chr (0xc0 lor (c lsr 6))); Buffer.add_char b (Char.chr (0x80 lor (c land 0x3f))) end
  else begin
    Buffer.add_char b (Char.chr (0xe0 lor (c lsr 12)));
    Buffer.add_char b (Char.chr (0x80 lor ((c lsr 6) land 0x3f)));
    Buffer.add_char b (Char.chr (0x80 lor (c land 0x3f)))
  end

(* a long name's part: 13 characters in three places of its entry, to a 0 *)
let long_part s o =
  let b = Buffer.create 26 in
  let rec chars = function
    | k :: more -> let c = Binary.le16 s (o + k) in if c <> 0 && c <> 0xffff then begin utf8 b c; chars more end
    | [] -> () in
  chars [ 1; 3; 5; 7; 9; 14; 16; 18; 20; 22; 24; 28; 30 ];
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
  let base = if base <> "" && base.[0] = '\005' then "\xe5" ^ String.sub base 1 (String.length base - 1) else base in
  if ext = "" then base else base ^ "." ^ ext

let entries (t : t) (d : entry) =
  let found = ref [] and long = ref "" and ended = ref false in
  List.iter (fun (at, bytes) ->
    let n = String.length bytes / 32 in
    for k = 0 to n - 1 do
      let o = 32 * k in
      let b0 = Char.code bytes.[o] and attr = Char.code bytes.[o + 11] in
      if !ended || b0 = 0 then ended := true
      else if b0 = 0xe5 then long := ""
      else if attr land 0x3f = 0x0f then long := long_part bytes o ^ (if b0 land 0x40 <> 0 then "" else !long)
      else if attr land 0x08 <> 0 then long := ""
      else begin
        let short = short_name bytes o in
        let name = if !long <> "" then !long else short in
        long := "";
        if short <> "." && short <> ".." then
          found := { name; is_dir = attr land 0x10 <> 0; read_only = attr land 0x01 <> 0;
                     first = Binary.le16 bytes (o + 26) lor (if t.bits = 32 then Binary.le16 bytes (o + 20) lsl 16 else 0); size = Binary.le32 bytes (o + 28);
                     mtime = seconds (Binary.le16 bytes (o + 24)) (Binary.le16 bytes (o + 22)); where = (at + o) / 32 } :: !found
      end
    done) (dir_pieces t d);
  List.rev !found

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
