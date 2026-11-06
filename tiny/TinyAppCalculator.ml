(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
 *
 * testing:
 * The arithmetic is tested on the host by sending messages to [update],
 * and the buttons by sending mouse events to TinyLibGUI
 * (tests/TinyLibGUI_test.sh).
 *)
open TinyLibPlayground
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
  op : char option;
  (* whether the next digit begins a number; whether there is no number to show *)
  fresh : bool;
  wrong : bool
}

let start = { shown = 0; kept = 0; op = None; fresh = true; wrong = false }

(* nine digits, which the machine's integers of 31 bits hold *)
let limit = 999999999

(*****************************************************************************)
(* The msg and update *)
(*****************************************************************************)

(* what a button or a key says *)
type msg = Digit of int | Op of char | Equals | Clear

(* the operation that awaits, done on the kept number and the shown one;
 * None when it has no result: a division by 0, or past [limit] (a
 * product is checked by a division before it is made) *)
let result { kept = a; shown = b; op; _ } : int option =
  match op with
  | Some '/' -> if b = 0 then None else Some (a / b)
  | Some '*' ->
      if a <> 0 && abs b > limit / abs a then None else Some (a * b)
  | _ ->
      let v =
        match op with
        | Some '+' -> a + b
        | Some '-' -> a - b
        | _ -> b
      in
      if abs v <= limit then Some v else None

(* an operation asked (None: the equals): the one that awaited is done,
 * this one awaits; asked right after another, it takes its place *)
let operate (m : model) (op : char option) : model =
  if m.fresh && m.op <> None && op <> None then
    { m with op; fresh = true; wrong = false }
  else
    (match result m with
     | Some v -> { shown = v; kept = v; op; fresh = true; wrong = false }
     | None -> { shown = 0; kept = 0; op; fresh = true; wrong = true })

let update (msg : msg) (m : model) : model =
  match msg with
  | Clear -> start
  | _ when m.wrong -> m
  | Digit d ->
      if m.fresh then { m with shown = d; fresh = false; wrong = false }
      else if m.shown > limit / 10 then m
      else { m with shown = (10 * m.shown) + d; fresh = false; wrong = false }
  | Op c -> operate m (Some c)
  | Equals -> operate m None

(*****************************************************************************)
(* The view, the keys *)
(*****************************************************************************)

(* what awaits over the number, then four rows of four buttons *)
let view { shown; kept; op; wrong; _ } : msg widget =
  let d n = Button (string_of_int n, Digit n) in
  let o c = Button (String.make 1 c, Op c) in
  let pending =
    match op with
    | None -> ""
    | Some c -> string_of_int kept ^ " " ^ String.make 1 c
  in
  Col [ Label pending;
        Field (if wrong then "error" else string_of_int shown);
        Row [ d 7; d 8; d 9; o '/' ];
        Row [ d 4; d 5; d 6; o '*' ];
        Row [ d 1; d 2; d 3; o '-' ];
        Row [ d 0; Button ("C", Clear); Button ("=", Equals); o '+' ] ]

(* a key is its button: the digits, the four operations, = or the
 * Enter, c *)
let key (k : key) : msg list =
  match k with
  | Char c when c >= '0' && c <= '9' -> [ Digit (Char.code c - 48) ]
  | Char ('+' | '-' | '*' | '/' as c) -> [ Op c ]
  | Char ('=' | '\n' | '\r') -> [ Equals ]
  | Char 'c' -> [ Clear ]
  | _ -> []

let calculator = { init = start; view; update; key }
