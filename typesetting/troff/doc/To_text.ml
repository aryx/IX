(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See To_text.mli *)

(* (tag_room: tmac.an's 3 points, of a letter's 7.2) *)
let look : Layout.look = { en = 1.; inch = 10.; width = 65.; tag_room = 0.4; justify = false }

(* the paper's left edge, from the terminal's *)
let offset = 5

let metrics (_ : Doc.style) (s : string) : float = float_of_int (Utf8.length s)

(* a line's pieces, each at its column; a piece that would start
 * before the one on its left ends is put right after it *)
let row (l : Layout.piece list) : string =
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
let title (width : float) ((left, middle, right) : string * string * string) : string =
  let w = int_of_float width in
  let b = Bytes.make w ' ' in
  let put (at : int) (s : string) = if at >= 0 && at + String.length s <= w then Bytes.blit_string s 0 b at (String.length s) in
  put 0 left; put ((w - String.length middle) / 2) middle; put (w - String.length right) right;
  String.make offset ' ' ^ Bytes.to_string b

let page (d : Doc.t) : string =
  let b = Buffer.create 4096 in
  let (left, _, _) = d.header in
  if left <> "" then begin Buffer.add_string b (title d.width d.header); Buffer.add_char b '\n' end;
  (* the footnotes, the last first: a terminal's page has no foot but
   * the document's end *)
  let feet = ref [] in
  let rec write (r : Layout.row) =
    match r with
    | Layout.Line l -> Buffer.add_string b (row l); Buffer.add_char b '\n'
    (* (a terminal has whole lines) *)
    | Layout.Skip n -> Buffer.add_string b (String.make (int_of_float (Float.round n)) '\n')
    | Layout.Together rows -> List.iter write rows
    | Layout.Drawing (x, p) ->
        (* a terminal has no lines to draw with: the picture's words, from
         * its top to its bottom, each at its place across *)
        let labels = List.filter_map (fun (m : Doc.mark) -> match m with
          | Doc.Label (lx, ly, _, text) -> Some (ly, lx, text)
          (* (a picture from a file: its name) *)
          | Doc.Image (ix, iy, _, _, name, _) -> Some (iy, ix, [ Doc.Text (Doc.plain, "[picture: " ^ name ^ "]") ])
          | Doc.Stroke _ -> None) p.marks in
        List.iter (fun (_, lx, text) ->
          let pieces, _ = Layout.one_line metrics (x +. Float.floor (lx *. look.inch)) text in
          Buffer.add_string b (row pieces); Buffer.add_char b '\n') (List.sort (fun (y1, x1, _) (y2, x2, _) -> if y1 = y2 then compare x1 x2 else compare y2 y1) labels)
    | Layout.Rule (x0, x1) ->
        let from = offset + int_of_float (Float.floor (x0 +. 0.01)) and upto = offset + int_of_float (Float.floor (x1 +. 0.01)) in
        Buffer.add_string b (String.make from ' ' ^ String.make (max 0 (upto - from)) '-' ^ "\n")
    | Layout.Foot rows -> feet := rows :: !feet in
  List.iter write (Layout.rows look metrics d);
  if !feet <> [] then begin
    Buffer.add_string b ("\n" ^ String.make offset ' ' ^ String.make 26 '_' ^ "\n");
    List.iter (fun rows -> List.iter write rows) (List.rev !feet)
  end;
  Buffer.contents b
