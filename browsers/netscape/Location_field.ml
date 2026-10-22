(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's libs/gui/Gui_field.ml and
 * src/chrome/Omnibox.ml (its 8af888e) *)

(* See Location_field.mli *)

type t = { text : string; caret : int; anchor : int }

let length (f : t) : int = String.length f.text

(* the character before a byte and after it: a UTF-8 letter's other
 * bytes are 10xxxxxx *)
let inside (s : string) (i : int) : bool =
  i > 0 && i < String.length s && Char.code s.[i] land 0xC0 = 0x80

let rec prev (s : string) (i : int) : int =
  if i <= 0 then 0 else if inside s (i - 1) then prev s (i - 1) else i - 1

let rec next (s : string) (i : int) : int =
  if i >= String.length s then String.length s
  else if inside s (i + 1) then next s (i + 1)
  else i + 1

let focused (text : string) : t =
  { text; caret = String.length text; anchor = 0 }

let select_all (f : t) : t = { f with anchor = 0; caret = length f }

let selection (f : t) : int * int =
  (min f.anchor f.caret, max f.anchor f.caret)

let selected (f : t) : string =
  let a, b = selection f in
  String.sub f.text a (b - a)

(* the bytes from a to b replaced by s, the caret after it *)
let replace (f : t) (a : int) (b : int) (s : string) : t =
  let at = a + String.length s in
  let after = String.sub f.text b (length f - b) in
  { text = String.sub f.text 0 a ^ s ^ after; caret = at; anchor = at }

let typed (s : string) (f : t) : t =
  let a, b = selection f in
  replace f a b s

let backspace (f : t) : t =
  let a, b = selection f in
  if a < b then replace f a b "" else replace f (prev f.text a) a ""

let delete (f : t) : t =
  let a, b = selection f in
  if a < b then replace f a b "" else replace f a (next f.text a) ""

type move = Left | Right | Home | End

let moved ~(select : bool) (how : move) (f : t) : t =
  let a, b = selection f in
  let caret =
    match how with
    | Home -> 0
    | End -> length f
    | Left -> if a < b && not select then a else prev f.text f.caret
    | Right -> if a < b && not select then b else next f.text f.caret
  in
  { f with caret; anchor = (if select then f.anchor else caret) }

let caret_at ~(select : bool) (i : int) (f : t) : t =
  let caret = max 0 (min (length f) i) in
  let caret = if inside f.text caret then prev f.text caret else caret in
  { f with caret; anchor = (if select then f.anchor else caret) }

let key ~(shift : bool) (name : string) (f : t) : t option =
  match name with
  | "Backspace" -> Some (backspace f)
  | "Delete" -> Some (delete f)
  | "ArrowLeft" -> Some (moved ~select:shift Left f)
  | "ArrowRight" -> Some (moved ~select:shift Right f)
  | "Home" -> Some (moved ~select:shift Home f)
  | "End" -> Some (moved ~select:shift End f)
  | _ -> None

let command (copy : string -> unit) (paste : unit -> string)
    (letter : string) (f : t) : t option =
  match letter with
  | "a" -> Some (select_all f)
  | "c" | "x" ->
      let s = selected f in
      if s <> "" then copy s;
      Some (if letter = "x" && s <> "" then backspace f else f)
  | "v" ->
      let line =
        match String.split_on_char '\n' (paste ()) with
        | first :: _ -> String.trim first
        | [] -> ""
      in
      Some (typed line f)
  | _ -> None

(* from the caret, or from where the end fits if that is before *)
let first_shown (measure : string -> float) (f : t) ~(room : float) : int =
  let rec fits i =
    if i >= f.caret || measure (String.sub f.text i (length f - i)) <= room
    then i
    else fits (next f.text i)
  in
  fits 0

let place (measure : string -> float) (f : t) ~(room : float) (i : int) :
    float =
  let from = first_shown measure f ~room in
  if i <= from then 0.
  else Float.min room (measure (String.sub f.text from (i - from)))

(* the boundary nearest to x: past one when x is beyond its half-way *)
let index_at (measure : string -> float) (f : t) ~(room : float) (x : float)
    : int =
  let at = place measure f ~room in
  let rec go i =
    if i >= length f then i
    else
      let j = next f.text i in
      if x < (at i +. at j) /. 2. then i else go j
  in
  go (first_shown measure f ~room)
