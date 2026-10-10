(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* ix: the author's mini-chrome's libs/richtext/Style.ml, its first version (docs/plans/plan_browser.md) *)

(* See Style.mli *)

type t = { bold : bool; italic : bool; underline : bool; strike : bool; size : float }

let plain = { bold = false; italic = false; underline = false; strike = false; size = 16. }
let toggle_bold s = { s with bold = not s.bold }
let toggle_italic s = { s with italic = not s.italic }
let toggle_underline s = { s with underline = not s.underline }
let toggle_strike s = { s with strike = not s.strike }
