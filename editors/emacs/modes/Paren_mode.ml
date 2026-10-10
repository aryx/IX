(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Paren_mode.mli *)
open Efuns

let mode : minor_mode = { min_name = "paren"; min_map = Keymap.create () }

let opening = "([{" and closing = ")]}"

let matching (text : Text.t) (pos : int) : int option =
  let c = Text.get text pos in
  (* the step, and what makes the depth more *)
  let step, more, less = if String.contains opening c then (1, opening, closing) else (-1, closing, opening) in
  let rec go (p : int) (depth : int) (left : int) : int option =
    if p < 0 || p >= Text.length text || left = 0 then None
    else begin
      let c = Text.get text p in
      if String.contains more c then go (p + step) (depth + 1) (left - 1)
      else if String.contains less c then (if depth = 0 then Some p else go (p + step) (depth - 1) (left - 1))
      else go (p + step) depth (left - 1)
    end in
  if String.contains opening c || String.contains closing c then go (pos + step) 0 20000 else None

let highlight (frame : frame) : (int * int) list =
  let text = frame.frm_buffer.buf_text and point = Frame.point frame in
  if not (List.memq mode frame.frm_buffer.buf_minor_modes) then []
  else begin
    let at (pos : int) (set : string) : (int * int) list =
      if pos >= 0 && pos < Text.length text && String.contains set (Text.get text pos)
      then (match matching text pos with Some m -> [ (m, m + 1) ] | None -> [])
      else [] in
    match at (point - 1) closing with [] -> at point opening | found -> found
  end

let () = Globals.editor.edt_highlights <- highlight :: Globals.editor.edt_highlights
