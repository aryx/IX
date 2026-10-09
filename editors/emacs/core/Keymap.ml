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
]

let rec of_bytes (s : string) : key =
  match List.assoc_opt s named with
  | Some name -> name
  | None ->
      let n = String.length s in
      if n = 1 && s.[0] < ' ' then "C-" ^ String.make 1 (Char.chr (Char.code s.[0] + 96))
      else if n > 1 && s.[0] = '\x1b' && s.[1] <> '[' && s.[1] <> 'O' then "M-" ^ of_bytes (String.sub s 1 (n - 1))
      else s

let any_char : key = "<char>"

(* (a name of several letters starts with a capital, C-, M- or <) *)
let is_char (key : key) : bool =
  key >= " " && key <> "\x7f" && (String.length key = 1 || key.[0] >= '\x80')
