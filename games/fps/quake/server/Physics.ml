(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Physics.mli *)

open Model
open Edict

let gravity = 800.
let stepsize = 18.

type hit = {
  fraction : float;
  endpos : vec;
  normal : vec;
  startsolid : bool;
  allsolid : bool;
  what : who;
  sky : bool;
}

(* (is this one ignored by a move of pass's: itself, its owner, what it
 * owns) *)
let ignored (pass : who) (e : who) : bool =
  same pass e
  || (match pass with Ent p -> same p.owner e | _ -> false)
  || match e with Ent x -> same x.owner pass | _ -> false

let trace_with (w : world) (start : vec) (mins : vec) (maxs : vec)
    (finish : vec) (pass : who) (monsters : bool) : hit =
  let point = mins = zero && maxs = zero in
  let t =
    Trace.move w.level
      (if point then 0 else 1)
      start finish
      (Brushes.solids w.play.brushes)
  in
  (* (a missile into the sky: what it hit was the sky's face) *)
  let sky =
    t.fraction < 1.
    && Trace.point_contents w.level (add t.endpos (scale (-1.) t.normal))
       = (Sky : contents)
  in
  let best =
    ref
      {
        fraction = t.fraction;
        endpos = t.endpos;
        normal = t.normal;
        startsolid = t.startsolid;
        allsolid = t.allsolid;
        what = Nobody;
        sky;
      }
  in
  let clip (who : who) ((o, omins, omaxs) : vec * vec * vec) : unit =
    if not (ignored pass who) then
      match
        Trace.box start finish (sub (add o omins) maxs) (sub (add o omaxs) mins)
      with
      | Some b when b.fraction < !best.fraction && not b.startsolid ->
          best :=
            {
              fraction = b.fraction;
              endpos = b.endpos;
              normal = b.normal;
              startsolid = false;
              allsolid = false;
              what = who;
              sky = false;
            }
      | _ -> ()
  in
  if monsters then
    List.iter
      (fun (e : t) ->
        if e.solid && not e.removed then clip (Ent e) (e.origin, e.mins, e.maxs))
      w.ents;
  (* (nomonsters: no entity at all, the player neither: QuakeC's
   * visible looks through every one) *)
  if monsters && w.client.phealth > 0. then clip The_player (where w The_player);
  !best

let trace (w : world) (start : vec) (mins : vec) (maxs : vec) (finish : vec)
    (pass : who) : hit =
  trace_with w start mins maxs finish pass true

let traceline (w : world) (start : vec) (finish : vec) (monsters : bool)
    (pass : who) : hit =
  trace_with w start zero zero finish pass monsters

(*****************************************************************************)
(* The monsters' steps (sv_move.c) *)
(*****************************************************************************)

(* SV_movestep: 18 up, the move, down twice that: on a floor, the step
 * taken; in the air (a ledge), refused. (The box is tested where it
 * ends, not swept across: a step is shorter than the box) *)
let move_step (w : world) (e : t) (move : vec) : bool =
  let neworg = add e.origin move in
  let start = { neworg with z = neworg.z +. stepsize } in
  let finish = { neworg with z = neworg.z -. (stepsize *. 2.) } in
  let t = trace w start e.mins e.maxs finish (Ent e) in
  let t =
    if t.startsolid then
      trace w
        { start with z = start.z -. stepsize }
        e.mins e.maxs finish (Ent e)
    else t
  in
  if t.allsolid || t.startsolid || t.fraction = 1. then false
  else if t.normal.z < 0.7 then false
  else begin
    e.origin <- t.endpos;
    e.onground <- true;
    true
  end

let anglemod (a : float) : float =
  let a = Float.rem a 360. in
  if a < 0. then a +. 360. else a

let change_yaw (e : t) : unit =
  let current = anglemod e.yaw in
  let move = e.ideal_yaw -. current in
  let move =
    if move > 180. then move -. 360.
    else if move < -180. then move +. 360.
    else move
  in
  let speed = 20. in
  let move = Float.max (-.speed) (Float.min speed move) in
  e.yaw <- anglemod (current +. move)

let walk_move (w : world) (e : t) (yaw : float) (dist : float) : bool =
  let a = yaw *. Float.pi /. 180. in
  move_step w e { x = Float.cos a *. dist; y = Float.sin a *. dist; z = 0. }

(* SV_StepDirection: turn that way, and step if not turning too much *)
let step_direction (w : world) (e : t) (yaw : float) (dist : float) : bool =
  e.ideal_yaw <- yaw;
  change_yaw e;
  let old = e.origin in
  if walk_move w e yaw dist then begin
    let delta = anglemod (e.yaw -. e.ideal_yaw) in
    (* (not facing it yet: back where it was, but the turn kept) *)
    if delta > 45. && delta < 315. then e.origin <- old;
    true
  end
  else false

(* SV_NewChaseDir: as Doom's P_NewChaseDir, in degrees *)
let new_chase_dir (w : world) (e : t) (goal : vec) (dist : float) : unit =
  let olddir = anglemod (Float.round (e.ideal_yaw /. 45.) *. 45.) in
  let turnaround = anglemod (olddir -. 180.) in
  let dx = goal.x -. e.origin.x and dy = goal.y -. e.origin.y in
  let d1 = if dx > 10. then 0. else if dx < -10. then 180. else -1. in
  let d2 = if dy < -10. then 270. else if dy > 10. then 90. else -1. in
  let try_dir (d : float) : bool =
    d <> -1. && d <> turnaround && step_direction w e d dist
  in
  let diag =
    if d1 <> -1. && d2 <> -1. then
      if d1 = 0. then if d2 = 90. then 45. else 315.
      else if d2 = 90. then 135.
      else 215.
    else -1.
  in
  if not (try_dir diag) then begin
    let d1, d2 =
      if random w < 0.25 || Float.abs dy > Float.abs dx then (d2, d1)
      else (d1, d2)
    in
    if not (try_dir d1 || try_dir d2 || try_dir olddir) then begin
      let dirs = [ 0.; 45.; 90.; 135.; 180.; 225.; 270.; 315. ] in
      let dirs = if random w < 0.5 then dirs else List.rev dirs in
      if not (List.exists try_dir dirs) then
        if not (step_direction w e turnaround dist) then e.ideal_yaw <- olddir
    end
  end

(* SV_CloseEnough: within dist of the goal's box *)
let close_enough (w : world) (e : t) (goal : who) (dist : float) : bool =
  let o, mins, maxs = where w goal in
  let a = add o mins and b = add o maxs in
  let em = add e.origin e.mins and ex = add e.origin e.maxs in
  not
    (a.x > ex.x +. dist
    || b.x < em.x -. dist
    || a.y > ex.y +. dist
    || b.y < em.y -. dist
    || a.z > ex.z +. dist
    || b.z < em.z -. dist)

let move_to_goal (w : world) (e : t) (dist : float) : unit =
  let chasing = e.onground && alive w e.enemy in
  if chasing && not (close_enough w e e.enemy dist) then begin
    let goal, _, _ = where w e.enemy in
    (* (a fourth of the time, or blocked: another way) *)
    if random w < 0.25 || not (step_direction w e e.ideal_yaw dist) then
      new_chase_dir w e goal dist
  end

(*****************************************************************************)
(* SV_Physics *)
(*****************************************************************************)

(* ClipVelocity: the part into the plane taken away, times backoff *)
let clip_velocity (v : vec) (n : vec) (backoff : float) : vec =
  let b = dot v n *. backoff in
  sub v (scale b n)

(* SV_PushEntity: moved as far as it goes, what it hit touched *)
let push_entity (w : world) (e : t) (move : vec) : hit =
  let t = trace w e.origin e.mins e.maxs (add e.origin move) (Ent e) in
  e.origin <- t.endpos;
  if t.fraction < 1. && not t.sky then e.touch w e t.what;
  if t.fraction < 1. && t.sky then remove w e;
  t

(* SV_Physics_Toss: Toss, Bounce, Fly_missile *)
let toss (w : world) (e : t) (dt : float) : unit =
  if not e.onground then begin
    if e.movetype <> Fly_missile then
      e.velocity <- { e.velocity with z = e.velocity.z -. (gravity *. dt) };
    let t = push_entity w e (scale dt e.velocity) in
    if t.fraction < 1. && not e.removed then begin
      let backoff = if e.movetype = Bounce then 1.5 else 1. in
      e.velocity <- clip_velocity e.velocity t.normal backoff;
      (* (on a floor: stopped once slow, as a toss at once) *)
      if t.normal.z > 0.7 then
        if e.velocity.z < 60. || e.movetype <> Bounce then begin
          e.onground <- true;
          e.velocity <- zero
        end
    end
  end

(* SV_Physics_Step: a monster falls when it is not on the ground (a
 * dog's leap, a floor gone) *)
let step (w : world) (e : t) (dt : float) : unit =
  if not e.onground then begin
    e.velocity <- { e.velocity with z = e.velocity.z -. (gravity *. dt) };
    let t = push_entity w e (scale dt e.velocity) in
    if t.fraction < 1. then begin
      e.velocity <- clip_velocity e.velocity t.normal 1.;
      if t.normal.z > 0.7 then begin
        e.onground <- true;
        e.velocity <- zero
      end
    end
  end

(* SV_RunThink: its think when its time comes, as often as it asks
 * within this frame *)
let run_think (w : world) (e : t) : unit =
  let guard = ref 0 in
  while
    (not e.removed) && e.nextthink > 0. && e.nextthink <= time w && !guard < 8
  do
    incr guard;
    e.nextthink <- 0.;
    e.think w e
  done

let run (w : world) (e : t) (dt : float) : unit =
  if not e.removed then begin
    (match e.movetype with
    | Toss | Bounce | Fly_missile -> toss w e dt
    | Step -> step w e dt
    | Mnone -> ());
    run_think w e
  end
