(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's mini-chrome's src/display/Stroke_text.ml, its first version, and Glyph_unicode's glyphs (docs/plans/plan_browser.md) *)

(* See Stroke_text.mli *)

(* a character's glyph: Hershey's for ASCII, Glyph_unicode's for the
 * rest (a letter with its mark, quotes, dashes), its '?' for what it
 * does not know.
 * old: Hershey.glyph (if String.length s = 1 then s.[0] else '?') *)

(* font units to the playground's, at a look's size *)
let scale_of (look : Style.t) = look.size /. Hershey.units_per_em

let metrics look s =
  let g = Glyph_unicode.glyph s in
  float_of_int (g.right - g.left) *. scale_of look

(* (the letters' strokes are Letter_strokes', drawn by the platform:
 * old: this made them here, a thin rectangle a segment, and every
 * platform drew them at each frame) *)
let run (color : Playground.color) (look : Style.t) (letters : (float * string) list) ~(baseline : float) : Playground.shape list =
  match letters with
  | [] -> []
  | (first, _) :: _ ->
      let last, s = List.nth letters (List.length letters - 1) in
      let pen = if look.bold then look.size /. 7. else look.size /. 16. in
      let width = last +. metrics look s -. first in
      let rule (y : float) : Playground.shape = Playground.rectangle color width (pen *. 0.8) |> Playground.move (first +. (width /. 2.)) y in
      Playground.letters color { size = look.size; bold = look.bold; italic = look.italic; baseline; at = letters }
      :: ((if look.underline then [ rule (baseline -. (look.size *. 0.18)) ] else []) @ if look.strike then [ rule (baseline +. (look.size *. 0.25)) ] else [])
