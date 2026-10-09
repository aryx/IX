(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Action.mli *)

let actions : (string, Efuns.action) Hashtbl.t = Hashtbl.create 64

let define (name : string) (action : Efuns.action) : unit =
  if Hashtbl.mem actions name then failwith ("action defined twice: " ^ name);
  Hashtbl.replace actions name action

let define_all (l : (string * Efuns.action) list) : unit =
  List.iter (fun ((name, action) : string * Efuns.action) -> define name action) l

let find_opt (name : string) : Efuns.action option = Hashtbl.find_opt actions name

let names () : string list =
  List.sort compare (Hashtbl.fold (fun (name : string) (_ : Efuns.action) (l : string list) -> name :: l) actions [])
