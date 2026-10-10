(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Zlib.mli *)

(* Common's, here too: this file links nothing of lib_core *)
let ( ||| ) a b = match a with Some x -> x | None -> b

exception Corrupt of string

let corrupt s = raise (Corrupt s)

(* the tables of the format: a length or distance symbol's base and
 * its count of extra bits *)
let len_base = [| 3; 4; 5; 6; 7; 8; 9; 10; 11; 13; 15; 17; 19; 23; 27; 31; 35; 43; 51; 59; 67; 83; 99; 115; 131; 163; 195; 227; 258 |]
let len_extra = [| 0; 0; 0; 0; 0; 0; 0; 0; 1; 1; 1; 1; 2; 2; 2; 2; 3; 3; 3; 3; 4; 4; 4; 4; 5; 5; 5; 5; 0 |]
let dist_base = [| 1; 2; 3; 4; 5; 7; 9; 13; 17; 25; 33; 49; 65; 97; 129; 193; 257; 385; 513; 769; 1025; 1537; 2049; 3073; 4097; 6145; 8193; 12289; 16385; 24577 |]
let dist_extra = [| 0; 0; 0; 0; 1; 1; 2; 2; 3; 3; 4; 4; 5; 5; 6; 6; 7; 7; 8; 8; 9; 9; 10; 10; 11; 11; 12; 12; 13; 13 |]

let adler32 (s : string) =
  let a = ref 1 and b = ref 0 in
  String.iter (fun c -> a := (!a + Char.code c) mod 65521; b := (!b + !a) mod 65521) s;
  (* its two halves, the high 16 bits first: an int has 31 bits where
   * mini-ml builds for arm (old: (!b lsl 16) lor !a) *)
  (!b, !a)

(*****************************************************************************)
(* Inflate *)
(*****************************************************************************)

(* the bits of a stream, least significant first *)
type input = { s : string; mutable pos : int; mutable bit : int (* the bits of s.[pos] used *) }

let bit (i : input) =
  if i.pos >= String.length i.s then corrupt "truncated";
  let c = Char.code i.s.[i.pos] in
  let b = (c lsr i.bit) land 1 in
  if i.bit = 7 then (i.bit <- 0; i.pos <- i.pos + 1) else i.bit <- i.bit + 1;
  b

let bits i n = let v = ref 0 in for k = 0 to n - 1 do v := !v lor (bit i lsl k) done; !v

(* a canonical code, as the count of codes of each length and the
 * symbols in code order: enough to decode, a bit at a time *)
type code = { counts : int array; symbols : int array }

let code_of_lengths (lengths : int array) : code =
  let counts = Array.make 16 0 in
  Array.iter (fun l -> counts.(l) <- counts.(l) + 1) lengths;
  counts.(0) <- 0;
  let offs = Array.make 16 0 in
  for l = 1 to 14 do offs.(l + 1) <- offs.(l) + counts.(l) done;
  let symbols = Array.make (Array.length lengths) 0 in
  Array.iteri (fun sym l -> if l > 0 then (symbols.(offs.(l)) <- sym; offs.(l) <- offs.(l) + 1)) lengths;
  { counts; symbols }

(* the codes of length l are consecutive numbers starting at [first],
 * their symbols at [index] in [symbols] *)
let decode i (c : code) =
  let rec go len code first index =
    if len > 15 then corrupt "bad code";
    let code = code lor bit i in
    let count = c.counts.(len) in
    if code - first < count then c.symbols.(index + code - first)
    else go (len + 1) (code lsl 1) ((first + count) lsl 1) (index + count)
  in
  go 1 0 0 0

let fixed =
  code_of_lengths (Array.init 288 (fun s -> if s < 144 then 8 else if s < 256 then 9 else if s < 280 then 7 else 8)),
  code_of_lengths (Array.make 30 5)

(* the order a dynamic block sends its code-length code's lengths in *)
let order = [| 16; 17; 18; 0; 8; 7; 9; 6; 10; 5; 11; 4; 12; 3; 13; 2; 14; 1; 15 |]

let dynamic i =
  let nlit = bits i 5 + 257 in
  let ndist = bits i 5 + 1 in
  let ncode = bits i 4 + 4 in
  let lens = Array.make 19 0 in
  for k = 0 to ncode - 1 do lens.(order.(k)) <- bits i 3 done;
  let lencode = code_of_lengths lens in
  let all = Array.make (nlit + ndist) 0 in
  let n = ref 0 in
  while !n < nlit + ndist do
    match decode i lencode with
    | sym when sym < 16 -> all.(!n) <- sym; incr n
    | sym ->
        let v, times = match sym with
          | 16 -> if !n = 0 then corrupt "repeat of nothing"; all.(!n - 1), 3 + bits i 2
          | 17 -> 0, 3 + bits i 3
          | _ -> 0, 11 + bits i 7 in
        if !n + times > nlit + ndist then corrupt "too many lengths";
        for _i = 1 to times do all.(!n) <- v; incr n done
  done;
  code_of_lengths (Array.sub all 0 nlit), code_of_lengths (Array.sub all nlit ndist)

let inflate_raw i (out : Buffer.t) =
  let rec blocks () =
    let last = bit i in
    (match bits i 2 with
     | 0 ->
         if i.bit > 0 then (i.bit <- 0; i.pos <- i.pos + 1);
         if i.pos + 4 > String.length i.s then corrupt "truncated";
         let len = Char.code i.s.[i.pos] lor (Char.code i.s.[i.pos + 1] lsl 8) in
         if i.pos + 4 + len > String.length i.s then corrupt "truncated";
         Buffer.add_substring out i.s (i.pos + 4) len;
         i.pos <- i.pos + 4 + len
     | 1 -> let lit, dist = fixed in codes lit dist
     | 2 -> let lit, dist = dynamic i in codes lit dist
     | _ -> corrupt "bad block type");
    if last = 0 then blocks ()
  and codes lit dist =
    match decode i lit with
    | 256 -> ()
    | sym when sym < 256 -> Buffer.add_char out (Char.chr sym); codes lit dist
    | sym ->
        let sym = sym - 257 in
        if sym >= 29 then corrupt "bad length";
        let len = len_base.(sym) + bits i len_extra.(sym) in
        let d = decode i dist in
        if d >= 30 then corrupt "bad distance";
        let d = dist_base.(d) + bits i dist_extra.(d) in
        let start = Buffer.length out - d in
        if start < 0 then corrupt "distance too far back";
        (* the copy may overlap what it writes: byte by byte *)
        for k = 0 to len - 1 do Buffer.add_char out (Buffer.nth out (start + k)) done;
        codes lit dist
  in
  blocks ()

let inflate_at pos s =
  if pos + 2 > String.length s then corrupt "truncated";
  let cmf = Char.code s.[pos] and flg = Char.code s.[pos + 1] in
  if cmf land 0x0f <> 8 || ((cmf lsl 8) lor flg) mod 31 <> 0 || flg land 0x20 <> 0 then corrupt "bad zlib header";
  let i = { s; pos = pos + 2; bit = 0 } in
  let out = Buffer.create 4096 in
  inflate_raw i out;
  if i.bit > 0 then (i.bit <- 0; i.pos <- i.pos + 1);
  if i.pos + 4 > String.length s then corrupt "truncated";
  let data = Buffer.contents out in
  let half (o : int) = (Char.code s.[i.pos + o] lsl 8) lor Char.code s.[i.pos + o + 1] in
  if (half 0, half 2) <> adler32 data then corrupt "bad checksum";
  data, i.pos + 4

(*****************************************************************************)
(* Deflate *)
(*****************************************************************************)

type output = { buf : Buffer.t; mutable acc : int; mutable nacc : int }

let inflate s = inflate_at 0 s

let inflate_blocks pos s =
  let out = Buffer.create 4096 in
  inflate_raw { s; pos; bit = 0 } out;
  Buffer.contents out

let put o v n =
  o.acc <- o.acc lor (v lsl o.nacc);
  o.nacc <- o.nacc + n;
  while o.nacc >= 8 do
    Buffer.add_char o.buf (Char.chr (o.acc land 0xff));
    o.acc <- o.acc lsr 8;
    o.nacc <- o.nacc - 8
  done

(* a Huffman code goes most significant bit first: reversed *)
let put_code o code len =
  let r = ref 0 in
  for k = 0 to len - 1 do if code land (1 lsl k) <> 0 then r := !r lor (1 lsl (len - 1 - k)) done;
  put o !r len

let put_lit o sym =
  if sym < 144 then put_code o (0x30 + sym) 8
  else if sym < 256 then put_code o (0x190 + sym - 144) 9
  else if sym < 280 then put_code o (sym - 256) 7
  else put_code o (0xc0 + sym - 280) 8

(* the symbol of a length or distance: the last base at or below it *)
let symbol bases v = let rec go k = if k + 1 < Array.length bases && bases.(k + 1) <= v then go (k + 1) else k in go 0

let window = 32768
let max_chain = 64

let deflate (s : string) =
  let o = { buf = Buffer.create (String.length s / 2 + 16); acc = 0; nacc = 0 } in
  Buffer.add_string o.buf "\x78\x01";
  put o 1 1;           (* the last block *)
  put o 1 2;           (* fixed codes *)
  let n = String.length s in
  (* the last position of each 3-byte hash, and each position's previous
   * one with the same hash *)
  let head = Hashtbl.create 4096 and prev = Array.make (max n 1) (-1) in
  let key p = (Char.code s.[p] lsl 16) lor (Char.code s.[p + 1] lsl 8) lor Char.code s.[p + 2] in
  let insert p = if p + 2 < n then begin
      let k = key p in
      prev.(p) <- Hashtbl.find_opt head k ||| (-1);
      Hashtbl.replace head k p end in
  let longest p =
    if p + 2 >= n then 0, 0
    else
      let rec go cand chain best bestd =
        if cand < 0 || p - cand > window || chain = 0 then best, bestd
        else
          let l = ref 0 in
          while !l < 258 && p + !l < n && s.[cand + !l] = s.[p + !l] do incr l done;
          if !l > best then go prev.(cand) (chain - 1) !l (p - cand) else go prev.(cand) (chain - 1) best bestd
      in
      go (Hashtbl.find_opt head (key p) ||| (-1)) max_chain 0 0
  in
  let p = ref 0 in
  while !p < n do
    let len, d = longest !p in
    if len >= 3 then begin
      let ls = symbol len_base len in
      put_lit o (257 + ls);
      put o (len - len_base.(ls)) len_extra.(ls);
      let ds = symbol dist_base d in
      put_code o ds 5;
      put o (d - dist_base.(ds)) dist_extra.(ds);
      for k = 0 to len - 1 do insert (!p + k) done;
      p := !p + len
    end
    else begin
      put_lit o (Char.code s.[!p]);
      insert !p;
      incr p
    end
  done;
  put_lit o 256;
  if o.nacc > 0 then put o 0 (8 - o.nacc);
  let hi, lo = adler32 s in
  List.iter (fun (v : int) -> Buffer.add_char o.buf (Char.chr (v lsr 8)); Buffer.add_char o.buf (Char.chr (v land 255))) [ hi; lo ];
  Buffer.contents o.buf

(*****************************************************************************)
(* CRC-32 *)
(*****************************************************************************)

(* A CRC is 32 bits and an int has 31 where mini-ml builds for arm: the
 * polynomial, 0xedb88320, does not fit in one. So a CRC is (hi, lo),
 * 16 bits each, and a shift right by k takes hi's low k bits into
 * lo's top. The table is two, of the halves of each entry.
 * old: one int and one table (crc32_sub, crc32), wrong on arm
 * (docs/plans/bugs/ix.md) *)
let crc_halves =
  let hi = Array.make 256 0 and lo = Array.make 256 0 in
  for n = 0 to 255 do
    let h = ref 0 and l = ref n in
    for _i = 0 to 7 do
      let odd = !l land 1 <> 0 in
      l := (!l lsr 1) lor ((!h land 1) lsl 15);
      h := !h lsr 1;
      if odd then begin
        h := !h lxor 0xedb8;
        l := !l lxor 0x8320
      end
    done;
    hi.(n) <- !h;
    lo.(n) <- !l
  done;
  (hi, lo)

let crc32_halves s ~pos ~len =
  let thi, tlo = crc_halves in
  let h = ref 0xffff and l = ref 0xffff in
  for i = pos to pos + len - 1 do
    let k = (!l lxor Char.code (String.unsafe_get s i)) land 0xff in
    l := ((!l lsr 8) lor ((!h land 0xff) lsl 8)) lxor tlo.(k);
    h := (!h lsr 8) lxor thi.(k)
  done;
  (!h lxor 0xffff, !l lxor 0xffff)

(* gzip's file (RFC 1952): ten bytes of header, the optional fields its
 * flags say (extra, a name, a comment, a header's CRC), deflate's
 * blocks, then the CRC-32 and the length of what they give *)
let gunzip s =
  let n = String.length s in
  if n < 18 || s.[0] <> '\x1f' || s.[1] <> '\x8b' || s.[2] <> '\x08' then corrupt "bad gzip header";
  let flags = Char.code s.[3] in
  let pos = ref 10 in
  if flags land 4 <> 0 then pos := !pos + 2 + (Char.code s.[!pos] lor (Char.code s.[!pos + 1] lsl 8));
  let zero () =
    (match String.index_from_opt s !pos '\000' with Some i -> pos := i + 1 | None -> corrupt "truncated")
  in
  if flags land 8 <> 0 then zero ();
  if flags land 16 <> 0 then zero ();
  if flags land 2 <> 0 then pos := !pos + 2;
  if !pos >= n then corrupt "truncated";
  let i = { s; pos = !pos; bit = 0 } in
  let out = Buffer.create (4 * n) in
  inflate_raw i out;
  if i.bit > 0 then (i.bit <- 0; i.pos <- i.pos + 1);
  if i.pos + 4 > n then corrupt "truncated";
  let data = Buffer.contents out in
  (* little-endian, the low half first *)
  let half (o : int) = Char.code s.[i.pos + o] lor (Char.code s.[i.pos + o + 1] lsl 8) in
  if (half 2, half 0) <> crc32_halves data ~pos:0 ~len:(String.length data) then corrupt "bad checksum";
  data
