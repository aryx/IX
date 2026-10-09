(* TinyLib: lib_core/commons/Console, the part the tiny programs call (tiny/TinyLib/README.md) *)
(* Standard output and error, through their capabilities *)

(* unbuffered by us: stdout's own buffer *)
val print : < Cap.stdout; .. > -> string -> unit

(* flushed, so that it comes out in order with a child's *)
val eprint : < Cap.stderr; .. > -> string -> unit

(* the channels themselves (xix's Console's), for a program that copies bytes *)
val stdin : < Cap.stdin; .. > -> in_channel
val stdout : < Cap.stdout; .. > -> out_channel
val stderr : < Cap.stderr; .. > -> out_channel

(* its descriptor, for a program that reads itself *)
val stdin_fd : < Cap.stdin; .. > -> Unix.file_descr
