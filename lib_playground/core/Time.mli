(* Elm's Time.Posix. Here a time is the seconds since 1970, as a
 * float. *)
(* ix: the playground has no interface for this module; ix has one for
 * each module, which gives what the .ml gives and no more. *)

type posix = float

(* [n] as a time, unchanged: unlike Elm's, it does not divide by
 * 1000. The recorded frames of the games and of mini-files depend on
 * it, because a program's first time is millis_to_posix 1. *)
val millis_to_posix : int -> posix
(* a time's milliseconds, if the time is in seconds *)
val posix_to_millis : posix -> int
