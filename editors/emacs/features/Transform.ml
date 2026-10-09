(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Transform.mli *)
open Efuns

(* [replace frame pos len s]: the point after s *)
let replace (frame : frame) (pos : int) (len : int) (s : string) : unit =
  let text = frame.frm_buffer.buf_text in
  ignore (Text.delete text pos len);
  Text.insert text pos s;
  Frame.goto frame (pos + String.length s)

(* the text from the point to the end of the word after it, changed *)
let on_word (f : string -> string) (frame : frame) : unit =
  let from = Frame.point frame in
  Move.forward_word frame;
  let len = Frame.point frame - from in
  replace frame from len (f (Text.sub frame.frm_buffer.buf_text from len))

(* (the first letter of the word is after what is not of it) *)
let capitalize (s : string) : string =
  let first = ref true in
  String.map (fun (c : char) ->
    if Char.lowercase_ascii c = Char.uppercase_ascii c then c
    else if !first then begin first := false; Char.uppercase_ascii c end
    else Char.lowercase_ascii c) s

let upcase_word (frame : frame) : unit = on_word String.uppercase_ascii frame
let downcase_word (frame : frame) : unit = on_word String.lowercase_ascii frame
let capitalize_word (frame : frame) : unit = on_word capitalize frame

let transpose_chars (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  let point = Frame.point frame in
  (* b the second of the two: the character at the point, or before it at a line's end *)
  let b = if point = Text.length text || Text.get text point = '\n' then Frame.prev text point else point in
  let a = Frame.prev text b and after = Frame.next text b in
  if b = 0 || a = b then failwith "Nothing to transpose";
  replace frame a (after - a) (Text.sub text b (after - b) ^ Text.sub text a (b - a))

let fill_column = 70

let blank (text : Text.t) (bol : int) : bool =
  let rec go (pos : int) : bool =
    pos = Text.length text || Text.get text pos = '\n' || ((Text.get text pos = ' ' || Text.get text pos = '\t') && go (pos + 1)) in
  go bol

let fill_paragraph (frame : frame) : unit =
  let text = frame.frm_buffer.buf_text in
  (* the paragraph's first line, and the position after its last *)
  let rec first (bol : int) : int = if bol = 0 || blank text (Text.bol text (bol - 1)) then bol else first (Text.bol text (bol - 1)) in
  let rec last (eol : int) : int = if eol = Text.length text || blank text (eol + 1) then eol else last (Text.eol text (eol + 1)) in
  let bol = Text.bol text (Frame.point frame) in
  if blank text bol then failwith "No paragraph here";
  let from = first bol and upto = last (Text.eol text bol) in
  let s = Text.sub text from (upto - from) in
  let rec indent (i : int) : int = if i < String.length s && (s.[i] = ' ' || s.[i] = '\t') then indent (i + 1) else i in
  let prefix = String.sub s 0 (indent 0) in
  let words = List.filter (fun (w : string) -> w <> "")
      (String.split_on_char ' ' (String.map (fun (c : char) -> if c = '\n' || c = '\t' then ' ' else c) s)) in
  (* a word goes on the line while it holds it *)
  let b = Buffer.create (String.length s) and col = ref 0 in
  List.iter (fun (w : string) ->
    let n = Utf8.length w in
    if !col = 0 then begin Buffer.add_string b (prefix ^ w); col := String.length prefix + n end
    else if !col + 1 + n > fill_column then begin Buffer.add_string b ("\n" ^ prefix ^ w); col := String.length prefix + n end
    else begin Buffer.add_string b (" " ^ w); col := !col + 1 + n end) words;
  if Buffer.contents b <> s then replace frame from (upto - from) (Buffer.contents b)

let goto_line (frame : frame) : unit =
  Minibuffer.read frame "Goto line: " "" Minibuffer.no_completion (fun (frame : frame) (answer : string) ->
    match int_of_string_opt (String.trim answer) with
    | Some n when n >= 1 -> Frame.goto frame (Text.forward_line frame.frm_buffer.buf_text 0 (n - 1))
    | _ -> failwith ("Not a line's number: " ^ answer))

let () = Action.define_all [
  "upcase_word", upcase_word; "downcase_word", downcase_word; "capitalize_word", capitalize_word;
  "transpose_chars", transpose_chars; "fill_paragraph", fill_paragraph; "goto_line", goto_line;
]
