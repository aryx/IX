(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See To_text.mli *)

let look : Layout.look = { width = 65.; margin = 5.; sub = 3. }

(* the paper's left edge, from the terminal's *)
let offset = 5

let metrics (_ : Doc.style) (s : string) : float = float_of_int (Utf8.length s)

(* a line's pieces, each at its column; a piece that would start
 * before the one on its left ends is put right after it *)
let row (l : Layout.line) : string =
  let b = Buffer.create 80 and col = ref 0 in
  List.iter (fun (p : Layout.piece) ->
    (* (a place between two columns is the one on its left, as nroff's) *)
    let at = offset + int_of_float (Float.floor (p.x +. 0.01)) in
    if at > !col then begin Buffer.add_string b (String.make (at - !col) ' '); col := at end;
    (* (a no-break space is a space, once the lines are broken; a minus
     * and a hyphen of the same kind are a terminal's hyphen) *)
    List.iter (fun c -> Buffer.add_string b (if c = "\xc2\xa0" then " " else if c = "\xe2\x88\x92" || c = "\xe2\x80\x91" then "-" else c)) (fst (Utf8.chars p.text));
    col := !col + Utf8.length p.text) l;
  (* (no space at the end of a line) *)
  let s = Buffer.contents b in
  let n = ref (String.length s) in
  while !n > 0 && s.[!n - 1] = ' ' do decr n done;
  String.sub s 0 !n

(* troff's .tl: three texts, at the left, in the middle, at the right *)
let title ((left, middle, right) : string * string * string) : string =
  let w = int_of_float look.width in
  let b = Bytes.make w ' ' in
  let put (at : int) (s : string) = if at >= 0 && at + String.length s <= w then Bytes.blit_string s 0 b at (String.length s) in
  put 0 left; put ((w - String.length middle) / 2) middle; put (w - String.length right) right;
  String.make offset ' ' ^ Bytes.to_string b

let page (d : Doc.t) : string =
  let b = Buffer.create 4096 in
  let (left, _, _) = d.header in
  if left <> "" then begin Buffer.add_string b (title d.header); Buffer.add_char b '\n' end;
  List.iter (fun l -> Buffer.add_string b (row l); Buffer.add_char b '\n') (Layout.lines look metrics d.body);
  Buffer.contents b
