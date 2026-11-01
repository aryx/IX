(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Apps.mli *)

type size = Max | Size of int * int

type entry = { group : string; name : string; icon : string; size : size; command : string }

let groups =
  [ "apps", "Apps"; "games", "Games"; "net", "Internet"; "devtools", "Developer";
    "system", "System"; "examples", "Examples" ]

let size_of_text line s =
  if s = "max" then Max
  else
    match String.split_on_char 'x' s with
    | [ w; h ] when int_of_string_opt w <> None && int_of_string_opt h <> None ->
        Size (int_of_string w, int_of_string h)
    | _ -> failwith ("Apps: a bad size: " ^ line)

let parse text =
  let entry line =
    match List.map String.trim (String.split_on_char '|' line) with
    | [ group; name; icon; size; command ] when group <> "" && name <> "" && command <> "" ->
        if group <> "top" && not (List.mem_assoc group groups) then failwith ("Apps: no such group: " ^ line);
        { group; name; icon; size = size_of_text line size; command }
    | _ -> failwith ("Apps: not five fields: " ^ line) in
  let wanted line = let l = String.trim line in l <> "" && l.[0] <> '#' in
  List.map entry (List.filter wanted (String.split_on_char '\n' text))

let program e =
  match String.split_on_char ' ' e.command with
  | p :: _ -> p
  | [] -> e.command

let open_line e =
  (* (wctl's -label is one word) *)
  let label = String.map (fun c -> if c = ' ' then '-' else c) e.name in
  let place = match e.size with
    | Max -> "-max"
    | Size (w, h) -> Printf.sprintf "-at c %d %d" w h in
  Printf.sprintf "new %s -label %s %s" place label e.command

type item = Run of entry | Group of string * string | Exit

let of_group entries g = List.filter (fun e -> e.group = g) entries

let left entries =
  let top = List.map (fun e -> Run e) (of_group entries "top") in
  let named = List.filter (fun (g, _) -> of_group entries g <> []) groups in
  top @ List.map (fun (g, name) -> Group (g, name)) named @ [ Exit ]

let right entries g = List.map (fun e -> Run e) (of_group entries g)

let row_h = 24
let left_w = 150
let right_w = 170

let size_of entries =
  let longest = List.fold_left (fun n (g, _) -> max n (List.length (of_group entries g))) (List.length (left entries)) groups in
  (left_w + right_w, (longest * row_h) + 8)

let row_at top y = if y < top then -1 else (y - top) / row_h
