(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Topdown.mli *)

(* ix: the author's playground's gamekits/racing/Topdown.ml, its car,
 * drive, bounce and push *)

type t = {
  x : float;
  y : float;
  vx : float;
  vy : float;
  heading : float;
  speed : float;
}

type params = {
  accel : float;
  friction : float;
  grip : float;
  steering : float;
  steering_speed : float;
}

let radians (d : float) : float = d *. Float.pi /. 180.

let drive (p : params) (top : float) (gas : float) (steer : float) (c : t) : t =
  let dt = 1. /. 60. in
  let speed = c.speed +. (gas *. p.accel *. dt) in
  let speed = speed -. (speed *. p.friction *. dt) in
  let speed = Float.max (-.top /. 3.) (Float.min top speed) in
  let heading =
    c.heading
    +. steer *. p.steering
       *. Float.min 1. (Float.abs speed /. p.steering_speed)
  in
  let a = radians heading in
  let vx = c.vx +. (p.grip *. ((speed *. cos a) -. c.vx))
  and vy = c.vy +. (p.grip *. ((speed *. sin a) -. c.vy)) in
  { x = c.x +. (vx *. dt); y = c.y +. (vy *. dt); vx; vy; heading; speed }

let bounce (wall : float -> float -> bool) (before : t) (after : t) : t =
  if (not (wall after.x after.y)) || wall before.x before.y then after
  else
    let x, vx =
      if wall after.x before.y then (before.x, -0.5 *. after.vx)
      else (after.x, after.vx)
    in
    let y, vy =
      if wall x after.y then (before.y, -0.5 *. after.vy)
      else (after.y, after.vy)
    in
    { after with x; y; vx; vy; speed = after.speed /. 2. }

let push (radius : float) (a : t) (b : t) : t * t =
  let dx = b.x -. a.x and dy = b.y -. a.y in
  let d = Float.hypot dx dy in
  if d >= 2. *. radius || d = 0. then (a, b)
  else
    let nx = dx /. d and ny = dy /. d in
    let half = ((2. *. radius) -. d) /. 2. in
    (* the velocities along the line, swapped *)
    let va = (a.vx *. nx) +. (a.vy *. ny)
    and vb = (b.vx *. nx) +. (b.vy *. ny) in
    let dv = vb -. va in
    ( {
        a with
        x = a.x -. (half *. nx);
        y = a.y -. (half *. ny);
        vx = a.vx +. (dv *. nx);
        vy = a.vy +. (dv *. ny);
      },
      {
        b with
        x = b.x +. (half *. nx);
        y = b.y +. (half *. ny);
        vx = b.vx -. (dv *. nx);
        vy = b.vy -. (dv *. ny);
      } )
