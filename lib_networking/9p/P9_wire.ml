(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See P9_wire.mli *)

open P9

(*****************************************************************************)
(* Writing *)
(*****************************************************************************)

let str b s = Binary.add_le16 b (String.length s); Buffer.add_string b s
let seconds b (t : float) = let n = Int64.of_float t in Binary.add_le16 b (Int64.to_int (Int64.logand n 0xffffL)); Binary.add_le16 b (Int64.to_int (Int64.shift_right n 16))
let qid b (q : qid) = Binary.add_u8 b q.qtype; Buffer.add_int64_le b (Int64.logor q.vers (Int64.shift_left (Int64.logand q.path 0xffffffffL) 32)); Binary.add_le32 b (Int64.to_int (Int64.shift_right_logical q.path 32))

(* a file's entry: its size (not counting itself), the device's type and
 * number (the kernel's to say: 0), the qid, the mode (the top byte its
 * type), the times, the length, four names *)
let encode_dir (d : Sys_plan9.dir) =
  let b = Buffer.create 128 in
  Binary.add_le16 b (Char.code d.dev_type); Binary.add_le32 b d.dev;
  qid b (qid_of d);
  Binary.add_le16 b d.perm; Binary.add_u8 b 0; Binary.add_u8 b d.mode_type;
  seconds b d.atime; seconds b d.mtime;
  Buffer.add_int64_le b (Int64.of_int d.length);
  str b d.name; str b d.uid; str b d.gid; str b d.muid;
  let body = Buffer.contents b in
  let all = Buffer.create (2 + String.length body) in
  Binary.add_le16 all (String.length body); Buffer.add_string all body;
  Buffer.contents all

let encode (m : message) =
  let b = Buffer.create 64 in
  let typ n = Binary.add_u8 b n; Binary.add_le16 b m.tag in
  (match m.mtyp with
   | T (Request.Version (msize, v)) -> typ 100; Binary.add_le32 b msize; str b v
   | R (Response.Version (msize, v)) -> typ 101; Binary.add_le32 b msize; str b v
   | T (Request.Auth (afid, user, aname)) -> typ 102; Binary.add_le32 b afid; str b user; str b aname
   | R (Response.Auth q) -> typ 103; qid b q
   | T (Request.Attach (fid, afid, user, aname)) ->
       typ 104; Binary.add_le32 b fid; Binary.add_le32 b (match afid with Some f -> f | None -> nofid); str b user; str b aname
   | R (Response.Attach q) -> typ 105; qid b q
   | R (Response.Error e) -> typ 107; str b e
   | T (Request.Flush old) -> typ 108; Binary.add_le16 b old
   | R Response.Flush -> typ 109
   | T (Request.Walk (fid, newfid, names)) -> typ 110; Binary.add_le32 b fid; Binary.add_le32 b newfid; Binary.add_le16 b (List.length names); List.iter (str b) names
   | R (Response.Walk qids) -> typ 111; Binary.add_le16 b (List.length qids); List.iter (qid b) qids
   | T (Request.Open (fid, mode)) -> typ 112; Binary.add_le32 b fid; Binary.add_u8 b mode
   | R (Response.Open (q, iounit)) -> typ 113; qid b q; Binary.add_le32 b iounit
   | T (Request.Create (fid, name, perm, mode)) -> typ 114; Binary.add_le32 b fid; str b name; Binary.add_le16 b (perm land 0xffff); Binary.add_u8 b 0; Binary.add_u8 b ((perm lsr 16) land 0xff); Binary.add_u8 b mode
   | R (Response.Create (q, iounit)) -> typ 115; qid b q; Binary.add_le32 b iounit
   | T (Request.Read (fid, offset, count)) -> typ 116; Binary.add_le32 b fid; Buffer.add_int64_le b (Int64.of_int offset); Binary.add_le32 b count
   | R (Response.Read data) -> typ 117; Binary.add_le32 b (String.length data); Buffer.add_string b data
   | T (Request.Write (fid, offset, data)) -> typ 118; Binary.add_le32 b fid; Buffer.add_int64_le b (Int64.of_int offset); Binary.add_le32 b (String.length data); Buffer.add_string b data
   | R (Response.Write count) -> typ 119; Binary.add_le32 b count
   | T (Request.Clunk fid) -> typ 120; Binary.add_le32 b fid
   | R Response.Clunk -> typ 121
   | T (Request.Remove fid) -> typ 122; Binary.add_le32 b fid
   | R Response.Remove -> typ 123
   | T (Request.Stat fid) -> typ 124; Binary.add_le32 b fid
   | R (Response.Stat d) -> typ 125; str b (encode_dir d)
   | T (Request.Wstat (fid, d)) -> typ 126; Binary.add_le32 b fid; str b (encode_dir d)
   | R Response.Wstat -> typ 127);
  let all = Buffer.create (4 + Buffer.length b) in
  Binary.add_le32 all (4 + Buffer.length b);
  Buffer.add_buffer all b;
  Buffer.contents all

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

(* a cursor on the bytes; Failure past their end *)
type cursor = { s : string; mutable o : int }

let need (c : cursor) n = if c.o + n > String.length c.s then failwith "9P: a message too short"
let g8 (c : cursor) = need c 1; let v = Char.code c.s.[c.o] in c.o <- c.o + 1; v
let g16 c = let lo = g8 c in lo lor (g8 c lsl 8)
(* (a fid's ~0, NOFID, is -1) *)
let g32 c = let lo = g16 c in let hi = g16 c in if hi land 0x8000 <> 0 then lo lor ((hi - 0x10000) lsl 16) else lo lor (hi lsl 16)
let g64 (c : cursor) = need c 8; let v = String.get_int64_le c.s c.o in c.o <- c.o + 8; v
let gstr (c : cursor) = let n = g16 c in need c n; let v = String.sub c.s c.o n in c.o <- c.o + n; v
let gseconds c = let lo = g16 c in float_of_int lo +. (float_of_int (g16 c) *. 65536.0)
let gqid c =
  let qtype = g8 c in
  let vers = Int64.logand (Int64.of_int32 (let lo = g16 c in let hi = g16 c in Int32.logor (Int32.of_int lo) (Int32.shift_left (Int32.of_int hi) 16))) 0xffffffffL in
  { qtype; vers; path = g64 c }

let gdir c : Sys_plan9.dir =
  let _size = g16 c in
  let dev_type = Char.chr (g16 c land 0xff) in
  let dev = g32 c in
  let q = gqid c in
  let perm = g16 c in
  let _ = g8 c in
  let mode_type = g8 c in
  let atime = gseconds c in
  let mtime = gseconds c in
  let length = Int64.to_int (g64 c) in
  let name = gstr c in
  let uid = gstr c in
  let gid = gstr c in
  let muid = gstr c in
  { name; uid; gid; muid; dev_type; dev; qid_path = q.path; qid_vers = q.vers; qid_type = q.qtype; mode_type; perm = perm land 0o777;
    atime; mtime; length }

let decode s : message =
  let c = { s; o = 0 } in
  let size = g32 c in
  if size <> String.length s then failwith "9P: a message's size is not its bytes'";
  let typ = g8 c in
  let tag = g16 c in
  let rec times n f = if n = 0 then [] else let v = f c in v :: times (n - 1) f in
  let mtyp = match typ with
    | 100 -> let msize = g32 c in T (Request.Version (msize, gstr c))
    | 101 -> let msize = g32 c in R (Response.Version (msize, gstr c))
    | 102 -> let afid = g32 c in let user = gstr c in T (Request.Auth (afid, user, gstr c))
    | 103 -> R (Response.Auth (gqid c))
    | 104 ->
        let fid = g32 c in
        let afid = g32 c in
        let user = gstr c in
        T (Request.Attach (fid, (if afid = nofid then None else Some afid), user, gstr c))
    | 105 -> R (Response.Attach (gqid c))
    | 107 -> R (Response.Error (gstr c))
    | 108 -> T (Request.Flush (g16 c))
    | 109 -> R Response.Flush
    | 110 -> let fid = g32 c in let newfid = g32 c in let n = g16 c in T (Request.Walk (fid, newfid, times n gstr))
    | 111 -> let n = g16 c in R (Response.Walk (times n gqid))
    | 112 -> let fid = g32 c in T (Request.Open (fid, g8 c))
    | 113 -> let q = gqid c in R (Response.Open (q, g32 c))
    | 114 ->
        (* the permissions' top byte (DMDIR: a directory) at bits 16 on: P9's perm *)
        let fid = g32 c in let name = gstr c in let low = g16 c in ignore (g8 c); let top = g8 c in
        T (Request.Create (fid, name, low lor (top lsl 16), g8 c))
    | 115 -> let q = gqid c in R (Response.Create (q, g32 c))
    | 116 -> let fid = g32 c in let offset = Int64.to_int (g64 c) in T (Request.Read (fid, offset, g32 c))
    | 117 -> let n = g32 c in need c n; R (Response.Read (String.sub s c.o n))
    | 118 -> let fid = g32 c in let offset = Int64.to_int (g64 c) in let n = g32 c in need c n; T (Request.Write (fid, offset, String.sub s c.o n))
    | 119 -> R (Response.Write (g32 c))
    | 120 -> T (Request.Clunk (g32 c))
    | 121 -> R Response.Clunk
    | 122 -> T (Request.Remove (g32 c))
    | 123 -> R Response.Remove
    | 124 -> T (Request.Stat (g32 c))
    | 125 -> let _n = g16 c in R (Response.Stat (gdir c))
    | 126 -> let fid = g32 c in let _n = g16 c in T (Request.Wstat (fid, gdir c))
    | 127 -> R Response.Wstat
    | n -> failwith (Printf.sprintf "9P: an unknown message's type, %d" n) in
  { tag; mtyp }

(* n bytes of the descriptor, or fewer at its end *)
let read_n fd n =
  let b = Bytes.create n in
  let rec go o = if o = n then o else match Unix.read fd b o (n - o) with 0 -> o | k -> go (o + k) in
  Bytes.sub_string b 0 (go 0)

let read fd =
  let head = read_n fd 4 in
  if String.length head < 4 then None
  else begin
    let size = Char.code head.[0] lor (Char.code head.[1] lsl 8) lor (Char.code head.[2] lsl 16) in
    if size < 7 || head.[3] <> '\000' then failwith "9P: a message's size";
    let rest = read_n fd (size - 4) in
    if String.length rest < size - 4 then None else Some (head ^ rest)
  end
