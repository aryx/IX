(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Buffer_menu.mli *)
open Efuns

let mode : major_mode = { maj_name = "Buffer Menu"; maj_map = Keymap.create (); maj_colors = None; maj_hooks = [] }

let name = "*Buffers*"

(* (a tab between two columns: a line's name is what is between its
 * first two) *)
let list_buffers (frame : frame) : unit =
  let from = frame.frm_buffer in
  let lines = List.filter_map (fun (b : buffer) ->
    if b.buf_name = name then None
    else Some (Printf.sprintf "%c%c\t%s\t%d\t%s\n" (if b == from then '.' else ' ') (if Ebuffer.modified b then '*' else ' ')
                 b.buf_name (Text.length b.buf_text) (match b.buf_filename with Some f -> f | None -> "")))
      Globals.editor.edt_buffers in
  let buf = match Ebuffer.find_buffer_opt name with Some b -> b | None -> Ebuffer.create name None (Text.create "") in
  ignore (Text.delete buf.buf_text 0 (Text.length buf.buf_text));
  Text.insert buf.buf_text 0 (String.concat "" lines);
  buf.buf_last_saved <- Text.version buf.buf_text;
  Ebuffer.set_major_mode buf mode;
  Frame.change_buffer frame buf;
  Frame.goto frame 0

let select (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let bol = Text.bol text (Frame.point frame) in
  match String.split_on_char '\t' (Text.sub text bol (Text.eol text bol - bol)) with
  | _ :: buffer :: _ -> (
      match Ebuffer.find_buffer_opt buffer with
      | Some buf -> Frame.change_buffer frame buf
      | None -> failwith ("No buffer named " ^ buffer))
  | _ -> failwith "No buffer on this line"

let () =
  List.iter (fun ((keys, action) : string * action) -> Keymap.add_binding mode.maj_map keys action) [
    Keymap.any_char, (fun (frame : frame) -> Top_window.message frame "RET shows the line's buffer, g lists again");
    "RET", select; "f", select; "g", list_buffers; "n", Move.forward_line; "p", Move.backward_line;
  ];
  Action.define_all [ "list_buffers", list_buffers; "buffer_menu_select", select ]
