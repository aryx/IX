(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOffice.mli *)

(* The editor's functions this file uses, by names of their own: the
 * office has a create, a key and a view too, and tiny-ml has no
 * modules, one name space for all its files (so: open, and these) *)
open TinyEditorScreen
open TinyLibPlayground
let editor_create = create
let editor_key = key
let editor_view = view
let editor_lines = lines
let editor_saved = saved
let editor_pending = pending
let editor_auto_fill = auto_fill
let editor_shapes = shapes
let editor_text = text

(* the page's colours, bytes of the machine's palette: white, black, a
 * frame's grey, the selection's blue, a heading's dark blue, the status
 * line's light grey *)
let white = 255
let black = 0
let grey = 153
let blue = 3
let dark_blue = 2
let light_grey = 204

(* an object of the page: its kind ("text", "sheet"), its box in
 * pixels, its data *)
type obj = { kind : string; x : int; y : int; w : int; h : int; data : string }

(* what the selected box is edited by: nothing; the screen editor, a
 * text box's; a sheet's cell, its column and row, and what is being
 * typed in it (None: the cell chosen, nothing typed yet); a drawing's
 * tool (0 a box, 1 an arrow, 2 a text), and the stroke the left button
 * is making, from where it went down to where it is, in the box *)
type edit = Nothing | Writing of editor | Cell of int * int * string option | Sketch of int * (int * int * int * int) option

type office = {
  mutable page : obj list;                (* the objects, the bottom one first *)
  mutable undo : obj list list;           (* the pages before, the last first *)
  mutable clean : obj list;               (* the page as it was last saved *)
  mutable sel : int;                      (* the selected object, its place in page; -1 none *)
  mutable editing : edit;                 (* what the selected box is edited by *)
  mutable drag : (int * int * int * obj * bool) option;   (* the right button held: the object, where
                                                           * the mouse was, the object then, resizing *)
  mutable at : int * int;                 (* the last click *)
  mutable buttons : int;                  (* the mouse's buttons, as last seen *)
  mutable message : string;               (* the status line's *)
  mutable prefix : bool;                  (* C-x typed *)
  where : string * int * int;             (* the file, the page's width and height *)
}

(* (eleven fields: tiny-ml's most on tiny-machine) *)

let say (o : office) (m : string) = o.message <- m

(*****************************************************************************)
(* The file *)
(*****************************************************************************)

(* a page's file: each object a line "kind x y w h n", then its n bytes
 * of data, then a newline (so that the file reads well in emacs) *)
let rec parse (s : string) (i : int) : obj list =
  match String.index_from_opt s i '\n' with
  | None -> []
  | Some e -> (
      let n = String.length s in
      let num v = match int_of_string_opt v with Some k -> k | None -> -1 in
      match String.split_on_char ' ' (String.sub s i (e - i)) with
      | [ kind; x; y; w; h; size ] when num size >= 0 && e + 1 + num size <= n ->
          let size = num size in
          { kind; x = num x; y = num y; w = num w; h = num h; data = String.sub s (e + 1) size } :: parse s (e + 2 + size)
      | _ -> [])

let text (o : office) : string =
  join (List.map (fun (b : obj) ->
    join [ b.kind; " "; string_of_int b.x; " "; string_of_int b.y; " "; string_of_int b.w; " ";
                            string_of_int b.h; " "; string_of_int (String.length b.data); "\n"; b.data; "\n" ]) o.page)

let create (width : int) (height : int) (file : string) (s : string) : office =
  let page = parse s 0 in
  { page; undo = []; clean = page; sel = -1; editing = Nothing; drag = None; at = (16, 16); buttons = 0;
    message = ""; prefix = false; where = (file, width, height) }

let saved (o : office) =
  o.clean <- o.page;
  (match o.editing with Writing e -> editor_saved e | _ -> ());
  let file, _, _ = o.where in
  o.message <- "Wrote " ^ file

(*****************************************************************************)
(* The page's objects *)
(*****************************************************************************)

let rec nth_obj (l : obj list) (i : int) : obj = match l with b :: rest -> if i = 0 then b else nth_obj rest (i - 1) | [] -> failwith "nth_obj"

(* the page with its i-th object replaced, or removed (None) *)
let rec replace (l : obj list) (i : int) (b : obj option) : obj list =
  match l with
  | x :: rest -> if i > 0 then x :: replace rest (i - 1) b else (match b with Some b -> b :: rest | None -> rest)
  | [] -> []

(* the topmost object under (x, y): its place, -1 *)
let hit (o : office) (x : int) (y : int) : int =
  let rec go i found = function
    | (b : obj) :: rest -> go (i + 1) (if x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h then i else found) rest
    | [] -> found in
  go 0 (-1) o.page

(* a change about to be made: the page as it is, kept for undo *)
let keep (o : office) = o.undo <- o.page :: o.undo

(* a text box's size in characters: its columns, its lines *)
let cols (b : obj) = max 1 ((b.w - 8) / 8)
let rows (b : obj) = max 1 ((b.h - 4) / 16)

(*****************************************************************************)
(* The sheet *)
(*****************************************************************************)

(* A sheet's data is a line a cell, its name and what was typed in it:
 *
 *     a1 3
 *     a2 Rent
 *     b1 =a1*2+sum(a1:a3)
 *
 * what was typed being a number, a formula (after an =, as in every
 * spreadsheet since VisiCalc's +), or text. A cell's name is its
 * column, a to z, and its row, 1 to 99. The numbers are integers:
 * tiny-ml's, 31 bits on tiny-machine, no floating point. *)

let name (c : int) (r : int) = String.make 1 (Char.chr (97 + c)) ^ string_of_int (r + 1)

(* the cells typed in: their names and what was typed *)
let cells (data : string) : (string * string) list =
  List.concat_map (fun l ->
    match String.index_opt l ' ' with
    | Some i -> [ String.sub l 0 i, String.sub l (i + 1) (String.length l - i - 1) ]
    | None -> []) (String.split_on_char '\n' data)

let typed_in (data : string) (n : string) = match List.assoc_opt n (cells data) with Some s -> s | None -> ""

(* the data with what is typed in cell n changed ("": the cell emptied) *)
let set_cell (data : string) (n : string) (input : string) : string =
  let others = List.filter (fun (m, _) -> m <> n) (cells data) in
  join (List.map (fun (m, s) -> m ^ " " ^ s ^ "\n") (if input = "" then others else others @ [ n, input ]))

(* a cell's value: a number, text (an empty cell is "", 0 in a sum), or
 * an error, said in the cell: #SYNTAX, #REF, #TEXT (text in a sum),
 * #DIV0, #CYCLE (a cell that needs itself) *)
type value = Num of int | Str of string | Err of string

exception Bad of string

(* A formula is read and computed at once, by recursive descent, with
 * no tree: expr is terms added, a term factors multiplied, a factor a
 * number, a cell, sum(a cell:a cell), a minus, or an expression in
 * parentheses. The reader: the formula, where it is, a cell's value.
 * (Functions of the reader, not a closure: tiny-ml takes a closure's
 * values in tiny-machine's 11 registers) *)
type reader = { src : string; mutable pos : int; fetch : string -> value }

let peek_char (p : reader) = if p.pos < String.length p.src then p.src.[p.pos] else '\000'
let rec blanks (p : reader) = if peek_char p = ' ' then (p.pos <- p.pos + 1; blanks p)
let digit (c : char) = c >= '0' && c <= '9'
let expect (p : reader) (c : char) = blanks p; if peek_char p = c then p.pos <- p.pos + 1 else raise (Bad "SYNTAX")
let rec number (p : reader) (k : int) =
  if digit (peek_char p) then (let d = Char.code (peek_char p) - 48 in p.pos <- p.pos + 1; number p ((k * 10) + d)) else k

(* a cell's name read: its column and its row, from 0 *)
let cell (p : reader) : int * int =
  blanks p;
  let c = peek_char p in
  if c < 'a' || c > 'z' then raise (Bad "SYNTAX");
  p.pos <- p.pos + 1;
  let r = number p 0 in
  if r < 1 || r > 99 then raise (Bad "REF");
  Char.code c - 97, r - 1

let int_of (v : value) : int =
  match v with Num k -> k | Str "" -> 0 | Str _ -> raise (Bad "TEXT") | Err e -> raise (Bad e)

let rec expr (p : reader) : int = sum p (term p)

and sum (p : reader) (v : int) : int =
  blanks p;
  let c = peek_char p in
  if c = '+' then (p.pos <- p.pos + 1; sum p (v + term p))
  else if c = '-' then (p.pos <- p.pos + 1; sum p (v - term p))
  else v

and term (p : reader) : int = product p (factor p)

and product (p : reader) (v : int) : int =
  blanks p;
  let c = peek_char p in
  if c = '*' then (p.pos <- p.pos + 1; product p (v * factor p))
  else if c = '/' then (p.pos <- p.pos + 1; let d = factor p in if d = 0 then raise (Bad "DIV0") else product p (v / d))
  else v

and factor (p : reader) : int =
  blanks p;
  let c = peek_char p in
  if digit c then number p 0
  else if c = '-' then (p.pos <- p.pos + 1; - (factor p))
  else if c = '(' then (p.pos <- p.pos + 1; let v = expr p in expect p ')'; v)
  else if p.pos + 4 <= String.length p.src && String.sub p.src p.pos 4 = "sum(" then begin
    p.pos <- p.pos + 4;
    let c0, r0 = cell p in
    expect p ':';
    let c1, r1 = cell p in
    expect p ')';
    let total = ref 0 in
    for c = min c0 c1 to max c0 c1 do
      for r = min r0 r1 to max r0 r1 do total := !total + int_of (p.fetch (name c r)) done
    done;
    !total
  end
  else (let c, r = cell p in int_of (p.fetch (name c r)))

let formula (s : string) (fetch : string -> value) : value =
  let p = { src = s; pos = 0; fetch } in
  try
    let v = expr p in
    blanks p;
    if p.pos < String.length s then Err "SYNTAX" else Num v
  with Bad e -> Err e

(* The values of a sheet's cells, by name, each computed once, those it
 * needs first; a cell being computed is #CYCLE meanwhile, which is
 * what a cell that needs itself gets *)
let values (data : string) : string -> value =
  let typed = cells data and memo = Hashtbl.create 16 in
  let rec value n =
    match Hashtbl.find_opt memo n with
    | Some v -> v
    | None ->
        Hashtbl.replace memo n (Err "CYCLE");
        let input = match List.assoc_opt n typed with Some s -> s | None -> "" in
        let v =
          if input <> "" && input.[0] = '=' then formula (String.sub input 1 (String.length input - 1)) value
          else match int_of_string_opt input with Some k -> Num k | None -> Str input in
        Hashtbl.replace memo n v;
        v in
  value

(*****************************************************************************)
(* Editing a text box *)
(*****************************************************************************)

(* the edited text put back into its box (a change, for undo, when it is
 * another text) *)
(* the selected box's data changed (a change, for undo, when it is
 * other data) *)
let change (o : office) (data : string) =
  let b = nth_obj o.page o.sel in
  if data <> b.data then (keep o; o.page <- replace o.page o.sel (Some { b with data }))

(* what is being edited put back into its box: a text box's text, what
 * is typed in a cell *)
let commit (o : office) =
  if o.sel >= 0 then
    match o.editing with
    | Writing e -> change o (editor_text e)
    | Cell (c, r, Some t) -> change o (set_cell (nth_obj o.page o.sel).data (name c r) t); o.editing <- Cell (c, r, None)
    | _ -> ()

let finish (o : office) = commit o; o.editing <- Nothing

(* the editor on box i's text, its cursor where (x, y) is *)
let edit (o : office) (i : int) (x : int) (y : int) =
  let b = nth_obj o.page i in
  let file, _, _ = o.where in
  let e = editor_create (cols b) (rows b + 2) file b.data in
  editor_auto_fill e (cols b);
  let lines = editor_lines e in
  let row = min (List.length lines - 1) (max 0 ((y - b.y - 2) / 16)) in
  for _i = 1 to row do ignore (editor_key e 14) done;
  let col = min (String.length (List.nth lines row)) (max 0 ((x - b.x - 4) / 8)) in
  for _i = 1 to col do ignore (editor_key e 6) done;
  o.sel <- i;
  o.editing <- Writing e

(*****************************************************************************)
(* Editing a sheet *)
(*****************************************************************************)

(* the grid: a column 8 characters wide, the rows' numbers in the first
 * 3 characters, the columns' letters in the first line *)
let cell_w = 64
let sheet_left (b : obj) = b.x + 25
let sheet_top (b : obj) = b.y + 17
let sheet_cols (b : obj) = max 1 ((b.w - 26) / cell_w)
let sheet_rows (b : obj) = max 1 ((b.h - 18) / 16)

(* the cell of box i under (x, y): chosen, nothing typed yet *)
let choose (o : office) (i : int) (x : int) (y : int) =
  let b = nth_obj o.page i in
  let c = (x - sheet_left b) / cell_w and r = (y - sheet_top b) / 16 in
  o.sel <- i;
  o.editing <- (if x >= sheet_left b && y >= sheet_top b && c < sheet_cols b && r < sheet_rows b then Cell (c, r, None) else Nothing)

(* A key at a cell, as in a spreadsheet: a character starts what is
 * typed there, which replaces what was; Enter puts it in the cell and
 * goes down; an arrow puts it and goes that way; C-g forgets it.
 * Enter on a cell where nothing is typed brings back what was typed
 * there, to change it; Backspace there empties the cell. *)
let cell_key (o : office) (c : int) (r : int) (typed : string option) (k : int) =
  let b = nth_obj o.page o.sel in
  let move dc dr = o.editing <- Cell (max 0 (min 25 (c + dc)), max 0 (min 98 (r + dr)), None) in
  let arrow () = if k = 128 then move 0 (-1) else if k = 129 then move 0 1 else if k = 130 then move (-1) 0 else move 1 0 in
  match typed with
  | None ->
      if k >= 32 && k < 127 then o.editing <- Cell (c, r, Some (String.make 1 (Char.chr k)))
      else if k = 10 || k = 13 then o.editing <- Cell (c, r, Some (typed_in b.data (name c r)))
      else if k >= 128 && k <= 131 then arrow ()
      else if k = 8 || k = 127 then change o (set_cell b.data (name c r) "")
      else if k = 7 then o.editing <- Nothing
      else o.message <- "a cell: type, Enter, the arrows; C-g"
  | Some t ->
      if k >= 32 && k < 127 then o.editing <- Cell (c, r, Some (t ^ String.make 1 (Char.chr k)))
      else if k = 8 || k = 127 then o.editing <- Cell (c, r, Some (if t = "" then "" else String.sub t 0 (String.length t - 1)))
      else if k = 10 || k = 13 then (commit o; move 0 1)
      else if k >= 128 && k <= 131 then (commit o; arrow ())
      else if k = 7 then o.editing <- Cell (c, r, None)

(*****************************************************************************)
(* The drawing *)
(*****************************************************************************)

(* A drawing's data is a line a shape, at its place in the drawing's
 * box:
 *
 *     box 10 10 80 30 cpu
 *     arrow 90 25 160 60
 *     text 20 70 a note
 *
 * a box and its label; an arrow, across then up or down (a block
 * diagram's connector: what the shapes draw is rectangles, and a
 * slanted line would need another kind); words. pic's idea (Brian
 * Kernighan, 1982: a picture as lines of text), drawn with the mouse. *)

let tools = [ "box"; "arrow"; "text" ]

(* a drawing's shapes: their kind, their numbers, their label *)
let figures (data : string) : (string * int list * string) list =
  List.concat_map (fun l ->
    match String.split_on_char ' ' l with
    | kind :: rest when List.mem kind tools ->
        let rec take k l =
          if k = 0 then [], l
          else (let v, r = match l with v :: r -> (match int_of_string_opt v with Some i -> i | None -> 0), r | [] -> 0, [] in
                let nums, words = take (k - 1) r in v :: nums, words) in
        let nums, words = take (if kind = "text" then 2 else 4) rest in
        [ kind, nums, String.concat " " words ]
    | _ -> []) (String.split_on_char '\n' data)

let figure_line ((kind, nums, label) : string * int list * string) : string =
  join (kind :: List.map (fun n -> " " ^ string_of_int n) nums @ (if label = "" then [ "\n" ] else [ " "; label; "\n" ]))

(* a shape drawn, the box's corner at (ox, oy); an arrow's head is
 * rectangles narrowing to its end, along its last stretch *)
let figure_shapes (ox : int) (oy : int) (colour : int) ((kind, nums, label) : string * int list * string) : shape list =
  match kind, nums with
  | "box", [ x; y; w; h ] ->
      let x = ox + x and y = oy + y in
      let label = if 8 * String.length label > w - 4 then String.sub label 0 (max 0 ((w - 4) / 8)) else label in
      [ Move (x, y, Rect (colour, w, 1)); Move (x, y + h - 1, Rect (colour, w, 1)); Move (x, y, Rect (colour, 1, h));
        Move (x + w - 1, y, Rect (colour, 1, h)); Move (x + ((w - (8 * String.length label)) / 2), y + ((h - 16) / 2), Words (colour, label)) ]
  | "arrow", [ x0; y0; x1; y1 ] ->
      let x0 = ox + x0 and y0 = oy + y0 and x1 = ox + x1 and y1 = oy + y1 in
      let head = List.init 4 (fun k ->
        if y1 > y0 then Move (x1 - k, y1 - k, Rect (colour, (2 * k) + 1, 1))
        else if y1 < y0 then Move (x1 - k, y1 + k, Rect (colour, (2 * k) + 1, 1))
        else if x1 >= x0 then Move (x1 - k, y0 - k, Rect (colour, 1, (2 * k) + 1))
        else Move (x1 + k, y0 - k, Rect (colour, 1, (2 * k) + 1))) in
      [ Move (min x0 x1, y0, Rect (colour, abs (x1 - x0) + 1, 1)); Move (x1, min y0 y1, Rect (colour, 1, abs (y1 - y0) + 1)) ] @ head
  | "text", [ x; y ] -> [ Move (ox + x, oy + y, Words (colour, label)) ]
  | _ -> []

(* what a stroke of a tool makes, from (x0, y0) to (x1, y1) *)
let stroked (tool : int) (x0 : int) (y0 : int) (x1 : int) (y1 : int) : string * int list * string =
  if tool = 0 then "box", [ min x0 x1; min y0 y1; abs (x1 - x0); abs (y1 - y0) ], ""
  else if tool = 1 then "arrow", [ x0; y0; x1; y1 ], ""
  else "text", [ x1; y1 ], ""

(* the shape a stroke made, added; a box or an arrow too small is a
 * click, not a shape *)
let draw_stroke (o : office) (tool : int) ((x0, y0, x1, y1) : int * int * int * int) =
  let b = nth_obj o.page o.sel in
  if tool = 2 || (tool = 0 && abs (x1 - x0) >= 8 && abs (y1 - y0) >= 8) || (tool = 1 && abs (x1 - x0) + abs (y1 - y0) >= 8) then
    change o (b.data ^ figure_line (stroked tool x0 y0 x1 y1))

(* A key in a drawing: Tab another tool; a character the last shape's
 * label longer; Backspace shorter, and an empty label's shape removed;
 * C-g the drawing left *)
let sketch_key (o : office) (tool : int) (k : int) =
  let b = nth_obj o.page o.sel in
  let figs = figures b.data in
  let relabel f = match List.rev figs with
    | (kind, nums, label) :: rest -> change o (join (List.map figure_line (List.rev rest @ f kind nums label)))
    | [] -> () in
  if k = 9 then o.editing <- Sketch ((tool + 1) mod 3, None)
  else if k >= 32 && k < 127 then relabel (fun kind nums label -> [ kind, nums, label ^ String.make 1 (Char.chr k) ])
  else if k = 8 || k = 127 then
    relabel (fun kind nums label -> if label = "" then [] else [ kind, nums, String.sub label 0 (String.length label - 1) ])
  else if k = 7 then o.editing <- Nothing
  else o.message <- "a drawing: Tab, the mouse, a label typed; C-g"

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

let help = "C-o text; C-x t sheet, d drawing; click edits; right button moves; C-_ undo"

let quit (o : office) : request =
  let refused = "Not saved: C-x C-s saves, C-x C-c again quits" in
  if o.page == o.clean || o.message = refused then Quit else (o.message <- refused; Continue)

(* a key given to the box being edited, then the keys it gives itself
 * (a macro's, M-x's); C-x C-s and C-x C-c are the page's *)
let editing_key (o : office) (e : editor) (k : int) : request =
  let rec given (r : request) =
    match editor_pending e with
    | Some k -> given (match editor_key e k with Continue -> r | r' -> r')
    | None -> r in
  match given (editor_key e k) with
  | Save -> commit o; Save
  | Quit -> commit o; quit o
  | Continue -> Continue

(* a new box where the last click was, of a kind, edited at once *)
let add (o : office) (kind : string) (w : int) (h : int) =
  let x, y = o.at in
  keep o;
  o.page <- o.page @ [ { kind; x; y; w; h; data = "" } ];
  let i = List.length o.page - 1 in
  o.sel <- i;
  if kind = "text" then edit o i x y else if kind = "sheet" then o.editing <- Cell (0, 0, None) else o.editing <- Sketch (0, None)

let key (o : office) (k : int) : request =
  match o.editing with
  | Writing e -> editing_key o e k
  | Cell (c, r, typed) when not o.prefix && k <> 24 -> o.message <- ""; cell_key o c r typed k; Continue
  | Sketch (tool, _) when not o.prefix && k <> 24 -> o.message <- ""; sketch_key o tool k; Continue
  | _ ->
      let was = o.message in
      o.message <- "";
      if o.prefix then begin
        o.prefix <- false;
        if k = 19 then (commit o; Save)
        else if k = 3 || k = 17 then (commit o; o.message <- was; quit o)
        else if k = 116 then (finish o; add o "sheet" (26 + (4 * cell_w)) (18 + (6 * 16)); Continue)
        else if k = 100 then (finish o; add o "drawing" 300 160; Continue)
        else (o.message <- "C-x: not a command"; Continue)
      end
      else begin
        if k = 24 then o.prefix <- true
        else if k = 15 then add o "text" 200 84
        else if (k = 8 || k = 127) && o.sel >= 0 then (keep o; o.page <- replace o.page o.sel None; o.sel <- -1)
        else if k = 31 then begin
          match o.undo with
          | p :: rest -> o.page <- p; o.undo <- rest; o.sel <- -1
          | [] -> o.message <- "No more undo"
        end
        else if k = 7 then (o.sel <- -1; o.message <- "Quit")
        else o.message <- help;
        Continue
      end

let mouse (o : office) (x : int) (y : int) (b : int) =
  let pressed k = b land k <> 0 && o.buttons land k = 0 in
  let i = hit o x y in
  match o.editing with
  | Sketch (tool, _) when pressed 1 && i >= 0 && i = o.sel ->
      (* in the drawing being edited: a stroke begins *)
      let ob = nth_obj o.page i in
      o.editing <- Sketch (tool, Some (x - ob.x, y - ob.y, x - ob.x, y - ob.y));
      o.buttons <- b
  | Sketch (tool, Some (x0, y0, _, _)) when b land 1 <> 0 ->
      (* the stroke follows the mouse, kept in the drawing's box *)
      let ob = nth_obj o.page o.sel in
      o.editing <- Sketch (tool, Some (x0, y0, max 0 (min (ob.w - 2) (x - ob.x)), max 0 (min (ob.h - 2) (y - ob.y))));
      o.buttons <- b
  | Sketch (tool, Some stroke) when b land 1 = 0 ->
      o.editing <- Sketch (tool, None);
      draw_stroke o tool stroke;
      o.buttons <- b
  | _ ->
  if pressed 1 then begin
    (* a click: the editing ends; in a text box, another begins *)
    finish o;
    o.at <- (x, y);
    o.sel <- i;
    if i >= 0 && (nth_obj o.page i).kind = "text" then edit o i x y
    else if i >= 0 && (nth_obj o.page i).kind = "sheet" then choose o i x y
    else if i >= 0 && (nth_obj o.page i).kind = "drawing" then o.editing <- Sketch (0, None)
  end
  else if pressed 4 || pressed 2 then begin
    (* the right button: the box under it grabbed, by its corner to resize *)
    finish o;
    let i = hit o x y in
    o.sel <- i;
    if i >= 0 then begin
      let was = nth_obj o.page i in
      keep o;
      o.drag <- Some (i, x, y, was, x >= was.x + was.w - 12 && y >= was.y + was.h - 12)
    end
  end
  else if b land 6 <> 0 then begin
    match o.drag with
    | Some (i, mx, my, was, resizing) ->
        let moved = if resizing then { was with w = max 32 (was.w + x - mx); h = max 24 (was.h + y - my) }
          else { was with x = was.x + x - mx; y = was.y + y - my } in
        o.page <- replace o.page i (Some moved)
    | None -> ()
  end
  else begin
    (* let go: a box grabbed and not moved is no change to undo *)
    (match o.drag, o.undo with Some _, p :: rest when p == o.page -> o.undo <- rest | _ -> ());
    o.drag <- None
  end;
  o.buttons <- b

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

(* how many characters of a word are shown: the stars are marks *)
let shown (w : string) = let n = ref 0 in String.iter (fun c -> if c <> '*' then incr n) w; !n

(* A text's lines, filled to cols characters: each a heading or not,
 * whether it starts in bold (a mark may open on a line and close on
 * the next), and its words with their marks. A paragraph is the lines
 * between two empty ones; a line "# words" is a heading of its own. *)
let filled (cols : int) (text : string) : (bool * bool * string) list =
  (* a paragraph's words as lines, the last first, on acc *)
  let rec fill heading words line n acc =
    match words with
    | [] -> if line = "" then acc else (heading, line) :: acc
    | w :: rest ->
        let k = shown w in
        if line = "" then fill heading rest w k acc
        else if n + 1 + k <= cols then fill heading rest (line ^ " " ^ w) (n + 1 + k) acc
        else fill heading rest w k ((heading, line) :: acc) in
  let words l = List.filter (fun w -> w <> "") (String.split_on_char ' ' l) in
  (* the lines, the paragraph's words so far, the result the last first *)
  let rec go lines para acc =
    let flush acc = if para = [] then acc else fill false para "" 0 acc in
    match lines with
    | [] -> flush acc
    | l :: rest when String.length l >= 2 && String.sub l 0 2 = "# " ->
        go rest [] (fill true (words (String.sub l 2 (String.length l - 2))) "" 0 (flush acc))
    | l :: rest when words l = [] -> go rest [] ((false, "") :: flush acc)
    | l :: rest -> go rest (para @ words l) acc in
  let lines = List.rev (go (String.split_on_char '\n' text) [] []) in
  (* whether each line starts in bold: the stars before it, in its paragraph *)
  let rec bolds bold = function
    | (heading, l) :: rest ->
        let stars = String.length l - shown l in
        (heading, bold, l) :: bolds (if l = "" then false else (if stars mod 2 = 1 then not bold else bold)) rest
    | [] -> [] in
  bolds false lines

(* a filled line drawn from (x, y), at most cols characters: its pieces
 * between the stars, plain or bold *)
let draw_line (colour : int) (x : int) (y : int) (cols : int) (bold : bool) (l : string) : shape list =
  let n = String.length l in
  let rec go i start col bold acc =
    if i >= n || l.[i] = '*' then begin
      let piece = String.sub l start (i - start) in
      let piece = if col + String.length piece > cols then String.sub piece 0 (max 0 (cols - col)) else piece in
      (* bold: the words twice, a pixel apart *)
      let at = x + (8 * col) in
      let acc = if piece = "" then acc
        else (if bold then Group [ Move (at, y, Words (colour, piece)); Move (at + 1, y, Words (colour, piece)) ] else Move (at, y, Words (colour, piece))) :: acc in
      if i >= n then List.rev acc else go (i + 1) (i + 1) (col + String.length piece) (not bold) acc
    end
    else go (i + 1) start col bold acc in
  go 0 0 0 bold []

(* a text box, shown: its text filled, the lines that fit *)
let text_view (b : obj) : shape list =
  let rec take k = function
    | (heading, bold, l) :: rest when k < rows b ->
        let colour = if heading then dark_blue else black in
        draw_line colour (b.x + 4) (b.y + 2 + (16 * k)) (cols b) (bold || heading) l @ take (k + 1) rest
    | _ -> [] in
  take 0 (filled (cols b) b.data)

(* a text box being edited: the editor's lines in it, its text as it
 * is written, and its cursor *)
let edit_view (b : obj) (e : editor) : shape list = [ Move (b.x + 4, b.y + 2, Group (editor_shapes e (rows b))) ]

(* A sheet: the columns' letters and the rows' numbers in grey, the
 * grid's lines, each cell's value, a number at the cell's right, text
 * at its left (cut at the cell's edge), an error as #WHY; the chosen
 * cell in a blue frame. The values are computed again at each view: a
 * sheet is small, and it has no other place for them. *)
let sheet_view (b : obj) (chosen : (int * int) option) : shape list =
  let value = values b.data and ncols = min 26 (sheet_cols b) and nrows = min 99 (sheet_rows b) in
  let x0 = sheet_left b and y0 = sheet_top b in
  let heads =
    List.init ncols (fun c -> Move (x0 + (c * cell_w) + 28, b.y + 1, Words (grey, String.make 1 (Char.chr (97 + c)))))
    @ List.init nrows (fun r -> let n = string_of_int (r + 1) in Move (b.x + 2 + (8 * (2 - String.length n)), y0 + (16 * r), Words (grey, n))) in
  let lines =
    List.init (ncols + 1) (fun c -> Move (x0 + (c * cell_w) - 1, b.y + 1, Rect (light_grey, 1, b.h - 2)))
    @ List.init (nrows + 1) (fun r -> Move (b.x + 1, y0 + (16 * r) - 1, Rect (light_grey, b.w - 2, 1))) in
  let shown c r =
    let n = name c r in
    match (if typed_in b.data n = "" then Str "" else value n) with
    | Str "" -> []
    | v ->
        let t, right = match v with Num k -> string_of_int k, true | Str t -> t, false | Err e -> "#" ^ e, false in
        let t = if String.length t > 7 then String.sub t 0 7 else t in
        let x = if right then x0 + (c * cell_w) + cell_w - 4 - (8 * String.length t) else x0 + (c * cell_w) + 2 in
        [ Move (x, y0 + (16 * r), Words ((match v with Err _ -> 160 | _ -> black), t)) ] in
  let cells_shown = List.concat_map (fun c -> List.concat_map (fun r -> shown c r) (List.init nrows (fun r -> r))) (List.init ncols (fun c -> c)) in
  let frame = match chosen with
    | Some (c, r) when c < ncols && r < nrows ->
        let x = x0 + (c * cell_w) - 1 and y = y0 + (16 * r) - 1 in
        [ Move (x, y, Rect (blue, cell_w + 1, 2)); Move (x, y + 15, Rect (blue, cell_w + 1, 2)); Move (x, y, Rect (blue, 2, 17)); Move (x + cell_w - 1, y, Rect (blue, 2, 17)) ]
    | _ -> [] in
  lines @ heads @ cells_shown @ frame

(* A drawing: its shapes, and the stroke being made, in blue *)
let drawing_view (b : obj) (tool : int) (stroke : (int * int * int * int) option) : shape list =
  List.concat_map (figure_shapes b.x b.y black) (figures b.data)
  @ (match stroke with Some (x0, y0, x1, y1) -> figure_shapes b.x b.y blue (stroked tool x0 y0 x1 y1) | None -> [])

(* a box's frame: blue when it is selected; a small square at its
 * corner, where the right button resizes it *)
let frame (b : obj) (selected : bool) : shape list =
  let c = if selected then blue else grey and x1 = b.x + b.w - 1 and y1 = b.y + b.h - 1 in
  [ Move (b.x, b.y, Rect (c, b.w, 1)); Move (b.x, y1, Rect (c, b.w, 1)); Move (b.x, b.y, Rect (c, 1, b.h)); Move (x1, b.y, Rect (c, 1, b.h)) ]
  @ (if selected then [ Move (x1 - 5, y1 - 5, Rect (c, 6, 6)) ] else [])

(* the status line: what the box being edited says (a search, M-x), or
 * the page's message, or the file's name *)
let status (o : office) : shape list =
  let file, width, height = o.where in
  let said = match o.editing with
    | Writing e -> (match List.rev (editor_view e) with last :: _ -> last | [] -> "")
    | Cell (c, r, typed) when o.sel >= 0 ->
        (* the formula bar: the cell, what is being typed in it, or what was *)
        name c r ^ ": " ^ (match typed with Some t -> t ^ "_" | None -> typed_in (nth_obj o.page o.sel).data (name c r))
    | Sketch (tool, _) -> "drawing: " ^ List.nth tools tool ^ " (Tab: another); the left button draws; type a label"
    | _ -> "" in
  let m = if said <> "" then said else if o.message <> "" then o.message
    else if o.prefix then "C-x-" else file ^ (if o.page == o.clean then "" else " (modified)") ^ "    " ^ help in
  let m = if String.length m * 8 > width - 8 then String.sub m 0 ((width - 8) / 8) else m in
  [ Move (0, height - 18, Rect (light_grey, width, 18)); Move (4, height - 17, Words (black, m)) ]

let view (o : office) : shape list =
  let _, width, height = o.where in
  let i = ref (-1) in
  Rect (white, width, height)
  :: List.map (fun (b : obj) ->
       incr i;
       let content = match o.editing with
         | Writing e when !i = o.sel -> edit_view b e
         | Cell (c, r, _) when !i = o.sel -> sheet_view b (Some (c, r))
         | Sketch (tool, stroke) when !i = o.sel -> drawing_view b tool stroke
         | _ ->
             if b.kind = "text" then text_view b
             else if b.kind = "sheet" then sheet_view b None
             else if b.kind = "drawing" then drawing_view b 0 None
             else [ Move (b.x + 4, b.y + 2, Words (black, b.kind ^ "?")) ] in
       Group (frame b (!i = o.sel) @ content)) o.page
  @ [ Group (status o) ]
