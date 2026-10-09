(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Multi_buffers.mli *)
open Efuns

(* a path's directory, with its / ("" for none), and its last name *)
let split (path : string) : string * string =
  match String.rindex_opt path '/' with
  | Some i -> (String.sub path 0 (i + 1), String.sub path (i + 1) (String.length path - i - 1))
  | None -> ("", path)

let is_directory (caps : caps) (path : string) : bool =
  match Sys_plan9.dirstat caps path with
  | (d : Sys_plan9.dir) -> d.mode_type land Sys_plan9.dmdir <> 0
  | exception _ -> false

let ignored_extensions : string list ref = ref []

(* the files of what is typed's directory that start with its last
 * name, a directory with its /; those of a name with a dot first only
 * if a dot is typed *)
let complete_filename (caps : caps) (typed : string) : string list =
  let dir, name = split typed in
  let entries = match Sys_plan9.dirread caps (if dir = "" then "." else dir) with l -> l | exception _ -> [] in
  List.sort compare (List.filter_map (fun (d : Sys_plan9.dir) ->
    if String.starts_with ~prefix:name d.name && (name <> "" || not (String.starts_with ~prefix:"." d.name))
       && not (List.exists (fun (suffix : string) -> Filename.check_suffix d.name suffix) !ignored_extensions)
    then Some (dir ^ d.name ^ (if d.mode_type land Sys_plan9.dmdir <> 0 then "/" else ""))
    else None) entries)

(* asked from the directory of the frame's file *)
let select_file (frame : frame) (prompt : string) (action : frame -> string -> unit) : unit =
  let dir = match frame.frm_buffer.buf_filename with Some f -> fst (split f) | None -> "" in
  Minibuffer.read frame prompt dir (complete_filename frame.caps) (fun (frame : frame) (file : string) ->
    if file = "" then failwith "No file name";
    action frame file)

let open_directory : (frame -> string -> unit) ref =
  ref (fun (_ : frame) (dir : string) -> failwith (dir ^ " is a directory"))

let open_file (frame : frame) (file : string) : unit =
  if is_directory frame.caps file then !open_directory frame file
  else Frame.change_buffer frame (Ebuffer.read frame.caps file)

let load_buffer (frame : frame) : unit = select_file frame "Find file: " open_file

let save_buffer (frame : frame) : unit =
  let buf = frame.frm_buffer in
  Ebuffer.save frame.caps buf;
  Top_window.message frame ("Wrote " ^ (match buf.buf_filename with Some f -> f | None -> ""))

let write_buffer (frame : frame) : unit =
  select_file frame "Write file: " (fun (frame : frame) (file : string) ->
    if is_directory frame.caps file then failwith (file ^ " is a directory");
    let buf = frame.frm_buffer in
    buf.buf_filename <- Some file;
    buf.buf_name <- Filename.basename file;
    save_buffer frame)

(* the buffer shown before this one: the first other of the editor's,
 * or a new one *)
let other_buffer (buf : buffer) : buffer =
  match List.find_opt (fun (b : buffer) -> b != buf) Globals.editor.edt_buffers with
  | Some b -> b
  | None -> Ebuffer.create "*scratch*" None (Text.create "")

(* [select_buffer frame prompt default action]: a buffer's name asked,
 * the default's for no answer *)
let select_buffer (frame : frame) (prompt : string) (default : buffer) (action : frame -> string -> unit) : unit =
  Minibuffer.read frame (Printf.sprintf "%s: (default %s) " prompt default.buf_name) ""
    (fun (typed : string) -> Minibuffer.among (Ebuffer.names ()) typed)
    (fun (frame : frame) (name : string) -> action frame (if name = "" then default.buf_name else name))

let change_buffer (frame : frame) : unit =
  select_buffer frame "Switch to buffer" (other_buffer frame.frm_buffer) (fun (frame : frame) (name : string) ->
    let buf = match Ebuffer.find_buffer_opt name with Some b -> b | None -> Ebuffer.create name None (Text.create "") in
    Frame.change_buffer frame buf)

let switch_to_other_buffer (frame : frame) : unit = Frame.change_buffer frame (other_buffer frame.frm_buffer)

let kill_buffer (frame : frame) : unit =
  select_buffer frame "Kill buffer" frame.frm_buffer (fun (frame : frame) (name : string) ->
    match Ebuffer.find_buffer_opt name with
    | None -> failwith ("No buffer named " ^ name)
    | Some buf ->
        let kill (_ : frame) : unit =
          let other = other_buffer buf in
          List.iter (fun (top : top_window) ->
            List.iter (fun (f : frame) -> if f.frm_buffer == buf then Frame.change_buffer f other) (Window.frames top.window))
            Globals.editor.top_windows;
          Ebuffer.kill buf in
        if Ebuffer.modified buf && buf.buf_filename <> None
        then Minibuffer.yes_or_no frame (Printf.sprintf "Buffer %s modified; kill anyway?" name) kill
        else kill frame)

let exit (frame : frame) : unit =
  let kill (frame : frame) : unit = (Top_window.of_frame frame).top_killed <- true in
  if List.exists (fun (b : buffer) -> Ebuffer.modified b && b.buf_filename <> None) Globals.editor.edt_buffers
  then Minibuffer.yes_or_no frame "Modified buffers exist; exit anyway?" kill
  else kill frame

let () = Action.define_all [
  "load_buffer", load_buffer; "save_buffer", save_buffer; "write_buffer", write_buffer;
  "change_buffer", change_buffer; "switch_to_other_buffer", switch_to_other_buffer; "kill_buffer", kill_buffer; "exit", exit;
]
