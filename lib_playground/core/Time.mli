(* Elm's Time.Posix. Here a time is the seconds since 1970, as a
 * float. *)
(* ix: the playground has no interface for this module; ix has one for
 * each module, which gives what the .ml gives and no more. *)

type posix = float

val millis_to_posix : int -> posix
(* (converts the seconds of a time to milliseconds) *)
val posix_to_millis : posix -> int
