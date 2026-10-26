(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mesh.mli *)

type color = int

let rgb (r : int) (g : int) (b : int) : color = (r lsl 16) lor (g lsl 8) lor b

(* the playground's (Color: the Tango palette's) *)
let white = rgb 255 255 255
let black = rgb 0 0 0
let red = rgb 0xcc 0 0
let yellow = rgb 0xed 0xd4 0

let rainbow =
  [
    red;
    rgb 0xf5 0x79 0;
    yellow;
    rgb 0x73 0xd2 0x16;
    rgb 0x34 0x65 0xa4;
    rgb 0x75 0x50 0x7b;
  ]

(*****************************************************************************)
(* Shapes *)
(*****************************************************************************)

type face = { color : color; points : Vec3.t list }
type shape = face list

let polygon3d (color : color) (points : Vec3.t list) : shape =
  if List.length points < 3 then failwith "polygon3d needs at least 3 points";
  [ { color; points } ]

let group3d (shapes : shape list) : shape = List.concat shapes
let is_empty (s : shape) : bool = s = []

(* Playground3d's box_faces: each face counterclockwise seen from
 * outside *)
let box (color : color) (width : float) (height : float) (depth : float) : shape
    =
  let hx = width /. 2. and hy = height /. 2. and hz = depth /. 2. in
  let p000 = (-.hx, -.hy, -.hz)
  and p001 = (-.hx, -.hy, hz)
  and p010 = (-.hx, hy, -.hz)
  and p011 = (-.hx, hy, hz)
  and p100 = (hx, -.hy, -.hz)
  and p101 = (hx, -.hy, hz)
  and p110 = (hx, hy, -.hz)
  and p111 = (hx, hy, hz) in
  List.map
    (fun (points : Vec3.t list) -> { color; points })
    [
      [ p100; p110; p111; p101 ] (* +x *);
      [ p001; p011; p010; p000 ] (* -x *);
      [ p010; p011; p111; p110 ] (* +y *);
      [ p000; p100; p101; p001 ] (* -y *);
      [ p001; p101; p111; p011 ] (* +z *);
      [ p000; p010; p110; p100 ] (* -z *);
    ]

let map_points (f : Vec3.t -> Vec3.t) (s : shape) : shape =
  List.map (fun (fc : face) -> { fc with points = List.map f fc.points }) s

let move3d (dx : float) (dy : float) (dz : float) (s : shape) : shape =
  map_points (fun ((x, y, z) : Vec3.t) -> (x +. dx, y +. dy, z +. dz)) s

let move_x3d (dx : float) (s : shape) : shape = move3d dx 0. 0. s
let move_y3d (dy : float) (s : shape) : shape = move3d 0. dy 0. s
let radians (d : float) : float = d *. Float.pi /. 180.

(* (Playground3d's order: x, then y, then z; an angle of 0 skipped, the
 * points as they are) *)
let rotate3d (ax : float) (ay : float) (az : float) (s : shape) : shape =
  let around (a : float) (f : float -> float -> Vec3.t -> Vec3.t) (s : shape) :
      shape =
    if a = 0. then s
    else
      let r = radians a in
      let c = cos r and sn = sin r in
      map_points (f c sn) s
  in
  s
  |> around ax (fun (c : float) (sn : float) ((x, y, z) : Vec3.t) ->
      (x, (y *. c) -. (z *. sn), (y *. sn) +. (z *. c)))
  |> around ay (fun (c : float) (sn : float) ((x, y, z) : Vec3.t) ->
      ((x *. c) +. (z *. sn), y, (-.x *. sn) +. (z *. c)))
  |> around az (fun (c : float) (sn : float) ((x, y, z) : Vec3.t) ->
      ((x *. c) -. (y *. sn), (x *. sn) +. (y *. c), z))

let scale3d (k : float) (s : shape) : shape = map_points (Vec3.scale k) s

(*****************************************************************************)
(* Meshes *)
(*****************************************************************************)

type t = {
  xs : Float.Array.t;
  ys : Float.Array.t;
  zs : Float.Array.t;
  first : int array;
  colors : color array;
  nxs : Float.Array.t;
  nys : Float.Array.t;
  nzs : Float.Array.t;
  shades : Bytes.t;
  cx : float;
  cy : float;
  cz : float;
  radius : float;
}

let faces (m : t) : int = Array.length m.colors

let make (s : shape) : t =
  let faces = Array.of_list s in
  let n = Array.length faces in
  let first = Array.make (n + 1) 0 in
  Array.iteri
    (fun (k : int) (f : face) ->
      first.(k + 1) <- first.(k) + List.length f.points)
    faces;
  let corners = first.(n) in
  let xs = Float.Array.make corners 0.
  and ys = Float.Array.make corners 0.
  and zs = Float.Array.make corners 0. in
  let nxs = Float.Array.make n 0.
  and nys = Float.Array.make n 0.
  and nzs = Float.Array.make n 0. in
  Array.iteri
    (fun (k : int) (f : face) ->
      List.iteri
        (fun (i : int) ((x, y, z) : Vec3.t) ->
          Float.Array.set xs (first.(k) + i) x;
          Float.Array.set ys (first.(k) + i) y;
          Float.Array.set zs (first.(k) + i) z)
        f.points;
      let nx, ny, nz = Vec3.face_normal f.points in
      Float.Array.set nxs k nx;
      Float.Array.set nys k ny;
      Float.Array.set nzs k nz)
    faces;
  (* the sphere: around the box's middle, as far as the farthest
   * corner (not the smallest sphere, near enough to it) *)
  let lo (a : Float.Array.t) : float =
    Float.Array.fold_left Float.min infinity a
  in
  let hi (a : Float.Array.t) : float =
    Float.Array.fold_left Float.max neg_infinity a
  in
  let cx = (lo xs +. hi xs) /. 2.
  and cy = (lo ys +. hi ys) /. 2.
  and cz = (lo zs +. hi zs) /. 2. in
  let r2 = ref 0. in
  for i = 0 to corners - 1 do
    let dx = Float.Array.get xs i -. cx
    and dy = Float.Array.get ys i -. cy
    and dz = Float.Array.get zs i -. cz in
    r2 := Float.max !r2 ((dx *. dx) +. (dy *. dy) +. (dz *. dz))
  done;
  {
    xs;
    ys;
    zs;
    first;
    colors = Array.map (fun (f : face) -> f.color) faces;
    nxs;
    nys;
    nzs;
    shades = Bytes.make n '\000';
    cx;
    cy;
    cz;
    radius = Float.sqrt !r2;
  }

let light (m : t) (index : color -> float -> int) : unit =
  for k = 0 to faces m - 1 do
    let b =
      Lighting.brightness_of_normal
        ( Float.Array.get m.nxs k,
          Float.Array.get m.nys k,
          Float.Array.get m.nzs k )
    in
    Bytes.set m.shades k (Char.chr (index m.colors.(k) b))
  done
