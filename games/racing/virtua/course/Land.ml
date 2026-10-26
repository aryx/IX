(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Land.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "The land" *)

let rgb = Mesh.rgb

type hill = {
  hx : float;
  hz : float;
  radius : float;
  height : float;
  top : float;
}

type palette = {
  low : Mesh.color list;
  mid : Mesh.color list;
  rock : Mesh.color list;
  snow : bool;
}

let green : palette =
  {
    low =
      [
        rgb 78 150 62;
        rgb 70 140 58;
        rgb 88 160 68;
        rgb 96 152 60;
        rgb 66 132 60;
      ];
    mid = [ rgb 50 115 52; rgb 58 124 50; rgb 44 104 50; rgb 70 120 56 ];
    rock =
      [ rgb 130 124 112; rgb 118 112 104; rgb 142 134 118; rgb 110 106 100 ];
    snow = true;
  }

type t = {
  x0 : float;
  z0 : float;
  cell : float;
  nx : int;
  nz : int;
  heights : float array;
  wet : bool array;
  palette : palette;
}

type sample = { sx : float; sz : float; sy : float; lifted : bool }

let inside (poly : (float * float) list) ((x, z) : float * float) : bool =
  let a = Array.of_list poly in
  let n = Array.length a in
  let c = ref false in
  for i = 0 to n - 1 do
    let x1, z1 = a.(i) and x2, z2 = a.((i + 1) mod n) in
    if z1 > z <> (z2 > z) && x < x1 +. ((z -. z1) /. (z2 -. z1) *. (x2 -. x1))
    then c := not !c
  done;
  !c

let smoothstep (a : float) (b : float) (x : float) : float =
  let t = Float.max 0. (Float.min 1. ((x -. a) /. (b -. a))) in
  t *. t *. (3. -. (2. *. t))

let rolling = Heightmap.generate ~seed:7 ~size:32 ~top:1. ~roughness:0.55

let natural (hills : hill list) (x : float) (z : float) : float =
  let bump (h : hill) : float =
    let d = Float.hypot (x -. h.hx) (z -. h.hz) in
    if d <= h.top then h.height
    else if d >= h.radius then 0.
    else
      h.height
      *. (0.5 +. (0.5 *. cos (Float.pi *. (d -. h.top) /. (h.radius -. h.top))))
  in
  let hills =
    List.fold_left (fun (m : float) (h : hill) -> Float.max m (bump h)) 0. hills
  in
  let rx = Float.rem (Float.abs (x /. 50.)) 31.
  and rz = Float.rem (Float.abs (z /. 50.)) 31. in
  hills +. (14. *. Float.max 0. (Heightmap.height rolling rx rz -. 0.2))

(* The road's samples are searched for the nearest one to each point of
 * the grid. *)
let make (samples : sample array) (hills : hill list)
    (sea : (float * float) list list) (palette : palette) (ground : float)
    (verge : float) : t =
  let x0, x1, z0, z1 =
    Array.fold_left
      (fun ((a, b, c, d) : float * float * float * float) (s : sample) ->
        (Float.min a s.sx, Float.max b s.sx, Float.min c s.sz, Float.max d s.sz))
      (infinity, neg_infinity, infinity, neg_infinity)
      samples
  in
  let margin = 600. and cell = 32. in
  let x0 = x0 -. margin and z0 = z0 -. margin in
  let nx = int_of_float ((x1 -. x0 +. margin) /. cell) + 1
  and nz = int_of_float ((z1 -. z0 +. margin) /. cell) + 1 in
  let point (k : int) : float * float =
    ( x0 +. (float_of_int (k mod (nx + 1)) *. cell),
      z0 +. (float_of_int (k / (nx + 1)) *. cell) )
  in
  let wet =
    Array.init
      ((nx + 1) * (nz + 1))
      (fun (k : int) ->
        List.exists (fun (w : (float * float) list) -> inside w (point k)) sea)
  in
  (* OPTIMIZATION (buckets): the samples in squares of [size] m, and a
   * point's nearest searched in rings of squares around its own, until
   * none left can be nearer (before ring r, those left are more than
   * r - 1 squares away); the first of equals, as the whole array's
   * walk: the same sample. Every point against every sample was a
   * sixth of mini-virtuaracing's start on arm.
   * old: Array.iter over the samples, for each point *)
  let size = 64. in
  let bx0, bz0 =
    Array.fold_left
      (fun ((a, b) : float * float) (s : sample) ->
        (Float.min a s.sx, Float.min b s.sz))
      (infinity, infinity) samples
  in
  let col (v : float) (o : float) : int =
    int_of_float (Float.floor ((v -. o) /. size))
  in
  let bnx =
    1
    + Array.fold_left
        (fun (m : int) (s : sample) -> max m (col s.sx bx0))
        0 samples
  and bnz =
    1
    + Array.fold_left
        (fun (m : int) (s : sample) -> max m (col s.sz bz0))
        0 samples
  in
  let buckets = Array.make (bnx * bnz) [] in
  for i = Array.length samples - 1 downto 0 do
    let s = samples.(i) in
    let b = (col s.sz bz0 * bnx) + col s.sx bx0 in
    buckets.(b) <- i :: buckets.(b)
  done;
  let height (k : int) : float =
    let x, z = point k in
    let best = ref infinity and first = ref max_int in
    let ci = col x bx0 and cj = col z bz0 in
    let visit (i : int) (j : int) : unit =
      if i >= 0 && i < bnx && j >= 0 && j < bnz then
        List.iter
          (fun (n : int) ->
            let s = samples.(n) in
            let d = Float.hypot (x -. s.sx) (z -. s.sz) in
            if d < !best || (d = !best && n < !first) then begin
              best := d;
              first := n
            end)
          buckets.((j * bnx) + i)
    in
    let far = max (max ci (bnx - 1 - ci)) (max cj (bnz - 1 - cj)) in
    let r = ref 0 in
    while !r <= far && not (!best < float_of_int (!r - 1) *. size) do
      let r' = !r in
      for i = ci - r' to ci + r' do
        visit i (cj - r');
        if r' > 0 then visit i (cj + r')
      done;
      for j = cj - r' + 1 to cj + r' - 1 do
        visit (ci - r') j;
        visit (ci + r') j
      done;
      incr r
    done;
    let nearest = samples.(!first) in
    let own = if wet.(k) then -8. else natural hills x z in
    if nearest.lifted then own
    else
      let t = smoothstep (verge +. 10.) (verge +. 60.) !best in
      let level = nearest.sy +. ground in
      level +. ((own -. level) *. t)
  in
  let heights =
    Array.init
      ((nx + 1) * (nz + 1))
      (fun (k : int) ->
        (* a hair of noise, so that no two facets of a slope are lit
         * alike *)
        height k
        +. (1.2 *. (Scenery.jitter (k mod (nx + 1)) ((k / (nx + 1)) + 7) -. 0.5)))
  in
  { x0; z0; cell; nx; nz; heights; wet; palette }

let clamp_index (l : t) (i : int) (j : int) : int =
  (max 0 (min l.nz j) * (l.nx + 1)) + max 0 (min l.nx i)

let at (l : t) (i : int) (j : int) : float = l.heights.(clamp_index l i j)

let height (l : t) (x : float) (z : float) : float =
  let fx = (x -. l.x0) /. l.cell and fz = (z -. l.z0) /. l.cell in
  let i = int_of_float (Float.floor fx) and j = int_of_float (Float.floor fz) in
  let u = fx -. Float.floor fx and v = fz -. Float.floor fz in
  let mix (a : float) (b : float) (f : float) : float = a +. ((b -. a) *. f) in
  mix
    (mix (at l i j) (at l (i + 1) j) u)
    (mix (at l i (j + 1)) (at l (i + 1) (j + 1)) u)
    v

let facet_color (l : t) (water : float) (wet : bool) (h : float) (k : int) :
    Mesh.color =
  let pick (colors : Mesh.color list) : Mesh.color =
    List.nth colors (k mod List.length colors)
  in
  if wet && h < water +. 1.5 then
    rgb 200 190 140 (* the beach, and the sand under the sea *)
  else if h < 22. then pick l.palette.low
  else if h < 55. then pick l.palette.mid
  else if h < 95. || not l.palette.snow then pick l.palette.rock
  else if k mod 3 = 0 then rgb 225 228 235
  else rgb 244 244 248

(* a facet's hash, from its cell and which of the two it is *)
let hash (i : int) (j : int) (k : int) : int =
  int_of_float ((Heightmap.random (3 + k) i j +. 1.) *. 5000.)

(* the sea over the wet cells, a quad each, flat (its shore is where the
 * land's facets come out of it) *)
let tiles (l : t) (water : float) (stride : int) :
    ((float * float) * Mesh.shape) list =
  let p (i : int) (j : int) : Vec3.t =
    ( l.x0 +. (float_of_int i *. l.cell),
      at l i j,
      l.z0 +. (float_of_int j *. l.cell) )
  in
  let quad (i : int) (j : int) : Mesh.shape list =
    let i' = i + stride and j' = j + stride in
    let wet =
      List.exists
        (fun ((i, j) : int * int) -> l.wet.(clamp_index l i j))
        [ (i, j); (i', j); (i, j'); (i', j') ]
    in
    let color (k : int) ((_, y1, _) : Vec3.t) ((_, y2, _) : Vec3.t)
        ((_, y3, _) : Vec3.t) : Mesh.color =
      facet_color l water wet ((y1 +. y2 +. y3) /. 3.) (hash i j k)
    in
    let a = p i j and b = p i' j' and c = p i' j and d = p i j' in
    let flat ((x, _, z) : Vec3.t) : Vec3.t = (x, water, z) in
    (* counterclockwise seen from above: faces up *)
    [
      Mesh.polygon3d (color 0 a b c) [ a; b; c ];
      Mesh.polygon3d (color 1 a d b) [ a; d; b ];
    ]
    @
    if wet then
      [ Mesh.polygon3d (rgb 50 110 190) [ flat a; flat d; flat b; flat c ] ]
    else []
  in
  let tile = 8 * stride in
  List.concat
    (List.init
       ((l.nz / tile) + 1)
       (fun (tj : int) ->
         List.filter_map
           (fun (ti : int) ->
             let quads =
               List.concat
                 (List.init 8 (fun (a : int) ->
                      List.concat
                        (List.init 8 (fun (b : int) ->
                             let i = (ti * tile) + (b * stride)
                             and j = (tj * tile) + (a * stride) in
                             if i + stride <= l.nx && j + stride <= l.nz then
                               quad i j
                             else []))))
             in
             if quads = [] then None
             else
               let cx =
                 l.x0
                 +. (float_of_int (ti * tile) +. (float_of_int tile /. 2.))
                    *. l.cell
               and cz =
                 l.z0
                 +. (float_of_int (tj * tile) +. (float_of_int tile /. 2.))
                    *. l.cell
               in
               Some ((cx, cz), Mesh.group3d quads))
           (List.init ((l.nx / tile) + 1) (fun (i : int) -> i))))
