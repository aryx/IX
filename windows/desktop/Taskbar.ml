(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Taskbar.mli *)

type window = { id : int; label : string; current : bool; hidden : bool; layer : string }

let window_of id label wctl =
  let words = List.filter (fun s -> s <> "") (String.split_on_char ' ' wctl) in
  match words with
  | _ :: _ :: _ :: _ :: current :: shown :: rest ->
      Some { id; label; current = current = "current"; hidden = shown = "hidden";
             layer = (match rest with l :: _ -> l | [] -> "") }
  | _ -> None

let tasks = List.filter (fun w -> w.layer = "")
let menu = List.find_opt (fun w -> w.layer = "popup" && w.label = "startmenu")

type part = Start | Task of window | Clock

let start_width = 64
let task_width = 160
let gap = 4

let layout (r : Rectangle.t) tasks clock_width =
  let y0 = r.min.y + 2 and y1 = r.max.y - 2 in
  let start_r : Rectangle.t = Rectangle.v (r.min.x + 2) y0 (r.min.x + 2 + start_width) y1 in
  let clock_r : Rectangle.t = Rectangle.v (r.max.x - clock_width - 2) y0 (r.max.x - 2) y1 in
  let x0 = start_r.max.x + gap and room = clock_r.min.x - gap - (start_r.max.x + gap) in
  let n = List.length tasks in
  let w = if n = 0 then 0 else min task_width (max 0 ((room - (gap * (n - 1))) / n)) in
  let buttons = List.mapi (fun i t ->
      let x = x0 + (i * (w + gap)) in
      (Task t, Rectangle.v x y0 (x + w) y1)) tasks in
  ((Start, start_r) :: buttons) @ [ (Clock, clock_r) ]

let at parts p =
  match List.find_opt (fun (_, r) -> Rectangle.contains r p) parts with
  | Some (part, _) -> Some part
  | None -> None

let shorten width_of room text =
  if width_of text <= room then text
  else begin
    let rec cut n =
      if n <= 0 then ""
      else
        let s = Utf8.sub text 0 n ^ "..." in
        if width_of s <= room then s else cut (n - 1) in
    cut (Utf8.length text - 1)
  end

let set_hidden id on ws = List.map (fun w -> if w.id = id then { w with hidden = on } else w) ws

let press ws part =
  let menu_win = menu ws in
  let hide_menu =
    match menu_win, part with
    | _, Start -> []
    | Some m, _ when not m.hidden -> [ m.id ]
    | _ -> [] in
  let ws = List.fold_left (fun ws id -> set_hidden id true ws) ws hide_menu in
  let lines = List.map (Printf.sprintf "hide -id %d") hide_menu in
  match part with
  | Start ->
      (match menu_win with
       | Some m when m.hidden -> [ Printf.sprintf "unhide -id %d" m.id ], set_hidden m.id false ws
       | Some m -> [ Printf.sprintf "hide -id %d" m.id ], set_hidden m.id true ws
       | None -> [], ws)
  | Clock -> lines, ws
  | Task t ->
      let front ws = List.map (fun w -> if w.layer <> "" then w else { w with current = w.id = t.id }) ws in
      if t.hidden then lines @ [ Printf.sprintf "unhide -id %d" t.id ], front (set_hidden t.id false ws)
      else if t.current then
        lines @ [ Printf.sprintf "hide -id %d" t.id ],
        List.map (fun w -> if w.id = t.id then { w with hidden = true; current = false } else w) ws
      else lines @ [ Printf.sprintf "current -id %d" t.id ], front ws
