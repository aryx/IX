(* TinyLib: lib_core/commons/Console, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Standard output and error, through their capabilities *)

(* unbuffered by us: stdout's own buffer *)
val print : < Cap.stdout; .. > -> string -> unit

(* flushed, so that it comes out in order with a child's *)
val eprint : < Cap.stderr; .. > -> string -> unit

(* the channel itself (xix's Console's), for a program that copies bytes *)
val stderr : < Cap.stderr; .. > -> out_channel
