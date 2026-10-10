(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's playground's libs/core/time/Clock.ml (docs/plans/plan_browser.md) *)

(* See Clock.mli *)

type time_of_day = { hour : int; minute : int; second : float }

let seconds_per_day = 86400

let split ~(offset : int) (t : float) : int * time_of_day =
  let local = t +. float_of_int (offset * 60) in
  (* floor, not truncate: before the epoch, a day starts below *)
  let day = int_of_float (Float.floor (local /. float_of_int seconds_per_day)) in
  let s = local -. (float_of_int day *. float_of_int seconds_per_day) in
  let whole = int_of_float s in
  let tod = { hour = whole / 3600; minute = whole / 60 mod 60; second = s -. float_of_int (whole / 60 * 60) } in
  (day, tod)

let local ~(offset : int) (t : float) : Civil.date * time_of_day =
  let day, tod = split ~offset t in
  (Civil.civil_from_days day, tod)

let of_local ~(offset : int) (d : Civil.date) (tod : time_of_day) : float =
  let day = Civil.days_from_civil d in
  float_of_int ((day * seconds_per_day) + (tod.hour * 3600) + (tod.minute * 60) - (offset * 60))
  +. tod.second

let to_string ~(seconds : bool) (tod : time_of_day) : string =
  if seconds then Printf.sprintf "%02d:%02d:%02d" tod.hour tod.minute (int_of_float tod.second)
  else Printf.sprintf "%02d:%02d" tod.hour tod.minute

let offset_to_string (offset : int) : string =
  let a = abs offset in
  Printf.sprintf "%c%02d:%02d" (if offset < 0 then '-' else '+') (a / 60) (a mod 60)
