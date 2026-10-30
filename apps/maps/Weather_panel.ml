(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Weather_panel.mli *)

module P = Playground

type state = Waiting | Came of Weather.t | Failed of string

let width (fw : float) : float = Float.min 300. (fw -. 12.)
let left (fw : float) : float = (fw /. 2.) -. width fw -. 6.
let top (fh : float) : float = (fh /. 2.) -. 6.
let foot (fh : float) : float = (-.fh /. 2.) +. 26.

let inside (fw : float) (fh : float) (mx : float) (my : float) : bool =
  mx >= left fw && mx <= left fw +. width fw && my <= top fh && my >= foot fh

(* a picture of the sky of [size] (its width) at (x, y) *)
let icon (kind : Weather.kind) (size : float) (x : float) (y : float) : P.shape list =
  let u = size /. 12. in
  let at (s : P.shape) (dx : float) (dy : float) : P.shape = s |> P.move (x +. (dx *. u)) (y +. (dy *. u)) in
  let sun (dx : float) (dy : float) (r : float) : P.shape = at (P.circle (P.rgb 245 180 30) (r *. u)) dx dy in
  let cloud (c : P.color) : P.shape list =
    [ at (P.circle c (2.5 *. u)) (-2.5) 0.; at (P.circle c (3.2 *. u)) 0.5 1.;
      at (P.circle c (2.2 *. u)) 3. (-0.3); at (P.rectangle c (7.5 *. u) (2.6 *. u)) 0.3 (-1.2) ]
  in
  let grey = P.rgb 150 150 160 and light = P.rgb 195 195 205 in
  let drops (c : P.color) : P.shape list =
    List.map (fun (dx : float) -> at (P.rectangle c (0.8 *. u) (2. *. u)) dx (-4.2)) [ -2.5; 0.; 2.5 ]
  in
  match kind with
  | Clear -> [ sun 0. 0. 4. ]
  | Partly -> sun 2. 2. 3. :: cloud light
  | Overcast -> cloud grey
  | Fog -> List.map (fun (dy : float) -> at (P.rectangle light (9. *. u) (1. *. u)) 0. dy) [ 2.5; 0.; -2.5 ]
  | Drizzle -> cloud light @ drops (P.rgb 120 170 230)
  | Rain -> cloud grey @ drops (P.rgb 40 90 200)
  | Snow -> cloud light @ List.map (fun (dx : float) -> at (P.circle (P.rgb 130 170 230) (0.8 *. u)) dx (-4.2)) [ -2.5; 0.; 2.5 ]
  | Storm -> cloud (P.rgb 100 100 115) @ [ at (P.polygon (P.rgb 245 180 30) [ (0.5 *. u, 0.); (-1.5 *. u, -3. *. u); (0., -3. *. u); (-1. *. u, -5.5 *. u); (2. *. u, -2. *. u); (0.5 *. u, -2. *. u) ]) 0. (-0.5) ]

(* a temperature in tenths of a degree, a whole number *)
let tenths (t : float) : int = int_of_float (Float.round (t *. 10.))

(* the next hours, a bar each: whole tenths to whole pixels *)
let bars (x : float) (y : float) (room : float) (height : int) (hours : (string * float) list) : P.shape list =
  match hours with
  | [] -> []
  | _ ->
      let values = List.map (fun ((_, t) : string * float) -> tenths t) hours in
      let lo = List.fold_left min max_int values and hi = List.fold_left max min_int values in
      let n = List.length values in
      let step = int_of_float room / n in
      List.mapi
        (fun (i : int) (v : int) ->
          let h = 4 + ((v - lo) * (height - 4) / max 1 (hi - lo)) in
          P.rectangle (P.rgb 240 150 60) (float_of_int (step - 1)) (float_of_int h)
          |> P.move (x +. float_of_int ((i * step) + (step / 2))) (y +. (float_of_int h /. 2.)))
        values

let panel (fw : float) (fh : float) (name : string) (state : state) : P.shape list =
  let x = left fw +. 10. and room = width fw -. 20. in
  let ink = P.rgb 20 20 20 and soft = P.rgb 90 90 90 in
  let line (color : P.color) (y : float) (s : string) : P.shape = fst (Map_look.text color ~size:14. x y (Map_look.cut room s)) in
  let back =
    P.rectangle (P.rgb 252 252 248) (width fw) (top fh -. foot fh)
    |> P.move (left fw +. (width fw /. 2.)) ((top fh +. foot fh) /. 2.)
  in
  let y0 = top fh -. 20. in
  let title = line ink y0 name in
  let body =
    match state with
    | Waiting -> [ line soft (y0 -. 24.) "asking the forecast..." ]
    | Failed why -> [ line soft (y0 -. 24.) why ]
    | Came f ->
        let big = y0 -. 40. in
        let now = fst (Map_look.text ink ~size:30. (x +. 64.) (big -. 12.) (Weather.degrees f.temperature)) in
        let says = line ink (big -. 42.) (Printf.sprintf "%s, wind %.0f km/h" (Weather.words f.code) f.wind) in
        let hot = List.map snd f.hours in
        let range =
          match hot with
          | [] -> ""
          | t :: _ ->
              let lo = List.fold_left Float.min t hot and hi = List.fold_left Float.max t hot in
              Printf.sprintf "the next %d hours: %s to %s" (List.length hot) (Weather.degrees lo) (Weather.degrees hi)
        in
        let row (i : int) (d : Weather.day) : P.shape list =
          let y = big -. 134. -. (float_of_int i *. 24.) in
          if y < foot fh +. 24. then []
          else
            (* (a tenth under 10 mm: 0.2 mm is not "0 mm") *)
            let rain =
              if d.rain >= 10. then Printf.sprintf "%.0f mm" d.rain
              else if d.rain > 0. then Printf.sprintf "%.1f mm" d.rain
              else ""
            in
            [ fst (Map_look.text ink ~size:14. x y (Weather.day_name d.date));
              fst (Map_look.text ink ~size:14. (x +. 92.) y (Weather.degrees d.low ^ " to " ^ Weather.degrees d.high));
              fst (Map_look.text soft ~size:14. (x +. 205.) y rain) ]
            @ icon (Weather.kind d.code) 20. (x +. 72.) (y +. 5.)
        in
        (icon (Weather.kind f.code) 52. (x +. 28.) (big -. 2.) @ [ now; says; line soft (big -. 62.) range ])
        @ bars x (big -. 114.) room 44 f.hours
        @ List.concat (List.mapi row f.days)
        @ [ line soft (foot fh +. 8.) "Open-Meteo.com, CC BY 4.0" ]
  in
  back :: title :: body
