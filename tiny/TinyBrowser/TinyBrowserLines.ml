(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyBrowserLines.mli *)

(*****************************************************************************)
(* Lines *)
(*****************************************************************************)

let bold = 1
let emph = 2
let code = 4
let big = 8
let under = 16

type run = { col : int; text : string; look : int; link : string; pic : int }
type line = { runs : run list; rule : bool }

(* A flow wraps words into lines of a given width, starting at a left
 * margin. *)
type flow = {
  width : int;
  mutable left : int;
  mutable made : run list;  (* the line being built, last run first *)
  mutable at : int;         (* the column where the next word goes *)
  mutable out : line list;  (* the finished lines, last line first *)
  mutable nlines : int;     (* how many lines are in out *)
  mutable blank : bool;     (* whether the next line wants a blank line
                             * before it *)
  mutable glue : int;       (* the column where the word being made started *)
  mutable cache : line array;  (* the lines from the top, when there were
                                * [cached] *)
  mutable cached : int;
}

let flow width =
  { width = width; left = 0; made = []; at = 0; out = []; nlines = 0;
    blank = false; glue = 0; cache = Array.make 0 { runs = []; rule = false };
    cached = 0 }

let push (f : flow) (l : line) =
  if f.blank then begin
    (match f.out with
     | x :: _ when x.runs <> [] || x.rule ->
       f.out <- { runs = []; rule = false } :: f.out;
       f.nlines <- f.nlines + 1
     | _ -> ());
    f.blank <- false
  end;
  f.out <- l :: f.out;
  f.nlines <- f.nlines + 1

let end_line (f : flow) =
  if f.made <> [] then begin
    push f { runs = List.rev f.made; rule = false }; f.made <- []
  end

(* Adds a word to the flow, after a space if [space] is true. When the
 * word has the same look and link as the previous run, it extends that
 * run instead of starting a new one. *)
(* Moves the word being made, from the column where it started, to a
 * new line, and ends the line before it. A word can be made of several
 * pieces with no space between them (a full stop and a reference's
 * [15], a link and the comma after it), so it is only known to be too
 * long for its line when its last piece comes. *)
let carry (f : flow) =
  let g = f.glue in
  let keep = ref [] and move = ref [] in
  List.iter (fun (r : run) ->
    let n = String.length r.text in
    if r.col + n <= g then keep := r :: !keep
    else if r.col >= g then move := r :: !move
    else begin
      keep := { col = r.col; text = String.sub r.text 0 (g - r.col);
                look = r.look; link = r.link; pic = r.pic } :: !keep;
      move := { col = g; text = String.sub r.text (g - r.col) (n - g + r.col);
                look = r.look; link = r.link; pic = r.pic } :: !move
    end) (List.rev f.made);
  (* the line kept without the spaces at its end *)
  let rec strip s =
    let n = String.length s in
    if n > 0 && s.[n - 1] = ' ' then strip (String.sub s 0 (n - 1)) else s in
  f.made <- (match !keep with
    | r :: rest ->
      let t = strip r.text in
      if t = "" then rest
      else { col = r.col; text = t; look = r.look; link = r.link;
             pic = r.pic } :: rest
    | [] -> []);
  end_line f;
  let shift = g - f.left in
  f.made <- List.map (fun (r : run) ->
    { col = r.col - shift; text = r.text; look = r.look; link = r.link;
      pic = r.pic }) !move;
  f.at <- f.at - shift;
  f.glue <- f.left

let word (f : flow) text look link space =
  let len = String.length text in
  if f.made = [] then f.at <- f.left;
  let space = space && f.made <> [] in
  let space =
    if space && f.at + 1 + len > f.width then (end_line f; f.at <- f.left; false)
    else space in
  if (not space) && f.made <> [] && f.at + len > f.width && f.glue > f.left
  then carry f;
  let col = if space then f.at + 1 else f.at in
  if space || f.made = [] then f.glue <- col;
  (match f.made with
   | r :: rest
     when r.look = look && r.link = link
          && r.col + String.length r.text = f.at ->
       f.made <- { col = r.col; text = r.text ^ (if space then " " else "") ^ text;
                   look = look; link = link; pic = -1 } :: rest
   | _ ->
       (* The space between two different runs belongs to neither, so a
        * link's underline stops where its text stops. *)
       f.made <-
         { col = col; text = text; look = look; link = link; pic = -1 }
         :: f.made);
  f.at <- col + len

(* A picture of [rows] rows of the screen: a line for
 * each row, whose one run is the picture's slice there (its number
 * times 256, plus the row), at the left margin. The text goes on under
 * it. *)
let picture_block (f : flow) id rows link =
  end_line f;
  for s = 0 to rows - 1 do
    push f { runs = [ { col = f.left; text = ""; look = 0; link = link;
                        pic = (id * 256) + s } ];
             rule = false }
  done

(* Adds a text exactly as it is, with no wrapping (for <pre>). *)
let verbatim (f : flow) text look link =
  if f.made = [] then f.at <- f.left;
  if text <> "" then begin
    f.made <-
      { col = f.at; text = text; look = look; link = link; pic = -1 } :: f.made;
    f.at <- f.at + String.length text
  end

(*****************************************************************************)
(* Tables *)
(*****************************************************************************)

(* The words of a cell are kept until the end of the table, when the
 * widths of its columns are known. *)
type item =
  | Word of string * int * string * bool
  | Break
  | Pic of int * int * int * string

type cell = { mutable items : item list; span : int; head : bool }
type table = {
  mutable rows : cell list list;  (* the rows so far, last row first *)
  mutable row : cell list;
  mutable cell : cell option;
  mutable depth : int;            (* how many tables are open inside it; their
                                   * cells just become text of the current cell *)
  mutable broken : int;           (* a line's end not yet in the cell, put
                                   * there before the next word: 1 a block's,
                                   * 2 an inner table's row's *)
}

let cell_words (c : cell) = List.rev c.items

(* Returns the narrowest a cell can be (its longest word) and the widest
 * it would like to be (its text with no wrapping, except at its own
 * line breaks). *)
let measure (c : cell) =
  let narrow = ref 0 and wide = ref 0 and line = ref 0 in
  List.iter (function
    | Word (t, _, _, sp) ->
        let len = String.length t in
        narrow := max !narrow len;
        line := !line + len + (if sp && !line > 0 then 1 else 0);
        wide := max !wide !line
    | Pic (_, cols, _, _) ->
        narrow := max !narrow cols; wide := max !wide cols; line := 0
    | Break -> line := 0) (cell_words c);
  !narrow, !wide

(* Computes the widths of n columns that must fit in [room]. If every
 * column fits at its widest, it gets that. Otherwise each column gets
 * its narrowest width, plus a share of the remaining room proportional
 * to how much wider it would like to be. *)
let widths rows n room =
  let narrow = Array.make n 0 and wide = Array.make n 0 in
  List.iter (fun row ->
    ignore (List.fold_left (fun k (c : cell) ->
      if k < n && c.span = 1 then begin
        let a, b = measure c in
        narrow.(k) <- max narrow.(k) a;
        wide.(k) <- max wide.(k) b
      end;
      k + c.span) 0 row)) rows;
  let sn = ref 0 and sw = ref 0 in
  for k = 0 to n - 1 do sn := !sn + narrow.(k); sw := !sw + wide.(k) done;
  if !sw <= room then wide
  else if !sn >= room then narrow
  else begin
    let w = Array.make n 0 in
    for k = 0 to n - 1 do
      w.(k) <-
        narrow.(k) + ((wide.(k) - narrow.(k)) * (room - !sn) / (!sw - !sn))
    done;
    w
  end

let gap = 2

(* Lays out a finished table into the flow: each cell is wrapped in its
 * column, and the cells of a row are put side by side. *)
let lay_table (f : flow) (t : table) =
  let rows = List.rev (List.map List.rev t.rows) in
  let rows = List.filter (fun r -> r <> []) rows in
  (* A caption spans all the columns, but counts as one here. *)
  let n =
    List.fold_left (fun m r ->
      max m (List.fold_left (fun s (c : cell) ->
        s + (if c.span >= 1000 then 1 else c.span)) 0 r)) 0 rows in
  if n > 0 then begin
    let room = f.width - f.left - (gap * (n - 1)) in
    let w = widths rows n room in
    (* A cell spanning several columns gets their widths plus the gaps
     * between them. *)
    let span_width k span =
      let s = ref 0 in
      for j = k to min n (k + span) - 1 do s := !s + w.(j) + gap done;
      !s - gap in
    let x = Array.make (n + 1) f.left in
    for k = 1 to n do x.(k) <- x.(k - 1) + w.(k - 1) + gap done;
    end_line f;
    f.blank <- true;
    List.iter (fun row ->
      let k = ref 0 in
      let laid = List.map (fun (c : cell) ->
        let cw = if !k < n then max 1 (span_width !k c.span) else 1 in
        let g = flow cw in
        List.iter (function
          | Word (text, look, link, sp) ->
            word g text (if c.head then look lor bold else look) link sp
          | Pic (id, _, rows, link) -> picture_block g id rows link
          | Break -> end_line g) (cell_words c);
        end_line g;
        let at = if !k < n then x.(!k) else x.(n) in
        k := !k + c.span;
        at, List.rev g.out) row in
      let height =
        List.fold_left (fun h (_, ls) -> max h (List.length ls)) 0 laid in
      for i = 0 to height - 1 do
        let runs = List.concat (List.map (fun (at, ls) ->
          match List.nth_opt ls i with
          | Some (l : line) ->
            List.map (fun (r : run) ->
              { col = r.col + at; text = r.text; look = r.look; link = r.link;
                pic = r.pic }) l.runs
          | None -> []) laid) in
        push f { runs = runs; rule = false }
      done) rows;
    f.blank <- true
  end
