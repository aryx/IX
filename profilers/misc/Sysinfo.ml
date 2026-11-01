(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Sysinfo.mli *)

let lines text = String.split_on_char '\n' text
let words line = List.filter (fun f -> f <> "") (String.split_on_char ' ' line)

let cores text =
  List.filter_map (fun line ->
      match List.nth_opt (words line) 8 with
      | Some idle -> Option.map (fun i -> 100 - i) (int_of_string_opt idle)
      | None -> None)
    (lines text)

let memory text =
  List.find_map (fun line ->
      match words line with
      | [ pair; "user" ] -> (
          match String.split_on_char '/' pair with
          | [ used; all ] -> (
              match int_of_string_opt used, int_of_string_opt all with
              | Some u, Some a when a > 0 -> Some (u * 100 / a)
              | _ -> None)
          | _ -> None)
      | _ -> None)
    (lines text)

(* the number after a word that starts a line *)
let field name text =
  List.find_map (fun line ->
      match words line with
      | w :: n :: _ when w = name -> int_of_string_opt n
      | _ -> None)
    (lines text)

let ether text =
  match field "in:" text, field "out:" text with
  | Some i, Some o -> Some (i, o)
  | _ -> None

let disk text =
  List.find_map (fun line ->
      match words line with
      | [ "io"; r; w ] -> (
          match int_of_string_opt r, int_of_string_opt w with
          | Some r, Some w -> Some (r, w)
          | _ -> None)
      | _ -> None)
    (lines text)

let grew before now = if now > before then now - before else 0

(* (a table of powers of ten: no float, no log in a program of 5 samples a
 * second: tenths of a power, by what v is above the power below it) *)
let log_tenths v =
  let rec go power tens = if v >= power * 10 then go (power * 10) (tens + 10) else (power, tens) in
  if v <= 0 then 0
  else
    let power, tens = go 1 0 in
    tens + 1 + (9 * (v - power) / (power * 9))

let log_percent top v =
  if v <= 0 then 0
  else min 100 (max 1 (log_tenths v * 100 / max 1 (log_tenths top)))

let short v =
  if v < 1000 then string_of_int v
  else if v < 1000000 then string_of_int (v / 1000) ^ "K"
  else string_of_int (v / 1000000) ^ "M"
