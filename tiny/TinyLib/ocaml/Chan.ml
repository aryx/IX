(* Yoann Padioleau
 * Copyright (C) 2023-2025 Semgrep Inc. LGPL 2.1, with the linking exception of its LICENSE. *)
open Fpath_.Operators

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Channels on (local) files.
 *
 * In many cases, having just the channel is not enough for good error
 * reporting so here we mostly wrap In_channel.t and Out_channel.t
 * (themselves alias for Stdlib.in_channel and Stdlib.out_channel) with
 * the filename attached to it.
 *)

(*****************************************************************************)
(* Types *)
(*****************************************************************************)

(* alt: call it source (as in spacegrep Src_file.ml) 
 * alt: move in separate Origin.ml (as in semgrep)
 *)
type origin = 
  | File of Fpath.t
  | Stdin
  | String
  | Channel
  | Network

type destination = 
  | OutFile of Fpath.t
  | Stdout

(* alt: "in", but reserved keyword, and "in_" is ugly *)
type i = { ic : in_channel; origin : origin }

type o = { oc : out_channel; dest : destination }

(*****************************************************************************)
(* API *)
(*****************************************************************************)

let origin (chani : i) =
  match chani.origin with
  | File f -> !!f
  | Stdin -> "<stdin>"
  | String -> "<string>"
  | Channel -> "<channel>"
  | Network -> "<network>"

let destination (chano : o) =
  match chano.dest with
  | OutFile f -> !!f
  | Stdout -> "<stdout>"
