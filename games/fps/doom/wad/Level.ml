(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Level.mli *)

type vertex = { x : float; y : float }

type sector = {
  index : int; (* its number in the level *)
  mutable floor : float;
  mutable ceiling : float;
  mutable floorpic : int;
  ceilingpic : int;
  mutable light : int;
  mutable special : int;
  tag : int;
  mutable lines : int list;
}

type side = { xoffset : float; yoffset : float; mutable top : int; mutable bottom : int; mutable middle : int; sector : int }

type line = { v1 : vertex; v2 : vertex; flags : int; mutable special : int; tag : int; front : int; back : int option }

let blocking = 1
let two_sided = 4
let upper_unpegged = 8
let lower_unpegged = 16

type seg = {
  sv1 : vertex;
  sv2 : vertex;
  angle : float;
  seg_line : int;
  seg_side : int;
  offset : float;
  side : side;
  front_sector : sector;
  back_sector : sector option;
}

type subsector = { first : int; count : int; sub_sector : sector }
type child = Node of int | Subsector of int
type node = { nx : float; ny : float; ndx : float; ndy : float; boxes : float array array; children : child array }
type thing = { tx : float; ty : float; tangle : float; kind : int; tflags : int }
type blockmap = { originx : float; originy : float; columns : int; rows : int; cells : int array array }

type t = {
  name : string;
  vertexes : vertex array;
  sectors : sector array;
  sides : side array;
  lines : line array;
  segs : seg array;
  subsectors : subsector array;
  nodes : node array;
  things : thing array;
  blockmap : blockmap;
}


let maps (wad : Wad.t) : string list =
  let n = Array.length wad.lumps in
  List.filter_map
    (fun (k : int) -> if k + 1 < n && wad.lumps.(k + 1).name = "THINGS" then Some wad.lumps.(k).name else None)
    (List.init n (fun (k : int) -> k))

(* [records data size f]: the lump's records of [size] bytes, each by f
 * given the lump and where the record starts *)
let records (data : string) (size : int) (f : string -> int -> 'a) : 'a array = Array.init (String.length data / size) (fun (k : int) -> f data (k * size))

let pi = 4. *. atan 1.

(* a short that is a count or an index (0xffff: none) *)
let ushort (d : string) (o : int) : int = Wad.short d o land 0xffff

let load (wad : Wad.t) (name : string) (texture : string -> int) (flat : string -> int) : t =
  let start = match Wad.index wad name with Some k -> k | None -> failwith ("no map " ^ name ^ " in the WAD") in
  let lump (n : string) : string =
    match List.find_opt (fun (k : int) -> start + k < Array.length wad.lumps && wad.lumps.(start + k).name = n) (List.init 11 (fun (k : int) -> k)) with
    | Some k -> wad.lumps.(start + k).data
    | None -> failwith (name ^ ": no " ^ n) in
  let s = Wad.short and name8 = Wad.name8 in
  let vertexes = records (lump "VERTEXES") 4 (fun (d : string) (o : int) -> { x = float (s d o); y = float (s d (o + 2)) }) in
  let sectors =
    records (lump "SECTORS") 26 (fun (d : string) (o : int) ->
        { index = o / 26; floor = float (s d o); ceiling = float (s d (o + 2)); floorpic = flat (name8 d (o + 4)); ceilingpic = flat (name8 d (o + 12));
          light = s d (o + 20); special = s d (o + 22); tag = s d (o + 24); lines = [] }) in
  let sides =
    records (lump "SIDEDEFS") 30 (fun (d : string) (o : int) ->
        { xoffset = float (s d o); yoffset = float (s d (o + 2)); top = texture (name8 d (o + 4)); bottom = texture (name8 d (o + 12));
          middle = texture (name8 d (o + 20)); sector = s d (o + 28) }) in
  let lines =
    records (lump "LINEDEFS") 14 (fun (d : string) (o : int) ->
        let back = ushort d (o + 12) in
        { v1 = vertexes.(ushort d o); v2 = vertexes.(ushort d (o + 2)); flags = s d (o + 4); special = s d (o + 6); tag = s d (o + 8);
          front = ushort d (o + 10); back = (if back = 0xffff then None else Some back) }) in
  Array.iteri
    (fun (k : int) (l : line) ->
      let add (sd : int) : unit = let sec = sectors.(sides.(sd).sector) in if not (List.mem k sec.lines) then sec.lines <- k :: sec.lines in
      add l.front;
      Option.iter add l.back)
    lines;
  let segs =
    records (lump "SEGS") 12 (fun (d : string) (o : int) ->
        let l = lines.(ushort d (o + 6)) and k = s d (o + 8) in
        let sd = if k = 0 then l.front else match l.back with Some b -> b | None -> l.front in
        let other = if k = 0 then l.back else Some l.front in
        { sv1 = vertexes.(ushort d o); sv2 = vertexes.(ushort d (o + 2));
          angle = float (ushort d (o + 4)) *. 2. *. pi /. 65536.; seg_line = ushort d (o + 6); seg_side = k;
          offset = float (s d (o + 10)); side = sides.(sd); front_sector = sectors.(sides.(sd).sector);
          back_sector =
            (if l.flags land two_sided = 0 then None else Option.map (fun (b : int) -> sectors.(sides.(b).sector)) other) }) in
  let subsectors =
    records (lump "SSECTORS") 4 (fun (d : string) (o : int) ->
        let first = ushort d (o + 2) in
        { first; count = ushort d o; sub_sector = segs.(first).front_sector }) in
  let child (v : int) : child = if v land 0x8000 <> 0 then Subsector (v land 0x7fff) else Node v in
  let nodes =
    records (lump "NODES") 28 (fun (d : string) (o : int) ->
        { nx = float (s d o); ny = float (s d (o + 2)); ndx = float (s d (o + 4)); ndy = float (s d (o + 6));
          boxes = Array.init 2 (fun (b : int) -> Array.init 4 (fun (i : int) -> float (s d (o + 8 + (8 * b) + (2 * i)))));
          children = [| child (ushort d (o + 24)); child (ushort d (o + 26)) |] }) in
  let things =
    records (lump "THINGS") 10 (fun (d : string) (o : int) ->
        { tx = float (s d o); ty = float (s d (o + 2)); tangle = float (s d (o + 4)) *. pi /. 180.; kind = s d (o + 6); tflags = s d (o + 8) }) in
  let blockmap =
    let d = lump "BLOCKMAP" in
    let columns = s d 4 and rows = s d 6 in
    let cell (c : int) : int array =
      let o = 2 * ushort d (8 + (2 * c)) in
      (* (a list starts with a 0, which is no line: id's builder's) *)
      let acc = ref [] and i = ref (o + 2) in
      while !i + 1 < String.length d && ushort d !i <> 0xffff do acc := ushort d !i :: !acc; i := !i + 2 done;
      Array.of_list (List.rev !acc) in
    { originx = float (s d 0); originy = float (s d 2); columns; rows; cells = Array.init (columns * rows) cell } in
  { name; vertexes; sectors; sides; lines; segs; subsectors; nodes; things; blockmap }

let root (level : t) : child = if level.nodes = [||] then Subsector 0 else Node (Array.length level.nodes - 1)

(* the side of (x, y) of the line through (ox, oy) along (dx, dy) *)
let side_of (x : float) (y : float) (ox : float) (oy : float) (dx : float) (dy : float) : int =
  let b (c : bool) : int = if c then 1 else 0 in
  (* (id's: a line along an axis first, where a point on it has a side
   * by the line's direction; else the cross product's sign) *)
  if dx = 0. then (if x <= ox then b (dy > 0.) else b (dy < 0.))
  else if dy = 0. then (if y <= oy then b (dx < 0.) else b (dx > 0.))
  else if (y -. oy) *. dx < dy *. (x -. ox) then 0
  else 1

let point_on_side (x : float) (y : float) (n : node) : int = side_of x y n.nx n.ny n.ndx n.ndy

let point_on_line_side (x : float) (y : float) (l : line) : int = side_of x y l.v1.x l.v1.y (l.v2.x -. l.v1.x) (l.v2.y -. l.v1.y)

let sector_at (level : t) (x : float) (y : float) : sector =
  let rec down (c : child) : sector =
    match c with
    | Subsector k -> level.subsectors.(k).sub_sector
    | Node k -> let n = level.nodes.(k) in down n.children.(point_on_side x y n) in
  down (root level)

let line_sector (level : t) (l : line) (k : int) : sector option =
  if k = 0 then Some level.sectors.(level.sides.(l.front).sector)
  else Option.map (fun (b : int) -> level.sectors.(level.sides.(b).sector)) l.back
