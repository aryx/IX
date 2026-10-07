(* Elm's Basics, the part the playground uses: opened by Playground.ml,
 * where a number is a float. So + - * / are the floats' here, and the
 * ints' are written with two dots. *)
(* ix: the playground has no interface for this module; ix has one for
 * each (what the .ml gives, no more). *)

val log : string -> unit

val ( /.. ) : int -> int -> int
val ( +.. ) : int -> int -> int
val ( -.. ) : int -> int -> int
val ( *.. ) : int -> int -> int

val ( / ) : float -> float -> float
val ( + ) : float -> float -> float
val ( - ) : float -> float -> float
val ( * ) : float -> float -> float

(* to the nearest int, a half up *)
val round : float -> int
(* [mod_by a b]: b mod a *)
val mod_by : int -> int -> int

val pi : float
(* 2 pi *)
val pi2 : float
val degrees_to_radians : float -> float
val radians_to_degrees : float -> float
(* [turns 0.5]: pi, half a turn in radians *)
val turns : float -> float

val clamp : 'number -> 'number -> 'number -> 'number
