(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyAppOrrery.mli *)
module P = TinyLibPlayground

(*****************************************************************************)
(* The planets *)
(*****************************************************************************)

(* The numbers come from the twin's Planets.ml (JPL's elements at J2000):
 * the distance is 42 sqrt a pixels, for a semi-major axis of a AU; the
 * radius is 2 + 3 sqrt (R / R_earth) pixels; the period is 365.25 a^1.5
 * days (Kepler's third law); the angle on 2000-01-01 is the mean
 * longitude, in 4096ths of a turn. *)
type planet = {
  name : string; colour : int; distance : int; radius : int;
  period : int; start : int;
}

let planet name colour distance radius period start =
  { name = name; colour = colour; distance = distance; radius = radius;
    period = period; start = start }

let planets = [
  planet "Mercury" 0xaa 26 4 88 2870;
  planet "Venus" 231 36 5 225 2071;
  planet "Earth" 54 42 5 365 1143;
  planet "Mars" 240 52 4 687 4044;
  planet "Jupiter" 130 96 12 4335 391;
  planet "Saturn" 248 130 11 10757 568;
  planet "Uranus" 50 184 8 30703 3564;
  planet "Neptune" 129 230 8 60226 3469;
]

(* where the Sun is, and the screen *)
let cx = 400
let cy = 240
let width = 640
let height = 480

(*****************************************************************************)
(* Angles, with integers *)
(*****************************************************************************)

(* A planet's angle after d days: where it was on 2000-01-01, plus its
 * share of a turn. The days are taken modulo the period first, so the
 * product stays small. *)
let angle (p : planet) d = p.start + ((d mod p.period) * 4096 / p.period)

(* its centre on the screen; y goes down, so the planets turn
 * counterclockwise, as seen from the north *)
let place (p : planet) d =
  let a = angle p d in
  cx + (p.distance * P.cos a / 1024), cy - (p.distance * P.sin a / 1024)

(*****************************************************************************)
(* Dates *)
(*****************************************************************************)

(* The date d days after 2000-01-01, by Howard Hinnant's
 * civil_from_days, as the twin does it (2000-01-01 is day 10957 of
 * 1970). *)
let two n = if n < 10 then "0" ^ string_of_int n else string_of_int n

let date d =
  let z = d + 10957 + 719468 in
  let era = z / 146097 in
  let doe = z - (era * 146097) in
  let yoe = (doe - (doe / 1460) + (doe / 36524) - (doe / 146096)) / 365 in
  let doy = doe - ((365 * yoe) + (yoe / 4) - (yoe / 100)) in
  let mp = ((5 * doy) + 2) / 153 in
  let day = doy - (((153 * mp) + 2) / 5) + 1 in
  let month = if mp < 10 then mp + 3 else mp - 9 in
  let year = yoe + (era * 400) + (if month <= 2 then 1 else 0) in
  string_of_int year ^ "-" ^ two month ^ "-" ^ two day

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* the days since 2000-01-01, the days that pass in a frame, and
 * whether the time stands still *)
type model = { days : int; speed : int; paused : bool }

let key k m =
  match k with
  | P.Up -> { m with speed = min 512 (m.speed * 2) }
  | P.Down -> { m with speed = max 1 (m.speed / 2) }
  | P.Char ' ' -> { m with paused = not m.paused }
  | P.Char 'r' -> { m with days = 0 }
  | _ -> m

let frame m = if m.paused then m else { m with days = m.days + m.speed }

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

(* a circle of radius r around (x, y): the ellipse in its box *)
let disc colour x y r = P.Move (x - r, y - r, P.Disc (colour, (2 * r) + 1, (2 * r) + 1))
let ring colour x y r =
  P.Move (x - r, y - r, P.Ellipse (colour, (2 * r) + 1, (2 * r) + 1))

(* The ground, which does not move: the night, its stars (dots from
 * the playground's random numbers, the same each time), the orbits and
 * the Sun. It is one value, so the playground sees it is the same at
 * each frame and draws it once. *)
let ground =
  let rec stars n seed acc =
    if n = 0 then acc
    else
      let seed = P.random seed in
      let x = seed mod width and y = (seed / width) mod height in
      stars (n - 1) seed (P.Move (x, y, P.Rect (0x55, 1, 1)) :: acc) in
  P.Group
    ((P.Rect (0, width, height) :: stars 150 7 [])
     @ List.map (fun (p : planet) -> ring 0x33 cx cy p.distance) planets
     @ [ disc 252 cx cy 10 ])

let words colour x y s = P.Move (x, y, P.Words (colour, s))

let view m =
  ground
  :: List.concat_map (fun (p : planet) ->
       let (x, y) = place p m.days in
       [ disc p.colour x y p.radius;
         words 0xaa (x + p.radius + 2) (y - 4) p.name ])
       planets
  @ [ words 255 8 8 (date m.days);
      words 0xaa 8 28
        (string_of_int (m.speed * 30) ^ " days a second"
         ^ (if m.paused then ", paused" else ""));
      words 0xaa 8 400 "up, down: speed";
      words 0xaa 8 416 "space: pause";
      words 0xaa 8 432 "r: back to 2000";
      words 0xaa 8 448 "q: quit" ]

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

let game : model P.game = {
  width = width; height = height;
  init = (fun _ -> { days = 0; speed = 2; paused = false });
  view = view; key = key; frame = frame;
  sound = (fun _ _ -> []); music = (fun _ -> None);
}

let main caps (_ : string array) = P.run caps game
