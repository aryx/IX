(* Exit: a subset of lib_core/commons/'s module (see Stdlib.mli). It says
 * how a program ends, as a value: the program's main returns it, and
 * TinyLibSystem.main gives it to the system. For Err, the words are
 * printed after the program's name, and the status is 1. *)
type code = int

type t =
  | OK
  | Err of string
  | Code of code

(* ExitCode n, raised deep inside a program, ends it as if the main's
 * value were Code n (where 0 is OK). *)
exception ExitCode of code
