(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Interactive.mli *)
open Efuns

(* (a name not typed whole runs the one command that starts with it) *)
let call_interactive (frame : frame) : unit =
  Minibuffer.read frame "M-x " "" (Minibuffer.among (Action.names ())) (fun (frame : frame) (name : string) ->
    match Action.find_opt name, Minibuffer.among (Action.names ()) name with
    | Some action, _ -> action frame
    | None, [ only ] when name <> "" -> (match Action.find_opt only with Some action -> action frame | None -> ())
    | None, _ -> failwith ("No such command: " ^ name))

let keyboard_quit (_ : frame) : unit = failwith "Quit"

let () = Action.define_all [ "call_interactive", call_interactive; "keyboard_quit", keyboard_quit ]
