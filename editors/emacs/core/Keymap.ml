(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Keymap.mli *)
open Efuns

let create () : map = Hashtbl.create 16

let rec add_binding (map : map) (keys : string) (action : action) : unit =
  match String.index_opt keys ' ' with
  | None -> Hashtbl.replace map keys (Function action)
  | Some i ->
      let key = String.sub keys 0 i in
      let sub : map =
        match Hashtbl.find_opt map key with
        | Some (Prefix m) -> m
        | _ -> let m = create () in Hashtbl.replace map key (Prefix m); m in
      add_binding sub (String.sub keys (i + 1) (String.length keys - i - 1)) action

let add_global_key (keys : string) (action : action) : unit = add_binding Globals.editor.edt_map keys action

let rec get_binding (map : map) (keys : key list) : binding option =
  match keys with
  | [] -> Some (Prefix map)
  | k :: rest -> (
      match Hashtbl.find_opt map k with
      | Some (Prefix m) -> get_binding m rest
      | Some (Function f) when rest = [] -> Some (Function f)
      | _ -> None)

(* the bytes that are not a character, or Control or Escape and one *)
let named : (string * key) list = [
  "\r", "RET"; "\t", "TAB"; "\x1b", "ESC"; "\x7f", "DEL"; "\x00", "C-@"; "\x1f", "C-_";
  "\x1b[A", "<up>"; "\x1b[B", "<down>"; "\x1b[C", "<right>"; "\x1b[D", "<left>"; "\x1b[H", "<home>"; "\x1b[F", "<end>";
  "\x1b[3~", "<delete>"; "\x1b[5~", "<prior>"; "\x1b[6~", "<next>";
  (* (xterm's: an arrow with Alt, with Control) *)
  "\x1b[1;3A", "M-<up>"; "\x1b[1;3B", "M-<down>"; "\x1b[1;3C", "M-<right>"; "\x1b[1;3D", "M-<left>";
  "\x1b[1;5A", "C-<up>"; "\x1b[1;5B", "C-<down>"; "\x1b[1;5C", "C-<right>"; "\x1b[1;5D", "C-<left>";
]

(* the mouse, as xterm says it: ESC [ < button ; column ; row M, from 1 *)
let mouse_event (s : string) : (int * int * int) option =
  let n = String.length s in
  if n > 4 && String.sub s 0 3 = "\x1b[<" && s.[n - 1] = 'M' then
    match List.map int_of_string_opt (String.split_on_char ';' (String.sub s 3 (n - 4))) with
    | [ Some button; Some col; Some row ] -> Some (button, row - 1, col - 1)
    | _ -> None
  else None

let mouse (s : string) : (int * int) option =
  match mouse_event s with Some (_, row, col) -> Some (row, col) | None -> None

let rec of_bytes (s : string) : key =
  match List.assoc_opt s named, mouse_event s with
  | Some name, _ -> name
  | None, Some (0, _, _) -> "<mouse-1>"
  | None, Some (64, _, _) -> "<wheel-up>"
  | None, Some (65, _, _) -> "<wheel-down>"
  | None, Some _ -> "<mouse>"
  | None, None ->
      let n = String.length s in
      if n = 1 && s.[0] < ' ' then "C-" ^ String.make 1 (Char.chr (Char.code s.[0] + 96))
      else if n > 1 && s.[0] = '\x1b' && s.[1] <> '[' && s.[1] <> 'O' then "M-" ^ of_bytes (String.sub s 1 (n - 1))
      else s

let any_char : key = "<char>"

(* (a name of several letters starts with a capital, C-, M- or <) *)
let is_char (key : key) : bool =
  key >= " " && key <> "\x7f" && (String.length key = 1 || key.[0] >= '\x80')
