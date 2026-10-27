(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Scenery.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "Shapes made of polygons", "The scenery" and "The landmarks" (Big
 * Forest's) *)

let rgb = Mesh.rgb
let polygon3d = Mesh.polygon3d
let group3d = Mesh.group3d
let box = Mesh.box
let move3d = Mesh.move3d
let move_y3d = Mesh.move_y3d
let rotate3d = Mesh.rotate3d

let jitter (i : int) (k : int) : float =
  (Heightmap.random 1 i k +. 1.) /. 2.0001

(*****************************************************************************)
(* Shapes made of polygons *)
(*****************************************************************************)

let loft (color : Mesh.color) (a : (float * float) list)
    (b : (float * float) list) (z0 : float) (z1 : float) : Mesh.shape =
  let a = Array.of_list a and b = Array.of_list b in
  let n = Array.length a in
  let at ((x, y) : float * float) (z : float) : Vec3.t = (x, y, z) in
  let side (i : int) : Mesh.shape =
    let j = (i + 1) mod n in
    polygon3d color [ at a.(i) z0; at a.(j) z0; at b.(j) z1; at b.(i) z1 ]
  in
  group3d
    (polygon3d color
       (List.map (fun (p : float * float) -> at p z1) (Array.to_list b))
    :: polygon3d color
         (List.rev_map (fun (p : float * float) -> at p z0) (Array.to_list a))
    :: List.init n side)

let ring (sides : int) (r : float) : (float * float) list =
  List.init sides (fun (k : int) ->
      let a = 2. *. Float.pi *. float_of_int k /. float_of_int sides in
      (r *. cos a, r *. sin a))

let wheel (color : Mesh.color) (sides : int) (r : float) (w : float) :
    Mesh.shape =
  loft color (ring sides r) (ring sides r) (-.w /. 2.) (w /. 2.)
  |> rotate3d 0. 90. 0.

(* The base points go round counterclockwise seen from above, so
 * [b_k; apex; b_k+1] faces out. *)
let cone (seed : int) (snow : float) (color : Mesh.color) (sides : int)
    (r : float) (h : float) : Mesh.shape =
  let base =
    Array.init sides (fun (k : int) ->
        let a =
          2. *. Float.pi
          *. (float_of_int k +. (0.4 *. jitter seed k))
          /. float_of_int sides
        in
        let r = r *. (0.75 +. (0.4 *. jitter seed (k + 50))) in
        (r *. cos a, 0., r *. sin a))
  in
  let apex =
    ((jitter seed 99 -. 0.5) *. r *. 0.3, h, (jitter seed 98 -. 0.5) *. r *. 0.3)
  in
  let mix ((x1, y1, z1) : Vec3.t) ((x2, y2, z2) : Vec3.t) (f : float) : Vec3.t =
    (x1 +. ((x2 -. x1) *. f), y1 +. ((y2 -. y1) *. f), z1 +. ((z2 -. z1) *. f))
  in
  group3d
    (List.concat
       (List.init sides (fun (k : int) ->
            let b0 = base.(k) and b1 = base.((k + 1) mod sides) in
            if snow = 0. then [ polygon3d color [ b0; apex; b1 ] ]
            else
              let m0 = mix b0 apex (1. -. snow)
              and m1 = mix b1 apex (1. -. snow) in
              [
                polygon3d color [ b0; m0; m1; b1 ];
                polygon3d (rgb 245 245 250) [ m0; apex; m1 ];
              ])))

let column (color : Mesh.color) (sides : int) (r : float) (h : float) :
    Mesh.shape =
  let base =
    Array.of_list
      (List.map (fun ((x, z) : float * float) -> (x, 0., z)) (ring sides r))
  in
  group3d
    (polygon3d color
       (List.rev_map
          (fun ((x, _, z) : Vec3.t) -> (x, h, z))
          (Array.to_list base))
    :: List.init sides (fun (k : int) ->
        let x0, _, z0 = base.(k) and x1, _, z1 = base.((k + 1) mod sides) in
        polygon3d color [ (x0, 0., z0); (x0, h, z0); (x1, h, z1); (x1, 0., z1) ])
    )

(* a roof over a house, the triangle of its gable lofted along its depth *)
let roof (color : Mesh.color) (w : float) (h : float) (d : float) : Mesh.shape =
  let gable = [ (-.w /. 2., 0.); (w /. 2., 0.); (0., h) ] in
  loft color gable gable (-.d /. 2.) (d /. 2.)

(*****************************************************************************)
(* The scenery *)
(*****************************************************************************)

let pine (k : int) : Mesh.shape =
  let green = if k mod 2 = 0 then rgb 30 100 45 else rgb 40 115 50 in
  group3d
    [
      box (rgb 100 65 30) 0.5 1.6 0.5 |> move_y3d 0.8;
      cone k 0. green 6 2.2 4. |> move_y3d 1.4;
      cone (k + 7) 0. green 5 1.6 3.4 |> move_y3d 3.6;
    ]

let pine_far (k : int) : Mesh.shape =
  let green = if k mod 2 = 0 then rgb 30 100 45 else rgb 40 115 50 in
  cone k 0. green 5 2.2 5.6 |> move_y3d 1.4

(* a palm: its trunk leaning, six fronds drooping from the top (one
 * face thick: seen from both sides) *)
let palm (k : int) : Mesh.shape =
  let lean = 8. +. (10. *. jitter k 3) in
  let frond (a : float) : Mesh.shape =
    let r = a *. Float.pi /. 180. in
    let c = cos r and s = sin r in
    Mesh.two_sided
      (polygon3d (rgb 60 150 60)
         [
           (0., 7., 0.);
           ((3.2 *. c) -. (0.6 *. s), 6.2, (3.2 *. s) +. (0.6 *. c));
           (4. *. c, 5.2, 4. *. s);
         ])
  in
  group3d
    (column (rgb 140 100 60) 5 0.3 7.
    :: List.init 6 (fun (i : int) ->
        frond ((60. *. float_of_int i) +. (30. *. jitter k i))))
  |> rotate3d lean (360. *. jitter k 4) 0.

let cypress (k : int) : Mesh.shape =
  group3d [ cone k 0. (rgb 55 115 55) 5 1.1 7. ]

let rock (k : int) : Mesh.shape = cone k 0. (rgb 150 130 105) 5 2.2 1.8

let sign : Mesh.shape =
  group3d
    [
      box (rgb 90 90 90) 0.3 2. 0.3 |> move3d (-1.5) 1. 0.;
      box (rgb 90 90 90) 0.3 2. 0.3 |> move3d 1.5 1. 0.;
      box Mesh.white 4. 1.4 0.3 |> move_y3d 2.6;
      box Mesh.red 3.4 0.5 0.35 |> move_y3d 2.6;
    ]

let chevron : Mesh.shape =
  group3d
    [
      box (rgb 60 60 60) 0.2 1.2 0.2 |> move_y3d 0.6;
      box (rgb 250 210 0) 1.6 1. 0.2 |> move_y3d 1.6;
      box Mesh.black 0.5 1.02 0.22 |> move_y3d 1.6;
    ]

(*****************************************************************************)
(* The landmarks *)
(*****************************************************************************)

(* five steps of spectators (a stripe of colours each) under a roof *)
let grandstand (ground : float) : Mesh.shape =
  let len = 36. in
  let crowd =
    [|
      rgb 220 60 60;
      rgb 240 200 40;
      rgb 60 110 220;
      rgb 240 240 240;
      rgb 60 170 90;
    |]
  in
  let steps =
    List.concat
      (List.init 5 (fun (k : int) ->
           let y = 1. +. (1.2 *. float_of_int k)
           and x = -2. -. (2.2 *. float_of_int k) in
           [
             box (rgb 170 170 170) 2.2 (y -. ground) len
             |> move3d x ((y +. ground) /. 2.) 0.;
             box crowd.(k) 1.2 0.5 (len -. 1.)
             |> move3d (x +. 0.4) (y +. 0.25) 0.;
           ]))
  in
  group3d
    (steps
    @ [
        box (rgb 120 120 130) 0.4 8. 0.4 |> move3d (-12.) 4. (-.len /. 2.);
        box (rgb 120 120 130) 0.4 8. 0.4 |> move3d (-12.) 4. (len /. 2.);
        box (rgb 40 60 140) 13. 0.4 (len +. 2.)
        |> rotate3d 0. 0. (-8.) |> move3d (-6.) 8.4 0.;
      ])

let gantry (color : Mesh.color) (w : float) : Mesh.shape =
  group3d
    [
      box (rgb 230 230 230) 1. 7. 1. |> move3d (-.w -. 1.) 3.5 0.;
      box (rgb 230 230 230) 1. 7. 1. |> move3d (w +. 1.) 3.5 0.;
      box color ((2. *. w) +. 3.) 1.6 0.6 |> move_y3d 7.;
      box (rgb 250 60 40) 1. 0.6 0.7 |> move3d (-2.) 7. 0.;
      box (rgb 250 60 40) 1. 0.6 0.7 |> move3d 2. 7. 0.;
    ]

(* its rim, spokes and cars are polygons in the wheel's plane (x, y),
 * on two A-frames *)
let ferris_wheel (angle : float) : Mesh.shape =
  let r = 20. and hub = 23. and n = 16 in
  let point (k : int) (rr : float) : float * float =
    let a =
      (angle +. (360. *. float_of_int k /. float_of_int n)) *. Float.pi /. 180.
    in
    (rr *. cos a, hub +. (rr *. sin a))
  in
  let quad (color : Mesh.color) ((x1, y1) : float * float)
      ((x2, y2) : float * float) ((x3, y3) : float * float)
      ((x4, y4) : float * float) (z : float) : Mesh.shape =
    polygon3d color [ (x1, y1, z); (x2, y2, z); (x3, y3, z); (x4, y4, z) ]
  in
  let rim =
    List.concat
      (List.init n (fun (k : int) ->
           List.map
             (fun (z : float) ->
               quad (rgb 240 240 240) (point k r)
                 (point (k + 1) r)
                 (point (k + 1) (r -. 0.8))
                 (point k (r -. 0.8))
                 z)
             [ -1.2; 1.2 ]))
  in
  let spokes =
    List.init n (fun (k : int) ->
        let x, y = point k r
        and a =
          (angle +. (360. *. float_of_int k /. float_of_int n))
          *. Float.pi /. 180.
        in
        let dx = -0.2 *. sin a and dy = 0.2 *. cos a in
        quad (rgb 200 200 210)
          (-.dx, hub -. dy)
          (dx, hub +. dy)
          (x +. dx, y +. dy)
          (x -. dx, y -. dy)
          0.)
  in
  let colors = Array.of_list Mesh.rainbow in
  let cars =
    List.init n (fun (k : int) ->
        let x, y = point k r in
        box colors.(k mod Array.length colors) 1.8 1.6 1.6
        |> move3d x (y -. 1.4) 0.)
  in
  let leg (x : float) (z : float) : Mesh.shape =
    polygon3d (rgb 150 150 160)
      [ (x -. 0.6, 0., z); (x +. 0.6, 0., z); (0.3, hub, z); (-0.3, hub, z) ]
  in
  (* (the rim, the spokes and the legs one face thick: seen from both
   * sides, Mesh.two_sided) *)
  group3d
    (List.map Mesh.two_sided rim
    @ List.map Mesh.two_sided spokes
    @ cars
    @ List.map Mesh.two_sided
        [ leg (-9.) (-2.); leg 9. (-2.); leg (-9.) 2.; leg 9. 2. ]
    @ [ box (rgb 90 90 100) 1.2 1.2 5. |> move_y3d hub ])

(* a track on stilts, a loop the loop in the middle (a ring of short
 * boxes), the cars resting at the station *)
let roller_coaster : Mesh.shape =
  let rail = rgb 240 220 40 and stilt = rgb 200 200 200 in
  let loop =
    List.init 20 (fun (k : int) ->
        let a = 18. *. float_of_int k in
        let r = a *. Float.pi /. 180. in
        box rail 1.2 0.4 2. |> rotate3d a 0. 0.
        |> move3d 0. (9. +. (8. *. cos r)) (8. *. sin r))
  in
  let run =
    List.init 12 (fun (k : int) ->
        let z = -30. +. (5. *. float_of_int k)
        and y = 4. +. (3. *. sin (float_of_int k *. 0.9)) in
        [
          box rail 1.2 0.4 5. |> move3d 0. y z;
          box stilt 0.3 y 0.3 |> move3d 0. (y /. 2.) z;
        ])
  in
  group3d
    (loop @ List.concat run
    @ List.init 3 (fun (k : int) ->
        box (rgb 220 40 40) 1.4 1. 1.8
        |> move3d 0. 4.9 (-20. +. (2. *. float_of_int k))))

(* a windmill (Bay Bridge's pair by the big right): a white tower, its
 * four sails turning *)
let windmill (angle : float) : Mesh.shape =
  let sail (k : int) : Mesh.shape =
    let a = angle +. (90. *. float_of_int k) in
    box (rgb 245 245 240) 1.4 9. 0.3 |> move_y3d 4.8 |> rotate3d 0. 0. a
  in
  group3d
    ([
       column (rgb 240 240 235) 8 3. 14.;
       cone 0 0. (rgb 170 60 50) 8 3.4 3. |> move_y3d 14.;
     ]
    @ List.map
        (fun (sh : Mesh.shape) -> sh |> move3d 0. 13. 3.4)
        (List.init 4 sail))

(* a sailing boat, for Acropolis' sea (its sail one face thick) *)
let sailboat : Mesh.shape =
  group3d
    [
      loft Mesh.white
        [ (-1.2, 0.); (1.2, 0.); (1.6, 1.2); (-1.6, 1.2) ]
        [ (-0.2, 0.3); (0.2, 0.3); (0.4, 1.2); (-0.4, 1.2) ]
        (-4.) 4.;
      Mesh.two_sided
        (polygon3d Mesh.white
           [ (0., 1.2, 2.); (0., 10., 0.5); (0., 1.2, -2.5) ]);
    ]

let lighthouse : Mesh.shape =
  group3d
    ([
       column Mesh.white 8 2.4 16.;
       column (rgb 60 60 60) 8 1.8 3. |> move_y3d 16.;
       cone 0 0. (rgb 200 40 40) 8 2.4 2. |> move_y3d 19.;
     ]
    @ List.init 3 (fun (k : int) ->
        column (rgb 210 40 40) 8 2.45 1.6
        |> move_y3d (2. +. (5. *. float_of_int k))))

(* The ruins of Acropolis: three steps, a peristyle of columns (some
 * fallen short), the beam over part of it, the pediment's triangle,
 * built along x *)
let temple : Mesh.shape =
  let marble = rgb 235 230 210 in
  let steps =
    List.init 3 (fun (k : int) ->
        box marble (20. -. float_of_int k) 0.6 (12. -. float_of_int k)
        |> move_y3d (0.3 +. (0.6 *. float_of_int k)))
  in
  let columns =
    List.concat
      (List.init 7 (fun (k : int) ->
           let x = -8. +. (float_of_int k *. 8. /. 3.) in
           let h = if k = 5 then 2.5 else 6. in
           [
             column marble 8 0.6 h |> move3d x 1.8 (-4.);
             column marble 8 0.6 (if k = 1 then 3.5 else 6.) |> move3d x 1.8 4.;
           ]))
  in
  group3d
    (steps @ columns
    @ [
        box marble 11. 1. 10. |> move3d (-3.3) 8.3 0.;
        roof marble 10.5 2.2 11. |> rotate3d 0. 90. 0. |> move3d (-3.3) 8.8 0.;
      ])

let house (k : int) : Mesh.shape =
  let w = 5. +. (2. *. jitter k 1)
  and d = 5. +. (2. *. jitter k 2)
  and h = 3. +. (2. *. jitter k 3) in
  group3d
    [
      box (rgb 240 235 225) w (h +. 2.) d |> move_y3d ((h /. 2.) -. 1.);
      roof (rgb 200 90 50) (w +. 0.6) 1.8 (d +. 0.4) |> move_y3d h;
    ]
