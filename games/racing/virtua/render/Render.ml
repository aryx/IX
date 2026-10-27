(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Render.mli *)

(* the most corners of a face, cut by the near plane *)
let most = 64

(* how the hidden faces are hidden: a depth for each pixel, or the
 * faces drawn far to near (the painter's algorithm, below) *)
type algorithm = Depth | Painter

let algorithm = ref Depth

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
  (* the painter's: the frame's faces kept, [kept] of them; face k's
   * corners on the screen from kfirst.(k) to kfirst.(k + 1) - 1 in
   * kxs, kys, kzs (1/z), its distance and its colour *)
  mutable kept : int;
  mutable kxs : Float.Array.t;
  mutable kys : Float.Array.t;
  mutable kzs : Float.Array.t;
  mutable kfirst : int array;
  mutable kdistance : int array;
  mutable kcolor : Bytes.t;
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
    kept = 0;
    kxs = Float.Array.create 0;
    kys = Float.Array.create 0;
    kzs = Float.Array.create 0;
    kfirst = [| 0 |];
    kdistance = [||];
    kcolor = Bytes.empty;
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
  if !algorithm = Depth then Array.fill r.depth 0 (Array.length r.depth) 0;
  r.kept <- 0;
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

(* OPTIMIZATION (setup): a race's frame is 7,200 faces, most a row or
 * two, a third none (no pixel's center inside): their setup cost four
 * times their pixels (plan_virtuaracing.md, stage 5). The ints' min
 * and max here, which mini-ml inlines (Stdlib's, polymorphic, are
 * calls); the rows found first, and a face with none left before its
 * plane, from the corners at the top and the bottom (int refs: a float
 * ref is a block). old: Stdlib's min and max; the plane, then
 *   let ymin = ref (Float.Array.get r.sy 0)
 *   and ymax = ref (Float.Array.get r.sy 0) in
 *   for k = 1 to n - 1 do
 *     ymin := Float.min !ymin (Float.Array.get r.sy k);
 *     ymax := Float.max !ymax (Float.Array.get r.sy k)
 *   done; *)
let imin (a : int) (b : int) : int = if a < b then a else b
let imax (a : int) (b : int) : int = if a > b then a else b

(* OPTIMIZATION (get): a corner's number, below [most] (face's test), a
 * row's within the screen (fill's y0 and y1), a mesh's corner within
 * its arrays (room): the arrays read and written without their bounds'
 * test, and fill's arrays taken from r once (each Float.Array.get of
 * r.sx was 8 instructions: r's field, the length, the test, the load).
 * old: Float.Array.get r.sx i, Float.Array.set r.lefts y x *)
let get (a : Float.Array.t) (i : int) : float = Float.Array.unsafe_get a i
let set (a : Float.Array.t) (i : int) (x : float) : unit =
  Float.Array.unsafe_set a i x

(* fill's rows y0 to y1 of the n corners *)
let fill_rows (r : t) (n : int) (color : char) (y0 : int) (y1 : int) : unit =
  let sx = r.sx and sy = r.sy and iz = r.iz in
  let lefts = r.lefts and rights = r.rights in
  (* 1/z's plane, a sx + b sy + c, through the corners of the largest
   * triangle of the fan from corner 0 (a corner cut by the near plane
   * may be very near another) *)
  let best = ref 1 and area = ref 0. in
  for i = 1 to n - 2 do
    let d =
      (get sx i -. get sx 0)
      *. (get sy (i + 1) -. get sy 0)
      -. (get sx (i + 1) -. get sx 0)
         *. (get sy i -. get sy 0)
    in
    if Float.abs d > Float.abs !area then begin
      best := i;
      area := d
    end
  done;
  if Float.abs !area > 1e-6 then begin
    let i = !best in
    let dx1 = get sx i -. get sx 0
    and dy1 = get sy i -. get sy 0
    and dz1 = get iz i -. get iz 0 in
    let dx2 = get sx (i + 1) -. get sx 0
    and dy2 = get sy (i + 1) -. get sy 0
    and dz2 = get iz (i + 1) -. get iz 0 in
    let a = ((dz1 *. dy2) -. (dz2 *. dy1)) /. !area in
    let b = ((dx1 *. dz2) -. (dx2 *. dz1)) /. !area in
    let c =
      get iz 0
      -. (a *. get sx 0)
      -. (b *. get sy 0)
    in
    for y = y0 to y1 do
      set lefts y infinity;
      set rights y neg_infinity
    done;
    (* each edge's x on the rows it crosses, taken downwards so that
     * a face's edge and its neighbour's are the same numbers *)
    for k = 0 to n - 1 do
      let j = if k = n - 1 then 0 else k + 1 in
      let top, bottom =
        if get sy k < get sy j then (k, j)
        else (j, k)
      in
      let xa = get sx top and ya = get sy top in
      let xb = get sx bottom
      and yb = get sy bottom in
      if ya < yb then begin
        let slope = (xb -. xa) /. (yb -. ya) in
        for y = imax y0 (first ya) to imin y1 (first yb - 1) do
          let x = xa +. ((float y +. 0.5 -. ya) *. slope) in
          if x < get lefts y then set lefts y x;
          if x > get rights y then set rights y x
        done
      end
    done;
    let step = int_of_float (a *. one) in
    for y = y0 to y1 do
      let x0 = imax 0 (first (get lefts y))
      and x1 = imin (r.width - 1) (first (get rights y) - 1) in
      if x0 <= x1 then begin
        match !algorithm with
        | Depth ->
            let d = (a *. (float x0 +. 0.5)) +. (b *. (float y +. 0.5)) +. c in
            span r y x0 x1 (imax 1 (int_of_float (d *. one))) step color
        | Painter ->
            Bytes.fill r.pixels ((y * r.width) + x0) (x1 - x0 + 1) color
      end
    done
  end

(* the n corners in sx, sy, iz, a convex polygon on the screen *)
let fill (r : t) (n : int) (color : char) : unit =
  let sy = r.sy in
  let top = ref 0 and bottom = ref 0 in
  for k = 1 to n - 1 do
    let y = get sy k in
    if y < get sy !top then top := k;
    if y > get sy !bottom then bottom := k
  done;
  let y0 = imax 0 (first (get sy !top))
  and y1 = imin (r.height - 1) (first (get sy !bottom) - 1) in
  if y0 <= y1 then fill_rows r n color y0 y1

(*****************************************************************************)
(* The painter's algorithm *)
(*****************************************************************************)

(* The faces of a frame kept, then drawn from the farthest to the
 * nearest (finish), each over what is there: no depth for each pixel,
 * none to clear or to test, but a sort; a face's distance is one
 * number, its corners' mean, so two faces that cross, or a long one
 * beside a short one, may be drawn in the wrong order (the road's
 * line under its tarmac). render=painter, to compare (Virtua). *)

let grow_floats (a : Float.Array.t) (n : int) : Float.Array.t =
  if Float.Array.length a >= n then a
  else begin
    let b = Float.Array.make (imax n (2 * Float.Array.length a)) 0. in
    Float.Array.blit a 0 b 0 (Float.Array.length a);
    b
  end

let grow_ints (a : int array) (n : int) : int array =
  if Array.length a >= n then a
  else begin
    let b = Array.make (imax n (2 * Array.length a)) 0 in
    Array.blit a 0 b 0 (Array.length a);
    b
  end

(* the n corners in sx, sy, iz kept, at the mean of their z, in whole
 * centimetres: OCaml on arm64 computes a * b + c in one instruction,
 * mini-ml in two, so a corner's z may be a last bit apart; two faces
 * so near the same distance are a tie, kept in the order they came,
 * by both (and the sort compares ints) *)
let keep (r : t) (n : int) (color : char) : unit =
  let k = r.kept in
  let at = r.kfirst.(k) in
  r.kxs <- grow_floats r.kxs (at + n);
  r.kys <- grow_floats r.kys (at + n);
  r.kzs <- grow_floats r.kzs (at + n);
  r.kfirst <- grow_ints r.kfirst (k + 2);
  r.kdistance <- grow_ints r.kdistance (k + 1);
  if Bytes.length r.kcolor < k + 1 then begin
    let b = Bytes.make (2 * (k + 1)) '\000' in
    Bytes.blit r.kcolor 0 b 0 k;
    r.kcolor <- b
  end;
  let z = ref 0. in
  for i = 0 to n - 1 do
    set r.kxs (at + i) (get r.sx i);
    set r.kys (at + i) (get r.sy i);
    set r.kzs (at + i) (get r.iz i);
    z := !z +. (1. /. get r.iz i)
  done;
  r.kdistance.(k) <- int_of_float (!z /. float n *. 100.);
  Bytes.set r.kcolor k color;
  r.kfirst.(k + 1) <- at + n;
  r.kept <- k + 1

let finish (r : t) : unit =
  if r.kept > 0 then begin
    (* the farthest first; a tie in the order the faces came *)
    let order = Array.init r.kept (fun (k : int) -> k) in
    Array.stable_sort
      (fun (a : int) (b : int) -> r.kdistance.(b) - r.kdistance.(a))
      order;
    Array.iter
      (fun (k : int) ->
        let at = r.kfirst.(k) and n = r.kfirst.(k + 1) - r.kfirst.(k) in
        for i = 0 to n - 1 do
          set r.sx i (get r.kxs (at + i));
          set r.sy i (get r.kys (at + i));
          set r.iz i (get r.kzs (at + i))
        done;
        fill r n (Bytes.get r.kcolor k))
      order;
    r.kept <- 0
  end

(*****************************************************************************)
(* A mesh's faces *)
(*****************************************************************************)

(* corner i of the face cut by the near plane, from corners a and b of
 * the mesh on each side of it *)
let cut (r : t) (i : int) (a : int) (b : int) : unit =
  let f =
    (r.near -. get r.vz a)
    /. (get r.vz b -. get r.vz a)
  in
  set r.cx i
    (get r.vx a
    +. (f *. (get r.vx b -. get r.vx a)));
  set r.cy i
    (get r.vy a
    +. (f *. (get r.vy b -. get r.vy a)));
  set r.cz i r.near

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
    let x = get r.vx i
    and y = get r.vy i
    and z = get r.vz i in
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
      let front = get r.vz i >= r.near
      and front' = get r.vz j >= r.near in
      if front then begin
        set r.cx !m' (get r.vx i);
        set r.cy !m' (get r.vy i);
        set r.cz !m' (get r.vz i);
        incr m'
      end;
      if front <> front' then begin
        cut r !m' i j;
        incr m'
      end
    done;
    for i = 0 to !m' - 1 do
      let iz = 1. /. get r.cz i in
      set r.sx i
        ((float r.width /. 2.) +. (r.focal *. get r.cx i *. iz));
      set r.sy i
        ((float r.height /. 2.) -. (r.focal *. get r.cy i *. iz));
      set r.iz i iz
    done;
    r.drawn <- r.drawn + 1;
    match !algorithm with
    | Depth -> fill r !m' color
    | Painter -> keep r !m' color
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

(* OPTIMIZATION (cull): a face turned away from the eye (ex, ey, ez,
 * in the mesh's own space) not drawn: a solid's far side, hidden by
 * its near one, which the depth would have kept anyway; half the
 * faces of the grid's view (plan_virtuaracing.md, stage 2). Not a face
 * seen from both sides (Mesh.two_sided).
 * old: every face drawn *)
let cull = ref true

let faces (r : t) (m : Mesh.t) (shades : Bytes.t) (ex : float) (ey : float)
    (ez : float) : unit =
  for k = 0 to Mesh.faces m - 1 do
    let i = m.first.(k) in
    if
      (not !cull)
      || Bytes.get m.both k <> '\000'
      || (get m.nxs k *. (ex -. get m.xs i))
         +. (get m.nys k *. (ey -. get m.ys i))
         +. (get m.nzs k *. (ez -. get m.zs i))
         > 0.
    then face r m k (Bytes.get shades k)
  done

let draw (r : t) (m : Mesh.t) : unit =
  if not (outside r (m.cx, m.cy, m.cz) m.radius) then begin
    room r m;
    let ex, ey, ez = r.eye
    and rx, ry, rz = r.right
    and ux, uy, uz = r.up
    and ax, ay, az = r.ahead in
    for i = 0 to Float.Array.length m.xs - 1 do
      let x = get m.xs i -. ex
      and y = get m.ys i -. ey
      and z = get m.zs i -. ez in
      set r.vx i ((x *. rx) +. (y *. ry) +. (z *. rz));
      set r.vy i ((x *. ux) +. (y *. uy) +. (z *. uz));
      set r.vz i ((x *. ax) +. (y *. ay) +. (z *. az))
    done;
    faces r m m.shades ex ey ez
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
      let x0, z0 = turn (get m.xs i) (get m.zs i) in
      let x = x0 +. px -. ex
      and y = get m.ys i +. py -. ey
      and z = z0 +. pz -. ez in
      set r.vx i ((x *. rx) +. (y *. ry) +. (z *. rz));
      set r.vy i ((x *. ux) +. (y *. uy) +. (z *. uz));
      set r.vz i ((x *. ax) +. (y *. ay) +. (z *. az))
    done;
    let n = Mesh.faces m in
    if Bytes.length r.shades < n then r.shades <- Bytes.create n;
    for k = 0 to n - 1 do
      let nx, nz = turn (get m.nxs k) (get m.nzs k) in
      let b = Lighting.brightness_of_normal (nx, get m.nys k, nz) in
      Bytes.set r.shades k (Char.chr (index m.colors.(k) b))
    done;
    (* the eye in the mesh's own space: moved back, turned back *)
    let x = ex -. px and z = ez -. pz in
    faces r m r.shades ((x *. c) -. (z *. s)) (ey -. py) ((x *. s) +. (z *. c))
  end
