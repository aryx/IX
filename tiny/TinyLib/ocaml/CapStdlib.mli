(* TinyLib: lib_core/system/CapStdlib, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* ix: the stdlib's functions given a capability (see Cap), the ones ix uses *)

val exit : < .. > -> int -> 'a
val open_in : < .. > -> string -> in_channel
