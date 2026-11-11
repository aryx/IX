(* Common, lib_core/commons/'s subset (see Stdlib.mli) *)
val ( ||| ) : 'a option -> 'a -> 'a

(* what a tool finds wrong in its input (a command, a file, a query), which
 * its command loop or main says to the person; a bug is a Failure instead *)
exception Error of string
val error : string -> 'a
