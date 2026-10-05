(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Build and run external "commands".
 *
 * This is a capability-aware alternative to Sys.command
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

type name = Name of string [@@deriving show]
type args = string list [@@deriving show]
type t = name * args [@@deriving show]

(* alt: we could also make it part of [t] and have a triple *)
type env = { vars : (string * string) list; inherit_parent_env : bool }

let env_of_list (inherit_parent_env : bool) (vars : (string * string) list) :
    env =
  { vars = vars; inherit_parent_env = inherit_parent_env }

(*****************************************************************************)
(* API *)
(*****************************************************************************)

let to_string  (Name s, xs) =
  s ^ " " ^ String.concat " " xs

let run _caps cmd =
  let str = to_string cmd in
  match Sys.command str with
  | 0 -> Exit.OK
  | n -> Exit.Code n
