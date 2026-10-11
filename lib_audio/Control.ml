(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Control.mli *)

(* ix: the author's playground's libs/audio/Control.ml (docs/plans/plan_audio.md) *)

type t = Knob of float * float | Switch | Selector of string list

let on (x : float) : bool = x >= 0.5
let of_bool (b : bool) : float = if b then 1. else 0.
let index (x : float) : int = int_of_float (Float.round x)

let to_string (c : t) (x : float) : string =
  match c with
  | Knob _ -> Printf.sprintf "%.3f" x
  | Switch -> if on x then "on" else "off"
  | Selector labels -> List.nth labels (index x)

let of_string (c : t) (s : string) : float option =
  match c with
  | Knob (lo, hi) -> Option.map (fun x -> Float.min hi (Float.max lo x)) (float_of_string_opt s)
  | Switch -> ( match s with "on" -> Some 1. | "off" -> Some 0. | _ -> None)
  | Selector labels ->
      let rec find i = function [] -> None | l :: rest -> if l = s then Some (float_of_int i) else find (i + 1) rest in
      find 0 labels
