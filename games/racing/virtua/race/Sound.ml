(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sound.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * "Sound" (and its update's plays) *)

let engine (rpm : float) (throttle : bool) (tunnel : bool) : unit =
  let hz = 45. +. (110. *. rpm) in
  let open_ = if throttle then 1. else 0.3 in
  let room = if tunnel then 1.6 else 1. in
  Audio.keep_playing "engine"
    (Audio.sawtooth hz
    |> Audio.low_pass ((400. +. (2400. *. rpm *. open_)) /. room)
    |> Audio.louder ((0.05 +. (0.04 *. open_)) *. room));
  Audio.keep_playing "engine_low"
    (Audio.square (hz /. 2.)
    |> Audio.low_pass 300.
    |> Audio.louder (0.05 *. room))

let road (d : Driving.t) : unit =
  let frac = Float.abs d.car.speed /. Driving.top_speed in
  let slide = Float.abs (Driving.slip d) in
  if
    Float.abs d.offset > 1.15 *. Course.road_width && Float.abs d.car.speed > 3.
  then
    Audio.keep_playing "gravel"
      (Audio.noise 500.
      |> Audio.low_pass (200. +. (600. *. frac))
      |> Audio.louder 0.15)
  else if (slide > 4. || d.spin > 0) && Float.abs d.car.speed > 25. then
    Audio.keep_playing "squeal"
      (Audio.triangle 1050. |> Audio.vibrato 11. 0.5
      |> Audio.louder
           (if d.spin > 0 then 0.06 else Float.min 0.06 (0.006 *. slide)));
  if frac > 0.3 then
    Audio.keep_playing "wind"
      (Audio.noise 6000. |> Audio.high_pass 1500.
      |> Audio.louder (0.03 *. frac *. frac))

let beep =
  Audio.sfx { Sfx.blip with frequency = 440.; sustain = 0.15; volume = 0.3 }

let go_beep =
  Audio.sfx { Sfx.blip with frequency = 880.; sustain = 0.5; volume = 0.3 }

let shift =
  Audio.noise 900. |> Audio.lasting 0.07 |> Audio.fading |> Audio.louder 0.12

let crash = Audio.sfx { Sfx.hit with volume = 0.35 }

let final_lap =
  Audio.after
    [
      Audio.square 660. |> Audio.lasting 0.12;
      Audio.square 880. |> Audio.lasting 0.3;
    ]
  |> Audio.louder 0.2

(* the checkpoints' jingles: the arcade played one of a dozen short
 * ones, cut off before their end; here three, in turn *)
let jingles =
  List.map
    (fun (notes : string) ->
      Audio.abc (Printf.sprintf "X:1\nL:1/16\nQ:1/4=150\nK:C\n%s|\n" notes)
      |> Audio.louder 0.22)
    [ "c2e2g2c'4"; "g2e2c'2g2e'4"; "d2f2a2d'2c'4" ]

let fanfare =
  Audio.abc "X:1\nL:1/8\nQ:1/4=160\nK:C\nG2 c2 e2 g4 e2 | g6 z2 |\n"
  |> Audio.louder 0.25

let game_over =
  Audio.after
    [
      Audio.square 392. |> Audio.lasting 0.25;
      Audio.square 330. |> Audio.lasting 0.25;
      Audio.square 262. |> Audio.lasting 0.6;
    ]
  |> Audio.louder 0.2

let pick = Audio.sfx { Sfx.blip with frequency = 660.; volume = 0.25 }

let event (e : Race.event) : unit =
  match e with
  | Beep -> Audio.play beep
  | Go -> Audio.play go_beep
  | Shift -> Audio.play shift
  | Crash -> Audio.play crash
  | Checkpoint cp -> Audio.play (List.nth jingles (cp mod List.length jingles))
  | Final_lap -> Audio.play final_lap
  | Goal -> Audio.play fanfare
  | Game_over -> Audio.play game_over
