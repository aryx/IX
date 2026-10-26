(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Race.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * race, drive and update; its sounds as events *)

type keys = { up : bool; down : bool; left : bool; right : bool }

type event =
  | Beep
  | Go
  | Shift
  | Crash
  | Checkpoint of int
  | Final_lap
  | Goal
  | Game_over

type t = {
  drive : Driving.t;
  rivals : Rivals.t list;
  time : int;
  clock : int;
  passed : int;
  message : string * int;
  lap_times : int list;
  finished : bool;
  over : bool;
}

let countdown = 180

let start (c : Course.t) : t =
  let slot = if c.rivals > 0 then Cars.player_slot else 0 in
  let d =
    Driving.at c
      (if c.rivals > 0 then Cars.slot_s slot else 0.)
      (if c.rivals > 0 then Cars.slot_lane slot else 0.)
  in
  {
    drive = d;
    rivals = Rivals.grid c;
    time = -countdown - 1;
    clock = c.start_time * 60;
    passed = 0;
    message = ("", 0);
    lap_times = [];
    finished = false;
    over = false;
  }

let lap (c : Course.t) (d : Driving.t) : int =
  int_of_float (Float.floor (d.s /. Course.lap_length c))

let checkpoint (c : Course.t) (d : Driving.t) : int =
  int_of_float
    (Float.floor (d.s /. (Course.lap_length c /. float_of_int c.checkpoints)))

let gears = 7

let gear (d : Driving.t) : int =
  max 1
    (min gears
       (1
       + int_of_float
           (Float.abs d.car.speed /. Driving.top_speed *. float_of_int gears)))

let revs (d : Driving.t) : float =
  let g =
    Float.max 0.
      (Float.abs d.car.speed /. Driving.top_speed *. float_of_int gears)
  in
  let f = g -. float_of_int (int_of_float g) in
  if g >= float_of_int gears then 1.
  else if g < 1. then 0.2 +. (0.8 *. f)
  else 0.45 +. (0.55 *. f)

(* one frame of the cars and the clock: the player's by the keys (after
 * the line, or out of time, steering itself along the road to a stop),
 * the rivals', the bumps *)
let drive (c : Course.t) (k : keys) (r : t) : t * event list =
  let d = r.drive in
  let d' =
    if r.time < 0 then d
    else if r.finished then
      let road =
        Driving.plane_heading (Track3d.at c.ribbon (Driving.wrap c d.s)).heading
      in
      let wanted =
        Float.max (-1.)
          (Float.min 1.
             ((Course.angle_diff d.car.heading road /. 15.)
             +. (d.offset *. 0.08)))
      in
      Driving.steer c (if d.car.speed > 1. then -0.5 else 0.) wanted d
    else
      let gas =
        if k.up then 1.
        else if k.down then if d.car.speed > 1. then -1.6 else -0.5
        else 0.
      in
      let wanted = (if k.left then 1. else 0.) -. if k.right then 1. else 0. in
      Driving.steer c gas wanted d
  in
  let rivals = if r.time < 0 then r.rivals else Rivals.drive c d' r.rivals in
  let d', rivals, bumped =
    if r.time < 0 then (d', rivals, false) else Rivals.bump c d' rivals
  in
  let time = r.time + 1 in
  let events =
    (if gear d' > gear d then [ Shift ] else [])
    @ (if
         (d'.bump = 0 && d.bump > 10)
         || (d'.spin > 0 && d.spin = 0)
         || (bumped && d.bump > 10)
       then [ Crash ]
       else [])
    @ (if time < 0 && time mod 60 = 0 then [ Beep ] else [])
    @ if time = 0 then [ Go ] else []
  in
  ( {
      r with
      drive = d';
      rivals;
      time;
      clock =
        (if time > 0 && not r.finished then max 0 (r.clock - 1) else r.clock);
    },
    events )

let step (c : Course.t) (k : keys) (r : t) : t * event list =
  let r', events = drive c k r in
  if r.finished then (r', events)
  else
    let lap_done = lap c r'.drive in
    let cp = checkpoint c r'.drive in
    let lap_time = r'.time - List.fold_left ( + ) 0 r.lap_times in
    if cp > r.passed && cp >= 1 && lap_done >= c.laps then
      (* the goal *)
      ( {
          r' with
          lap_times = lap_time :: r.lap_times;
          passed = cp;
          finished = true;
        },
        events @ [ Goal ] )
    else if cp > r.passed && cp >= 1 then begin
      (* a checkpoint: time added; at the line, a lap done *)
      let at_line = cp mod c.checkpoints = 0 in
      let lap_times =
        if at_line then lap_time :: r.lap_times else r.lap_times
      in
      let best =
        at_line && List.for_all (fun (t : int) -> lap_time < t) r.lap_times
      in
      let final = at_line && lap_done = c.laps - 1 in
      let message =
        if final then "FINAL LAP"
        else if best then Printf.sprintf "TIME BONUS  +%d   BEST LAP" c.bonus
        else Printf.sprintf "TIME BONUS  +%d" c.bonus
      in
      ( {
          r' with
          passed = cp;
          clock = r'.clock + (c.bonus * 60);
          lap_times;
          message = (message, r'.time + 150);
        },
        events @ [ Checkpoint cp ] @ if final then [ Final_lap ] else [] )
    end
    else if r'.clock = 0 && r'.time > 0 then
      ({ r' with finished = true; over = true }, events @ [ Game_over ])
    else (r', events)
