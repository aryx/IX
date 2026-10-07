(* A colour: Elm's Color, as the playground's shapes take it. Its
 * named ones are Tango's palette (Elm's own choice). *)
(* ix: the playground has no interface for this module; ix has one for
 * each (what the .ml gives, no more). *)

type t =
  | Hex of string (* "#cc0000" *)
  | Rgb of int * int * int

(* red, green, blue, each kept between 0 and 255 *)
val rgb : int -> int -> int -> t

val white : t
val black : t
val red : t
val orange : t
val yellow : t
val green : t
val blue : t
val purple : t
val brown : t
val lightYellow : t
val lightOrange : t
val lightBrown : t
val lightGreen : t
val lightBlue : t
val lightPurple : t
val lightRed : t
val darkYellow : t
val darkOrange : t
val darkBrown : t
val darkGreen : t
val darkBlue : t
val darkPurple : t
val darkRed : t
val lightGray : t
val gray : t
val darkGray : t
val lightCharcoal : t
val charcoal : t
val darkCharcoal : t

(* red, orange, yellow, green, blue, purple *)
val rainbow : t list
