(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Driving.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "The car" *)

let top_speed = 124.
let grass_speed = 45.
let kmh (speed : float) : float = Float.abs speed /. top_speed *. 330.

let params : Topdown.params =
  {
    accel = 78.;
    friction = 0.55;
    grip = 0.2;
    steering = 2.2;
    steering_speed = 25.;
  }

let grass_params : Topdown.params = { params with grip = 0.07 }
let plane_heading (world : float) : float = 90. -. world

type t = {
  car : Topdown.t;
  s : float;
  offset : float;
  wheel : float;
  bump : int;
  spin : int;
}

let spin_frames = 70

let at (c : Course.t) (s : float) (offset : float) : t =
  let x, _, z = Track3d.across c.ribbon s offset in
  let p = Track3d.at c.ribbon s in
  {
    car =
      {
        x;
        y = -.z;
        vx = 0.;
        vy = 0.;
        heading = plane_heading p.heading;
        speed = 0.;
      };
    s;
    offset;
    wheel = 0.;
    bump = 99;
    spin = 0;
  }

let length (c : Course.t) : float = Track3d.length c.ribbon

let wrap (c : Course.t) (s : float) : float =
  Float.rem (Float.rem s (length c) +. length c) (length c)

let world (c : Course.t) (d : t) : Vec3.t * float =
  let _, y, _ = Track3d.across c.ribbon d.s d.offset in
  let spun =
    if d.spin > 0 then
      720. *. (1. -. ((float_of_int d.spin /. float_of_int spin_frames) ** 2.))
    else 0.
  in
  ((d.car.x, y, -.d.car.y), 90. -. d.car.heading +. spun)

let slip (d : t) : float =
  if Float.hypot d.car.vx d.car.vy < 5. then 0.
  else
    Course.angle_diff d.car.heading (atan2 d.car.vy d.car.vx *. 180. /. Float.pi)

let steer (c : Course.t) (gas : float) (wanted : float) (d : t) : t =
  let near = if c.laps > 1 then wrap c d.s else d.s in
  let road = plane_heading (Track3d.at c.ribbon near).heading in
  let spinning = d.spin > 0 in
  let gas, wanted = if spinning then (0., 0.) else (gas, wanted) in
  let wheel = d.wheel +. Float.max (-0.1) (Float.min 0.1 (wanted -. d.wheel)) in
  let on_road = Float.abs d.offset <= 1.15 *. Course.road_width in
  let car =
    if (not on_road) && d.car.speed > grass_speed then
      { d.car with speed = d.car.speed -. 1.2 }
    else d.car
  in
  let car =
    if spinning then
      {
        car with
        speed = car.speed *. 0.96;
        vx = car.vx *. 0.96;
        vy = car.vy *. 0.96;
      }
    else car
  in
  let lock = wheel *. (1. -. (0.5 *. Float.abs car.speed /. top_speed)) in
  let moved =
    Topdown.drive
      (if on_road then params else grass_params)
      top_speed gas lock car
  in
  let rail (x : float) (y : float) : bool =
    let _, off = Track3d.locate_near c.ribbon near x (-.y) in
    Float.abs off > Course.verge -. 0.8
  in
  let after = Topdown.bounce rail car moved in
  let hit = after.x <> moved.x || after.y <> moved.y in
  (* against the rail the car scrapes along it: some of its speed lost
   * (Topdown.bounce would halve it every frame the gas pushes it back
   * in, a stop), and its nose turned back along the road *)
  let turn = Course.angle_diff after.heading road in
  let after : Topdown.t =
    if not hit then after
    else
      {
        after with
        speed = moved.speed *. 0.85;
        heading =
          (if Float.abs turn < 90. then after.heading +. (0.25 *. turn)
           else after.heading);
      }
  in
  let s, offset = Track3d.locate_near c.ribbon near after.x (-.after.y) in
  let ds =
    if c.laps > 1 then
      Course.angle_diff (near *. 360. /. length c) (s *. 360. /. length c)
      *. length c /. 360.
    else s -. near
  in
  let d' =
    {
      car = after;
      s = d.s +. ds;
      offset;
      wheel;
      bump = (if hit then 0 else d.bump + 1);
      spin = max 0 (d.spin - 1);
    }
  in
  (* a spin: the rail hit hard and not along it, or the car sliding too
   * far sideways; when it ends, the car is set facing the road, as the
   * arcade did *)
  if
    (not spinning)
    && ((hit && car.speed > 55. && Float.abs turn > 14.)
       || (Float.abs (slip d') > 32. && car.speed > 45.))
  then { d' with spin = spin_frames }
  else if spinning && d'.spin = 0 then
    {
      d' with
      car =
        {
          d'.car with
          heading = road;
          vx = 0.;
          vy = 0.;
          speed = Float.min 10. d'.car.speed;
        };
      wheel = 0.;
    }
  else d'
