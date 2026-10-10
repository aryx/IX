(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Fonts.mli *)

type char_ = { dx : int; x : int; y : int; w : int; h : int; pattern : string }

type t = {
  name : string;
  height : int;
  min_x : int; max_x : int; min_y : int; max_y : int;
  chars : char_ array;
}

let font_file_id = 0xdb
let none = { dx = 0; x = 0; y = 0; w = 0; h = 0; pattern = "\000\000" }

(* The file: its id, three bytes (abstraction, family, variant), then
 * numbers of 16 bits of which Oberon keeps the low byte: the height,
 * minX, maxX, minY, maxY; the runs' number, and each run, the first
 * character and the one after the last; a box (dx, x, y, w, h) for
 * each character of the runs; then their patterns, (w + 7) / 8 bytes a
 * row. A y and minY are signed bytes. *)
let read name (f : Files.t) : t option =
  let r = Files.set f 0 in
  let int16 () = let b = Files.read_byte r in ignore (Files.read_byte r); b in
  let signed b = if b >= 128 then b - 256 else b in
  if Files.read_byte r <> font_file_id then None
  else begin
    for _i = 1 to 3 do ignore (Files.read_byte r) done;
    let height = int16 () in
    let min_x = int16 () in
    let max_x = int16 () in
    let min_y = signed (int16 ()) in
    let max_y = int16 () in
    let nruns = int16 () in
    let runs = Array.make nruns (0, 0) in
    for k = 0 to nruns - 1 do
      let first = int16 () in
      let last = int16 () in
      runs.(k) <- (first, last)
    done;
    let codes = Array.of_list (List.concat_map (fun (first, last) -> List.init (last - first) (fun i -> first + i)) (Array.to_list runs)) in
    (* (loops: the file is read in their order) *)
    let boxes = Array.make (Array.length codes) (0, 0, 0, 0, 0) in
    for j = 0 to Array.length codes - 1 do
      let dx = int16 () in
      let x = int16 () in
      let y = signed (int16 ()) in
      let w = int16 () in
      let h = int16 () in
      boxes.(j) <- (dx, x, y, w, h)
    done;
    let chars = Array.make 128 none in
    for j = 0 to Array.length codes - 1 do
      let dx, x, y, w, h = boxes.(j) in
      let b = Buffer.create 32 in
      Buffer.add_char b (Char.chr w);
      Buffer.add_char b (Char.chr h);
      for _i = 1 to (w + 7) / 8 * h do Buffer.add_char b (Files.read r) done;
      if codes.(j) < 128 then chars.(codes.(j)) <- { dx; x; y; w; h; pattern = Buffer.contents b }
    done;
    Some { name; height; min_x; max_x; min_y; max_y; chars }
  end

(* the fonts read (Oberon's list, root) *)
let fonts : (string * t) list ref = ref []

let rec this name =
  match List.assoc_opt name !fonts with
  | Some font -> font
  | None -> (
      match Option.bind (Files.old name) (read name) with
      | Some font -> fonts := (name, font) :: !fonts; font
      | None -> if name = "Oberon10.Scn.Fnt" then Machine.panic "Fonts: no Oberon10.Scn.Fnt" else default ())

and default () = this "Oberon10.Scn.Fnt"

let get (font : t) c = font.chars.(Char.code c land 127)
let names () = List.rev_map fst !fonts
