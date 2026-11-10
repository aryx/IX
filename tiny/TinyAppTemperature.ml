(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * See TinyAppTemperature.mli
 *)
open TinyLibGUI

(* the two fields' texts, as typed *)
type model = { c : string; f : string }

let init : model = { c = ""; f = "" }

(* a field's new text *)
type msg = Celsius of string | Fahrenheit of string

(* a text's whole number, None when it is not one (a sign, then one to
 * six digits; old: the number and whether it was one, a pair) *)
let number (s : string) : int option =
  let n = String.length s in
  let rec from i v =
    if i = n then Some v
    else if s.[i] >= '0' && s.[i] <= '9' then
      from (i + 1) ((10 * v) + Char.code s.[i] - 48)
    else None in
  if n > 0 && s.[0] = '-' then
    (if n = 1 || n > 7 then None
     else match from 1 0 with Some v -> Some (- v) | None -> None)
  else if n = 0 || n > 6 then None
  else from 0 0

(* a over b, to the nearest whole number (the machine's division goes
 * toward 0) *)
let nearest a b = if a >= 0 then (a + (b / 2)) / b else - ((b / 2) - a) / b

(* a field typed in has its text, whatever it is; the other one has the
 * other temperature when that text is a number, and is left alone
 * when it is not *)
let update (msg : msg) (m : model) : model =
  match msg with
  | Celsius s ->
      { c = s;
        f = (match number s with
             | Some v -> string_of_int (nearest ((9 * v) + 160) 5)
             | None -> m.f) }
  | Fahrenheit s ->
      { c = (match number s with
             | Some v -> string_of_int (nearest (5 * (v - 32)) 9)
             | None -> m.c);
        f = s }

let view { c; f } : msg widget = 
  Row [ Input (c, (fun s -> Celsius s)); Label "Celsius ="; 
        Input (f, (fun s -> Fahrenheit s)); Label "Fahrenheit" ]

let temperature : (model, msg) gui =
  { init; view; update; key = (fun _ -> []) }

(*****************************************************************************)
(* Entry point *)
(*****************************************************************************)

(* the program, temp: the converter run (no system call of its own;
 * user/temp.ml its one line) *)
let main (_ : < .. >) (_ : string array) = run temperature
