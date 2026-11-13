(* Elm's Basics, the part of it that the playground uses. Playground.ml
 * opens it, and there a number is a float. So + - * / are the
 * operators on floats here, and the ones on ints are written with two
 * dots. *)
(* ix: the playground has no interface for this module; ix has one for
 * each module, which gives what the .ml gives and no more. *)

val log : string -> unit

external ( /.. ) : int -> int -> int = "%divint"
external ( +.. ) : int -> int -> int = "%addint"
external ( -.. ) : int -> int -> int = "%subint"
external ( *.. ) : int -> int -> int = "%mulint"

external ( / ) : float -> float -> float = "%divfloat"
external ( + ) : float -> float -> float = "%addfloat"
external ( - ) : float -> float -> float = "%subfloat"
external ( * ) : float -> float -> float = "%mulfloat"

(* rounds to the nearest int; a half is rounded up *)
val round : float -> int
(* [mod_by a b] is b mod a *)
val mod_by : int -> int -> int

val pi : float
(* 2 pi *)
val pi2 : float
val degrees_to_radians : float -> float
val radians_to_degrees : float -> float
(* [turns 0.5] is pi, half a turn in radians *)
val turns : float -> float

val clamp : 'number -> 'number -> 'number -> 'number
