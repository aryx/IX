(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Screens.mli *)

(* ix: the author's playground's games/racing/TinyVirtuaRacing.ml, its
 * race's display (time_text, minimap, tachometer, hud_race) and its
 * scenes' texts (in its view) *)

module P = Playground

let text (color : P.color) (size : float) (str : string) : P.shape =
  P.words color str |> P.scale size

let time_text (frames : int) : string =
  let frames = max 0 frames in
  Printf.sprintf "%d'%02d\"%02d" (frames / 3600)
    (frames / 60 mod 60)
    (frames mod 60 * 100 / 60)

(* the course's map, bottom right, its level under it; the rivals dots,
 * the player a red marker *)
let minimap (screen : P.screen) (c : Course.t) (d : Driving.t)
    (rivals : Rivals.t list) : P.shape list =
  let x0, x1, z0, z1 = Course.bounds c in
  let k = 170. /. Float.max (x1 -. x0) (z1 -. z0) in
  let cx = screen.right -. 120. and cy = screen.bottom +. 150. in
  let at (px : float) (pz : float) : float * float =
    ( cx +. ((px -. ((x0 +. x1) /. 2.)) *. k),
      cy -. ((pz -. ((z0 +. z1) /. 2.)) *. k) )
  in
  let n = Track3d.segments c.ribbon in
  let dots =
    List.init (n / 6) (fun (j : int) ->
        let p =
          Track3d.at c.ribbon (float_of_int (6 * j) *. Track3d.step c.ribbon)
        in
        let x, y = at p.px p.pz in
        P.square (P.rgb 230 230 230) 3. |> P.move x y)
  in
  let others =
    List.map
      (fun (r : Rivals.t) ->
        let p = Track3d.at c.ribbon r.rs in
        let x, y = at p.px p.pz in
        P.circle (P.rgb 60 140 255) 3.5 |> P.move x y)
      rivals
  in
  let x, y = at d.car.x (-.d.car.y) in
  dots @ others
  @ [
      P.circle P.red 6. |> P.move x y;
      text P.yellow 2. c.level |> P.move cx (cy -. 110.);
    ]

(* the tachometer, an arc on the left: the revs round it, the yellow
 * zone where to change gear, the red one past it, the needle *)
let tachometer (screen : P.screen) (rpm : float) (gear : int) : P.shape list =
  let cx = screen.left +. 120. and cy = screen.bottom +. 190. in
  let r = 80. in
  let angle (f : float) : float = 210. -. (240. *. f) in
  let marks =
    List.init 25 (fun (k : int) ->
        let f = float_of_int k /. 24. in
        let color =
          if f > 0.92 then P.red else if f > 0.78 then P.yellow else P.white
        in
        let a = angle f *. Float.pi /. 180. in
        P.rectangle color 4. 14.
        |> P.rotate (angle f -. 90.)
        |> P.move (cx +. (r *. cos a)) (cy +. (r *. sin a)))
  in
  let a = angle (Float.min 1. rpm) in
  let ar = a *. Float.pi /. 180. in
  let needle =
    P.rectangle (P.rgb 255 90 40) 72. 4.
    |> P.rotate a
    |> P.move (cx +. (36. *. cos ar)) (cy +. (36. *. sin ar))
  in
  marks
  @ [
      needle;
      P.circle (P.rgb 40 40 40) 22. |> P.move cx cy;
      text P.white 2.5 (string_of_int gear) |> P.move cx cy;
    ]

let race (screen : P.screen) (blink : P.shape list -> P.shape list)
    (c : Course.t) (r : Race.t) : P.shape list =
  let top = screen.top and left = screen.left and right = screen.right in
  let bottom = screen.bottom in
  let d = r.drive in
  let lap_now = max 1 (min c.laps (Race.lap c d + 1)) in
  let current = r.time - List.fold_left ( + ) 0 r.lap_times in
  let best =
    match r.lap_times with
    | [] -> None
    | l -> Some (List.fold_left min max_int l)
  in
  let hurry = r.clock < 10 * 60 && r.time > 0 in
  [
    text P.white 2. "TIME" |> P.move_y (top -. 30.);
    text
      (if hurry then P.red else P.yellow)
      7.
      (string_of_int ((r.clock + 59) / 60))
    |> P.move_y (top -. 80.);
    text P.white 2. "LAP TIME" |> P.move (right -. 150.) (top -. 30.);
    text P.white 2.8 (time_text (max 0 current))
    |> P.move (right -. 150.) (top -. 62.);
    text P.yellow 2.4
      (match best with
      | Some b -> "BEST " ^ time_text b
      | None -> "")
    |> P.move (right -. 150.) (top -. 96.);
    text P.white 2.4
      (Printf.sprintf "SPEED %3.0f km/h" (Driving.kmh d.car.speed))
    |> P.move (left +. 170.) (bottom +. 70.);
    text P.white 2.4
      (if c.laps > 1 then Printf.sprintf "LAPS %d/%d" lap_now c.laps else c.name)
    |> P.move (left +. 170.) (bottom +. 35.);
  ]
  @ (if c.rivals > 0 then
       [
         text P.white 2. "POSITION" |> P.move (left +. 110.) (top -. 30.);
         text P.yellow 4.
           (Printf.sprintf "%s/%d"
              (Rivals.ordinal (Rivals.position d r.rivals))
              (c.rivals + 1))
         |> P.move (left +. 110.) (top -. 70.);
       ]
     else [])
  @ tachometer screen (Race.revs d) (Race.gear d)
  @ minimap screen c d r.rivals
  @ (if r.time < 0 then
       [
         text P.yellow 12. (string_of_int (((-r.time - 1) / 60) + 1))
         |> P.move_y 150.;
       ]
     else if r.time < 60 then
       [ text (P.rgb 60 230 90) 12. "GO!" |> P.move_y 150. ]
     else [])
  @
  let msg, until = r.message in
  if r.time < until then blink [ text P.yellow 4. msg |> P.move_y 180. ] else []

let title (blink : P.shape list -> P.shape list) : P.shape list =
  [
    text (P.rgb 250 60 40) 7. "TINY VIRTUA RACING" |> P.move_y 300.;
    text P.white 2.5
      "up: accelerate   down: brake   left/right: steer   v: view"
    |> P.move_y 230.;
  ]
  @ blink [ text P.yellow 3. "PRESS SPACE" |> P.move_y 170. ]

let select (screen : P.screen) (blink : P.shape list -> P.shape list)
    (c : Course.t) : P.shape list =
  [
    text P.white 4. "SELECT COURSE" |> P.move_y (screen.top -. 60.);
    text (P.rgb 250 140 30) 7. (Printf.sprintf "<  %s  >" c.name)
    |> P.move_y (screen.bottom +. 170.);
    text P.white 3.
      (Printf.sprintf "%s   %s   %.1f km" c.level
         (if c.laps > 1 then Printf.sprintf "%d LAPS" c.laps else "TO THE GOAL")
         (Course.lap_length c /. 1000.))
    |> P.move_y (screen.bottom +. 110.);
  ]
  @ blink
      [
        text P.yellow 3. "left/right: course    space: race"
        |> P.move_y (screen.bottom +. 60.);
      ]

let finished (blink : P.shape list -> P.shape list) (c : Course.t) (r : Race.t)
    : P.shape list =
  if r.over then
    [
      text P.red 8. "GAME OVER" |> P.move_y 250.;
      text P.white 3. (Printf.sprintf "%d LAPS DONE" (List.length r.lap_times))
      |> P.move_y 170.;
    ]
    @ blink [ text P.white 3. "PRESS SPACE" |> P.move_y 100. ]
  else
    [
      text P.yellow 8. "GOAL!" |> P.move_y 250.;
      text P.white 4. (Printf.sprintf "TIME %s" (time_text r.time))
      |> P.move_y 160.;
    ]
    @ (match r.lap_times with
      | [] | [ _ ] -> []
      | times ->
          [
            text P.white 3.
              (Printf.sprintf "BEST LAP %s"
                 (time_text (List.fold_left min max_int times)))
            |> P.move_y 110.;
          ])
    @ (if c.rivals > 0 then
         [
           text P.white 3.
             (Printf.sprintf "POSITION %s"
                (Rivals.ordinal (Rivals.position r.drive r.rivals)))
           |> P.move_y 70.;
         ]
       else [])
    @ blink [ text P.white 3. "PRESS SPACE" |> P.move_y 20. ]
