(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Render.mli *)

(* the most corners of a face, cut by the near plane *)
let most = 64

type t = {
  width : int;
  height : int;
  pixels : Bytes.t;
  (* each pixel's 1/z, times [one]; 0: nothing there *)
  depth : int array;
  (* the eye: where, its right, up and ahead (Camera.basis) *)
  mutable eye : Vec3.t;
  mutable right : Vec3.t;
  mutable up : Vec3.t;
  mutable ahead : Vec3.t;
  (* the focal length in pixels *)
  mutable focal : float;
  mutable near : float;
  mutable far : float;
  (* the view's edges: x / z and y / z at the screen's side and top *)
  mutable side : float;
  mutable top : float;
  (* a mesh's corners seen from the eye *)
  mutable vx : Float.Array.t;
  mutable vy : Float.Array.t;
  mutable vz : Float.Array.t;
  (* a mesh's shades, lit as it is turned ([draw_at]) *)
  mutable shades : Bytes.t;
  (* a face's corners, cut by the near plane (cx, cy, cz), then on the
   * screen (sx, sy, and iz = 1/z) *)
  cx : Float.Array.t;
  cy : Float.Array.t;
  cz : Float.Array.t;
  sx : Float.Array.t;
  sy : Float.Array.t;
  iz : Float.Array.t;
  (* a face's left and right edges on each row *)
  lefts : Float.Array.t;
  rights : Float.Array.t;
  mutable drawn : int;
}

(* 1/z in whole numbers: the near plane's 1/0.1 times this is 6.7e8,
 * within 31 bits *)
let one = 67108864.

let create (width : int) (height : int) : t =
  let corners () : Float.Array.t = Float.Array.make most 0. in
  {
    width;
    height;
    pixels = Bytes.make (width * height) '\000';
    depth = Array.make (width * height) 0;
    eye = (0., 0., 0.);
    right = (1., 0., 0.);
    up = (0., 1., 0.);
    ahead = (0., 0., 1.);
    focal = 1.;
    near = 0.1;
    far = 1000.;
    side = 1.;
    top = 1.;
    vx = Float.Array.create 0;
    vy = Float.Array.create 0;
    vz = Float.Array.create 0;
    shades = Bytes.empty;
    cx = corners ();
    cy = corners ();
    cz = corners ();
    sx = corners ();
    sy = corners ();
    iz = corners ();
    lefts = Float.Array.make height 0.;
    rights = Float.Array.make height 0.;
    drawn = 0;
  }

let width (r : t) : int = r.width
let height (r : t) : int = r.height
let pixels (r : t) : Bytes.t = r.pixels
let faces_drawn (r : t) : int = r.drawn

let frame (r : t) (c : Camera.t) (background : int) : unit =
  let right, up, ahead = Camera.basis ~up:c.up ~eye:c.eye ~target:c.target in
  r.eye <- c.eye;
  r.right <- right;
  r.up <- up;
  r.ahead <- ahead;
  r.focal <- Camera.focal c *. float r.height /. 2.;
  r.near <- c.near;
  r.far <- c.far;
  r.side <- float r.width /. 2. /. r.focal;
  r.top <- float r.height /. 2. /. r.focal;
  Bytes.fill r.pixels 0 (Bytes.length r.pixels) (Char.chr background);
  Array.fill r.depth 0 (Array.length r.depth) 0;
  r.drawn <- 0

(*****************************************************************************)
(* A face's pixels *)
(*****************************************************************************)

(* the column or row of the first pixel whose center is at or past
 * [v] *)
let first (v : float) : int = int_of_float (Float.ceil (v -. 0.5))

(* [span r y x0 x1 d step color]: row y from x0 to x1, the depth d at
 * x0 *)
let span (r : t) (y : int) (x0 : int) (x1 : int) (d : int) (step : int)
    (color : char) : unit =
  let row = y * r.width in
  let d = ref d in
  for i = row + x0 to row + x1 do
    if !d >= Array.unsafe_get r.depth i then begin
      Array.unsafe_set r.depth i !d;
      Bytes.unsafe_set r.pixels i color
    end;
    d := !d + step
  done

(* the n corners in sx, sy, iz, a convex polygon on the screen *)
let fill (r : t) (n : int) (color : char) : unit =
  (* 1/z's plane, a sx + b sy + c, through the corners of the largest
   * triangle of the fan from corner 0 (a corner cut by the near plane
   * may be very near another) *)
  let best = ref 1 and area = ref 0. in
  for i = 1 to n - 2 do
    let d =
      (Float.Array.get r.sx i -. Float.Array.get r.sx 0)
      *. (Float.Array.get r.sy (i + 1) -. Float.Array.get r.sy 0)
      -. (Float.Array.get r.sx (i + 1) -. Float.Array.get r.sx 0)
         *. (Float.Array.get r.sy i -. Float.Array.get r.sy 0)
    in
    if Float.abs d > Float.abs !area then begin
      best := i;
      area := d
    end
  done;
  if Float.abs !area > 1e-6 then begin
    let i = !best in
    let dx1 = Float.Array.get r.sx i -. Float.Array.get r.sx 0
    and dy1 = Float.Array.get r.sy i -. Float.Array.get r.sy 0
    and dz1 = Float.Array.get r.iz i -. Float.Array.get r.iz 0 in
    let dx2 = Float.Array.get r.sx (i + 1) -. Float.Array.get r.sx 0
    and dy2 = Float.Array.get r.sy (i + 1) -. Float.Array.get r.sy 0
    and dz2 = Float.Array.get r.iz (i + 1) -. Float.Array.get r.iz 0 in
    let a = ((dz1 *. dy2) -. (dz2 *. dy1)) /. !area in
    let b = ((dx1 *. dz2) -. (dx2 *. dz1)) /. !area in
    let c =
      Float.Array.get r.iz 0
      -. (a *. Float.Array.get r.sx 0)
      -. (b *. Float.Array.get r.sy 0)
    in
    (* the rows *)
    let ymin = ref (Float.Array.get r.sy 0)
    and ymax = ref (Float.Array.get r.sy 0) in
    for k = 1 to n - 1 do
      ymin := Float.min !ymin (Float.Array.get r.sy k);
      ymax := Float.max !ymax (Float.Array.get r.sy k)
    done;
    let y0 = max 0 (first !ymin)
    and y1 = min (r.height - 1) (first !ymax - 1) in
    if y0 <= y1 then begin
      for y = y0 to y1 do
        Float.Array.set r.lefts y infinity;
        Float.Array.set r.rights y neg_infinity
      done;
      (* each edge's x on the rows it crosses, taken downwards so that
       * a face's edge and its neighbour's are the same numbers *)
      for k = 0 to n - 1 do
        let j = if k = n - 1 then 0 else k + 1 in
        let top, bottom =
          if Float.Array.get r.sy k < Float.Array.get r.sy j then (k, j)
          else (j, k)
        in
        let xa = Float.Array.get r.sx top and ya = Float.Array.get r.sy top in
        let xb = Float.Array.get r.sx bottom
        and yb = Float.Array.get r.sy bottom in
        if ya < yb then begin
          let slope = (xb -. xa) /. (yb -. ya) in
          for y = max y0 (first ya) to min y1 (first yb - 1) do
            let x = xa +. ((float y +. 0.5 -. ya) *. slope) in
            if x < Float.Array.get r.lefts y then Float.Array.set r.lefts y x;
            if x > Float.Array.get r.rights y then Float.Array.set r.rights y x
          done
        end
      done;
      let step = int_of_float (a *. one) in
      for y = y0 to y1 do
        let x0 = max 0 (first (Float.Array.get r.lefts y))
        and x1 = min (r.width - 1) (first (Float.Array.get r.rights y) - 1) in
        if x0 <= x1 then begin
          let d = (a *. (float x0 +. 0.5)) +. (b *. (float y +. 0.5)) +. c in
          span r y x0 x1 (max 1 (int_of_float (d *. one))) step color
        end
      done
    end
  end

(*****************************************************************************)
(* A mesh's faces *)
(*****************************************************************************)

(* corner i of the face cut by the near plane, from corners a and b of
 * the mesh on each side of it *)
let cut (r : t) (i : int) (a : int) (b : int) : unit =
  let f =
    (r.near -. Float.Array.get r.vz a)
    /. (Float.Array.get r.vz b -. Float.Array.get r.vz a)
  in
  Float.Array.set r.cx i
    (Float.Array.get r.vx a
    +. (f *. (Float.Array.get r.vx b -. Float.Array.get r.vx a)));
  Float.Array.set r.cy i
    (Float.Array.get r.vy a
    +. (f *. (Float.Array.get r.vy b -. Float.Array.get r.vy a)));
  Float.Array.set r.cz i r.near

(* face k of m, its corners in vx, vy, vz *)
let face (r : t) (m : Mesh.t) (k : int) (color : char) : unit =
  let f0 = m.first.(k) and f1 = m.first.(k + 1) in
  let behind = ref 0
  and beyond = ref false
  and left = ref true
  and right = ref true
  and above = ref true
  and below = ref true in
  for i = f0 to f1 - 1 do
    let x = Float.Array.get r.vx i
    and y = Float.Array.get r.vy i
    and z = Float.Array.get r.vz i in
    if z < r.near then incr behind;
    if z >= r.far then beyond := true;
    if x >= -.r.side *. z then left := false;
    if x <= r.side *. z then right := false;
    if y <= r.top *. z then above := false;
    if y >= -.r.top *. z then below := false
  done;
  let n = f1 - f0 in
  if
    !behind < n && (not !beyond)
    && n < most / 2
    && not (!left || !right || !above || !below)
  then begin
    (* the corners in front of the near plane, and where an edge
     * crosses it *)
    let m' = ref 0 in
    for i = f0 to f1 - 1 do
      let j = if i = f1 - 1 then f0 else i + 1 in
      let front = Float.Array.get r.vz i >= r.near
      and front' = Float.Array.get r.vz j >= r.near in
      if front then begin
        Float.Array.set r.cx !m' (Float.Array.get r.vx i);
        Float.Array.set r.cy !m' (Float.Array.get r.vy i);
        Float.Array.set r.cz !m' (Float.Array.get r.vz i);
        incr m'
      end;
      if front <> front' then begin
        cut r !m' i j;
        incr m'
      end
    done;
    for i = 0 to !m' - 1 do
      let iz = 1. /. Float.Array.get r.cz i in
      Float.Array.set r.sx i
        ((float r.width /. 2.) +. (r.focal *. Float.Array.get r.cx i *. iz));
      Float.Array.set r.sy i
        ((float r.height /. 2.) -. (r.focal *. Float.Array.get r.cy i *. iz));
      Float.Array.set r.iz i iz
    done;
    r.drawn <- r.drawn + 1;
    fill r !m' color
  end

(* the sphere (x, y, z) of radius rad, seen from the eye, outside the
 * view *)
let outside (r : t) ((x, y, z) : Vec3.t) (rad : float) : bool =
  let v = Vec3.sub (x, y, z) r.eye in
  let x = Vec3.dot v r.right
  and y = Vec3.dot v r.up
  and z = Vec3.dot v r.ahead in
  (* the distance to a side plane x = side z is (x - side z) /
   * sqrt (1 + side^2) *)
  let ks = Float.sqrt (1. +. (r.side *. r.side))
  and kt = Float.sqrt (1. +. (r.top *. r.top)) in
  z +. rad < r.near
  || z -. rad > r.far
  || x -. (r.side *. z) > rad *. ks
  || -.x -. (r.side *. z) > rad *. ks
  || y -. (r.top *. z) > rad *. kt
  || -.y -. (r.top *. z) > rad *. kt

let room (r : t) (m : Mesh.t) : unit =
  let n = Float.Array.length m.xs in
  if Float.Array.length r.vx < n then begin
    r.vx <- Float.Array.make n 0.;
    r.vy <- Float.Array.make n 0.;
    r.vz <- Float.Array.make n 0.
  end

let faces (r : t) (m : Mesh.t) (shades : Bytes.t) : unit =
  for k = 0 to Mesh.faces m - 1 do
    face r m k (Bytes.get shades k)
  done

let draw (r : t) (m : Mesh.t) : unit =
  if not (outside r (m.cx, m.cy, m.cz) m.radius) then begin
    room r m;
    let ex, ey, ez = r.eye
    and rx, ry, rz = r.right
    and ux, uy, uz = r.up
    and ax, ay, az = r.ahead in
    for i = 0 to Float.Array.length m.xs - 1 do
      let x = Float.Array.get m.xs i -. ex
      and y = Float.Array.get m.ys i -. ey
      and z = Float.Array.get m.zs i -. ez in
      Float.Array.set r.vx i ((x *. rx) +. (y *. ry) +. (z *. rz));
      Float.Array.set r.vy i ((x *. ux) +. (y *. uy) +. (z *. uz));
      Float.Array.set r.vz i ((x *. ax) +. (y *. ay) +. (z *. az))
    done;
    faces r m m.shades
  end

let draw_at (r : t) (m : Mesh.t) (angle : float) ((px, py, pz) : Vec3.t)
    (index : Mesh.color -> float -> int) : unit =
  let a = angle *. Float.pi /. 180. in
  let c = cos a and s = sin a in
  (* Mesh.rotate3d's turn about y *)
  let turn (x : float) (z : float) : float * float =
    ((x *. c) +. (z *. s), (-.x *. s) +. (z *. c))
  in
  let mx, mz = turn m.cx m.cz in
  if not (outside r (mx +. px, m.cy +. py, mz +. pz) m.radius) then begin
    room r m;
    let ex, ey, ez = r.eye
    and rx, ry, rz = r.right
    and ux, uy, uz = r.up
    and ax, ay, az = r.ahead in
    for i = 0 to Float.Array.length m.xs - 1 do
      let x0, z0 = turn (Float.Array.get m.xs i) (Float.Array.get m.zs i) in
      let x = x0 +. px -. ex
      and y = Float.Array.get m.ys i +. py -. ey
      and z = z0 +. pz -. ez in
      Float.Array.set r.vx i ((x *. rx) +. (y *. ry) +. (z *. rz));
      Float.Array.set r.vy i ((x *. ux) +. (y *. uy) +. (z *. uz));
      Float.Array.set r.vz i ((x *. ax) +. (y *. ay) +. (z *. az))
    done;
    let n = Mesh.faces m in
    if Bytes.length r.shades < n then r.shades <- Bytes.create n;
    for k = 0 to n - 1 do
      let nx, nz = turn (Float.Array.get m.nxs k) (Float.Array.get m.nzs k) in
      let b = Lighting.brightness_of_normal (nx, Float.Array.get m.nys k, nz) in
      Bytes.set r.shades k (Char.chr (index m.colors.(k) b))
    done;
    faces r m r.shades
  end
