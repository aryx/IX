(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Play.mli *)

open Model

type command = {
  forward : bool;
  back : bool;
  left : bool;
  right : bool;
  strafe_left : bool;
  strafe_right : bool;
  jump : bool;
  run : bool;
  look_up : bool;
  look_down : bool;
  use_key : bool;
}

type t = {
  level : Model.t;
  brushes : Brushes.t;
  body : Brushes.body;
  mutable pitch : float;
  mutable waterlevel : int;
  mutable jump_released : bool;
  mutable use_released : bool;
  mutable time : float;
  styles : string array;
  mutable bob_speed : float;
}

(* sv_*'s and cl_*'s defaults *)
let maxspeed = 320.
let friction = 4.
let edgefriction = 2.
let stopspeed = 100.
let accelerate = 10.
let gravity = 800.
let stepsize = 18.
let view_height = 22.
let player_mins = Brushes.player_mins
let player_maxs = Brushes.player_maxs

let create (m : Model.t) : t =
  let styles = Array.make 64 "" in
  let brushes = Brushes.create m styles in
  let start =
    List.find_opt
      (fun (e : (string * string) list) ->
        value e "classname" = Some "info_player_start")
      m.entities
  in
  let origin, yaw =
    match start with
    | Some e ->
        ( add
            (vec_of_string
               (match value e "origin" with Some v -> v | None -> "0 0 0"))
            { x = 0.; y = 0.; z = 1. },
          match Option.bind (value e "angle") float_of_string_opt with
          | Some a -> a
          | None -> 0. )
    | None -> (zero, 0.)
  in
  {
    level = m;
    brushes;
    body = { origin; velocity = zero; yaw; onground = false; ground = -1 };
    pitch = 0.;
    waterlevel = 0;
    jump_released = true;
    use_released = true;
    time = 0.;
    styles;
    bob_speed = 0.;
  }

let place (p : t) (origin : vec) (yaw : float) (pitch : float) : unit =
  p.body.origin <- origin;
  p.body.yaw <- yaw;
  p.body.velocity <- zero;
  p.pitch <- pitch

let yaw (p : t) : float = p.body.yaw

(* V_CalcBob: up and down with the steps, as fast as the walk *)
let bob (p : t) : float =
  let cycle = Float.rem p.time 0.6 /. 0.6 in
  let pi = 4. *. atan 1. in
  let cycle =
    if cycle < 0.5 then pi *. cycle /. 0.5
    else pi +. (pi *. (cycle -. 0.5) /. 0.5)
  in
  let b = p.bob_speed *. 0.02 in
  let b = (b *. 0.3) +. (b *. 0.7 *. sin cycle) in
  Float.max (-7.) (Float.min 4. b)

let eye (p : t) : vec =
  add p.body.origin { x = 0.; y = 0.; z = view_height +. bob p }

let bmodels (p : t) : (int * int * vec * int) list = Brushes.drawn p.brushes

(*****************************************************************************)
(* The move (sv_phys.c) *)
(*****************************************************************************)

let trace (p : t) (start : vec) (finish : vec) : Trace.trace =
  Trace.move p.level 1 start finish (Brushes.solids p.brushes)

(* the velocity along the plane (ClipVelocity), its tiny parts zero *)
let clip_velocity (v : vec) (n : vec) : vec =
  let backoff = dot v n in
  let c (a : float) : float = if a > -0.1 && a < 0.1 then 0. else a in
  let r = sub v (scale backoff n) in
  { x = c r.x; y = c r.y; z = c r.z }

(* SV_FlyMove: the box along its velocity for time, sliding along what
 * it hits, up to 4 planes; 1 a floor was hit, 2 a wall (a step?) *)
let fly_move (p : t) (time : float) : int =
  let b = p.body in
  let primal = b.velocity in
  let original = ref b.velocity in
  let planes = ref []
  and blocked = ref 0
  and time_left = ref time
  and bump = ref 0
  and stop = ref false in
  while (not !stop) && !bump < 4 do
    incr bump;
    if b.velocity = zero then stop := true
    else begin
      let t = trace p b.origin (add b.origin (scale !time_left b.velocity)) in
      if t.allsolid then begin
        b.velocity <- zero;
        blocked := 3;
        stop := true
      end
      else begin
        if t.fraction > 0. then begin
          b.origin <- t.endpos;
          original := b.velocity;
          planes := []
        end;
        if t.fraction = 1. then stop := true
        else begin
          if t.normal.z > 0.7 then begin
            blocked := !blocked lor 1;
            b.onground <- true;
            b.ground <- t.hit
          end;
          if t.normal.z = 0. then blocked := !blocked lor 2;
          time_left := !time_left -. (!time_left *. t.fraction);
          planes := !planes @ [ t.normal ];
          (* along a plane that keeps the others' sides, or the crease
           * of two *)
          let along =
            List.find_map
              (fun (n : vec) ->
                let v = clip_velocity !original n in
                if
                  List.for_all
                    (fun (o : vec) -> o == n || dot v o >= 0.)
                    !planes
                then Some v
                else None)
              !planes
          in
          (match along with
          | Some v -> b.velocity <- v
          | None -> (
              match !planes with
              | [ a; c ] ->
                  let dir = cross a c in
                  b.velocity <- scale (dot dir b.velocity) dir
              | _ ->
                  b.velocity <- zero;
                  blocked := 7;
                  stop := true));
          (* (against the first velocity: stop, no jitter in corners) *)
          if dot b.velocity primal <= 0. then begin
            b.velocity <- zero;
            stop := true
          end
        end
      end
    end
  done;
  !blocked

(* SV_PushEntity: moved by a vector, as far as it goes *)
let push_entity (p : t) (move : vec) : Trace.trace =
  let t = trace p p.body.origin (add p.body.origin move) in
  p.body.origin <- t.endpos;
  t

(* SV_WalkMove: the slide, or the same 18 units up and put down *)
let walk_move (p : t) (dt : float) : unit =
  let b = p.body in
  let oldonground = b.onground in
  b.onground <- false;
  let oldorg = b.origin and oldvel = b.velocity in
  let clip = fly_move p dt in
  if clip land 2 <> 0 && (oldonground || p.waterlevel > 0) then begin
    let nosteporg = b.origin and nostepvel = b.velocity in
    b.origin <- oldorg;
    ignore (push_entity p { x = 0.; y = 0.; z = stepsize });
    b.velocity <- { oldvel with z = 0. };
    ignore (fly_move p dt);
    let down =
      push_entity p { x = 0.; y = 0.; z = -.stepsize +. (oldvel.z *. dt) }
    in
    if down.fraction < 1. && down.normal.z > 0.7 then begin
      b.onground <- true;
      b.ground <- down.hit
    end
    else begin
      (* not on a floor: the move without the step *)
      b.origin <- nosteporg;
      b.velocity <- nostepvel
    end
  end

(*****************************************************************************)
(* The wish (sv_user.c) *)
(*****************************************************************************)

let user_friction (p : t) (dt : float) : unit =
  let v = p.body.velocity in
  let speed = sqrt ((v.x *. v.x) +. (v.y *. v.y)) in
  if speed > 0. then begin
    (* over a drop, more friction: the edge's *)
    let o = p.body.origin in
    let start =
      {
        x = o.x +. (v.x /. speed *. 16.);
        y = o.y +. (v.y /. speed *. 16.);
        z = o.z +. player_mins.z;
      }
    in
    let t =
      Trace.move p.level 0 start
        { start with z = start.z -. 34. }
        (Brushes.solids p.brushes)
    in
    let f = if t.fraction = 1. then friction *. edgefriction else friction in
    let control = if speed < stopspeed then stopspeed else speed in
    let newspeed = Float.max 0. (speed -. (dt *. control *. f)) in
    p.body.velocity <- scale (newspeed /. speed) v
  end

let accelerate_to (p : t) (dt : float) (wishdir : vec) (wishspeed : float)
    (cap : float) : unit =
  let current = dot p.body.velocity wishdir in
  let add_speed = Float.min cap wishspeed -. current in
  if add_speed > 0. then begin
    let a = Float.min add_speed (accelerate *. dt *. wishspeed) in
    p.body.velocity <- add p.body.velocity (scale a wishdir)
  end

let water_move (p : t) (dt : float) (fmove : float) (smove : float)
    (umove : float) : unit =
  let f, r, _ = View.angle_vectors p.pitch p.body.yaw in
  let wish = add (scale fmove f) (scale smove r) in
  let wish =
    if fmove = 0. && smove = 0. && umove = 0. then
      { wish with z = wish.z -. 60. }
    else { wish with z = wish.z +. umove }
  in
  let wishspeed = Float.min maxspeed (length wish) *. 0.7 in
  let v = p.body.velocity in
  let speed = length v in
  let newspeed =
    if speed > 0. then Float.max 0. (speed -. (dt *. speed *. friction)) else 0.
  in
  if speed > 0. then p.body.velocity <- scale (newspeed /. speed) v;
  if wishspeed > 0. && wishspeed -. newspeed > 0. then begin
    let a = Float.min (wishspeed -. newspeed) (accelerate *. wishspeed *. dt) in
    p.body.velocity <- add p.body.velocity (scale a (normalize wish))
  end

(* SV_CheckWater: how deep *)
let check_water (p : t) : unit =
  let o = p.body.origin in
  let wet (z : float) : bool =
    match Trace.point_contents p.level { o with z = o.z +. z } with
    | Water | Slime | Lava -> true
    | _ -> false
  in
  p.waterlevel <-
    (if not (wet (player_mins.z +. 1.)) then 0
     else if not (wet ((player_mins.z +. player_maxs.z) *. 0.5)) then 1
     else if not (wet view_height) then 2
     else 3)

let frame (p : t) (dt : float) (c : command) : unit =
  p.time <- p.time +. dt;
  let b = p.body in
  if not (Brushes.exited p.brushes) then begin
    (* the turns: 140 degrees a second, 210 running *)
    let turn = (if c.run then 1.5 else 1.) *. 140. *. dt in
    if c.left then b.yaw <- b.yaw +. turn;
    if c.right then b.yaw <- b.yaw -. turn;
    if c.look_up then p.pitch <- Float.max (-70.) (p.pitch -. (150. *. dt));
    if c.look_down then p.pitch <- Float.min 80. (p.pitch +. (150. *. dt));
    let k = if c.run then 2. else 1. in
    let fmove =
      k *. 200. *. ((if c.forward then 1. else 0.) -. if c.back then 1. else 0.)
    in
    let smove =
      k *. 350.
      *. ((if c.strafe_right then 1. else 0.)
         -. if c.strafe_left then 1. else 0.)
    in
    check_water p;
    (* the jump (player.qc's PlayerJump): once a press, from the
     * ground; in water, up *)
    let umove = if c.jump && p.waterlevel >= 2 then 200. else 0. in
    if c.jump && p.jump_released && b.onground && p.waterlevel < 2 then begin
      b.velocity <- { b.velocity with z = b.velocity.z +. 270. };
      b.onground <- false;
      p.jump_released <- false
    end;
    if not c.jump then p.jump_released <- true;
    if p.waterlevel >= 2 then water_move p dt fmove smove umove
    else begin
      (* the wish on the ground's plane: the yaw only *)
      let f, r, _ = View.angle_vectors 0. b.yaw in
      let wish = add (scale fmove f) (scale smove r) in
      let wishspeed = length wish in
      let wishdir =
        if wishspeed > 0. then scale (1. /. wishspeed) wish else zero
      in
      let wishspeed = Float.min maxspeed wishspeed in
      if b.onground then begin
        user_friction p dt;
        accelerate_to p dt wishdir wishspeed wishspeed
      end
      else accelerate_to p dt wishdir wishspeed 30.
    end;
    (* gravity, out of the water *)
    if p.waterlevel <= 1 then
      b.velocity <- { b.velocity with z = b.velocity.z -. (gravity *. dt) };
    walk_move p dt;
    p.bob_speed <-
      sqrt ((b.velocity.x *. b.velocity.x) +. (b.velocity.y *. b.velocity.y));
    Brushes.touch p.brushes b p.time;
    if c.use_key && p.use_released then begin
      let f, _, _ = View.angle_vectors p.pitch b.yaw in
      Brushes.use p.brushes b (eye p) f p.time
    end;
    p.use_released <- not c.use_key
  end;
  Brushes.run p.brushes b p.time dt
