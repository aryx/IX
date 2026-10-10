(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's src/display/Browser_text.ml, its first version (docs/plans/plan_browser.md) *)

(* See Browser_text.mli *)

let characters (s : string) : string list =
  let rec go i acc =
    if i >= String.length s then List.rev acc
    else
      (* (a character's bytes by its first one; one byte for a broken one) *)
      let c = Char.code s.[i] in
      let n = if c < 0xc0 then 1 else if c < 0xe0 then 2 else if c < 0xf0 then 3 else 4 in
      let n = if i + n > String.length s then 1 else n in
      go (i + n) (String.sub s i n :: acc)
  in
  go 0 []

let root_look = Looks.root 16.

let style_of (l : Looks.t) : Style.t =
  { bold = l.bold; italic = l.italic; underline = l.underline; strike = l.strike; size = l.size }

let cell_of (l : Looks.t) : float = 0.6 *. l.size

let metrics (l : Looks.t) (s : string) : float =
  if l.monospace then cell_of l *. float_of_int (List.length (characters s))
  else List.fold_left (fun w c -> w +. Stroke_text.metrics (style_of l) c) 0. (characters s)

let tail (n : int) (s : string) : string =
  let cs = characters s in
  let k = List.length cs in
  if k <= n then s else String.concat "" (List.filteri (fun i _ -> i >= k - n) cs)

let escape_html (s : string) : string =
  String.concat "" (List.map (fun c -> match c with "&" -> "&amp;" | "<" -> "&lt;" | ">" -> "&gt;" | c -> c) (characters s))
