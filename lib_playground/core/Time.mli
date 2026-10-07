(* Elm's Time.Posix, here seconds since 1970 as a float. *)
(* ix: the playground has no interface for this module; ix has one for
 * each (what the .ml gives, no more). *)

type posix = float

val millis_to_posix : int -> posix
(* (its seconds made milliseconds) *)
val posix_to_millis : posix -> int
