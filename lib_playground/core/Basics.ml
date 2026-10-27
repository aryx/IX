(* ix: the author's playground's libs/core/Basics.ml (docs/plans/done/plan_playground.md) *)
let log s =
  Printf.printf "%s" s

(* ix: externals, where they were let (/..) = (/) and so on: by mini-ml,
 * a value of another directory's unit is not inlined (its summary not
 * read), so each + of a program that opens Basics was a call of a
 * closure, its floats boxed; an external is the operation itself *)
external (/..) : int -> int -> int = "%divint"
external (+..) : int -> int -> int = "%addint"
external (-..) : int -> int -> int = "%subint"
external ( *.. ) : int -> int -> int = "%mulint"

(* prefer float operators as default *)
external (/) : float -> float -> float = "%divfloat"
external (+) : float -> float -> float = "%addfloat"
external (-) : float -> float -> float = "%subfloat"
external ( * ) : float -> float -> float = "%mulfloat"

let (round: float -> int) = fun f ->
    int_of_float (floor (f +. 0.5))

let mod_by a b =
  b mod a

let pi = Float.pi
let pi2 = 8. *. atan 1.

(* was called just degrees in Basics.elm *)
let degrees_to_radians deg =
  (deg * pi) / 180.

let radians_to_degrees rad =
  rad * 180. / pi

let (turns: float -> float) = fun angle_in_turns ->
    2. * pi * angle_in_turns

let (clamp: 'number -> 'number -> 'number -> 'number) = fun low high number ->
  if number < low then
    low
  else if number > high then
    high
  else
    number
