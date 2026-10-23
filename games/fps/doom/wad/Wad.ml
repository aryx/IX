(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Wad.mli *)

type lump = { name : string; data : string }

type t = { kind : string; lumps : lump array }

let u8 (s : string) (i : int) : int = Char.code s.[i]

let short (s : string) (i : int) : int =
  let v = u8 s i lor (u8 s (i + 1) lsl 8) in
  if v >= 0x8000 then v - 0x10000 else v

let int32 (s : string) (i : int) : int =
  let v = u8 s i lor (u8 s (i + 1) lsl 8) lor (u8 s (i + 2) lsl 16) in
  let hi = u8 s (i + 3) in
  (* (the top byte signed: -1 is 0xffffffff) *)
  v lor ((if hi >= 0x80 then hi - 0x100 else hi) lsl 24)

let name8 (s : string) (i : int) : string =
  let n = ref 0 in
  while !n < 8 && s.[i + !n] <> '\000' do incr n done;
  String.uppercase_ascii (String.sub s i !n)

let parse (s : string) : t =
  if String.length s < 12 then failwith "not a WAD: too short";
  let kind = String.sub s 0 4 in
  if kind <> "IWAD" && kind <> "PWAD" then failwith "not a WAD: no IWAD nor PWAD";
  let n = int32 s 4 and dir = int32 s 8 in
  if dir < 0 || dir + (16 * n) > String.length s then failwith "not a WAD: its directory is outside it";
  let lump (k : int) : lump =
    let e = dir + (16 * k) in
    let pos = int32 s e and size = int32 s (e + 4) in
    if pos < 0 || size < 0 || pos + size > String.length s then failwith "a lump outside the WAD";
    { name = name8 s (e + 8); data = String.sub s pos size }
  in
  { kind; lumps = Array.init n lump }

let index (wad : t) (name : string) : int option =
  let rec look (k : int) : int option = if k < 0 then None else if wad.lumps.(k).name = name then Some k else look (k - 1) in
  look (Array.length wad.lumps - 1)

let find (wad : t) (name : string) : lump option = Option.map (fun (k : int) -> wad.lumps.(k)) (index wad name)

let get (wad : t) (name : string) : string =
  match find wad name with Some l -> l.data | None -> failwith ("no lump " ^ name ^ " in the WAD")

let between (wad : t) (first : string) (last : string) : lump list =
  let inside = ref false and acc = ref [] in
  Array.iter
    (fun (l : lump) ->
      if l.name = first then inside := true
      else if l.name = last then inside := false
      else if !inside && l.data <> "" then acc := l :: !acc)
    wad.lumps;
  List.rev !acc

let add_short (b : Buffer.t) (v : int) : unit =
  Buffer.add_char b (Char.chr (v land 0xff));
  Buffer.add_char b (Char.chr ((v lsr 8) land 0xff))

let add_int32 (b : Buffer.t) (v : int) : unit =
  add_short b (v land 0xffff);
  add_short b ((v lsr 16) land 0xffff)

let add_name8 (b : Buffer.t) (name : string) : unit =
  for i = 0 to 7 do Buffer.add_char b (if i < String.length name then name.[i] else '\000') done

let write (kind : string) (lumps : lump list) : string =
  let b = Buffer.create 1_000_000 in
  let size = List.fold_left (fun (n : int) (l : lump) -> n + String.length l.data) 0 lumps in
  Buffer.add_string b kind;
  add_int32 b (List.length lumps);
  add_int32 b (12 + size);
  List.iter (fun (l : lump) -> Buffer.add_string b l.data) lumps;
  let pos = ref 12 in
  List.iter
    (fun (l : lump) ->
      add_int32 b !pos;
      add_int32 b (String.length l.data);
      add_name8 b l.name;
      pos := !pos + String.length l.data)
    lumps;
  Buffer.contents b
