(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Modules.mli *)

let table : (string * (unit -> unit)) list ref = ref []

let command name p = table := !table @ [ name, p ]
let this_command name = List.assoc_opt name !table

(* M.P's M *)
let module_of name = match String.index_opt name '.' with Some i -> String.sub name 0 i | None -> name

let modules () = List.fold_left (fun acc (name, _) -> let m = module_of name in if List.mem m acc then acc else acc @ [ m ]) [] !table
let commands m = List.filter (fun name -> module_of name = m) (List.map fst !table)
