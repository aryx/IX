(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Keys.mli *)

(* (a character alone is no name of Vt.key's: itself, after Escape with Alt) *)
let key (alt : bool) (ctrl : bool) (name : string) : string option =
  if String.length name = 1 && not ctrl then Some (if alt then "\x1b" ^ name else name) else Vt.key ~alt ~ctrl name

(* a word's keys, each the bytes a terminal sends *)
let keys (word : string) : string list option =
  let n = String.length word in
  if n > 1 && word.[0] = '=' then Some (List.init (n - 1) (fun (i : int) -> String.make 1 word.[i + 1]))
  else begin
    let rec modifiers (w : string) (ctrl : bool) (alt : bool) : string * bool * bool =
      if String.length w > 2 && w.[1] = '-' && w.[0] = 'C' then modifiers (String.sub w 2 (String.length w - 2)) true alt
      else if String.length w > 2 && w.[1] = '-' && w.[0] = 'A' then modifiers (String.sub w 2 (String.length w - 2)) ctrl true
      else (w, ctrl, alt) in
    let name, ctrl, alt = modifiers word false false in
    match key alt ctrl name with Some bytes -> Some [ bytes ] | None -> None
  end

(* 16x60: a screen of 16 rows and 60 columns *)
let size (word : string) : (int * int) option =
  match String.split_on_char 'x' word with
  | [ r; c ] -> (
      match (int_of_string_opt r, int_of_string_opt c) with
      | Some rows, Some cols -> Some (rows, cols)
      | _ -> None)
  | _ -> None

let run_each (each : Tui_turbo.model -> unit) (script : string) : (Curses.t, string) result =
  let p : Tui_turbo.model Tui.program = Tui_turbo.program in
  let rec go (model : Tui_turbo.model) (words : string list) : (Curses.t, string) result =
    match words with
    | [] -> Ok (p.view model)
    | "" :: rest -> go model rest
    (* (time alone: a slice more of what runs) *)
    | "." :: rest -> go (p.update (Tui.Tick 0.05) model) rest
    | w :: rest -> (
        match size w with
        | Some (rows, cols) -> go (p.update (Tui.Resize (rows, cols)) model) rest
        | None ->
        match keys w with
        | None -> Error w
        | Some ks ->
            (* a tick after a word: what runs (a program started by
             * Control-F9) goes on a slice *)
            let model = List.fold_left (fun (m : Tui_turbo.model) (k : string) -> p.update (Tui.Key k) m) model ks in
            let model = p.update (Tui.Tick 0.05) model in
            each model;
            go model rest) in
  go p.init (String.split_on_char ' ' script)

let run (script : string) : (Curses.t, string) result = run_each (fun (_ : Tui_turbo.model) -> ()) script

let screen (script : string) : (string list, string) result =
  match run script with Ok s -> Ok (Curses.text s) | Error w -> Error w
