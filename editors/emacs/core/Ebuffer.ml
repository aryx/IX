(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Ebuffer.mli *)
open Efuns

let fundamental_mode : major_mode = { maj_name = "Fundamental"; maj_map = Keymap.create () }

let find_buffer_opt (name : string) : buffer option =
  List.find_opt (fun (b : buffer) -> b.buf_name = name) Globals.editor.edt_buffers

let create (name : string) (filename : string option) (text : Text.t) : buffer =
  let rec unique (n : int) : string =
    let s = if n = 1 then name else Printf.sprintf "%s<%d>" name n in
    if find_buffer_opt s = None then s else unique (n + 1) in
  let buf = {
    buf_text = text; buf_name = unique 1; buf_filename = filename; buf_last_saved = Text.version text;
    buf_map = Keymap.create (); buf_major_mode = fundamental_mode; buf_minor_modes = [];
  } in
  Globals.editor.edt_buffers <- buf :: Globals.editor.edt_buffers;
  buf

let read (caps : < Cap.open_in ; .. >) (filename : string) : buffer =
  match List.find_opt (fun (b : buffer) -> b.buf_filename = Some filename) Globals.editor.edt_buffers with
  | Some buf -> buf
  | None ->
      let s = match FS.read_opt caps (Fpath.v filename) with Some s -> s | None -> "" in
      create (Filename.basename filename) (Some filename) (Text.create s)

let save (caps : < Cap.open_out ; .. >) (buf : buffer) : unit =
  match buf.buf_filename with
  | None -> failwith "No file name"
  | Some filename ->
      FS.write caps (Fpath.v filename) (Text.to_string buf.buf_text);
      buf.buf_last_saved <- Text.version buf.buf_text

let modified (buf : buffer) : bool = Text.version buf.buf_text <> buf.buf_last_saved
