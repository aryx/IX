(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf_filter.ml; lzw's early is said, where it was optional (1); Zlib is ix's (inflate, and inflate_blocks where the playground's Inflate was called) (docs/plans/plan_pdf.md) *)

(* See Pdf_filter.mli *)

open Pdf_object

let ascii_hex (s : string) : string =
  let b = Buffer.create (String.length s / 2) and high = ref (-1) in
  (try
     String.iter
       (fun c ->
         if c = '>' then raise Exit
         else if not (is_space c) then if !high < 0 then high := hex c else (Buffer.add_char b (Char.chr ((!high * 16) + hex c)); high := -1))
       s
   with Exit -> ());
  if !high >= 0 then Buffer.add_char b (Char.chr (!high * 16));
  Buffer.contents b

(* five characters of 85 values are four bytes; z is four zeros *)
let ascii85 (s : string) : string =
  let b = Buffer.create (String.length s) and group = ref 0 and count = ref 0 in
  let flush n =
    for i = 0 to n - 1 do Buffer.add_char b (Char.chr ((!group lsr (8 * (3 - i))) land 255)) done;
    group := 0;
    count := 0
  in
  (try
     String.iter
       (fun c ->
         if c = '~' then raise Exit
         else if c = 'z' && !count = 0 then Buffer.add_string b "\000\000\000\000"
         else if c >= '!' && c <= 'u' then (
           group := (!group * 85) + Char.code c - 33;
           incr count;
           if !count = 5 then flush 4))
       s
   with Exit -> ());
  if !count > 1 then (
    let n = !count in
    for _i = n to 4 do group := (!group * 85) + 84 done;
    flush (n - 1));
  Buffer.contents b

let run_length (s : string) : string =
  let b = Buffer.create (String.length s) and i = ref 0 and n = String.length s in
  (try
     while !i < n do
       let l = Char.code s.[!i] in
       if l = 128 then raise Exit
       else if l < 128 then (Buffer.add_string b (String.sub s (!i + 1) (min (l + 1) (n - !i - 1))); i := !i + l + 2)
       else if !i + 1 < n then (Buffer.add_string b (String.make (257 - l) s.[!i + 1]); i := !i + 2)
       else raise Exit
     done
   with Exit -> ());
  Buffer.contents b

(* Welch's codes of 9 to 12 bits, the high bit first (a GIF's are the
 * other way); 256 clears the table, 257 ends *)
let lzw ~(early : int) (s : string) : string =
  let b = Buffer.create (String.length s * 3) and table = Array.make 4096 "" in
  for i = 0 to 255 do table.(i) <- String.make 1 (Char.chr i) done;
  let next = ref 258 and width = ref 9 and at = ref 0 and previous = ref "" in
  let code () =
    let v = ref 0 in
    for _i = 1 to !width do
      v := (!v lsl 1) lor (if !at lsr 3 < String.length s then (Char.code s.[!at lsr 3] lsr (7 - (!at land 7))) land 1 else 0);
      incr at
    done;
    if !at > 8 * String.length s then 257 else !v
  in
  let rec go () =
    let c = code () in
    if c = 256 then (next := 258; width := 9; previous := ""; go ())
    else if c <> 257 then (
      let entry = if c < !next && (c < 256 || c >= 258) then table.(c) else if !previous <> "" then !previous ^ String.make 1 !previous.[0] else "" in
      Buffer.add_string b entry;
      if !previous <> "" && !next < 4096 && entry <> "" then (table.(!next) <- !previous ^ String.make 1 entry.[0]; incr next);
      previous := entry;
      if !next + early >= 1 lsl !width && !width < 12 then incr width;
      go ())
  in
  go ();
  Buffer.contents b

(* a row predicted from its neighbours, as PNG's rows are (each led by
 * its kind) or TIFF's (from the left) *)
let unpredict (d : dict) (s : string) : string =
  let int key default = match List.assoc_opt key d with Some v -> to_int v | None -> default in
  let predictor = int "Predictor" 1 in
  if predictor = 1 then s
  else (
    let colors = int "Colors" 1 and bpc = int "BitsPerComponent" 8 and columns = int "Columns" 1 in
    let bpp = max 1 (colors * bpc / 8) and row = ((columns * colors * bpc) + 7) / 8 in
    let step = if predictor >= 10 then row + 1 else row in
    let rows = String.length s / step in
    let out = Bytes.make (rows * row) '\000' in
    let get y x = if x < 0 || y < 0 then 0 else Char.code (Bytes.get out ((y * row) + x)) in
    for y = 0 to rows - 1 do
      let kind = if predictor >= 10 then Char.code s.[y * step] else 1 in
      for x = 0 to row - 1 do
        let raw = Char.code s.[(y * step) + x + if predictor >= 10 then 1 else 0] in
        let a = get y (x - bpp) and up = get (y - 1) x and c = get (y - 1) (x - bpp) in
        let predicted =
          match kind with
          | 0 -> 0
          | 1 -> a
          | 2 -> up
          | 3 -> (a + up) / 2
          | _ ->
              let p = a + up - c in
              let pa = abs (p - a) and pb = abs (p - up) and pc = abs (p - c) in
              if pa <= pb && pa <= pc then a else if pb <= pc then up else c
        in
        Bytes.set out ((y * row) + x) (Char.chr ((raw + predicted) land 255))
      done
    done;
    Bytes.to_string out)

let inflate (s : string) : string = try fst (Zlib.inflate s) with _ -> ( try Zlib.inflate_blocks 2 s with _ -> "")

(* [decode resolve d bytes]: a stream's bytes with its filters undone,
 * in order, as far as they are ours: a filter left (a picture's own:
 * DCTDecode is JPEG) stops it, and is named *)
let decode (resolve : t -> t) (d : dict) (bytes : string) : string * string option =
  let list v = match resolve v with Array l -> List.map resolve l | Null -> [] | v -> [ v ] in
  let filters = match List.assoc_opt "Filter" d with Some v -> list v | None -> [] in
  let parms = match List.assoc_opt "DecodeParms" d with Some v -> list v | None -> [] in
  let rec go bytes filters parms =
    match filters with
    | [] -> (bytes, None)
    | Name f :: rest -> (
        let p = match parms with Dict p :: _ -> List.map (fun (k, v) -> (k, resolve v)) p | _ -> [] in
        let parms = match parms with _ :: t -> t | [] -> [] in
        match f with
        | "FlateDecode" | "Fl" -> go (unpredict p (inflate bytes)) rest parms
        | "LZWDecode" | "LZW" -> go (unpredict p (lzw ~early:(match List.assoc_opt "EarlyChange" p with Some v -> to_int v | None -> 1) bytes)) rest parms
        | "ASCIIHexDecode" | "AHx" -> go (ascii_hex bytes) rest parms
        | "ASCII85Decode" | "A85" -> go (ascii85 bytes) rest parms
        | "RunLengthDecode" | "RL" -> go (run_length bytes) rest parms
        | other -> (bytes, Some other))
    | _ -> (bytes, None)
  in
  go bytes filters parms
