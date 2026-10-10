(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Macros.mli *)
open Efuns

let macro : key list ref = ref []

let start_macro (frame : frame) : unit =
  (Top_window.of_frame frame).top_recorded <- Some [];
  Top_window.message frame "Defining keyboard macro..."

(* (the keys recorded end with the two that end the macro) *)
let end_macro (frame : frame) : unit =
  let top = Top_window.of_frame frame in
  match top.top_recorded with
  | Some (_ :: _ :: keys) ->
      macro := List.rev keys;
      top.top_recorded <- None;
      Top_window.message frame "Keyboard macro defined"
  | _ -> failwith "Not defining a keyboard macro"

let call_macro (frame : frame) : unit =
  let top = Top_window.of_frame frame in
  if top.top_recorded <> None then failwith "A keyboard macro is being defined";
  if !macro = [] then failwith "No keyboard macro defined";
  List.iter (fun (key : key) -> Top_window.handle_key top key) !macro

let () = Action.define_all [ "start_macro", start_macro; "end_macro", end_macro; "call_macro", call_macro ]
