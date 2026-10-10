(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dired.mli *)
open Efuns

(* a line: d or -, a file's length, then the name, from this column *)
let name_col = 14

(* a name's color: a directory's (it ends with /) blue *)
let color : (string -> Vt.attrs) ref =
  ref (fun (name : string) -> if Filename.check_suffix name "/" || name = ".." then { Vt.plain with fg = Blue; bold = true } else Vt.plain)

(* (a line's colors depend on no other) *)
let colors (text : string) : colors =
  Array.of_list (List.map (fun (line : string) ->
    let n = String.length line - name_col in
    if n <= 0 then []
    else (match !color (String.sub line name_col n) with a when a = Vt.plain -> [] | a -> [ (name_col, n, a) ]))
    (String.split_on_char '\n' text))

let mode : major_mode = { maj_name = "Dired"; maj_map = Keymap.create (); maj_colors = Some colors; maj_hooks = [] }

let listing (caps : caps) (dir : string) : string =
  let entries = List.sort (fun (a : Sys_plan9.dir) (b : Sys_plan9.dir) -> compare a.name b.name) (Sys_plan9.dirread caps dir) in
  let line (kind : char) (length : string) (name : string) : string = Printf.sprintf "%c %10s  %s\n" kind length name in
  String.concat "" (line 'd' "" ".." :: List.map (fun (d : Sys_plan9.dir) ->
    if d.mode_type land Sys_plan9.dmdir <> 0 then line 'd' "" (d.name ^ "/") else line '-' (string_of_int d.length) d.name) entries)

(* the buffer's text read again from its directory *)
let update (frame : frame) : unit =
  let buf = frame.frm_buffer in
  match buf.buf_filename with
  | None -> ()
  | Some dir ->
      let text = buf.buf_text and line = Text.line buf.buf_text (Frame.point frame) in
      ignore (Text.delete text 0 (Text.length text));
      Text.insert text 0 (listing frame.caps dir);
      buf.buf_last_saved <- Text.version text;
      Frame.goto frame (Text.forward_line text 0 line)

let open_directory (frame : frame) (dir : string) : unit =
  let dir = if Filename.check_suffix dir "/" then dir else dir ^ "/" in
  let buf =
    match List.find_opt (fun (b : buffer) -> b.buf_filename = Some dir && b.buf_major_mode == mode) Globals.editor.edt_buffers with
    | Some buf -> buf
    | None ->
        let buf = Ebuffer.create (Filename.basename dir ^ "/") (Some dir) (Text.create "") in
        Ebuffer.set_major_mode buf mode;
        buf in
  Frame.change_buffer frame buf;
  update frame

(* what the point's line names, a directory's with its / *)
let file (frame : frame) : string =
  let buf = frame.frm_buffer in
  let text = buf.buf_text in
  let bol = Text.bol text (Frame.point frame) in
  let eol = Text.eol text bol in
  if eol - bol <= name_col then failwith "No file on this line";
  (match buf.buf_filename with Some dir -> dir | None -> "") ^ Text.sub text (bol + name_col) (eol - bol - name_col)

let open_line (frame : frame) : unit = Multi_buffers.open_file frame (FS.cleanname (file frame))

let parent (frame : frame) : unit =
  match frame.frm_buffer.buf_filename with
  | Some dir -> open_directory frame (FS.cleanname (dir ^ ".."))
  | None -> ()

let () =
  Multi_buffers.open_directory := open_directory;
  List.iter (fun ((keys, action) : string * action) -> Keymap.add_binding mode.maj_map keys action) [
    Keymap.any_char, (fun (frame : frame) -> Top_window.message frame "RET opens, ^ the directory above, g reads again");
    "RET", open_line; "f", open_line; "^", parent; "g", update; "n", Move.forward_line; "p", Move.backward_line;
  ];
  Action.define_all [ "dired_open", open_line; "dired_parent", parent; "dired_update", update ]
