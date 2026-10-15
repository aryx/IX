(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyAppTemperature.mli *)

open TinyLibGUI

(* the two fields' texts, as typed *)
type model = { c : string; f : string }

(* a field's new text *)
type msg = Celsius of string | Fahrenheit of string

(* a text's whole number, and whether it is one (a sign, then one to
 * six digits) *)
let number s =
  let n = String.length s in
  let rec from i v = if i = n then v, true else if s.[i] >= '0' && s.[i] <= '9' then from (i + 1) ((10 * v) + Char.code s.[i] - 48) else 0, false in
  if n > 0 && s.[0] = '-' then (if n = 1 || n > 7 then 0, false else (let (v, ok) = from 1 0 in - v, ok))
  else if n = 0 || n > 6 then 0, false
  else from 0 0

(* a over b, to the nearest whole number (the machine's division goes
 * toward 0) *)
let nearest a b = if a >= 0 then (a + (b / 2)) / b else - ((b / 2) - a) / b

(* a field typed in has its text, whatever it is; the other one has the
 * other temperature when that text is a number, and is left alone
 * when it is not *)
let update msg m =
  match msg with
  | Celsius s -> let (v, ok) = number s in { c = s; f = (if ok then string_of_int (nearest ((9 * v) + 160) 5) else m.f) }
  | Fahrenheit s -> let (v, ok) = number s in { c = (if ok then string_of_int (nearest (5 * (v - 32)) 9) else m.c); f = s }

let view { c; f } = Row [ Input (c, (fun s -> Celsius s)); Label "Celsius ="; Input (f, (fun s -> Fahrenheit s)); Label "Fahrenheit" ]

let temperature = { init = { c = ""; f = "" }; view; update; key = (fun _ -> []) }
