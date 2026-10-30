(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Image.mli *)

type t = {
  file : string;
  sections : (int * int * int * int) list;
  entry_point : int;
  version : string;
  strings : int;
  user_strings : int;
  blobs : int;
  guids : int;
  blobs_size : int;
  rows : int array;
  tables : int array array array;
}

exception Bad_image of string

let bad (msg : string) = raise (Bad_image msg)

let u8 = Binary.u8
let u16 = Binary.le16
let u32 = Binary.le32

let offset_in (sections : (int * int * int * int) list) (rva : int) : int =
  match List.find_opt (fun (va, vsize, _, raw) -> rva >= va && rva < va + max vsize raw) sections with
  | Some (va, _, off, _) -> off + rva - va
  | None -> bad (Printf.sprintf "RVA 0x%x in no section" rva)

let offset (img : t) (rva : int) : int = offset_in img.sections rva

(* a NUL-terminated name at [at] *)
let cstring (s : string) (at : int) : string =
  match String.index_from_opt s at '\000' with
  | Some e -> String.sub s at (e - at)
  | None -> bad "a name without its end"

(* II.24.2.4: a blob's length in 1, 2 or 4 bytes, by its first's high
 * bits (0, 10, 110): (the length, where the bytes start) *)
let compressed (s : string) (at : int) : int * int =
  let b = u8 s at in
  if b land 0x80 = 0 then (b, at + 1)
  else if b land 0xC0 = 0x80 then (((b land 0x3F) lsl 8) lor u8 s (at + 1), at + 2)
  else
    ((((b land 0x1F) lsl 24) lor (u8 s (at + 1) lsl 16) lor (u8 s (at + 2) lsl 8)
      lor u8 s (at + 3)), at + 4)

let string (img : t) (i : int) : string = cstring img.file (img.strings + i)

let blob (img : t) (i : int) : string =
  let n, at = compressed img.file (img.blobs + i) in
  String.sub img.file at n

let guid (img : t) (i : int) : string =
  if i = 0 then "" else String.sub img.file (img.guids + (i - 1) * 16) 16

(* UTF-16, its last byte a flag (II.24.2.4); kept as UTF-8, so Latin-1
 * text is one byte a character (plan_dotnet.md, decision 7) *)
let user_string (img : t) (i : int) : string =
  let n, at = compressed img.file (img.user_strings + i) in
  let b = Buffer.create n in
  let k = ref 0 in
  while !k + 1 < n do
    let c = u16 img.file (at + !k) in
    if c < 256 then Buffer.add_char b (Char.chr c)
    else Buffer.add_utf_8_uchar b (Uchar.of_int c);
    k := !k + 2
  done;
  Buffer.contents b

let decode (c : Metadata.coded) (v : int) : int * int =
  let row = v lsr c.bits in
  if row = 0 then (-1, 0)
  else
    let tag = v land ((1 lsl c.bits) - 1) in
    if tag >= Array.length c.tables then bad ("a coded index " ^ c.cname ^ " out of its tables")
    else (c.tables.(tag), row)

let get (img : t) (table : int) (row : int) (col : string) : int =
  img.tables.(table).(row).(Metadata.col table col)

let range (img : t) (table : int) (row : int) (col : string) (target : int) : int * int =
  let first = get img table row col in
  let last =
    if row < img.rows.(table) then get img table (row + 1) col - 1
    else img.rows.(target) in
  (first, last)

(* II.24.2.6: the tables' stream *)
let read_tables (s : string) (at : int) : int array * int array array array =
  let heaps = u8 s (at + 6) in
  (* (Valid, 64 bits, by its two halves: arm's int has 31) *)
  let lo = u32 s (at + 8) and hi = u32 s (at + 12) in
  let present t = if t < 32 then (lo lsr t) land 1 = 1 else (hi lsr (t - 32)) land 1 = 1 in
  let rows = Array.make 64 0 in
  let p = ref (at + 24) in
  for t = 0 to 63 do
    if present t then begin rows.(t) <- u32 s !p; p := !p + 4 end
  done;
  if heaps land 0x20 <> 0 then p := !p + 4;
  for t = Metadata.count to 63 do
    if rows.(t) > 0 then bad (Printf.sprintf "table 0x%x, not ECMA-335's" t)
  done;
  let size (k : Metadata.column) : int =
    match k with
    | U8 | U16 -> 2
    | U32 -> 4
    | String -> if heaps land 1 <> 0 then 4 else 2
    | Guid -> if heaps land 2 <> 0 then 4 else 2
    | Blob -> if heaps land 4 <> 0 then 4 else 2
    | Table t -> if rows.(t) < 0x10000 then 2 else 4
    | Coded c ->
        let most = Array.fold_left (fun m t -> if t < 0 then m else max m rows.(t)) 0 c.tables in
        if most < 1 lsl (16 - c.bits) then 2 else 4 in
  let tables =
    Array.init Metadata.count (fun t ->
        let cols = Array.map (fun (_, k) -> size k) (Metadata.columns t) in
        Array.init (rows.(t) + 1) (fun r ->
            if r = 0 then [||]
            else
              Array.map (fun n ->
                  let v = if n = 2 then u16 s !p else u32 s !p in
                  p := !p + n;
                  v) cols)) in
  (Array.sub rows 0 Metadata.count, tables)

let read (file : string) : t =
  try
    if String.length file < 0x80 || String.sub file 0 2 <> "MZ" then bad "not a PE file (no MZ)";
    let pe = u32 file 0x3C in
    if String.sub file pe 4 <> "PE\000\000" then bad "not a PE file (no PE)";
    let coff = pe + 4 in
    let nsections = u16 file (coff + 2) in
    let opt = coff + 20 in
    let opt_size = u16 file (coff + 16) in
    (* PE32 or PE32+: the directories at 96 or 112, the 15th the CLI's *)
    let dirs = match u16 file opt with
      | 0x10b -> opt + 96
      | 0x20b -> opt + 112
      | m -> bad (Printf.sprintf "an optional header 0x%x" m) in
    let sections =
      List.init nsections (fun i ->
          let h = opt + opt_size + i * 40 in
          (u32 file (h + 12), u32 file (h + 8), u32 file (h + 20), u32 file (h + 16))) in
    let cli_rva = u32 file (dirs + 14 * 8) in
    if cli_rva = 0 then bad "no CLI header: not a .NET assembly";
    let cli = offset_in sections cli_rva in
    let md = offset_in sections (u32 file (cli + 8)) in
    let entry_point = u32 file (cli + 20) in
    if u32 file md <> 0x424A5342 then bad "no metadata (BSJB)";
    let vlen = u32 file (md + 12) in
    let version = cstring (String.sub file (md + 16) vlen ^ "\000") 0 in
    let nstreams = u16 file (md + 16 + vlen + 2) in
    let p = ref (md + 16 + vlen + 4) in
    let streams =
      List.init nstreams (fun _ ->
          let off = u32 file !p and size = u32 file (!p + 4) in
          let name = cstring file (!p + 8) in
          p := !p + 8 + ((String.length name + 4) land (lnot 3));
          (name, (md + off, size))) in
    let stream n = match List.assoc_opt n streams with
      | Some (o, _) -> o
      | None -> bad ("no stream " ^ n) in
    let tables_at = match List.assoc_opt "#~" streams with
      | Some (o, _) -> o
      | None -> bad "no #~ stream (an assembly being edited: #-)" in
    let rows, tables = read_tables file tables_at in
    let opt_stream n = match List.assoc_opt n streams with Some (o, _) -> o | None -> 0 in
    { file; sections; entry_point; version;
      strings = stream "#Strings"; user_strings = opt_stream "#US";
      blobs = opt_stream "#Blob"; guids = opt_stream "#GUID";
      blobs_size = (match List.assoc_opt "#Blob" streams with Some (_, n) -> n | None -> 0);
      rows; tables }
  with Invalid_argument _ -> bad "truncated"

type clause = {
  kind : int;
  try_start : int;
  try_end : int;
  handler_start : int;
  handler_end : int;
  class_token : int;
}
type body = {
  max_stack : int;
  locals_token : int;
  init_locals : bool;
  code : string;
  clauses : clause list;
}

(* II.25.4: a tiny header (a byte: the size, 2 in its low bits) or a
 * fat one (12 bytes), then the IL, then, aligned on 4, the sections of
 * exception clauses, small (12 bytes a clause) or fat (24) *)
let body (img : t) (rva : int) : body =
  let s = img.file in
  let at = offset img rva in
  let b = u8 s at in
  if b land 3 = 2 then
    { max_stack = 8; locals_token = 0; init_locals = false;
      code = String.sub s (at + 1) (b lsr 2); clauses = [] }
  else if b land 3 = 3 then begin
    let flags = u16 s at in
    let hsize = (flags lsr 12) * 4 in
    let size = u32 s (at + 4) in
    let code_at = at + hsize in
    let clauses = ref [] in
    let more = ref (flags land 0x08 <> 0) in
    let p = ref ((code_at + size + 3) land (lnot 3)) in
    while !more do
      let kind = u8 s !p in
      let fat = kind land 0x40 <> 0 in
      let n =
        if fat then (u8 s (!p + 1) lor (u8 s (!p + 2) lsl 8) lor (u8 s (!p + 3) lsl 16) - 4) / 24
        else (u8 s (!p + 1) - 4) / 12 in
      for i = 0 to n - 1 do
        let c =
          if fat then
            let q = !p + 4 + i * 24 in
            let ts = u32 s (q + 4) and hs = u32 s (q + 12) in
            { kind = u32 s q; try_start = ts; try_end = ts + u32 s (q + 8);
              handler_start = hs; handler_end = hs + u32 s (q + 16);
              class_token = u32 s (q + 20) }
          else
            let q = !p + 4 + i * 12 in
            let ts = u16 s (q + 2) and hs = u16 s (q + 5) in
            { kind = u16 s q; try_start = ts; try_end = ts + u8 s (q + 4);
              handler_start = hs; handler_end = hs + u8 s (q + 7);
              class_token = u32 s (q + 8) } in
        if kind land 1 <> 0 then clauses := c :: !clauses
      done;
      let len = if fat then 4 + n * 24 else 4 + n * 12 in
      more := kind land 0x80 <> 0;
      p := (!p + len + 3) land (lnot 3)
    done;
    { max_stack = u16 s (at + 2); locals_token = u32 s (at + 8);
      init_locals = flags land 0x10 <> 0; code = String.sub s code_at size;
      clauses = List.rev !clauses }
  end
  else bad (Printf.sprintf "a method's header 0x%x at RVA 0x%x" b rva)
