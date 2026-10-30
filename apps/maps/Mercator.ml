(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Mercator.mli *)

let pi = 3.14159265358979323846
let max_latitude : float = 85.05112878
let world_size (z : int) : int = 256 lsl z

let x_of_longitude (z : int) (lon : float) : int =
  int_of_float (floor ((lon +. 180.) /. 360. *. float_of_int (world_size z)))

let y_of_latitude (z : int) (lat : float) : int =
  let lat = Float.max (-.max_latitude) (Float.min max_latitude lat) in
  let t = log (tan ((pi /. 4.) +. (lat *. pi /. 360.))) in
  let y = int_of_float (floor ((1. -. (t /. pi)) /. 2. *. float_of_int (world_size z))) in
  (* (at the very top the rounding gives -1) *)
  max 0 (min (world_size z - 1) y)

let longitude_of_x (z : int) (x : int) : float =
  (float_of_int x /. float_of_int (world_size z) *. 360.) -. 180.

let latitude_of_y (z : int) (y : int) : float =
  let t = pi *. (1. -. (2. *. float_of_int y /. float_of_int (world_size z))) in
  ((2. *. atan (exp t)) -. (pi /. 2.)) *. 180. /. pi
