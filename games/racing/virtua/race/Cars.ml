(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Cars.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * car_model, shadow, liveries and grid *)

let rgb = Mesh.rgb
let box = Mesh.box
let move3d = Mesh.move3d

let model (livery : Mesh.color) (braking : bool) : Mesh.shape =
  let white = rgb 240 240 240 and dark = rgb 35 35 40 in
  (* a section of the body: [w] half wide at the bottom, narrower at the
   * top, from [y] up [h] (counterclockwise seen from behind) *)
  let sect (w : float) (h : float) (y : float) : (float * float) list =
    [ (-.w, y); (w, y); (w *. 0.75, y +. h); (-.w *. 0.75, y +. h) ]
  in
  let tyre (r : float) (w : float) : Mesh.shape = Scenery.wheel dark 8 r w in
  let front (x : float) : Mesh.shape = tyre 0.38 0.4 |> move3d x 0.38 (-1.45) in
  let rear (x : float) : Mesh.shape = tyre 0.46 0.55 |> move3d x 0.46 1.3 in
  (* the shadow, on the road under it *)
  let shadow =
    Mesh.polygon3d (rgb 45 50 45)
      [
        (-0.95, 0.04, 2.);
        (0.95, 0.04, 2.);
        (0.95, 0.04, -2.);
        (-0.95, 0.04, -2.);
      ]
  in
  Mesh.group3d
    [
      shadow;
      Scenery.loft livery (sect 0.1 0.12 0.3) (sect 0.3 0.35 0.25) (-2.3) (-0.9);
      Scenery.loft livery (sect 0.3 0.35 0.25) (sect 0.45 0.45 0.2) (-0.9) 0.6;
      Scenery.loft white (sect 0.45 0.62 0.2) (sect 0.22 0.3 0.3) 0.6 2.;
      Scenery.loft livery (sect 0.22 0.3 0.15) (sect 0.22 0.3 0.15) (-0.3) 1.1
      |> Mesh.move_x3d 0.62;
      Scenery.loft livery (sect 0.22 0.3 0.15) (sect 0.22 0.3 0.15) (-0.3) 1.1
      |> Mesh.move_x3d (-0.62);
      box dark 0.42 0.06 0.8 |> move3d 0. 0.66 (-0.2);
      box (rgb 250 210 0) 0.3 0.28 0.34 |> move3d 0. 0.78 0.1;
      box livery 2.1 0.06 0.45 |> move3d 0. 0.18 (-2.25);
      box white 0.05 0.3 0.5 |> move3d (-1.05) 0.25 (-2.25);
      box white 0.05 0.3 0.5 |> move3d 1.05 0.25 (-2.25);
      box livery 1.6 0.08 0.45 |> move3d 0. 1.15 2.;
      box dark 0.06 0.55 0.6 |> move3d (-0.8) 0.95 2.;
      box dark 0.06 0.55 0.6 |> move3d 0.8 0.95 2.;
      box dark 0.1 0.5 0.1 |> move3d 0. 0.85 1.9;
      box (if braking then rgb 255 60 60 else rgb 90 20 20) 0.3 0.12 0.06
      |> move3d 0. 0.4 2.05;
      front (-0.95);
      front 0.95;
      rear (-0.95);
      rear 0.95;
    ]

let liveries =
  [|
    rgb 30 90 220;
    rgb 250 250 250;
    rgb 250 200 20;
    rgb 30 160 70;
    rgb 240 120 20;
    rgb 150 50 190;
    rgb 20 20 20;
    rgb 0 170 200;
    rgb 230 90 150;
    rgb 120 120 130;
    rgb 120 70 30;
    rgb 60 60 180;
    rgb 200 200 60;
    rgb 220 30 30;
    rgb 90 200 150;
  |]

let player_slot = 8
let slot_s (k : int) : float = -12. -. (8. *. float_of_int k)
let slot_lane (k : int) : float = if k mod 2 = 0 then -2.8 else 2.8
