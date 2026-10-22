(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bspfile.mli *)

type t = { version : int; lumps : string array }

let entities = 0
let planes = 1
let textures = 2
let vertexes = 3
let visibility = 4
let nodes = 5
let texinfo = 6
let faces = 7
let lighting = 8
let clipnodes = 9
let leafs = 10
let marksurfaces = 11
let edges = 12
let surfedges = 13
let models = 14
let u8 (s : string) (i : int) : int = Char.code s.[i]
let ushort (s : string) (i : int) : int = u8 s i lor (u8 s (i + 1) lsl 8)

let short (s : string) (i : int) : int =
  let v = ushort s i in
  if v >= 0x8000 then v - 0x10000 else v

let int32 (s : string) (i : int) : int =
  let v = u8 s i lor (u8 s (i + 1) lsl 8) lor (u8 s (i + 2) lsl 16) in
  let hi = u8 s (i + 3) in
  (* (the top byte signed: -1 is 0xffffffff) *)
  v lor ((if hi >= 0x80 then hi - 0x100 else hi) lsl 24)

let float32 (s : string) (i : int) : float =
  (* (two halves: 0x80000000 and up are no int of 31 bits) *)
  let lo = Int32.of_int (ushort s i) and hi = Int32.of_int (ushort s (i + 2)) in
  Int32.float_of_bits (Int32.logor (Int32.shift_left hi 16) lo)

let name (s : string) (i : int) (n : int) : string =
  let k = ref 0 in
  while !k < n && s.[i + !k] <> '\000' do
    incr k
  done;
  String.sub s i !k

let parse (s : string) : t =
  if String.length s < 4 + (15 * 8) then failwith "not a .bsp: too short";
  let version = int32 s 0 in
  if version <> 29 then
    failwith (Printf.sprintf "a .bsp of version %d, not 29" version);
  let lump (k : int) : string =
    let pos = int32 s (4 + (8 * k)) and len = int32 s (8 + (8 * k)) in
    if pos < 0 || len < 0 || pos + len > String.length s then
      failwith "a lump outside the .bsp";
    String.sub s pos len
  in
  { version; lumps = Array.init 15 lump }

let add_short (b : Buffer.t) (v : int) : unit =
  Buffer.add_char b (Char.chr (v land 0xff));
  Buffer.add_char b (Char.chr ((v lsr 8) land 0xff))

let add_int32 (b : Buffer.t) (v : int) : unit =
  add_short b (v land 0xffff);
  add_short b ((v asr 16) land 0xffff)

let add_name (b : Buffer.t) (n : int) (name : string) : unit =
  for i = 0 to n - 1 do
    Buffer.add_char b (if i < String.length name then name.[i] else '\000')
  done

let write (bsp : t) : string =
  let b = Buffer.create 1_000_000 in
  add_int32 b bsp.version;
  (* (each lump at an offset that is a multiple of 4, as qbsp's) *)
  let pos = ref (4 + (15 * 8)) in
  Array.iter
    (fun (l : string) ->
      add_int32 b !pos;
      add_int32 b (String.length l);
      pos := (!pos + String.length l + 3) land lnot 3)
    bsp.lumps;
  Array.iter
    (fun (l : string) ->
      Buffer.add_string b l;
      while Buffer.length b land 3 <> 0 do
        Buffer.add_char b '\000'
      done)
    bsp.lumps;
  Buffer.contents b
