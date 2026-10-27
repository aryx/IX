(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Rivals.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "The rivals" *)

type t = {
  rs : float;
  lane : float;
  rspeed : float;
  home : float;
  top : float;
  livery : Mesh.color;
}

let grid (c : Course.t) : t list =
  List.init c.rivals (fun (k : int) ->
      let slot = if k < Cars.player_slot then k else k + 1 in
      {
        rs = Cars.slot_s slot;
        lane = Cars.slot_lane slot;
        rspeed = 0.;
        home = Cars.slot_lane slot;
        top =
          (Driving.top_speed *. (0.9 -. (0.012 *. float_of_int k)))
          +. (4. *. Scenery.jitter k 9);
        livery = Cars.liveries.(k mod Array.length Cars.liveries);
      })

(* the speed for the sharpest turn 10 to 50 segments ahead: radius r
 * allows sqrt (grip * r), the speed at which a car going round a circle
 * needs all its tyres' grip (v^2 / r = grip) *)
let corner_speed (c : Course.t) (s : float) : float =
  let step = Track3d.step c.ribbon in
  let k0 = int_of_float (Driving.wrap c s /. step) in
  let sharpest = ref 0. in
  for k = 10 to 50 do
    sharpest :=
      Float.max !sharpest (Float.abs (Course.turn c (k0 + k)))
  done;
  if !sharpest < 0.05 then infinity
  else
    let radius = step /. (!sharpest *. Float.pi /. 180.) in
    Float.sqrt (32. *. radius)

let drive (c : Course.t) (player : Driving.t) (rivals : t list) : t list =
  let dt = 1. /. 60. in
  let arr = Array.of_list rivals in
  Array.to_list
    (Array.map
       (fun (r : t) ->
         let wanted = Float.min r.top (corner_speed c r.rs) in
         (* accelerating as the player's car does, harder from low speed *)
         let accel = 70. *. (1. -. (0.6 *. r.rspeed /. Driving.top_speed)) in
         let rspeed =
           if r.rspeed < wanted then r.rspeed +. (accel *. dt)
           else Float.max wanted (r.rspeed -. (45. *. dt))
         in
         (* a slower car just ahead in my lane: move over *)
         let blocked (lane : float) : bool =
           Array.exists
             (fun (o : t) ->
               o != r && o.rs > r.rs
               && o.rs -. r.rs < 25.
               && o.rspeed < rspeed
               && Float.abs (o.lane -. lane) < 3.)
             arr
           || player.s > r.rs
              && player.s -. r.rs < 25.
              && player.car.speed < rspeed
              && Float.abs (player.offset -. lane) < 3.
         in
         let target =
           if blocked r.lane then
             if blocked (-.r.home) then r.lane else -.r.home
           else if blocked r.home then r.lane
           else r.home
         in
         let lane =
           r.lane +. Float.max (-0.08) (Float.min 0.08 (target -. r.lane))
         in
         { r with rs = r.rs +. (rspeed *. dt); rspeed; lane })
       arr)

let place (c : Course.t) (r : t) : Vec3.t * float =
  (Track3d.across c.ribbon r.rs r.lane, (Track3d.at c.ribbon r.rs).heading)

let bump (c : Course.t) (d : Driving.t) (rivals : t list) :
    Driving.t * t list * bool =
  let d, acc, crashed =
    List.fold_left
      (fun ((d, acc, crashed) : Driving.t * t list * bool) (r : t) ->
        let (x, _, z), h = place c r in
        if Float.hypot (x -. d.car.x) (z +. d.car.y) > 4.4 then
          (d, r :: acc, crashed)
        else
          let a = Driving.plane_heading h *. Float.pi /. 180. in
          let other : Topdown.t =
            {
              x;
              y = -.z;
              vx = r.rspeed *. cos a;
              vy = r.rspeed *. sin a;
              heading = Driving.plane_heading h;
              speed = r.rspeed;
            }
          in
          let hard = Float.abs (d.car.speed -. r.rspeed) > 30. in
          let car, _ = Topdown.push 2.2 d.car other in
          let d : Driving.t =
            {
              d with
              car =
                {
                  car with
                  speed = Float.min car.speed (Float.hypot car.vx car.vy);
                };
              bump = 0;
            }
          in
          let d =
            if hard && d.spin = 0 then { d with spin = Driving.spin_frames }
            else d
          in
          (d, { r with rspeed = r.rspeed *. 0.9 } :: acc, true))
      (d, [], false) rivals
  in
  (d, List.rev acc, crashed)

let position (d : Driving.t) (rivals : t list) : int =
  1 + List.length (List.filter (fun (r : t) -> r.rs > d.s) rivals)

let ordinal (n : int) : string =
  let suffix =
    if n mod 100 >= 11 && n mod 100 <= 13 then "TH"
    else
      match n mod 10 with
      | 1 -> "ST"
      | 2 -> "ND"
      | 3 -> "RD"
      | _ -> "TH"
  in
  string_of_int n ^ suffix
