(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Frame.mli. efuns' Frame is its design's source: a buffer, a
 * point, a first line, a status line; the rows are made another way. *)
open Efuns

let create (caps : caps) (buf : buffer) : frame = {
  frm_buffer = buf;
  frm_point = Text.new_point buf.buf_text (Text.get_position buf.buf_point);
  frm_start = Text.new_point buf.buf_text (Text.get_position buf.buf_start);
  frm_goal = None; frm_xpos = 0; frm_ypos = 0; frm_width = 0; frm_height = 0; frm_has_status_line = true; caps;
}

let kill (frame : frame) : unit =
  let buf = frame.frm_buffer in
  Text.set_position buf.buf_text buf.buf_point (Text.get_position frame.frm_point);
  Text.set_position buf.buf_text buf.buf_start (Text.get_position frame.frm_start);
  Text.remove_point buf.buf_text frame.frm_point;
  Text.remove_point buf.buf_text frame.frm_start

let change_buffer (frame : frame) (buf : buffer) : unit =
  kill frame;
  frame.frm_buffer <- buf;
  frame.frm_point <- Text.new_point buf.buf_text (Text.get_position buf.buf_point);
  frame.frm_start <- Text.new_point buf.buf_text (Text.get_position buf.buf_start);
  frame.frm_goal <- None;
  let editor = Globals.editor in
  if List.memq buf editor.edt_buffers then
    editor.edt_buffers <- buf :: List.filter (fun (b : buffer) -> b != buf) editor.edt_buffers

let point (frame : frame) : int = Text.get_position frame.frm_point
let goto (frame : frame) (pos : int) : unit = Text.set_position frame.frm_buffer.buf_text frame.frm_point pos

(*****************************************************************************)
(* Columns *)
(*****************************************************************************)

(* what is shown for the character at pos, when it is at col: its
 * cells' text, how many bytes it is, how many cells *)
let shown (text : Text.t) (pos : int) (col : int) : string * int * int =
  let c = Text.get text pos in
  if c = '\t' then (let n = 8 - (col mod 8) in (String.make n ' ', 1, n))
  else if c < ' ' then ("^" ^ String.make 1 (Char.chr (Char.code c + 64)), 1, 2)
  else if c = '\x7f' then ("^?", 1, 2)
  else if c < '\x80' then (String.make 1 c, 1, 1)
  else begin
    let s = Text.sub text pos (min 4 (Text.length text - pos)) in
    let code, n = Utf8.decode s 0 in
    (* a byte that is no character's: its number, as Emacs shows it; a
     * wide character has two cells, a combining one none: it is drawn
     * over the character before (at a line's start it has no such) *)
    if code = 0xFFFD && s.[0] <> '\xef' then (Printf.sprintf "\\%03o" (Char.code c), 1, 4)
    else (String.sub s 0 n, n, if col = 0 then max 1 (Utf8.width code) else Utf8.width code)
  end

let next (text : Text.t) (pos : int) : int =
  if pos >= Text.length text then pos else let _, bytes, _ = shown text pos 0 in pos + bytes

(* (the bytes of a character after its first are 10xxxxxx) *)
let rec prev (text : Text.t) (pos : int) : int =
  if pos <= 0 then 0
  else if pos > 1 && Char.code (Text.get text (pos - 1)) land 0xC0 = 0x80 then prev text (pos - 1)
  else pos - 1

(* along the line from bol, a column counted at each character, while
 * [go] says so of the position and its column *)
let rec along (text : Text.t) (pos : int) (col : int) (go : int -> int -> bool) : int * int =
  if pos < Text.length text && Text.get text pos <> '\n' && go pos col then begin
    let _, bytes, cells = shown text pos col in
    along text (pos + bytes) (col + cells) go
  end
  else (pos, col)

let column (text : Text.t) (pos : int) : int =
  snd (along text (Text.bol text pos) 0 (fun (p : int) (_ : int) -> p < pos))

let position_of_column (text : Text.t) (bol : int) (col : int) : int =
  fst (along text bol 0 (fun (_ : int) (c : int) -> c < col))

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

(* the rows of text shown, from frm_start, each its pieces (a column,
 * a text, how it is shown), the last first; where the point is in them
 * (a row and a column, the frame's), if it is; the start of the last
 * line that starts in them *)
let layout (frame : frame) : (int * string * Vt.attrs) list array * (int * int) option * int =
  let text = frame.frm_buffer.buf_text in
  let height = frame.frm_height - (if frame.frm_has_status_line then 1 else 0) and width = frame.frm_width in
  let rows : (int * string * Vt.attrs) list array = Array.make (max 0 height) [] in
  let point = point frame and len = Text.length text in
  let cursor : (int * int) option ref = ref None in
  let last = ref (Text.get_position frame.frm_start) in
  (* the piece being made: a text all shown one way *)
  let piece = Buffer.create width and piece_col = ref 0 and piece_attrs = ref Vt.plain in
  let flush (row : int) : unit =
    if Buffer.length piece > 0 then rows.(row) <- (!piece_col, Buffer.contents piece, !piece_attrs) :: rows.(row);
    Buffer.clear piece in
  let put (row : int) (col : int) (s : string) (attrs : Vt.attrs) : unit =
    if attrs <> !piece_attrs then flush row;
    if Buffer.length piece = 0 then begin piece_col := col; piece_attrs := attrs end;
    Buffer.add_string piece s in
  (* the colors: the line's pieces not passed yet, and where it starts *)
  let colors = Ebuffer.colors frame.frm_buffer !last (max 1 height) in
  let line = ref (match colors with Some (_, n) -> n | None -> 0) and bol = ref !last in
  let of_line (n : int) : (int * int * Vt.attrs) list =
    match colors with Some (c, _) when n < Array.length c -> c.(n) | _ -> [] in
  let pieces = ref (of_line !line) in
  let reversed = List.concat_map (fun (f : frame -> (int * int) list) -> f frame) Globals.editor.edt_highlights in
  let rec attrs (pos : int) : Vt.attrs =
    match !pieces with
    | (col, n, _) :: rest when col + n <= pos - !bol -> pieces := rest; attrs pos
    | (col, _, a) :: _ when col <= pos - !bol -> a
    | _ -> Vt.plain in
  let attrs (pos : int) : Vt.attrs =
    let a = attrs pos in
    if List.exists (fun ((first, after) : int * int) -> first <= pos && pos < after) reversed then { a with reverse = true } else a in
  let rec go (pos : int) (row : int) (col : int) : unit =
    if row < height then begin
      if pos = len || Text.get text pos = '\n' then begin
        if pos = point then cursor := Some (row, col);
        flush row;
        if pos < len then begin
          if row + 1 < height then last := pos + 1;
          incr line;
          bol := pos + 1;
          pieces := of_line !line;
          go (pos + 1) (row + 1) 0
        end
      end
      else begin
        let glyph, bytes, cells = shown text pos col in
        (* the last column is the fold's mark's *)
        if col + cells > width - 1 then begin
          put row col (String.make (max 0 (width - 1 - col)) ' ' ^ "\\") Vt.plain;
          flush row;
          go pos (row + 1) 0
        end
        else begin
          if pos = point then cursor := Some (row, col);
          put row col glyph (attrs pos);
          go (pos + bytes) row (col + cells)
        end
      end
    end in
  go !last 0 0;
  (rows, !cursor, !last)

let point_shown (frame : frame) : bool = let _, cursor, _ = layout frame in cursor <> None
let last_line (frame : frame) : int = let _, _, last = layout frame in last

let recenter (frame : frame) (above : int) : unit =
  let text = frame.frm_buffer.buf_text in
  Text.set_position text frame.frm_start (Text.forward_line text (point frame) (-above))

(* --**-  name  (mode)  L1 C0 -----: ** for a buffer modified *)
let status (frame : frame) : string =
  let buf = frame.frm_buffer in
  let s = Printf.sprintf "--%s-  %s  (%s)  L%d C%d " (if Ebuffer.modified buf then "**" else "--") buf.buf_name
      buf.buf_major_mode.maj_name (Text.line buf.buf_text (point frame) + 1) (column buf.buf_text (point frame)) in
  let n = Utf8.length s in
  if n >= frame.frm_width then Utf8.sub s 0 frame.frm_width else s ^ String.make (frame.frm_width - n) '-'

let display (frame : frame) (screen : Curses.t) : Curses.t * (int * int) =
  (* the point's line in the middle; first of all, if a folded line
   * still hides the point *)
  if not (point_shown frame) then recenter frame ((frame.frm_height - 1) / 2);
  if not (point_shown frame) then recenter frame 0;
  let rows, cursor, _ = layout frame in
  let screen = ref screen in
  Array.iteri (fun (i : int) (row : (int * string * Vt.attrs) list) ->
    screen := Curses.pieces (frame.frm_ypos + i)
        (List.rev_map (fun ((col, text, attrs) : int * string * Vt.attrs) -> (frame.frm_xpos + col, text, attrs)) row) !screen) rows;
  if frame.frm_has_status_line then
    screen := Curses.put ~attrs:{ Vt.plain with reverse = true } (frame.frm_ypos + frame.frm_height - 1) frame.frm_xpos (status frame) !screen;
  let row, col = match cursor with Some c -> c | None -> (0, 0) in
  (!screen, (frame.frm_ypos + row, frame.frm_xpos + col))
