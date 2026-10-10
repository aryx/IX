(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Indent.mli *)
open Efuns

(* where the line's text starts: after its spaces and tabs *)
let rec text_start (text : Text.t) (pos : int) : int =
  if pos < Text.length text && (Text.get text pos = ' ' || Text.get text pos = '\t') then text_start text (pos + 1) else pos

(* the indentation of the line before bol's that is not blank: its column *)
let rec before (text : Text.t) (bol : int) : int =
  if bol = 0 then 0
  else begin
    let start = Text.bol text (bol - 1) in
    let first = text_start text start in
    if first = Text.eol text start then before text start else Frame.column text first
  end

let indent_line (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let bol = Text.bol text (Frame.point frame) in
  let first = text_start text bol in
  let now = Frame.column text first and wanted = before text bol in
  ignore (Text.delete text bol (first - bol));
  Text.insert text bol (String.make (if now < wanted then wanted else now + 2) ' ');
  (* (a point in the indentation: to the text's start) *)
  let first = text_start text bol in
  if Frame.point frame < first then Frame.goto frame first

let newline_and_indent (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let bol = Text.bol text (Frame.point frame) in
  Edit.insert_string frame ("\n" ^ Text.sub text bol (min (text_start text bol) (Frame.point frame) - bol))

let () = Action.define_all [ "indent_line", indent_line; "newline_and_indent", newline_and_indent ]
