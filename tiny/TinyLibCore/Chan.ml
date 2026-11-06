(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Chan.mli: lib_core/commons/Chan.ml's code *)

type origin =
  | File of Fpath.t
  | Stdin
  | String
  | Channel
  | Network

type destination =
  | OutFile of Fpath.t
  | Stdout

type i = { ic : in_channel; origin : origin }

type o = { oc : out_channel; dest : destination }

let origin (chani : i) =
  match chani.origin with
  | File f -> Fpath.to_string f
  | Stdin -> "<stdin>"
  | String -> "<string>"
  | Channel -> "<channel>"
  | Network -> "<network>"

let destination (chano : o) =
  match chano.dest with
  | OutFile f -> Fpath.to_string f
  | Stdout -> "<stdout>"
