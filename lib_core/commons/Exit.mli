(* ix: how a program ends, as a value (xix's Exit). A program's main
 * is a function that returns one, and only its Main gives it to the
 * system:
 *
 *     let () = Cap.main (fun caps ->
 *       Exit.exit caps (Exit.catch (fun () -> CLI.main caps argv)))
 *
 *     CLI.main returns OK                         the status 0
 *     CLI.main returns Err "no such file"         the words logged, 1
 *     deep inside, raise (Exit.ExitCode 2)   -->  catch: Code 2
 *
 * So a program is a function like another: a test calls CLI.main
 * and looks at what it returns, where a call of Stdlib's exit in its
 * middle would end the test with it. And ending needs a capability,
 * so a function without it cannot stop the program behind its
 * caller's back.
 *
 * plan9-is-cleaner:
 * Unix's status is a number of 8 bits, 0 for success, and what 1, 2
 * or 127 mean is each command's convention. Plan 9's exits takes a
 * string, empty for success, else the reason in words, which the
 * shell keeps as it is in $status. [Err] is that: on Plan 9 its
 * string is the process's last words (Sys_plan9.exits), on Unix it
 * is logged and the status is 1. *)

(* 0 means ok, otherwise means error (e.g., 2 for "fatal error") *)
type code = int

type t =
  (* code 0 in Unix *)
  | OK
  (* code 1 in Unix. This will lead to a call to Logs.err and an exit 1.
   * Note that This is similar to Plan9's exits() *)
  | Err of string
  (* specific exit code (must be > 0 otherwise use OK) *)
  | Code of code

val show: t -> string

(* The code can also be 0 here; it will be converted back to OK by catch() *)
exception ExitCode of code

val exit: < Cap.exit; ..> -> t -> unit

(* [catch caps f] will run [f()] and return its exit value
 * but also catch the Exitcode exn [f] may throw and
 * convert the exn to the corresponding exit value.
 *)
val catch : (unit -> t) -> t
