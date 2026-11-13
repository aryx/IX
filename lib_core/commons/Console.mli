(* Standard output and error, through their capabilities *)

(* We add no buffer of our own; only stdout's own buffer is used *)
val print : < Cap.stdout; .. > -> string -> unit

(* It is flushed, so that it comes out in order with a child's output *)
val eprint : < Cap.stderr; .. > -> string -> unit

(* The channels themselves, as xix's Console has them, for a program that
 * copies bytes *)
val stdin : < Cap.stdin; .. > -> in_channel
val stdout : < Cap.stdout; .. > -> out_channel
val stderr : < Cap.stderr; .. > -> out_channel

(* Their descriptors, for a program that does its own reads and writes
 * (echo writes its message in one write) *)
val stdin_fd : < Cap.stdin; .. > -> Unix.file_descr
val stdout_fd : < Cap.stdout; .. > -> Unix.file_descr
