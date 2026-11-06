(* Exit, lib_core/commons/'s subset (see Stdlib.mli): how a program
 * ends, as a value, which its main returns and TinyLibSystem.main
 * gives the system (Err's words said after the program's name, the
 * status 1) *)
type code = int

type t =
  | OK
  | Err of string
  | Code of code

(* raised deep inside, the main's value Code (0: OK) *)
exception ExitCode of code
