(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Ebuffer.mli *)
open Efuns

let fundamental_mode : major_mode = { maj_name = "Fundamental"; maj_map = Keymap.create (); maj_colors = None; maj_hooks = [] }

let find_buffer_opt (name : string) : buffer option =
  List.find_opt (fun (b : buffer) -> b.buf_name = name) Globals.editor.edt_buffers

let make (name : string) (filename : string option) (text : Text.t) : buffer = {
  buf_text = text; buf_name = name; buf_filename = filename; buf_last_saved = Text.version text;
  buf_point = Text.new_point text 0; buf_start = Text.new_point text 0; buf_mark = None;
  buf_map = Keymap.create (); buf_major_mode = fundamental_mode; buf_minor_modes = []; buf_colors = None;
}

let set_major_mode (buf : buffer) (mode : major_mode) : unit =
  buf.buf_major_mode <- mode;
  buf.buf_minor_modes <- [];
  buf.buf_colors <- None;
  List.iter (fun (hook : buffer -> unit) -> hook buf) mode.maj_hooks

(* OPTIMIZATION: the highlighter is given the lines asked and not the
 * whole text, from a line before them where an item of the program
 * starts: one that does not begin with a space, after an empty line (or
 * 1,000 lines before, or the text's start). A highlighter reads a text
 * from its start: what it says of a line depends on what is before (a
 * comment open, a let's arguments); from an item's start it says the
 * same, but: in a comment or a string that has such a line in it,
 * whose end is then shown as code (ix's sources' comments have a star
 * or a space at their lines' starts); and where a name's color is
 * said by a line far from it (an assembly file's labels, a Smalltalk
 * class's variables). Of ix's 1,967 sources, at four places in each,
 * 80 screens of 7,868 are not the whole text's (with the author's
 * colors, where a parameter and a local show; 26 of 7,440 before
 * they did). [whole] is the simple way, to
 * compare (mini-emacs-tty -whole; tests/keys.sh does, on ix's sources).
 * old: let colors = highlighter (Text.to_string buf.buf_text), kept
 *   while the text's version is the same.
 * A character typed in tiny/TinyML.ml (83,342 bytes, 1,765 lines), by
 * OCaml's code: 21 ms at its start and 37 at its end with the whole
 * text, 1.3 and 1.7 so; with OCaml's items parsed too (Names_ml), 46
 * and 2.6. *)
let whole : bool ref = ref false

(* (not a line that starts with and: OCaml's "and f x =" and "and t ="
 * continue an item, and say what they are by the let or the type
 * before them) *)
let starts_item (text : Text.t) (bol : int) : bool =
  bol + 4 < Text.length text && not (String.contains " \t\n" (Text.get text bol)) && (bol = 1 || Text.get text (bol - 2) = '\n')
  && Text.sub text bol 4 <> "and "

let rec item_start (text : Text.t) (bol : int) (left : int) : int =
  if bol = 0 || left = 0 || starts_item text bol then bol else item_start text (Text.bol text (bol - 1)) (left - 1)

(* the start of the item after the line at bol, or the text's end: a
 * part of the text ends with an item whole, for a highlighter that
 * parses (OCaml's, an item at a time) *)
let rec item_after (text : Text.t) (bol : int) (left : int) : int =
  let next = Text.eol text bol + 1 in
  if next >= Text.length text then Text.length text
  else if left = 0 || starts_item text next then next
  else item_after text next (left - 1)

let colors (buf : buffer) (start : int) (lines : int) : (colors * int) option =
  match buf.buf_major_mode.maj_colors with
  | None -> None
  | Some highlighter ->
      let text = buf.buf_text in
      let from = if !whole then 0 else item_start text (Text.bol text start) 1000 in
      (* (some lines more: a banner is known by the two lines after it) *)
      let upto = if !whole then Text.length text else item_after text (Text.forward_line text start (lines + 4)) 1000 in
      let colors =
        match buf.buf_colors with
        | Some (version, f, u, colors) when version = Text.version text && f = from && u >= upto -> colors
        | _ ->
            let colors = highlighter (Text.sub text from (upto - from)) in
            buf.buf_colors <- Some (Text.version text, from, upto, colors);
            colors in
      Some (colors, Text.newlines text from (Text.bol text start))

let create (name : string) (filename : string option) (text : Text.t) : buffer =
  let rec unique (n : int) : string =
    let s = if n = 1 then name else Printf.sprintf "%s<%d>" name n in
    if find_buffer_opt s = None then s else unique (n + 1) in
  let buf = make (unique 1) filename text in
  Globals.editor.edt_buffers <- buf :: Globals.editor.edt_buffers;
  buf

let kill (buf : buffer) : unit =
  Globals.editor.edt_buffers <- List.filter (fun (b : buffer) -> b != buf) Globals.editor.edt_buffers

let names () : string list = List.map (fun (b : buffer) -> b.buf_name) Globals.editor.edt_buffers

let read (caps : < Cap.open_in ; .. >) (filename : string) : buffer =
  match List.find_opt (fun (b : buffer) -> b.buf_filename = Some filename) Globals.editor.edt_buffers with
  | Some buf -> buf
  | None ->
      let s = match FS.read_opt caps (Fpath.v filename) with Some s -> s | None -> "" in
      let buf = create (Filename.basename filename) (Some filename) (Text.create s) in
      (match List.find_opt (fun ((suffix, _) : string * major_mode) -> Filename.check_suffix filename suffix) Globals.editor.edt_modes with
       | Some (_, mode) -> set_major_mode buf mode
       | None -> ());
      buf

let save (caps : < Cap.open_out ; .. >) (buf : buffer) : unit =
  match buf.buf_filename with
  | None -> failwith "No file name"
  | Some filename ->
      FS.write caps (Fpath.v filename) (Text.to_string buf.buf_text);
      buf.buf_last_saved <- Text.version buf.buf_text

let modified (buf : buffer) : bool = Text.version buf.buf_text <> buf.buf_last_saved
