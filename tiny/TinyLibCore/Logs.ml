(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Logs.mli *)

type level = App | Error | Warning | Info | Debug

let rank l =
  match l with App -> 0 | Error -> 1 | Warning -> 2 | Info -> 3 | Debug -> 4

let level = ref (Some Warning)
let set_level l = level := l

let reporter = ref (fun (_ : level) s -> print_string (s ^ "\n"))
let set_reporter f = reporter := f

let log l msgf =
  match !level with
  | Some top when rank l <= rank top -> msgf (fun s -> !reporter l s)
  | _ -> ()

let app msgf = log App msgf
let err msgf = log Error msgf
let warn msgf = log Warning msgf
let info msgf = log Info msgf
let debug msgf = log Debug msgf
