(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's apps/devtools/TinyDrScheme.ml, its sections Editing and Update; a string's characters are taken without a Seq, an Option.value is written out, and Enter at the prompt takes the frame's typed text with it (docs/plans/plan_scheme.md) *)

(* See DrScheme_update.mli *)

open Playground
open DrScheme_model
open DrScheme_draw
open DrScheme_run

(*****************************************************************************)
(* Editing *)
(*****************************************************************************)
let repeating = [ "Backspace"; "Delete"; "ArrowLeft"; "ArrowRight"; "ArrowUp"; "ArrowDown" ]

(* the keys pressed this frame, and those held long enough to repeat *)
let presses (m : model) (computer : computer) : string list * (string * int) list =
  let down = Set_.elements computer.keyboard.keys in
  let held = List.map (fun k -> (k, 1 + (match List.assoc_opt k m.held with Some n -> n | None -> 0))) down in
  (List.filter_map (fun (k, n) -> if n = 1 || (List.mem k repeating && n > 24 && n mod 3 = 0) then Some k else None) held, held)

let edit (t : Text_edit.t) (computer : computer) (keys : string list) ~(multiline : bool) : Text_edit.t =
  let typed =
    let all = computer.keyboard.typed in
    String.concat "" (List.filter_map (fun c -> if Char.code c >= 32 && Char.code c < 127 then Some (String.make 1 c) else None) (List.init (String.length all) (String.get all))) in
  let t = if typed <> "" then Text_edit.insert typed t else t in
  List.fold_left
    (fun t k ->
      let s = Text_edit.to_string t in
      let line, col = place s (Text_edit.caret t) in
      match k with
      | "Enter" when multiline ->
          (* the new line indented as the one it breaks *)
          let _, l = List.nth (lines s) line in
          let rec spaces i = if i < String.length l && l.[i] = ' ' then spaces (i + 1) else i in
          Text_edit.insert ("\n" ^ String.make (spaces 0) ' ') t
      | "Tab" -> Text_edit.insert "  " t
      | "Backspace" -> Text_edit.delete_backward t
      | "Delete" -> Text_edit.delete_forward t
      | "ArrowLeft" -> Text_edit.at (max 0 (Text_edit.caret t - 1)) t
      | "ArrowRight" -> Text_edit.at (min (String.length s) (Text_edit.caret t + 1)) t
      | "ArrowUp" when line > 0 -> Text_edit.at (offset s (line - 1) col) t
      | "ArrowDown" -> Text_edit.at (offset s (line + 1) col) t
      | "Home" -> Text_edit.at (offset s line 0) t
      | "End" -> Text_edit.at (offset s line max_int) t
      | _ -> t)
    t keys

(* whether the prompt holds whole expressions, or wants more lines *)
let complete (s : string) : bool =
  match Sexpr_read.read_all Scheme s with _ -> true | exception Sexpr_read.Error (msg, _) -> not (String.starts_with ~prefix:"end of input" msg)

(* the definitions scrolled so that the caret shows *)
let reveal (m : model) : model =
  let line, _ = place (Text_edit.to_string m.defs) (Text_edit.caret m.defs) in
  if line < m.top then { m with top = line } else if line >= m.top + rows then { m with top = line - rows + 1 } else m

(*****************************************************************************)
(* Update *)
(*****************************************************************************)
let update (computer : computer) (m : model) : model =
  let keys, held = presses m computer in
  let control = Set_.mem "Control" computer.keyboard.keys in
  let mouse = mouse_at computer in
  let clicked b = computer.mouse.mclick && inside mouse b in
  let m' = { m with frames = m.frames + 1; held } in
  let m =
    match (m.stepper, m.status) with
    | Some s, _ -> update_stepper computer keys m' s
    | None, World w -> if control && List.mem "b" keys then break m' else update_world computer m' w
    | None, _ ->
        let m = m' in
        (* the buttons, and their keys: Control-T executes, Control-B
           breaks, as in DrScheme *)
        let m = if clicked execute_button || (control && List.mem "t" keys) then execute m else m in
        let m = if clicked break_button || (control && List.mem "b" keys) then break m else m in
        let m = if clicked step_button && not (running m) then open_stepper m else m in
        let m =
          if clicked language_button && not (running m) then
            { m with level = (match m.level with Beginning -> Standard | Standard -> Beginning); entries = Warning "Language changed: click Execute." :: m.entries }
          else m
        in
        (* the mouse: a click in a window gives it the keys, and in the
           definitions places the caret; a drag selects *)
        let mx, my = mouse in
        let in_defs = my >= defs_y && my < defs_y +. defs_h in
        let defs_offset () =
          let s = Text_edit.to_string m.defs in
          offset s (m.top + int_of_float ((my -. defs_y -. 4.) /. lh)) (int_of_float (Float.round ((mx -. text_x) /. cw)))
        in
        let m =
          if computer.mouse.mclick && in_defs then { m with focus = Definitions; defs = Text_edit.at (defs_offset ()) m.defs; dragging = true }
          else if computer.mouse.mclick && my >= inter_y && my < inter_y +. inter_h then { m with focus = Interactions }
          else if m.dragging && computer.mouse.mdown then { m with defs = Text_edit.to_ (defs_offset ()) m.defs }
          else { m with dragging = computer.mouse.mdown && m.dragging }
        in
        (* the keys, into the window that has them *)
        let m =
          if control then
            match (List.mem "z" keys, m.focus) with
            | true, Definitions -> { m with defs = Text_edit.undo m.defs; pink = None }
            | _ -> m
          else
            match m.focus with
            | Definitions ->
                let defs = edit m.defs computer keys ~multiline:true in
                if Text_edit.to_string defs = Text_edit.to_string m.defs then { m with defs }
                else
                  let m = { m with defs; pink = None } in
                  (* DrScheme's reminder that what runs is not what shows *)
                  if m.executed <> None && not (List.exists (function Warning _ -> true | _ -> false) m.entries) then
                    add (Warning "Warning: The definitions window has changed. Click Execute.") m
                  else m
            | Interactions ->
                (* ix: what was typed in this frame is in the line before Enter
                 * is asked whether the line is whole. A frame is an eighth of a
                 * second on mini-9pi, and the last parenthesis and Enter are
                 * then one frame's: the line was taken for an unfinished one
                 * (found by the session under mini-qemu), and a whole line and
                 * its Enter in a frame ran nothing.
                 * old: ... && complete (Text_edit.to_string m.input) *)
                let typed = edit m.input computer (List.filter (fun k -> k <> "Enter") keys) ~multiline:true in
                if List.mem "Enter" keys && not (running m) && complete (Text_edit.to_string typed) then
                  let text = Text_edit.to_string typed in
                  let m = { (add (Echo text) m) with input = Text_edit.of_string "" } in
                  match Sexpr_read.read_all Scheme text with
                  | forms -> { m with machine = Some (machine m); status = Busy { forms; from_defs = false; running = false } }
                  | exception Sexpr_read.Error (msg, _) -> add (Failure ("read: " ^ msg)) m
                else if running m then m
                else { m with input = edit m.input computer keys ~multiline:true }
        in
        reveal m
  in
  let m = work m fuel in
  { m with keyboard = computer.keyboard; mouse = computer.mouse }
