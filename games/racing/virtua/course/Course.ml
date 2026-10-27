(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Course.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "The courses", "The road, cut in chunks", and the sky of its
 * "View" *)

let rgb = Mesh.rgb
let polygon3d = Mesh.polygon3d
let rotate3d = Mesh.rotate3d
let move3d = Mesh.move3d
let box = Mesh.box
let road_width = 6. (* half of it *)

(* The land next to the road is this far below it, the road standing on
 * the sides of its embankment ([segment]): an eye above a road only
 * 0.1 over the land sees the land win the depth test near the bottom
 * of the screen, where a quad of land straddles the eye *)
let ground = -1.5
let verge = 2.5 *. road_width (* the grass along it, up to the rail *)
let water_level = ground +. 0.2
let rumble_length = 3
let chunk_size = 40
let map_unit = 40.

let angle_diff (a : float) (b : float) : float =
  Float.rem (Float.rem (b -. a +. 180.) 360. +. 360.) 360. -. 180.

(* a turn of [period] seconds, in degrees, at [time] (Playground.spin) *)
let spin (period : float) (time : float) : float =
  360. *. Float.rem time period /. period

(* A circuit through points (x, y on the map, height in metres), each
 * corner leaning into itself: the bank is read from how much the
 * course turns at each point, so a course is written as where the road
 * goes and nothing else. *)
let circuit (points : (float * float * float) list) : Track3d.t =
  let a =
    Array.of_list
      (List.map
         (fun ((x, y, h) : float * float * float) ->
           (x *. map_unit, y *. map_unit, h))
         points)
  in
  let n = Array.length a in
  let heading (i : int) (j : int) : float =
    let x1, z1, _ = a.(i mod n) and x2, z2, _ = a.(j mod n) in
    atan2 (x2 -. x1) (-.(z2 -. z1)) *. 180. /. Float.pi
  in
  Track3d.build 2.
    (List.init n (fun (i : int) ->
         let turn = angle_diff (heading (i + n - 1) i) (heading i (i + 1)) in
         let x, z, y = a.(i) in
         Track3d.control ~y ~width:road_width
           ~bank:(Float.max (-10.) (Float.min 10. (-.turn *. 0.2)))
           x z))

(* how much the road turns at segment [i], in degrees per segment,
 * averaged over a few (the resampled spline wobbles by a hair from one
 * sample to the next) *)
let turn_at (ribbon : Track3d.t) (i : int) : float =
  let at (k : int) : Track3d.place =
    Track3d.at ribbon (float_of_int k *. Track3d.step ribbon)
  in
  angle_diff (at (i - 3)).heading (at (i + 4)).heading /. 7.

(* the road's box, x0 x1 z0 z1 (bounds) *)
let box_of (ribbon : Track3d.t) : float * float * float * float =
  let n = Track3d.segments ribbon in
  List.fold_left
    (fun ((x0, x1, z0, z1) : float * float * float * float) (k : int) ->
      let p = Track3d.at ribbon (float_of_int k *. Track3d.step ribbon) in
      ( Float.min x0 p.px,
        Float.max x1 p.px,
        Float.min z0 p.pz,
        Float.max z1 p.pz ))
    (infinity, neg_infinity, infinity, neg_infinity)
    (List.init n (fun (k : int) -> k))

(* Stretches of road that are more than a road: a suspension bridge, an
 * overpass (the road crossing over itself), a tunnel, and the grey
 * concrete walls that stand instead of the rails in places. *)
type span_kind = Suspension | Overpass | Tunnel | Wall
type span = { kind : span_kind; s0 : float; s1 : float }

let in_span (spans : span list) (kinds : span_kind list) (s : float) :
    span option =
  List.find_opt
    (fun (sp : span) -> List.mem sp.kind kinds && s >= sp.s0 && s <= sp.s1)
    spans

(* the road off the land: the land under it is left as it is *)
let lifted = [ Suspension; Overpass; Tunnel ]

type piece = { mesh : Mesh.t; far : Mesh.t; mx : float; mz : float }

type t = {
  name : string;
  level : string;
  ribbon : Track3d.t;
  laps : int;
  checkpoints : int;
  start_time : int;
  bonus : int;
  rivals : int;
  spans : span list;
  terrain : Land.t;
  grass : Mesh.color * Mesh.color;
  chunks : piece array;
  tiles : piece array;
  landmarks : Mesh.t list;
  landscape : Mesh.shape list;
  animated : float -> Mesh.shape list;
  box : float * float * float * float;
  turns : Float.Array.t;
}

(*****************************************************************************)
(* Placing things *)
(*****************************************************************************)

(* what the scenery of a course is placed from: the road, its spans,
 * the land, and where nothing stands (the sea) *)
type site = {
  ribbon : Track3d.t;
  spans : span list;
  terrain : Land.t;
  taken : float * float -> bool;
  (* the scenery for a far chunk (road_near): its simpler trees; the
   * trees' places, found once for the two ([trees]); whether a tree
   * has a far kind of its own (else the far chunk is the near one) *)
  far : bool;
  places : (int * int, (int * float * float * float) list) Hashtbl.t;
  far_kinds : bool ref;
}

let place (ribbon : Track3d.t) (s : float) (offset : float) (shape : Mesh.shape)
    : Mesh.shape =
  let x, y, z = Track3d.across ribbon s offset in
  let p = Track3d.at ribbon s in
  shape |> rotate3d 0. (-.p.heading) 0. |> move3d x y z

(* [on_land site x y shape]: standing on the land at (x, y) on the map,
 * a little sunk (the land between the corners of a cell is not quite
 * flat) *)
let on_land (site : site) (x : float) (y : float) (shape : Mesh.shape) :
    Mesh.shape =
  let x = x *. map_unit and z = y *. map_unit in
  shape |> move3d x (Land.height site.terrain x z -. 0.4) z

(* [trees (kind, far) every rows site i]: a tree each side of segment
 * [i], beyond the rail, every [every] segments: on the land, clear of
 * the road (of *another* part of it too, since a circuit comes back
 * near itself), not in the sea, not on the rock; [far]'s for a far
 * chunk. Its places found once, for the near chunk and the far one
 * (a Track3d.locate each: the course's start 45% longer when found
 * twice) *)
let trees ((near, far) : (int -> Mesh.shape) * (int -> Mesh.shape))
    (every : int) (rows : int) (site : site) (i : int) : Mesh.shape list =
  if near != far then site.far_kinds := true;
  let kind = if site.far then far else near in
  if i mod every <> 0 then []
  else
    let found () : (int * float * float * float) list =
      let s = float_of_int i *. Track3d.step site.ribbon in
      let _, road_y, _ = Track3d.across site.ribbon s 0. in
      List.concat_map
        (fun (row : int) ->
          List.filter_map
            (fun (side : float) ->
              let off =
                side
                *. (verge +. 4.
                   +. (float_of_int row *. 9.)
                   +. (5. *. Scenery.jitter i (row + int_of_float side)))
              in
              let x, _, z = Track3d.across site.ribbon s off in
              let _, nearest = Track3d.locate site.ribbon x z in
              let h = Land.height site.terrain x z in
              if
                Float.abs nearest >= verge +. 2.
                && (not (site.taken (x, z)))
                && h < road_y +. 30.
              then Some (i + row, x, h -. 0.4, z)
              else None)
            [ -1.; 1. ])
        (List.init rows (fun (r : int) -> r))
    in
    let places =
      match Hashtbl.find_opt site.places (i, every) with
      | Some l -> l
      | None ->
          let l = found () in
          Hashtbl.replace site.places (i, every) l;
          l
    in
    List.map
      (fun ((k, x, y, z) : int * float * float * float) ->
        kind k |> move3d x y z)
      places

(* signs every 150 segments, chevrons outside the sharp curves *)
let signs (site : site) (i : int) : Mesh.shape list =
  let s = float_of_int i *. Track3d.step site.ribbon in
  let turn = turn_at site.ribbon i in
  if in_span site.spans [ Suspension; Overpass; Tunnel ] s <> None then []
  else if i mod 150 = 75 then
    [ place site.ribbon s (1.3 *. road_width) Scenery.sign ]
  else if Float.abs turn > 1.8 && i mod 5 = 0 then
    [
      place site.ribbon s
        ((if turn > 0. then -1.4 else 1.4) *. road_width)
        Scenery.chevron;
    ]
  else []

(* the start, on a circuit: the line chequered, the gantry over it,
 * the grandstand on the left, over the rail, and the checkpoints'
 * gantries round the lap *)
let start (ribbon : Track3d.t) (checkpoints : int) : Mesh.shape list =
  let w = road_width in
  let chequer =
    List.concat
      (List.init 2 (fun (row : int) ->
           List.init 8 (fun (k : int) ->
               let a = -.w +. (float_of_int k *. w /. 4.) in
               Track3d.strip ribbon
                 (if (k + row) mod 2 = 0 then Mesh.white else Mesh.black)
                 row a
                 (a +. (w /. 4.)))))
  in
  [
    Mesh.group3d chequer;
    place ribbon 0. 0. (Scenery.gantry (rgb 30 60 200) w);
    place ribbon 30. (-.verge -. 1.) (Scenery.grandstand ground);
  ]
  @ List.init (checkpoints - 1) (fun (k : int) ->
      place ribbon
        (float_of_int (k + 1)
        *. Track3d.length ribbon /. float_of_int checkpoints)
        0.
        (Scenery.gantry (rgb 240 200 30) w))

(* The suspension bridge, along the ribbon from [s0] to [s1]: two
 * towers standing in the sea, the two main cables hanging between
 * them (a parabola, the shape a cable takes under an evenly spread
 * deck) and running down to the ends, a hanger every few metres from
 * cable to deck. The deck itself is in the road's chunks ([segment]).
 * Its hundreds of polygons are what made Model 1 famous. The cables
 * and the hangers one face thick: seen from both sides. *)
let bridge (ribbon : Track3d.t) (s0 : float) (s1 : float) : Mesh.shape list =
  let w = road_width in
  let side_off = 1.55 *. w in
  let len = s1 -. s0 in
  let t1 = s0 +. (0.22 *. len) and t2 = s1 -. (0.22 *. len) in
  let top = 26. and bed = -8. in
  let deck (s : float) (side : float) : float =
    let _, y, _ = Track3d.across ribbon s (side *. side_off) in
    y
  in
  let cable (s : float) (side : float) : float =
    let d = deck s side in
    if s < t1 then d +. 1.5 +. ((top -. 1.5) *. (s -. s0) /. (t1 -. s0))
    else if s > t2 then d +. 1.5 +. ((top -. 1.5) *. (s1 -. s) /. (s1 -. t2))
    else
      let u = (2. *. (s -. t1) /. (t2 -. t1)) -. 1. in
      d +. 2. +. ((top -. 2.) *. u *. u)
  in
  let red = rgb 235 85 55 and steel = rgb 190 60 40 in
  let tower (s : float) : Mesh.shape =
    let _, y, _ = Track3d.across ribbon s 0. in
    let h = y -. bed +. top +. 1. in
    let leg (side : float) : Mesh.shape =
      box red 1.6 h 1.6 |> move3d (side *. side_off) (h /. 2.) 0.
    in
    let beam (y : float) : Mesh.shape =
      box red ((2. *. side_off) +. 1.6) 1.2 1.2 |> Mesh.move_y3d y
    in
    let at = Track3d.at ribbon s in
    Mesh.group3d
      [
        leg (-1.);
        leg 1.;
        beam (h -. 0.6);
        beam (y -. bed +. (top *. 0.55));
        beam (y -. bed -. 1.8);
      ]
    |> rotate3d 0. (-.at.heading) 0.
    |> move3d at.px bed at.pz
  in
  let ds = 2. in
  let pieces = int_of_float (len /. ds) in
  let cables =
    List.concat_map
      (fun (side : float) ->
        List.init pieces (fun (k : int) ->
            let sa = s0 +. (float_of_int k *. ds)
            and sb = s0 +. (float_of_int (k + 1) *. ds) in
            let xa, _, za = Track3d.across ribbon sa (side *. side_off)
            and xb, _, zb = Track3d.across ribbon sb (side *. side_off) in
            let ya = cable sa side and yb = cable sb side in
            Mesh.two_sided
              (polygon3d steel
                 [
                   (xa, ya, za);
                   (xb, yb, zb);
                   (xb, yb +. 0.5, zb);
                   (xa, ya +. 0.5, za);
                 ])))
      [ -1.; 1. ]
  in
  let hangers =
    List.concat_map
      (fun (side : float) ->
        List.init (pieces / 2) (fun (k : int) ->
            let s = s0 +. (float_of_int (2 * k) *. ds) in
            let x, y, z = Track3d.across ribbon s (side *. side_off)
            and fx, fz = Track3d.forward ribbon s in
            let yc = cable s side in
            Mesh.two_sided
              (polygon3d (rgb 220 220 220)
                 [
                   (x, y, z);
                   (x +. (fx *. 0.25), y, z +. (fz *. 0.25));
                   (x +. (fx *. 0.25), yc, z +. (fz *. 0.25));
                   (x, yc, z);
                 ])))
      [ -1.; 1. ]
  in
  [ tower t1; tower t2 ] @ cables @ hangers

(* piers under a raised road, every 30 m, down to [bed] *)
let piers (ribbon : Track3d.t) (bed : float) (s0 : float) (s1 : float) :
    Mesh.shape list =
  List.init
    (int_of_float ((s1 -. s0) /. 30.) + 1)
    (fun (k : int) ->
      let s = s0 +. (float_of_int k *. 30.) in
      let at = Track3d.at ribbon s in
      let h = at.py -. 1.8 -. bed in
      box (rgb 170 170 165) (2.6 *. road_width) h 2.5
      |> Mesh.move_y3d (bed +. (h /. 2.))
      |> rotate3d 0. (-.at.heading) 0.
      |> move3d at.px 0. at.pz)

(* the mouths of a tunnel: a concrete face around the road at each end *)
let portals (ribbon : Track3d.t) (s0 : float) (s1 : float) : Mesh.shape list =
  let concrete = rgb 150 150 145 in
  let face =
    Mesh.group3d
      [
        box concrete (2. *. verge) 4. 1.5 |> Mesh.move_y3d 8.;
        box concrete 4. 8. 1.5 |> move3d (-.verge +. 2.) 4. 0.;
        box concrete 4. 8. 1.5 |> move3d (verge -. 2.) 4. 0.;
      ]
  in
  [ place ribbon s0 0. face; place ribbon s1 0. face ]

(*****************************************************************************)
(* The road, cut in chunks *)
(*****************************************************************************)

(* A segment of road: the kerbs and the tarmac; then, on land, the
 * grass verges, the rail at their edge (red and white, what the car
 * bounces off) and the sides of the embankment down to the land; grey
 * concrete walls instead of the rails where the course has them; on a
 * bridge or an overpass, the deck's edges, its rails and the girders
 * under it; in a tunnel, its walls and its roof. *)
let segment (ribbon : Track3d.t) (spans : span list)
    (grass2 : Mesh.color * Mesh.color) (i : int) : Mesh.shape list =
  let strip = Track3d.strip ribbon and wall = Track3d.wall ribbon in
  let light = i / rumble_length mod 2 = 0 in
  let rumble = if light then rgb 240 240 240 else rgb 200 40 40 in
  let tarmac = if light then rgb 110 110 110 else rgb 100 100 100 in
  let w = road_width in
  let road =
    [
      strip rumble i (-1.15 *. w) (-.w);
      strip tarmac i (-.w) w;
      strip rumble i w (1.15 *. w);
    ]
    @ if light then [ strip Mesh.white i (-0.03 *. w) (0.03 *. w) ] else []
  in
  let light_grass, dark_grass = grass2 in
  let grass = if light then light_grass else dark_grass in
  let s = float_of_int i *. Track3d.step ribbon in
  match in_span spans [ Suspension; Overpass; Tunnel; Wall ] s with
  | Some { kind = Suspension | Overpass; _ } ->
      road
      @ [
          strip (rgb 150 150 150) i (-.verge) (-1.15 *. w);
          strip (rgb 150 150 150) i (1.15 *. w) verge;
          wall (rgb 230 230 230) i (-.verge) 1.;
          wall (rgb 230 230 230) i verge 1.;
          wall (rgb 180 70 40) i (-.verge) (-1.8);
          wall (rgb 180 70 40) i verge (-1.8);
        ]
  | Some { kind = Tunnel; _ } ->
      (* the roof: the ribbon's quad lifted 8 metres, facing down *)
      let up ((x, y, z) : Vec3.t) : Vec3.t = (x, y +. 8., z) in
      let near (o : float) : Vec3.t = up (Track3d.across ribbon s o)
      and far (o : float) : Vec3.t =
        up (Track3d.across ribbon (s +. Track3d.step ribbon) o)
      in
      road
      @ [
          strip (rgb 90 90 90) i (-.verge) (-1.15 *. w);
          strip (rgb 90 90 90) i (1.15 *. w) verge;
          wall (rgb 120 120 115) i (-.verge) 8.;
          wall (rgb 120 120 115) i verge 8.;
          polygon3d (rgb 80 80 80)
            [ near verge; near (-.verge); far (-.verge); far verge ];
        ]
  | Some { kind = Wall; _ } ->
      road
      @ [
          strip grass i (-.verge) (-1.15 *. w);
          strip grass i (1.15 *. w) verge;
          wall (rgb 175 175 170) i (-.verge) 2.5;
          wall (rgb 175 175 170) i verge 2.5;
          wall dark_grass i (-.verge) (-3.);
          wall dark_grass i verge (-3.);
        ]
  | None ->
      let rail = if i / 2 mod 2 = 0 then rgb 230 230 230 else rgb 210 50 40 in
      road
      @ [
          strip grass i (-.verge) (-1.15 *. w);
          strip grass i (1.15 *. w) verge;
          wall rail i (-.verge) 0.8;
          wall rail i verge 0.8;
          wall dark_grass i (-.verge) (-3.);
          wall dark_grass i verge (-3.);
        ]

(*****************************************************************************)
(* A course *)
(*****************************************************************************)

(* a hill at (x, y) on the map, [radius] and [top] (the radius of a flat
 * top, a plateau) in squares, [height] in metres *)
let hill (top : float) (x : float) (y : float) (radius : float) (height : float)
    : Land.hill =
  {
    hx = x *. map_unit;
    hz = y *. map_unit;
    radius = radius *. map_unit;
    height;
    top = top *. map_unit;
  }

(* what a course is written as *)
type description = {
  d_name : string;
  d_level : string;
  points : (float * float * float) list;
  d_laps : int;
  d_checkpoints : int;
  d_start_time : int;
  d_bonus : int;
  d_rivals : int;
  (* its spans, two points on the map each, where they start and end *)
  d_spans : (span_kind * (float * float) * (float * float)) list;
  palette : Land.palette;
  d_grass : Mesh.color * Mesh.color;
  hills : Land.hill list;
  sea : (float * float) list list;
  scenery : site -> int -> Mesh.shape list; (* along segment i *)
  landscape : site -> Mesh.shape list; (* the landmarks *)
  moving : site -> float -> Mesh.shape list;
}

let make (d : description) : t =
  let ribbon = circuit d.points in
  let spans =
    List.map
      (fun ((kind, (x0, y0), (x1, y1)) :
             span_kind * (float * float) * (float * float)) ->
        let s0, _ = Track3d.locate ribbon (x0 *. map_unit) (y0 *. map_unit)
        and s1, _ = Track3d.locate ribbon (x1 *. map_unit) (y1 *. map_unit) in
        { kind; s0; s1 })
      d.d_spans
  in
  let sea =
    List.map
      (List.map (fun ((x, y) : float * float) -> (x *. map_unit, y *. map_unit)))
      d.sea
  in
  (* the road's samples, every 4 m *)
  let step = Track3d.step ribbon in
  let samples =
    Array.init
      (Track3d.segments ribbon / 2)
      (fun (k : int) ->
        let s = float_of_int (2 * k) *. step in
        let p = Track3d.at ribbon s in
        {
          Land.sx = p.px;
          sz = p.pz;
          sy = p.py;
          lifted = in_span spans lifted s <> None;
        })
  in
  let terrain = Land.make samples d.hills sea d.palette ground verge in
  let site =
    {
      ribbon;
      spans;
      terrain;
      taken =
        (fun (p : float * float) ->
          List.exists (fun (w : (float * float) list) -> Land.inside w p) sea);
      far = false;
      places = Hashtbl.create 1024;
      far_kinds = ref false;
    }
  in
  let far_site = { site with far = true } in
  let segments = Track3d.segments ribbon in
  let chunks =
    Array.init
      ((segments + chunk_size - 1) / chunk_size)
      (fun (k : int) ->
        let first = k * chunk_size in
        let last = min segments (first + chunk_size) - 1 in
        let mid =
          Track3d.at ribbon (float_of_int ((first + last) / 2) *. step)
        in
        let shapes (site : site) : Mesh.shape list =
          List.concat
            (List.init
               (last - first + 1)
               (fun (j : int) ->
                 segment ribbon spans d.d_grass (first + j)
                 @ d.scenery site (first + j)))
        in
        let mesh = Mesh.make (Mesh.group3d (shapes site)) in
        let far =
          if !(site.far_kinds) then Mesh.make (Mesh.group3d (shapes far_site))
          else mesh
        in
        { mesh; far; mx = mid.px; mz = mid.pz })
  in
  (* (the places no more needed: site is kept, by the landscape's
   * closures) *)
  Hashtbl.reset site.places;
  let tiles =
    Array.of_list
      (List.map
         (fun (((x, z), shape) : (float * float) * Mesh.shape) ->
           let mesh = Mesh.make shape in
           { mesh; far = mesh; mx = x; mz = z })
         (Land.tiles terrain water_level 1))
  in
  {
    name = d.d_name;
    level = d.d_level;
    ribbon;
    laps = d.d_laps;
    checkpoints = d.d_checkpoints;
    start_time = d.d_start_time;
    bonus = d.d_bonus;
    rivals = d.d_rivals;
    spans;
    terrain;
    grass = d.d_grass;
    chunks;
    tiles;
    landmarks = List.map Mesh.make (d.landscape site);
    landscape = d.landscape site;
    animated = d.moving site;
    box = box_of ribbon;
    turns = Float.Array.make (Track3d.segments ribbon + 64) nan;
  }

(* Big Forest, the beginner's: a long pit straight up the diagonal, the
 * right-handers round the top, back along the middle, the U hanging
 * at the bottom, and the hard right by the grey wall and the amusement
 * park -- Ferris wheel, roller coaster -- onto the straight again.
 * Nearly flat, in a forest, mountains all round. *)
let big_forest () : t =
  make
    {
      d_name = "BIG FOREST";
      d_level = "BEGINNER";
      points =
        [
          (6., 12.3, 0.);
          (10., 9.3, 0.);
          (14., 6.6, 1.);
          (17., 4.7, 2.);
          (19.5, 3., 3.);
          (21.2, 3.2, 4.);
          (24., 5., 5.);
          (25.8, 6.5, 5.);
          (25., 8.8, 4.);
          (23.5, 10., 3.);
          (20., 10.6, 2.);
          (17.8, 11.2, 2.);
          (16.5, 13., 3.);
          (16.2, 16., 4.);
          (15., 17.8, 3.);
          (12.5, 18., 2.);
          (11., 16.5, 2.);
          (10.8, 14.2, 1.);
          (9.8, 12.8, 1.);
          (8., 13., 0.);
          (6.2, 14.8, 0.);
          (4.2, 16.4, 0.);
          (2.7, 16.1, 0.);
          (2.4, 14.8, 0.);
          (3.6, 13.7, 0.);
        ];
      d_laps = 5;
      d_checkpoints = 2;
      d_start_time = 45;
      d_bonus = 24;
      d_rivals = 15;
      d_spans = [ (Wall, (4.8, 16.), (2.5, 14.3)) ];
      palette = Land.green;
      d_grass = (rgb 70 160 60, rgb 60 140 50);
      hills =
        [
          hill 0. 6. 4. 5. 40.;
          hill 0. 20. 15. 2.5 18.;
          hill 0. (-8.) 8. 9. 160.;
          hill 0. 12. (-8.) 10. 180.;
          hill 0. 32. (-3.) 9. 150.;
          hill 0. 36. 13. 8. 120.;
          hill 0. 22. 28. 9. 110.;
          hill 0. 6. 27. 8. 100.;
          hill 0. (-7.) 21. 7. 90.;
        ];
      sea = [];
      scenery =
        (fun (site : site) (i : int) ->
          trees (Scenery.pine, Scenery.pine_far) 3 2 site i @ signs site i);
      landscape =
        (fun (site : site) ->
          start site.ribbon 2
          @ [
              Scenery.roller_coaster |> rotate3d 0. 60. 0.
              |> on_land site 7. 18.2;
            ]);
      moving =
        (fun (site : site) (time : float) ->
          [
            Scenery.ferris_wheel (spin 3. time)
            |> rotate3d 0. 30. 0. |> on_land site 3.2 18.8;
          ]);
    }

(* Bay Bridge, medium: the straight, a right and its right-left-right
 * kink, the suspension bridge across the inlet, a left that loops over
 * the road it will come back along (the overpass), the tunnel through
 * the hill, the big right by the windmills, the climb beside the grey
 * retaining wall, under the overpass, and the final long right at the
 * tail onto the straight. Narrow, walled, palms by the sea. *)
let bay_bridge () : t =
  make
    {
      d_name = "BAY BRIDGE";
      d_level = "MEDIUM";
      points =
        [
          (6., 11., 0.);
          (10., 8.9, 1.);
          (14., 6.8, 2.);
          (18., 4.6, 3.);
          (21., 2.8, 4.);
          (23.5, 2.2, 5.);
          (25.3, 3.4, 6.);
          (24.8, 5.3, 8.);
          (22.8, 6.8, 10.);
          (21.2, 8.5, 12.);
          (21., 10.4, 14.);
          (21.6, 12.2, 16.);
          (19.4, 13.7, 16.);
          (17.1, 15.3, 16.);
          (14.8, 16.9, 15.);
          (13.6, 18.5, 13.);
          (13.2, 20.3, 11.);
          (14., 21.6, 10.);
          (15.8, 22., 9.);
          (17.8, 21.4, 8.);
          (19.6, 20.2, 7.);
          (21.2, 19., 6.);
          (22.8, 18.4, 5.);
          (24.5, 19., 4.);
          (25.2, 20.9, 3.);
          (24., 22.7, 2.);
          (21.5, 23.6, 1.);
          (18.5, 24., 0.);
          (16., 23.6, 0.);
          (13.6, 21., 0.);
          (12.3, 19., 2.);
          (11.9, 16.8, 5.);
          (11.8, 14.5, 6.);
          (11., 12.6, 4.);
          (9., 12.2, 2.);
          (6.5, 13.3, 1.);
          (3.8, 14.2, 0.);
          (2.2, 13.4, 0.);
          (3., 12.1, 0.);
        ];
      d_laps = 5;
      d_checkpoints = 2;
      d_start_time = 45;
      d_bonus = 24;
      d_rivals = 15;
      d_spans =
        [
          (Suspension, (21.2, 12.5), (15.3, 16.5));
          (Overpass, (13.3, 19.5), (15.2, 22.));
          (Tunnel, (20.2, 19.8), (23.6, 18.5));
          (Wall, (18.5, 24.), (13.9, 21.4));
          (Wall, (24.8, 5.3), (21.1, 9.4));
        ];
      palette = Land.green;
      d_grass = (rgb 70 160 60, rgb 60 140 50);
      hills =
        [
          hill 0. 22.2 18.8 3.5 30.;
          hill 0. 31. 27. 8. 150.;
          hill 0. 8. 29. 8. 130.;
          hill 0. (-6.) 20. 7. 120.;
          hill 0. (-5.) 3. 7. 110.;
          hill 0. 14. (-6.) 8. 140.;
          hill 0. 33. 2. 7. 120.;
        ];
      sea =
        [
          [
            (16.2, 14.4);
            (19.4, 12.4);
            (23., 13.3);
            (29., 13.4);
            (40., 13.);
            (40., 17.5);
            (25., 16.8);
            (21.5, 16.8);
            (18.5, 17.6);
            (16.8, 17.4);
          ];
        ];
      scenery =
        (fun (site : site) (i : int) ->
          trees (Scenery.palm, Scenery.palm) 7 1 site i @ signs site i);
      landscape =
        (fun (site : site) ->
          start site.ribbon 2
          @ List.concat_map
              (fun (sp : span) ->
                match sp.kind with
                | Suspension ->
                    bridge site.ribbon sp.s0 sp.s1
                    @ piers site.ribbon (-8.) sp.s0 sp.s1
                | Overpass -> piers site.ribbon ground sp.s0 sp.s1
                | Tunnel -> portals site.ribbon sp.s0 sp.s1
                | Wall -> [])
              site.spans
          @ [ Scenery.lighthouse |> on_land site 30. 12.4 ]);
      moving =
        (fun (site : site) (time : float) ->
          [
            Scenery.windmill (spin 20. time)
            |> rotate3d 0. 200. 0. |> on_land site 27.2 20.4;
            Scenery.windmill (spin 17. time +. 40.)
            |> rotate3d 0. 200. 0. |> on_land site 26.8 23.2;
          ]);
    }

(* Acropolis, the expert's: the blob of the map -- the long straight up
 * the left, round the top, the bends down the right with the sea
 * beyond, back along the bottom -- and the finger up its middle: a
 * long straight to the keyhole hairpin, a hard long left, and a long
 * straight back; the zigzag, the canyon's twisty bends to the line.
 * The ruins on their hill, houses on the mountainside. *)
let acropolis () : t =
  make
    {
      d_name = "ACROPOLIS";
      d_level = "EXPERT";
      points =
        [
          (1.6, 13., 0.);
          (2., 10.8, 2.);
          (3.3, 8.6, 5.);
          (4.6, 6.8, 8.);
          (7., 5.1, 11.);
          (10., 3.6, 14.);
          (13., 2.7, 16.);
          (15.5, 2.4, 17.);
          (17.3, 2.9, 17.);
          (18.2, 4.3, 16.);
          (19., 5.8, 15.);
          (20.6, 6.6, 14.);
          (22.2, 8.4, 12.);
          (24., 10., 9.);
          (25., 11.8, 7.);
          (24.3, 13.2, 6.);
          (21.5, 13.9, 5.);
          (19.5, 14.8, 4.);
          (17., 15.4, 3.);
          (15.2, 15.3, 3.);
          (14.3, 14.2, 3.);
          (14.4, 12., 5.);
          (14.7, 9.2, 8.);
          (15., 6.9, 10.);
          (15.7, 5.6, 11.);
          (15.1, 4.5, 12.);
          (13.9, 4.7, 12.);
          (13.4, 6.1, 11.);
          (13.2, 9., 8.);
          (12.9, 12., 5.);
          (12.6, 14.3, 3.);
          (11.7, 15.6, 2.);
          (10., 15.2, 2.);
          (8.3, 15.9, 1.);
          (6.8, 17.2, 1.);
          (5., 17.8, 0.);
          (3.2, 17.1, 0.);
          (2., 15.3, 0.);
        ];
      d_laps = 5;
      d_checkpoints = 2;
      d_start_time = 45;
      d_bonus = 25;
      d_rivals = 15;
      d_spans = [ (Wall, (15.6, 5.8), (13.5, 5.8)) ];
      palette = Land.dry;
      d_grass = (rgb 165 160 90, rgb 150 145 80);
      hills =
        [
          hill 0.6 8. 10. 3.2 34.;
          hill 0. 9. 3.5 4. 30.;
          hill 0. 4. 20.5 3. 45.;
          hill 0. 8.5 19.5 2.5 38.;
          hill 0. (-7.) 6. 8. 140.;
          hill 0. 6. (-7.) 8. 130.;
          hill 0. 20. (-6.) 8. 150.;
          hill 0. 9. 28. 8. 110.;
          hill 0. (-6.) 24. 7. 100.;
        ];
      sea =
        [ [ (27., -10.); (45., -10.); (45., 30.); (27., 30.); (27.5, 12.) ] ];
      scenery =
        (fun (site : site) (i : int) ->
          trees (Scenery.cypress, Scenery.cypress) 7 1 site i
          @ (if i mod 11 = 5 then trees (Scenery.rock, Scenery.rock) 1 1 site i
             else [])
          @ signs site i);
      landscape =
        (fun (site : site) ->
          start site.ribbon 2
          @ [ Scenery.temple |> rotate3d 0. 20. 0. |> on_land site 8. 10. ]
          @ List.init 12 (fun (k : int) ->
              Scenery.house k
              |> rotate3d 0. (40. *. Scenery.jitter k 4) 0.
              |> on_land site
                   (7.5 +. (1.1 *. float_of_int (k mod 4)) +. Scenery.jitter k 5)
                   (6.2 +. (0.9 *. float_of_int (k / 4)))));
      moving =
        (fun (_ : site) (time : float) ->
          List.init 3 (fun (k : int) ->
              Scenery.sailboat
              |> rotate3d 0. (20. +. (70. *. float_of_int k)) 0.
              |> move3d
                   (((30. +. (3. *. float_of_int k)) *. map_unit)
                   +. Playground.wave (-20.) 20.
                        (14. +. float_of_int k)
                        (Playground.Time time))
                   water_level
                   ((2. +. (8. *. float_of_int k)) *. map_unit)));
    }

(*****************************************************************************)
(* What is drawn *)
(*****************************************************************************)

let lod = ref true
let far_away = 150.

let road_near (c : t) (s : float) ((ex, _, ez) : Vec3.t) : Mesh.t list =
  let len = Track3d.length c.ribbon in
  let wrapped = Float.rem (Float.rem s len +. len) len in
  let chunk = int_of_float (wrapped /. Track3d.step c.ribbon) / chunk_size in
  let n = Array.length c.chunks in
  let closed = c.laps > 1 in
  let near = ref [] in
  for k = n - 1 downto 0 do
    let ahead =
      if closed then (((k - chunk + 1) mod n) + n) mod n else k - chunk + 1
    in
    let p = c.chunks.(k) in
    let d = Float.hypot (p.mx -. ex) (p.mz -. ez) in
    if (ahead >= 0 && ahead < 7) || d < 160. then
      near := (if !lod && d > far_away then p.far else p.mesh) :: !near
  done;
  !near

let land_near (c : t) ((ex, _, ez) : Vec3.t) : Mesh.t list =
  Array.fold_right
    (fun (p : piece) (l : Mesh.t list) ->
      if Float.hypot (p.mx -. ex) (p.mz -. ez) < 1300. then p.mesh :: l else l)
    c.tiles []

(* The sky, the haze and the floor. A ceiling 200 up (over the tallest
 * mountain), from behind the eye to far ahead; the floor, under the
 * land (for beyond its edge), goes as far; and the haze is a slope
 * rising from the floor's far edge to meet the ceiling, which bends
 * down to it -- all within the far plane (2000), and all nearly flat,
 * facing up: flat shading lights a face by its slope, and a steep haze
 * would be grey, darker or lighter with the heading; the sky is seen
 * from below. The haze starts past the mountains: in front of them it
 * would hide their feet and leave their tops floating.
 *
 *     ceiling  ________________________
 *      (200 up)                        \___  (40 up)
 *       eye                           ___/
 *     floor ___________________________/  haze
 *                                  1400  1560 ahead *)
let sky_over (cam : Camera.t) (ground : float) (floor : Mesh.color) : Mesh.shape
    =
  let ex, ey, ez = cam.eye and tx, _, tz = cam.target in
  let d = Float.max 1e-9 (Float.hypot (tx -. ex) (tz -. ez)) in
  let fx = (tx -. ex) /. d and fz = (tz -. ez) /. d in
  let at (ahead : float) (k : float) (y : float) : Vec3.t =
    ( ex +. (ahead *. fx) -. (k *. 1200. *. fz),
      y,
      ez +. (ahead *. fz) +. (k *. 1200. *. fx) )
  in
  let top = ey +. 200.
  and low = ey +. 40.
  and bend = 1000.
  and far = 1400.
  and edge = 1560. in
  let blue = rgb 150 205 250 in
  Mesh.group3d
    [
      polygon3d floor
        [
          at (-300.) (-1.) ground;
          at (-300.) 1. ground;
          at far 1. ground;
          at far (-1.) ground;
        ];
      polygon3d blue
        [
          at (-300.) (-1.) top;
          at (-300.) 1. top;
          at bend 1. top;
          at bend (-1.) top;
        ];
      polygon3d blue
        [ at bend (-1.) top; at bend 1. top; at edge 1. low; at edge (-1.) low ];
      polygon3d (rgb 215 232 248)
        [
          at far (-1.) ground;
          at far 1. ground;
          at edge 1. low;
          at edge (-1.) low;
        ];
    ]

let sky (c : t) (cam : Camera.t) : Mesh.shape =
  sky_over cam ground (snd c.grass)

(*****************************************************************************)
(* The course select's miniature *)
(*****************************************************************************)

let miniature_scale = 0.1

(* OPTIMIZATION (once): what the race's display and the rivals asked of
 * the road at each frame, the same answers, made once: the course's
 * box (a Track3d.at for each segment, at each frame: the map), a
 * segment's turn (41 for each rival at each frame: its braking); with
 * the map's dots (Screens), 2,800 Track3d.at a frame, 10% of it.
 * old: bounds walked the road, Rivals called turn_at *)
let bounds (c : t) : float * float * float * float = c.box

let turn (c : t) (i : int) : float =
  if i < 0 || i >= Float.Array.length c.turns then turn_at c.ribbon i
  else begin
    let v = Float.Array.get c.turns i in
    if Float.is_nan v then begin
      let v = turn_at c.ribbon i in
      Float.Array.set c.turns i v;
      v
    end
    else v
  end

let miniature_center (c : t) : float * float =
  let x0, x1, z0, z1 = bounds c in
  ((x0 +. x1) /. 2., (z0 +. z1) /. 2.)

let shrink (c : t) (s : Mesh.shape) : Mesh.shape =
  let cx, cz = miniature_center c in
  s |> Mesh.move3d (-.cx) 0. (-.cz) |> Mesh.scale3d miniature_scale

(* the land a quad of two cells, the road a band of three segments (the
 * line's white), the landmarks *)
let miniature (c : t) : Mesh.shape =
  let n = Track3d.segments c.ribbon in
  let band =
    List.init (n / 3) (fun (k : int) ->
        let at (j : int) = float_of_int j *. Track3d.step c.ribbon in
        let sa = at (3 * k) and sb = at (min n ((3 * k) + 3)) in
        let a (o : float) = Track3d.across c.ribbon sa o
        and b (o : float) = Track3d.across c.ribbon sb o in
        let lift ((x, y, z) : Vec3.t) : Vec3.t = (x, y +. 1.5, z) in
        polygon3d
          (if k = 0 then Mesh.white else rgb 90 90 95)
          (List.map lift
             [
               a (-2. *. road_width);
               a (2. *. road_width);
               b (2. *. road_width);
               b (-2. *. road_width);
             ]))
  in
  let tiles = List.map snd (Land.tiles c.terrain water_level 2) in
  shrink c (Mesh.group3d (tiles @ band @ c.landscape))

(* (the playground's course's lap_length) *)
let lap_length (c : t) : float =
  if c.laps = 1 then Track3d.length c.ribbon -. (2. *. Track3d.step c.ribbon)
  else Track3d.length c.ribbon

let far_meshes (c : t) : Mesh.t list =
  Array.fold_right (fun (p : piece) (l : Mesh.t list) -> p.far :: l) c.chunks []

let meshes (c : t) : Mesh.t list =
  Array.fold_right
    (fun (p : piece) (l : Mesh.t list) -> p.mesh :: l)
    c.chunks []
  @ Array.fold_right
      (fun (p : piece) (l : Mesh.t list) -> p.mesh :: l)
      c.tiles []
  @ c.landmarks
