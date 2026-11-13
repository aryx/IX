(* Common: a subset of lib_core/commons/'s module (see Stdlib.mli) *)
val ( ||| ) : 'a option -> 'a -> 'a

(* Error is what a tool finds wrong in its input (a command, a file, a
 * query); the tool's command loop or main tells it to the person. A bug
 * is a Failure instead. *)
exception Error of string
val error : string -> 'a
