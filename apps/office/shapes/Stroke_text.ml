(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/office/stroke_text/Stroke_text.ml (docs/plans/plan_office.md) *)

(* See Stroke_text.mli *)

(* a character's glyph: Hershey's for ASCII, Glyph_unicode's for the
 * rest (a letter with its mark, quotes, dashes), its '?' for what it
 * does not know: the letters' strokes are Letter_strokes', which are.
 * old: Hershey.glyph (if String.length s = 1 then s.[0] else '?') *)

(* font units to the playground's, at a look's size *)
let scale_of (look : Style.t) = look.size /. Hershey.units_per_em

let metrics look s =
  let g = Glyph_unicode.glyph s in
  float_of_int (g.right - g.left) *. scale_of look

(* (the letter one shape, Playground's Letters, which the platform draws
 * from its strokes, once: old: its strokes made here, a thin rectangle
 * a segment, drawn by every platform at each frame) *)
let glyph color (look : Style.t) s ~x ~baseline =
  let pen = if look.bold then look.size /. 7. else look.size /. 16. in
  let advance = metrics look s in
  let rule y =
    Playground.rectangle color advance (pen *. 0.8) |> Playground.move (x +. (advance /. 2.)) y
  in
  Playground.letters color { size = look.size; bold = look.bold; italic = look.italic; baseline; at = [ (x, s) ] }
  :: ((if look.underline then [ rule (baseline -. (look.size *. 0.18)) ] else [])
  @ if look.strike then [ rule (baseline +. (look.size *. 0.25)) ] else [])
