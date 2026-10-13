(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyAppCalculator.mli *)

open TinyLibGUI

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* the number shown; the one kept, with the operation that awaits its
 * second number (' ': none); whether the next digit begins a number;
 * whether there is no number to show *)
type model = { shown : int; kept : int; op : char; fresh : bool; wrong : bool }

(* what a button or a key says *)
type msg = Digit of int | Op of char | Equals | Clear

let start = { shown = 0; kept = 0; op = ' '; fresh = true; wrong = false }

(* nine digits, which the machine's integers of 31 bits hold *)
let limit = 999999999

(* kept op shown: the number, and whether there is one (none by 0, none
 * past the limit: a product is asked by a division, before it is made) *)
let result m =
  let a = m.kept and b = m.shown in
  if m.op = '/' then (if b = 0 then 0, false else a / b, true)
  else if m.op = '*' then (if a <> 0 && abs b > limit / abs a then 0, false else a * b, true)
  else (let v = if m.op = '+' then a + b else if m.op = '-' then a - b else b in v, abs v <= limit)

(* an operation asked (' ': the equals): the one that awaited is done,
 * this one awaits; asked right after another, it takes its place *)
let operate m op =
  if m.fresh && m.op <> ' ' && op <> ' ' then { shown = m.shown; kept = m.kept; op = op; fresh = true; wrong = false }
  else (let (v, ok) = result m in { shown = v; kept = v; op = op; fresh = true; wrong = not ok })

let update msg m =
  match msg with
  | Clear -> start
  | _ when m.wrong -> m
  | Digit d ->
      if m.fresh then { shown = d; kept = m.kept; op = m.op; fresh = false; wrong = false }
      else if m.shown > limit / 10 then m
      else { shown = (10 * m.shown) + d; kept = m.kept; op = m.op; fresh = false; wrong = false }
  | Op c -> operate m c
  | Equals -> operate m ' '

(*****************************************************************************)
(* The view, the keys *)
(*****************************************************************************)

(* what awaits over the number, then four rows of four buttons *)
let view m =
  let d n = Button (string_of_int n, Digit n) in
  let o c = Button (String.make 1 c, Op c) in
  Col [ Label (if m.op = ' ' then "" else string_of_int m.kept ^ " " ^ String.make 1 m.op);
        Field (if m.wrong then "error" else string_of_int m.shown);
        Row [ d 7; d 8; d 9; o '/' ]; Row [ d 4; d 5; d 6; o '*' ]; Row [ d 1; d 2; d 3; o '-' ];
        Row [ d 0; Button ("C", Clear); Button ("=", Equals); o '+' ] ]

(* a key is its button: the digits, the four operations, = or the
 * Enter, c *)
let key k =
  let c = Char.chr k in
  if c >= '0' && c <= '9' then [ Digit (k - 48) ]
  else if c = '+' || c = '-' || c = '*' || c = '/' then [ Op c ]
  else if c = '=' || k = 10 || k = 13 then [ Equals ]
  else if c = 'c' then [ Clear ]
  else []

let calculator = { init = start; view = view; update = update; key = key }
