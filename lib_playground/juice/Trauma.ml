(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/juice/Trauma.ml; its optional arguments are said *)

(* See Trauma.mli *)

let add (amount : float) (trauma : float) : float = Float.min 1. (trauma +. amount)

(* ix: per_second was optional: 1 *)
let decay ~(per_second : float) ~(dt : float) (trauma : float) : float = Float.max 0. (trauma -. (per_second *. dt))

let shake (trauma : float) : float = trauma *. trauma

(*****************************************************************************)
(* Smooth or not *)
(*****************************************************************************)

let noise ~(seed : int) (x : float) : float =
  let i = Float.to_int (Float.floor x) in
  Tween.lerp (Hash.hash ~seed i) (Hash.hash ~seed (i + 1)) (Ease.smoothstep (x -. Float.floor x))

let jitter ~(seed : int) (x : float) : float = Hash.hash ~seed (Float.to_int (Float.floor x))

type offset = { dx : float; dy : float; angle : float }

(* ix: the three were optional: smooth, 40 pixels, 5 degrees *)
let offset ~(smooth : bool) ~(max_offset : float) ~(max_angle : float) ~(seed : int) ~(trauma : float) (time : float) :
    offset =
  let s = shake trauma in
  let read k = if smooth then noise ~seed:(seed + k) (time *. 25.) else jitter ~seed:(seed + k) (time *. 60.) in
  { dx = max_offset *. s *. read 0; dy = max_offset *. s *. read 1; angle = max_angle *. s *. read 2 }
