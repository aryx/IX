(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Chan.mli: lib_core/commons/Chan.ml's code *)

type origin =
  | File of Fpath.t
  | Stdin
  | String
  | Channel
  | Network

type i = { ic : in_channel; origin : origin }

let origin (chani : i) =
  match chani.origin with
  | File f -> Fpath.to_string f
  | Stdin -> "<stdin>"
  | String -> "<string>"
  | Channel -> "<channel>"
  | Network -> "<network>"
