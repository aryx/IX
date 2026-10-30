(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Map_look.mli *)

module P = Playground

let text (color : P.color) ~(size : float) (x : float) (baseline : float) (s : string) : P.shape * float =
  let rec place (x0 : float) (acc : (float * string) list) (l : string list) =
    match l with
    | [] -> (List.rev acc, x0)
    | c :: rest ->
        let g = Glyph_unicode.glyph c in
        place (x0 +. (float_of_int (g.right - g.left) *. size /. Hershey.units_per_em)) ((x0, c) :: acc) rest
  in
  let at, x1 = place x [] (Text.chars s) in
  (P.letters color { size; bold = false; italic = false; baseline; at }, x1 -. x)

let width_of (s : string) : float = snd (text P.black ~size:14. 0. 0. s)

let cut (room : float) (s : string) : string =
  if width_of s <= room then s
  else
    let rec go (acc : string) (l : string list) : string =
      match l with
      | c :: rest when width_of (acc ^ c ^ "...") <= room -> go (acc ^ c) rest
      | _ -> acc ^ "..."
    in
    go "" (Text.chars s)
