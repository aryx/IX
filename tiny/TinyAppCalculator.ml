(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *)
(* See TinyAppCalculator.mli *)
(* The arithmetic is tested on the host by sending messages to [update],
 * and the buttons by sending mouse events to TinyLibGUI
 * (tests/TinyLibGUI_test.sh). *)
open TinyLibGUI

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

(* the number shown; the one kept, with the operation that awaits its
 * second number.
 *)
type model = { 
  shown : int; 
  kept : int; 
  op : char; (* ' ' = None *)
  (* whether the next digit begins a number; whether there is no number to show *)
  fresh : bool; 
  wrong : bool 
}

let start = { shown = 0; kept = 0; op = ' '; fresh = true; wrong = false }

(* nine digits, which the machine's integers of 31 bits hold *)
let limit = 999999999

(*****************************************************************************)
(* The msg and update *)
(*****************************************************************************)

(* what a button or a key says *)
type msg = Digit of int | Op of char | Equals | Clear

(* kept op shown: the number, and whether there is one (none by 0, none
 * past the limit: a product is asked by a division, before it is made) *)
let result { kept = a; shown = b; op; _ } =
  if op = '/' then (if b = 0 then 0, false else a / b, true)
  else if op = '*' then (if a <> 0 && abs b > limit / abs a then 0, false else a * b, true)
  else (let v = if op = '+' then a + b else if op = '-' then a - b else b in v, abs v <= limit)

(* an operation asked (' ': the equals): the one that awaited is done,
 * this one awaits; asked right after another, it takes its place *)
let operate m op =
  if m.fresh && m.op <> ' ' && op <> ' ' then { m with op; fresh = true; wrong = false }
  else (let (v, ok) = result m in { shown = v; kept = v; op = op; fresh = true; wrong = not ok })

let update (msg : msg) (m : model) : model =
  match msg with
  | Clear -> start
  | _ when m.wrong -> m
  | Digit d ->
      if m.fresh then { m with shown = d; fresh = false; wrong = false }
      else if m.shown > limit / 10 then m
      else { m with shown = (10 * m.shown) + d; fresh = false; wrong = false }
  | Op c -> operate m c
  | Equals -> operate m ' '

(*****************************************************************************)
(* The view, the keys *)
(*****************************************************************************)

(* what awaits over the number, then four rows of four buttons *)
let view { shown; kept; op; wrong; _ } : msg widget =
  let d n = Button (string_of_int n, Digit n) in
  let o c = Button (String.make 1 c, Op c) in
  Col [ Label (if op = ' ' then "" else string_of_int kept ^ " " ^ String.make 1 op);
        Field (if wrong then "error" else string_of_int shown);
        Row [ d 7; d 8; d 9; o '/' ];
        Row [ d 4; d 5; d 6; o '*' ];
        Row [ d 1; d 2; d 3; o '-' ];
        Row [ d 0; Button ("C", Clear); Button ("=", Equals); o '+' ] ]

(* a key is its button: the digits, the four operations, = or the
 * Enter, c *)
let key (k : int) : msg list =
  let c = Char.chr k in
  if c >= '0' && c <= '9' then [ Digit (k - 48) ]
  else if c = '+' || c = '-' || c = '*' || c = '/' then [ Op c ]
  else if c = '=' || k = 10 || k = 13 then [ Equals ]
  else if c = 'c' then [ Clear ]
  else []

let calculator = { init = start; view; update; key }
