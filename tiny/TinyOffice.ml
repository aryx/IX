(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOffice.mli *)

open TinyLibPlayground
open TinyLibGUI

(* what a key or the mouse asks of the program around: nothing, to save
 * the file, to quit *)
type request = Continue | Save | Quit

(* the page's colours, bytes of the machine's palette: white, black, a
 * frame's grey, the selected box's blue, the status line's light grey,
 * selected text's pale blue *)
let white = 255
let black = 0
let grey = 153
let blue = 3
let light_grey = 204
let pale_blue = 188

(* an object of the page: its kind ("text", "sheet", "drawing", "paint",
 * "chart"), its box in pixels, its data, its name (a sheet's, which a
 * chart names; "" for the others) *)
type obj = { kind : string; x : int; y : int; w : int; h : int; data : string; called : string }

(* a text box being edited: its characters and their styles (a byte
 * each: bold 1, italic 2, underlined 4, large 8), the cursor, the
 * selection's other end (the cursor's place: none), the style of what
 * is typed next, whether the left button is selecting *)
type doc = { mutable txt : string; mutable sty : string; mutable cur : int; mutable anchor : int; mutable typing : int; mutable selecting : bool }

(* what the selected box is edited by: nothing; a text box's text; a
 * sheet's cell, its column and row, and what is being
 * typed in it (None: the cell chosen, nothing typed yet); a drawing's
 * tool (0 a box, 1 an arrow, 2 a text), and the stroke the left button
 * is making, from where it went down to where it is, in the box; a
 * paint's colour (its place in pixel_letters), its brush (0 thin, 1
 * thick), and the pixel where the left button last was, when it is
 * down; the selected sheet's new name, being typed *)
type edit = Nothing | Writing of doc | Cell of int * int * string option | Sketch of int * (int * int * int * int) option
  | Painting of int * int * (int * int) option | Naming of string

(* what the menus ask for: to save, to quit, to undo, to delete the
 * selected box, a new box of a kind, a drawing's tool; in a text, to
 * cut, copy, paste, a style (0: plain); in a paint, a colour, a brush,
 * the picture cleared; in a sheet, a name typed, a chart of the chosen
 * cell's column *)
type command = Do_save | Do_quit | Do_undo | Do_delete | Do_add of string | Do_tool of int | Do_cut | Do_copy | Do_paste | Do_style of int
  | Do_ink of int | Do_brush of int | Do_clear | Do_name | Do_chart

type office = {
  mutable page : obj list;                (* the objects, the bottom one first *)
  mutable undo : obj list list;           (* the pages before, the last first *)
  mutable clean : obj list;               (* the page as it was last saved *)
  mutable sel : int;                      (* the selected object, its place in page; -1 none *)
  mutable editing : edit;                 (* what the selected box is edited by *)
  mutable drag : (int * int * int * obj * bool) option;   (* a box grabbed: the object, where the
                                                           * mouse was, the object then, resizing *)
  mutable at : int * int;                 (* the last click *)
  menu : menu_state;                      (* the menus', and the mouse's buttons as last seen *)
  mutable message : string;               (* the status line's *)
  mutable prefix : bool;                  (* C-x typed *)
  where : string * int * int;             (* the file, the page's width and height *)
}

(* (eleven fields: tiny-ml's most on tiny-machine) *)

let say (o : office) (m : string) = o.message <- m

(*****************************************************************************)
(* The page's objects *)
(*****************************************************************************)

(* a list's elements with their places, from 0 *)
let numbered (l : 'a list) : (int * 'a) list =
  let rec go k l = match l with x :: rest -> (k, x) :: go (k + 1) rest | [] -> [] in
  go 0 l

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
  String.concat "" (List.map (fun (m, s) -> m ^ " " ^ s ^ "\n") (if input = "" then others else others @ [ n, input ]))

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

(*****************************************************************************)
(* Text *)
(*****************************************************************************)

(* A text box's data is its text, with a mark where the style changes:
 *
 *     A \{b}bold\{} word, and \{il}large italic\{}.
 *
 * the style's letters between \{ and } (b bold, i italic, u
 * underlined, l large), \{} plain, \\ a backslash. Being edited, it is
 * two strings of the same length: the characters, and their styles. *)
let letters = "biul"

let decode (data : string) : string * string =
  let n = String.length data in
  let rec go i style chars styles =
    if i >= n then (String.concat "" (List.rev chars), String.concat "" (List.rev styles))
    else if data.[i] = '\\' && i + 1 < n && data.[i + 1] = '{' then begin
      match String.index_from_opt data i '}' with
      | Some e ->
          let s = ref 0 in
          String.iter (fun c -> match String.index_from_opt letters 0 c with Some k -> s := !s lor (1 lsl k) | None -> ()) (String.sub data (i + 2) (e - i - 2));
          go (e + 1) !s chars styles
      | None -> go n style chars styles
    end
    else begin
      let skip = if data.[i] = '\\' && i + 1 < n then 1 else 0 in
      go (i + 1 + skip) style (String.make 1 data.[i + skip] :: chars) (String.make 1 (Char.chr style) :: styles)
    end in
  go 0 0 [] []

let mark (s : int) = "\\{" ^ String.concat "" (List.init 4 (fun k -> if s land (1 lsl k) <> 0 then String.make 1 letters.[k] else "")) ^ "}"

let encode (txt : string) (sty : string) : string =
  let rec go i was acc =
    if i >= String.length txt then String.concat "" (List.rev (if was <> 0 then mark 0 :: acc else acc))
    else begin
      let s = Char.code sty.[i] in
      let c = if txt.[i] = '\\' then "\\\\" else String.make 1 txt.[i] in
      go (i + 1) s (c :: (if s <> was then mark s :: acc else acc))
    end in
  go 0 0 []

(* A text laid out in a width: each character's place, its x and its
 * line, and the end's (where a cursor after the last character is);
 * each line's top and height, its largest character's. A word goes to
 * the next line when it does not fit (one wider than the line is cut);
 * a newline ends a line. *)
type laid = { px : int array; ln : int array; top : int array; tall : int array }

let cw (sty : string) (i : int) = char_width (Char.code sty.[i] lsl 8)

let lay_out (width : int) (txt : string) (sty : string) : laid =
  let n = String.length txt in
  let px = Array.make (n + 1) 0 and ln = Array.make (n + 1) 0 in
  let x = ref 0 and l = ref 0 and i = ref 0 in
  while !i < n do
    if txt.[!i] = '\n' then (px.(!i) <- !x; ln.(!i) <- !l; x := 0; incr l; incr i)
    else begin
      let j = ref !i and ww = ref 0 in
      while !j < n && txt.[!j] <> ' ' && txt.[!j] <> '\n' do ww := !ww + cw sty !j; incr j done;
      if !j = !i then j := !i + 1 else if !x > 0 && !x + !ww > width then (x := 0; incr l);
      for k = !i to !j - 1 do
        if txt.[k] <> ' ' && !x > 0 && !x + cw sty k > width then (x := 0; incr l);
        px.(k) <- !x; ln.(k) <- !l; x := !x + cw sty k
      done;
      i := !j
    end
  done;
  px.(n) <- !x; ln.(n) <- !l;
  let tall = Array.make (!l + 1) 16 and top = Array.make (!l + 1) 0 in
  for k = 0 to n - 1 do if txt.[k] <> '\n' then tall.(ln.(k)) <- max tall.(ln.(k)) (char_height (Char.code sty.[k] lsl 8)) done;
  for k = 1 to !l do top.(k) <- top.(k - 1) + tall.(k - 1) done;
  { px; ln; top; tall }

(* the place in the text nearest (x, y): on the line there, the first
 * character whose middle is right of x, or the line's last place *)
let index_at (lay : laid) (txt : string) (sty : string) (x : int) (y : int) : int =
  let n = String.length txt and lines = Array.length lay.top in
  let line = ref (lines - 1) and found = ref (-1) and last = ref 0 in
  for k = 0 to lines - 1 do if !line = lines - 1 && y < lay.top.(k) + lay.tall.(k) then line := k done;
  for i = 0 to n do
    if lay.ln.(i) = !line then begin
      last := i;
      if !found < 0 && (i = n || txt.[i] = '\n' || lay.px.(i) + (cw sty i / 2) > x) then found := i
    end
  done;
  if !found >= 0 then !found else !last

(* the selection, from its first character to after its last *)
let selection (d : doc) = (min d.cur d.anchor, max d.cur d.anchor)

(* the cursor put at i, no selection, what is typed next in the style
 * of the character before *)
let go_to (d : doc) (i : int) =
  let i = max 0 (min (String.length d.txt) i) in
  d.cur <- i;
  d.anchor <- i;
  if i > 0 && d.txt.[i - 1] <> '\n' then d.typing <- Char.code d.sty.[i - 1]

(* the selection replaced by a text and its styles *)
let put_text (d : doc) (t : string) (styles : string) =
  let (a, z) = selection d and n = String.length d.txt in
  d.txt <- String.sub d.txt 0 a ^ t ^ String.sub d.txt z (n - z);
  d.sty <- String.sub d.sty 0 a ^ styles ^ String.sub d.sty z (n - z);
  d.cur <- a + String.length t;
  d.anchor <- d.cur

(* A style: the selection's (set, or taken off when all of it has it
 * already), or, nothing selected, what is typed next's; 0 plain. *)
let restyle (d : doc) (bit : int) =
  let (a, z) = selection d in
  if a = z then d.typing <- (if bit = 0 then 0 else d.typing lxor bit)
  else begin
    let all = ref true in
    for i = a to z - 1 do if Char.code d.sty.[i] land bit = 0 then all := false done;
    let one i = let s = Char.code d.sty.[a + i] in String.make 1 (Char.chr (if bit = 0 then 0 else if !all then s land lnot bit else s lor bit)) in
    let n = String.length d.txt in
    d.sty <- String.sub d.sty 0 a ^ String.concat "" (List.init (z - a) one) ^ String.sub d.sty z (n - z)
  end

(* what was cut or copied, its characters and their styles *)
let clipboard = ref ("", "")
let copy (d : doc) = let (a, z) = selection d in clipboard := (String.sub d.txt a (z - a), String.sub d.sty a (z - a))

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
    | Writing d -> change o (encode d.txt d.sty)
    | Cell (c, r, Some t) -> change o (set_cell (nth_obj o.page o.sel).data (name c r) t); o.editing <- Cell (c, r, None)
    | _ -> ()

let finish (o : office) = commit o; o.editing <- Nothing

(* box i's text edited, its cursor where (x, y) is, the left button
 * selecting from there if it is down *)
let edit (o : office) (i : int) (x : int) (y : int) (selecting : bool) =
  let b = nth_obj o.page i in
  let (txt, sty) = decode b.data in
  let d = { txt; sty; cur = 0; anchor = 0; typing = 0; selecting } in
  go_to d (index_at (lay_out (b.w - 8) txt sty) txt sty (x - b.x - 4) (y - b.y - 2));
  o.sel <- i;
  o.editing <- Writing d

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
  String.concat "" (kind :: List.map (fun n -> " " ^ string_of_int n) nums @ (if label = "" then [ "\n" ] else [ " "; label; "\n" ]))

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
    | (kind, nums, label) :: rest -> change o (String.concat "" (List.map figure_line (List.rev rest @ f kind nums label)))
    | [] -> () in
  if k = 9 then o.editing <- Sketch ((tool + 1) mod 3, None)
  else if k >= 32 && k < 127 then relabel (fun kind nums label -> [ kind, nums, label ^ String.make 1 (Char.chr k) ])
  else if k = 8 || k = 127 then
    relabel (fun kind nums label -> if label = "" then [] else [ kind, nums, String.sub label 0 (String.length label - 1) ])
  else if k = 7 then o.editing <- Nothing
  else o.message <- "a drawing: Tab, the mouse, a label typed; C-g"

(*****************************************************************************)
(* Paint *)
(*****************************************************************************)

(* A paint's data is its picture, a line a row of pixels, a letter a
 * pixel, its colour:
 *
 *     ..kkk..
 *     .krrrk.
 *
 * . white, k black, r red, g green, b blue, y yellow, o orange, p
 * purple, n brown, a grey (TinyLibPlayground's pixel_letters; a row
 * ends at its last colour that is not white). A pixel is a square of 4
 * by 4 on the page; a row is one word of fat pixels, its letters (made
 * the kernel's bytes when it is drawn), so a stroke draws again the
 * rows it went through, and nothing else. *)
let paint_names = [ "white"; "black"; "red"; "green"; "blue"; "yellow"; "orange"; "purple"; "brown"; "grey" ]

(* the picture's size in pixels, in box b *)
let paint_cols (b : obj) = max 1 ((b.w - 4) / 4)
let paint_rows (b : obj) = max 1 ((b.h - 4) / 4)

(* the pixel under (x, y), in the picture *)
let pixel_at (b : obj) (x : int) (y : int) = (max 0 (min (paint_cols b - 1) ((x - b.x - 2) / 4)), max 0 (min (paint_rows b - 1) ((y - b.y - 2) / 4)))

(* a row without the white at its end *)
let rec trim_white (row : string) = let n = String.length row in if n > 0 && row.[n - 1] = '.' then trim_white (String.sub row 0 (n - 1)) else row

(* The pixels a stroke of a brush covers, from (c0, r0) to (c1, r1), in
 * a letter, put in the picture: a thick brush 3 pixels wide. *)
let painted (b : obj) (letter : char) (brush : int) (c0 : int) (r0 : int) (c1 : int) (r1 : int) : string =
  let nrows = paint_rows b and ncols = paint_cols b in
  let rows = Array.make nrows "" in
  List.iteri (fun r row -> if r < nrows then rows.(r) <- row) (String.split_on_char '\n' b.data);
  let set c r =
    if c >= 0 && c < ncols && r >= 0 && r < nrows then begin
      let row = rows.(r) in
      let row = if String.length row > c then row else row ^ String.make (c + 1 - String.length row) '.' in
      rows.(r) <- trim_white (String.sub row 0 c ^ String.make 1 letter ^ String.sub row (c + 1) (String.length row - c - 1))
    end in
  let n = max 1 (max (abs (c1 - c0)) (abs (r1 - r0))) in
  for k = 0 to n do
    let c = c0 + ((c1 - c0) * k / n) and r = r0 + ((r1 - r0) * k / n) in
    if brush = 0 then set c r else for dr = -1 to 1 do for dc = -1 to 1 do set (c + dc) (r + dr) done done
  done;
  (* (the rows up to the last one that is not white) *)
  let last = ref (-1) in
  for r = 0 to nrows - 1 do if rows.(r) <> "" then last := r done;
  String.concat "" (List.init (!last + 1) (fun r -> rows.(r) ^ "\n"))

(* a stroke painted in the selected paint (the page changed, its undo
 * kept when the stroke began) *)
let paint (o : office) (ink : int) (brush : int) (c0 : int) (r0 : int) (c1 : int) (r1 : int) =
  let b = nth_obj o.page o.sel in
  o.page <- replace o.page o.sel (Some { b with data = painted b pixel_letters.[ink] brush c0 r0 c1 r1 })

(* a key in a paint: a digit a colour (0 white, 1 black...); C-g leaves it *)
let paint_key (o : office) (brush : int) (k : int) =
  if k >= 48 && k < 58 then o.editing <- Painting (k - 48, brush, None)
  else if k = 7 then o.editing <- Nothing
  else o.message <- "a paint: the left button paints; the Paint menu, or a digit a colour; C-g"

(* A paint: each row a word of fat pixels, the rows that fit, as much
 * of each as fits *)
let paint_view (b : obj) : shape list =
  let ncols = paint_cols b and nrows = paint_rows b in
  let rec rows l r =
    match l with
    | row :: rest when r < nrows ->
        let n = min ncols (String.length row) in
        (if n > 0 then [ Move (b.x + 2, b.y + 2 + (4 * r), Words (fat_pixels, if n = String.length row then row else String.sub row 0 n)) ] else []) @ rows rest (r + 1)
    | _ -> [] in
  rows (String.split_on_char '\n' b.data) 0

(*****************************************************************************)
(* The chart *)
(*****************************************************************************)

(* A chart's data is a line: bars, the sheet it draws by its name, the
 * cells of its values, and of its labels if it has some:
 *
 *     bars budget b1:b3 a1:a3
 *
 * a range being cells of a column or of a row. The values are the
 * sheet's at each view, so a chart follows its sheet; a sheet renamed,
 * its charts are too. *)

(* the cells of a range, "b1:b3" or "a1:c1" ([] if it is none) *)
let range_cells (r : string) : string list =
  let at n = if String.length n >= 2 && n.[0] >= 'a' && n.[0] <= 'z' then
      (match int_of_string_opt (String.sub n 1 (String.length n - 1)) with Some k when k >= 1 -> Some (Char.code n.[0] - 97, k - 1) | _ -> None)
    else None in
  match String.split_on_char ':' r with
  | [ a; b ] -> (
      match at a, at b with
      | Some (c0, r0), Some (c1, r1) when c0 = c1 && r1 >= r0 -> List.init (r1 - r0 + 1) (fun k -> name c0 (r0 + k))
      | Some (c0, r0), Some (c1, r1) when r0 = r1 && c1 >= c0 -> List.init (c1 - c0 + 1) (fun k -> name (c0 + k) r0)
      | _ -> [])
  | _ -> []

(* A chart's bars, each its label and its value (a cell that is not a
 * number, 0), from its sheet on the page; or, none, why *)
let chart_bars (page : obj list) (b : obj) : (string * int) list * string =
  let first = match String.split_on_char '\n' b.data with l :: _ -> l | [] -> "" in
  match String.split_on_char ' ' first with
  | "bars" :: sheet :: range :: rest -> (
      match List.filter (fun (s : obj) -> s.kind = "sheet" && s.called = sheet) page with
      | s :: _ ->
          let value = values s.data in
          let labels = match rest with l :: _ -> range_cells l | [] -> [] in
          let label k = match labels with [] -> "" | _ -> (
            match (if k < List.length labels then value (List.nth labels k) else Str "") with Num v -> string_of_int v | Str t -> t | Err e -> "#" ^ e) in
          let bars = List.map (fun (k, n) -> (label k, match value n with Num v -> v | _ -> 0)) (numbered (range_cells range)) in
          if bars = [] then ([], "no cells in " ^ range) else (bars, "")
      | [] -> ([], "no sheet " ^ sheet))
  | _ -> ([], "a chart: bars SHEET b1:b3 a1:a3")

(* the bars' colours, in turn: the paint's blue, red, green, yellow,
 * orange, purple *)
let bar_colours = [ 54; 240; 42; 252; 231; 129 ]

(* A chart: a bar a value, as tall as its share of the largest (none
 * below 0), its value above it, its label under it (cut to its width);
 * the axis a grey line *)
let chart_view (page : obj list) (b : obj) : shape list =
  match chart_bars page b with
  | [], why -> [ Move (b.x + 4, b.y + 2, Words (160, why)) ]
  | bars, _ ->
      let n = List.length bars in
      let top = List.fold_left (fun m (_, v) -> max m v) 1 bars in
      let bw = max 6 ((b.w - 16) / n) and base = b.y + b.h - 20 and room = b.h - 42 in
      let cut t = let k = max 0 ((bw - 2) / 8) in if String.length t > k then String.sub t 0 k else t in
      List.concat (List.map (fun (k, (label, v)) ->
        let x = b.x + 8 + (k * bw) and tall = max 0 (v * room / top) in
        (if tall > 0 then [ Move (x + 2, base - tall, Rect (List.nth bar_colours (k mod 6), bw - 4, tall)) ] else [])
        @ [ Move (x + 2, base - tall - 16, Words (black, cut (string_of_int v))); Move (x + 2, base + 2, Words (black, cut label)) ]) (numbered bars))
      @ [ Move (b.x + 4, base, Rect (grey, b.w - 8, 1)) ]

(* a name a sheet can have: a letter, then letters, digits, _ *)
let good_name (n : string) =
  n <> "" && ((n.[0] >= 'a' && n.[0] <= 'z') || (n.[0] >= 'A' && n.[0] <= 'Z'))
  && String.for_all (fun c -> (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_') n

(* A key while the selected sheet's name is typed: a character, Backspace,
 * Enter (the name given, to the charts of the sheet too), C-g *)
let name_key (o : office) (typed : string) (k : int) =
  if k >= 32 && k < 127 then o.editing <- Naming (typed ^ String.make 1 (Char.chr k))
  else if (k = 8 || k = 127) && typed <> "" then o.editing <- Naming (String.sub typed 0 (String.length typed - 1))
  else if k = 13 || k = 10 then begin
    let s = nth_obj o.page o.sel in
    if not (good_name typed) then o.message <- "a name: a letter, then letters, digits, _"
    else if List.exists (fun (b : obj) -> b.called = typed && b != s) o.page then o.message <- "another sheet is " ^ typed
    else begin
      let renamed l = match String.split_on_char ' ' l with "bars" :: was :: rest when was = s.called -> String.concat " " ("bars" :: typed :: rest) | _ -> l in
      keep o;
      o.page <- List.map (fun (b : obj) ->
        if b == s then { b with called = typed }
        else if b.kind = "chart" then { b with data = String.concat "\n" (List.map renamed (String.split_on_char '\n' b.data)) }
        else b) o.page;
      o.editing <- Nothing
    end
  end
  else if k = 7 then o.editing <- Nothing

(* a chart of the chosen cell's column, beside its sheet (under it, if
 * the page is too narrow): its cells from the first number to the last,
 * the column at its left their labels *)
let make_chart (o : office) (c : int) =
  let s = nth_obj o.page o.sel in
  let value = values s.data in
  let rows = List.filter (fun r -> match value (name c r) with Num _ -> true | _ -> false) (List.init 99 (fun r -> r)) in
  match rows with
  | [] -> o.message <- "no numbers in column " ^ String.make 1 (Char.chr (97 + c))
  | r0 :: _ ->
      let r1 = List.fold_left max r0 rows in
      let range c = name c r0 ^ ":" ^ name c r1 in
      let data = "bars " ^ s.called ^ " " ^ range c ^ (if c > 0 then " " ^ range (c - 1) else "") ^ "\n" in
      let _, width, _ = o.where in
      let x, y = if s.x + s.w + 216 <= width then s.x + s.w + 16, s.y else s.x, s.y + s.h + 24 in
      keep o;
      o.page <- o.page @ [ { kind = "chart"; x; y; w = 200; h = 120; data; called = "" } ];
      o.sel <- List.length o.page - 1;
      o.editing <- Nothing

(*****************************************************************************)
(* The file *)
(*****************************************************************************)

(* A page's file is a document in mini-troff's format
 * (plan_typesetting.md): Markdown's lines, and \name[options]{text}
 * for what Markdown has not. Each object is a \box at its place (x, y,
 * width, height), its content the lines up to one that is a } alone:
 *
 *     \box[20 40 200 84]{
 *     # Tiny office
 *
 *     A page of **boxes**, *styled*, \u{underlined}.
 *     }
 *
 *     \box[300 40 282 114]{
 *     | a     | b      |
 *     |-------|--------|
 *     | Rent  | 500    |
 *     | Total | =b1+b2 |
 *     }
 *
 * The kind is in the content: a table is a sheet (its header the
 * columns' letters, then a row a line, what was typed in each cell;
 * its name after its box's numbers), a fence ```drawing, ```paint or
 * ```chart is that (its lines as they are), the rest text. A text's styles are Markdown's, **bold**, *italic*, a line
 * "# " large, and \u{} underlined, \large{} large in a line; \ before a
 * character that would be read otherwise. So emacs edits a page as any
 * text (no count of bytes to keep right), and a Markdown file, with no
 * \box, is opened as one text box. *)

(* a text's line as Markdown, from its characters and their styles *)
let md_of_line (t : string) (st : string) : string =
  let n = String.length t in
  let all_large = n > 0 && String.for_all (fun c -> Char.code c land 8 <> 0) st in
  let base = if all_large then 8 else 0 in
  let stars k = if k = 1 then "**" else if k = 2 then "*" else if k = 3 then "***" else "" in
  let opens k = (if k land 8 <> 0 then "\\large{" else "") ^ (if k land 4 <> 0 then "\\u{" else "") ^ stars (k land 3) in
  let closes k = stars (k land 3) ^ (if k land 4 <> 0 then "}" else "") ^ (if k land 8 <> 0 then "}" else "") in
  let one i c =
    if c = '\\' || c = '*' || c = '{' || c = '}' || (i = 0 && (c = '#' || c = '|' || c = '`')) then "\\" ^ String.make 1 c else String.make 1 c in
  let rec go i was acc =
    if i >= n then String.concat "" (List.rev (closes was :: acc))
    else begin
      let k = Char.code st.[i] land lnot base in
      go (i + 1) k (one i t.[i] :: (if k <> was then opens k :: closes was :: acc else acc))
    end in
  (if all_large then "# " else "") ^ go 0 0 []

(* a Markdown line as characters and their styles: stars toggle italic
 * (one), bold (two), both (three); \u{ and \large{ open a style that
 * the next } closes; \ takes the next character as it is *)
let line_of_md (l : string) : string * string =
  let n = String.length l in
  let base, start = if n >= 2 && String.sub l 0 2 = "# " then 8, 2 else 0, 0 in
  let starts i w = i + String.length w <= n && String.sub l i (String.length w) = w in
  let rec any l = match l with k :: rest -> k lor any rest | [] -> 0 in
  let rec go i opened stars chars styles =
    let add c = go (i + 1) opened stars (String.make 1 c :: chars) (String.make 1 (Char.chr (base lor stars lor any opened)) :: styles) in
    if i >= n then (String.concat "" (List.rev chars), String.concat "" (List.rev styles))
    else if starts i "\\u{" then go (i + 3) (4 :: opened) stars chars styles
    else if starts i "\\large{" then go (i + 7) (8 :: opened) stars chars styles
    else if l.[i] = '\\' && i + 1 < n then
      go (i + 2) opened stars (String.make 1 l.[i + 1] :: chars) (String.make 1 (Char.chr (base lor stars lor any opened)) :: styles)
    else if l.[i] = '}' && opened <> [] then go (i + 1) (match opened with _ :: rest -> rest | [] -> []) stars chars styles
    else if l.[i] = '*' then begin
      let k = if starts i "***" then 3 else if starts i "**" then 2 else 1 in
      go (i + k) opened (stars lxor (if k = 1 then 2 else if k = 2 then 1 else 3)) chars styles
    end
    else add l.[i] in
  go start [] 0 [] []

(* a text box's data as Markdown's lines, and back *)
let md_of_text (data : string) : string list =
  let (t, st) = decode data in
  let rec lines i =
    match String.index_from_opt t i '\n' with
    | Some e -> md_of_line (String.sub t i (e - i)) (String.sub st i (e - i)) :: lines (e + 1)
    | None -> [ md_of_line (String.sub t i (String.length t - i)) (String.sub st i (String.length t - i)) ] in
  if t = "" then [] else lines 0

let text_of_md (ls : string list) : string =
  let read = List.map line_of_md ls in
  encode (String.concat "" (List.map (fun (k, (t, _)) -> if k = 0 then t else "\n" ^ t) (numbered read)))
    (String.concat "" (List.map (fun (k, (_, st)) -> if k = 0 then st else "\000" ^ st) (numbered read)))

(* A sheet as a table, its columns as wide as their widest cell, and
 * back (a | in a cell is \|) *)
let md_of_sheet (data : string) : string list =
  let cs = cells data in
  let col n = Char.code n.[0] - 97 and row n = (match int_of_string_opt (String.sub n 1 (String.length n - 1)) with Some r -> r | None -> 1) - 1 in
  let ncols = List.fold_left (fun m (n, _) -> max m (col n + 1)) 1 cs and nrows = List.fold_left (fun m (n, _) -> max m (row n + 1)) 0 cs in
  let esc s = String.concat "" (List.map (fun c -> if c = '|' then "\\|" else String.make 1 c) (List.init (String.length s) (fun i -> s.[i]))) in
  let cell c r = esc (typed_in data (name c r)) in
  let wide = List.init ncols (fun c -> List.fold_left (fun m r -> max m (String.length (cell c r))) 1 (List.init nrows (fun r -> r))) in
  let pad s w = s ^ String.make (w - String.length s) ' ' in
  let line f = "|" ^ String.concat "" (List.map (fun (c, w) -> " " ^ pad (f c) w ^ " |") (numbered wide)) in
  line (fun c -> String.make 1 (Char.chr (97 + c)))
  :: ("|" ^ String.concat "" (List.map (fun w -> String.make (w + 2) '-' ^ "|") wide))
  :: List.init nrows (fun r -> line (fun c -> cell c r))

(* a table's line, its cells: between the |, trimmed, \| a | *)
let table_cells (l : string) : string list =
  let n = String.length l in
  let rec go i cur acc =
    if i >= n then List.rev acc
    else if l.[i] = '\\' && i + 1 < n && l.[i + 1] = '|' then go (i + 2) (cur ^ "|") acc
    else if l.[i] = '|' then go (i + 1) "" (String.trim cur :: acc)
    else go (i + 1) (cur ^ String.make 1 l.[i]) acc in
  match go 0 "" [] with _ :: cells -> cells | [] -> []

let sheet_of_md (ls : string list) : string =
  match ls with
  | _ :: _ :: rows ->
      String.concat "" (List.concat (List.map (fun (r, l) -> List.concat (List.map (fun (c, t) -> if t = "" then [] else [ name c r ^ " " ^ t ^ "\n" ]) (numbered (table_cells l)))) (numbered rows)))
  | _ -> ""

(* the file of a page, and its page *)
let text (o : office) : string =
  String.concat "" (List.map (fun (k, (b : obj)) ->
    let content =
      if b.kind = "sheet" then md_of_sheet b.data
      else if b.kind = "drawing" || b.kind = "paint" || b.kind = "chart" then
        (* (its lines as they are, a paint's empty rows too; not the empty one after the last newline) *)
        [ "```" ^ b.kind ] @ (match List.rev (String.split_on_char '\n' b.data) with "" :: r -> List.rev r | l -> List.rev l) @ [ "```" ]
      else md_of_text b.data in
    String.concat "" ((if k = 0 then "" else "\n") :: ("\\box[" ^ string_of_int b.x ^ " " ^ string_of_int b.y ^ " " ^ string_of_int b.w ^ " " ^ string_of_int b.h ^ (if b.called = "" then "" else " " ^ b.called) ^ "]{\n")
          :: List.map (fun l -> l ^ "\n") content @ [ "}\n" ])) (numbered o.page))

let obj_of (x : int) (y : int) (w : int) (h : int) (called : string) (ls : string list) : obj =
  let lines_data l = String.concat "" (List.map (fun s -> s ^ "\n") l) in
  match ls with
  | first :: _ when String.length first > 0 && first.[0] = '|' -> { kind = "sheet"; x; y; w; h; data = sheet_of_md ls; called }
  | first :: rest when first = "```drawing" || first = "```paint" || first = "```chart" ->
      { kind = String.sub first 3 (String.length first - 3); x; y; w; h; data = lines_data (List.filter (fun l -> l <> "```") rest); called = "" }
  | _ -> { kind = "text"; x; y; w; h; data = text_of_md ls; called = "" }

let parse (width : int) (height : int) (s : string) : obj list =
  let is_box l = String.length l > 6 && String.sub l 0 5 = "\\box[" && String.sub l (String.length l - 2) 2 = "]{" in
  let rec go ls =
    match ls with
    | l :: rest when is_box l ->
        let words = String.split_on_char ' ' (String.sub l 5 (String.length l - 7)) in
        let num v = match int_of_string_opt v with Some k -> k | None -> 0 in
        let rec content acc ls = match ls with "}" :: rest -> List.rev acc, rest | x :: rest -> content (x :: acc) rest | [] -> List.rev acc, [] in
        let (inside, rest) = content [] rest in
        (match words with
         | [ x; y; w; h ] -> obj_of (num x) (num y) (num w) (num h) "" inside :: go rest
         | [ x; y; w; h; called ] -> obj_of (num x) (num y) (num w) (num h) called inside :: go rest
         | _ -> go rest)
    | _ :: rest -> go rest
    | [] -> [] in
  let ls = String.split_on_char '\n' s in
  if s = "" then []
  else if List.exists is_box ls then go ls
  else [ obj_of 16 40 (width - 32) (height - 80) "" (match List.rev ls with "" :: r -> List.rev r | _ -> ls) ]

let create (width : int) (height : int) (file : string) (s : string) : office =
  let page = parse width height s in
  { page; undo = []; clean = page; sel = -1; editing = Nothing; drag = None; at = (16, 40); menu = menu_closed ();
    message = ""; prefix = false; where = (file, width, height) }

let saved (o : office) =
  o.clean <- o.page;
  let file, _, _ = o.where in
  o.message <- "Wrote " ^ file

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

let help = "the menus above; a click edits a box; its tab moves it, its corner resizes it"

let quit (o : office) : request =
  let refused = "Not saved: C-x C-s saves, C-x C-c again quits" in
  if o.page == o.clean || o.message = refused then Quit else (o.message <- refused; Continue)

(* A key in a text: a character typed, in the style of what is typed
 * next; Backspace, C-d the selection or a character deleted; the
 * arrows (C-f, C-p, C-n), C-a, C-e the cursor moved; C-b bold, Tab
 * italic, C-u underlined, C-l large; C-w cut, C-y pasted; C-g no
 * selection. The box grows to show it all. *)
let write_key (o : office) (d : doc) (k : int) =
  let b = nth_obj o.page o.sel in
  let lay = lay_out (b.w - 8) d.txt d.sty and n = String.length d.txt in
  let (a, z) = selection d and line = lay.ln.(d.cur) in
  let vertical l = if l >= 0 && l < Array.length lay.top then go_to d (index_at lay d.txt d.sty lay.px.(d.cur) lay.top.(l)) in
  let rec back i = if i > 0 && lay.ln.(i - 1) = line && d.txt.[i - 1] <> '\n' then back (i - 1) else i in
  let rec forth i = if i < n && d.txt.[i] <> '\n' && lay.ln.(i + 1) = line then forth (i + 1) else i in
  if (k >= 32 && k < 127) || k = 10 || k = 13 then put_text d (String.make 1 (if k = 13 then '\n' else Char.chr k)) (String.make 1 (Char.chr d.typing))
  else if k = 8 || k = 127 then ((if a = z && a > 0 then d.anchor <- a - 1); put_text d "" "")
  else if k = 4 then ((if a = z && z < n then d.anchor <- z + 1); put_text d "" "")
  else if k = 130 then go_to d (if a < z then a else d.cur - 1)
  else if k = 131 || k = 6 then go_to d (if a < z then z else d.cur + 1)
  else if k = 128 || k = 16 then vertical (line - 1)
  else if k = 129 || k = 14 then vertical (line + 1)
  else if k = 1 then go_to d (back d.cur)
  else if k = 5 then go_to d (forth d.cur)
  else if k = 2 then restyle d 1
  else if k = 9 then restyle d 2
  else if k = 21 then restyle d 4
  else if k = 12 then restyle d 8
  else if k = 23 then (copy d; put_text d "" "")
  else if k = 25 then (let (t, st) = !clipboard in put_text d t st)
  else if k = 7 then d.anchor <- d.cur
  else o.message <- "a text: C-b bold, Tab italic, C-u underlined, C-l large; C-w cut, C-y paste";
  let lay = lay_out (b.w - 8) d.txt d.sty in
  let last = Array.length lay.top - 1 in
  let need = lay.top.(last) + lay.tall.(last) + 6 in
  if need > b.h then o.page <- replace o.page o.sel (Some { b with h = need })

(* a new box where the last click was, of a kind, edited at once (the
 * menus' Insert) *)
let add (o : office) (kind : string) (w : int) (h : int) =
  let x, y = o.at in
  keep o;
  let rec fresh k = let n = "sheet" ^ string_of_int k in if List.exists (fun (b : obj) -> b.called = n) o.page then fresh (k + 1) else n in
  o.page <- o.page @ [ { kind; x; y; w; h; data = ""; called = (if kind = "sheet" then fresh 1 else "") } ];
  let i = List.length o.page - 1 in
  o.sel <- i;
  if kind = "text" then edit o i x y false else if kind = "sheet" then o.editing <- Cell (0, 0, None)
  else if kind = "paint" then o.editing <- Painting (1, 0, None) else o.editing <- Sketch (0, None)

(* what a menu's item asks for (the keys ask for the same) *)
let command (o : office) (c : command) : request =
  match c with
  | Do_save -> commit o; Save
  | Do_quit -> commit o; quit o
  | Do_undo ->
      finish o;
      (match o.undo with
       | p :: rest -> o.page <- p; o.undo <- rest; o.sel <- -1
       | [] -> o.message <- "No more undo");
      Continue
  | Do_delete -> finish o; (if o.sel >= 0 then (keep o; o.page <- replace o.page o.sel None; o.sel <- -1)); Continue
  | Do_add kind ->
      finish o;
      (if kind = "sheet" then add o "sheet" (26 + (4 * cell_w)) (18 + (6 * 16))
       else if kind = "drawing" then add o "drawing" 300 160
       else if kind = "paint" then add o "paint" 200 124 else add o "text" 200 84);
      Continue
  | Do_tool t -> (match o.editing with Sketch (_, _) -> o.editing <- Sketch (t, None) | _ -> ()); Continue
  | Do_ink k -> (match o.editing with Painting (_, brush, _) -> o.editing <- Painting (k, brush, None) | _ -> ()); Continue
  | Do_brush k -> (match o.editing with Painting (ink, _, _) -> o.editing <- Painting (ink, k, None) | _ -> ()); Continue
  | Do_clear -> (match o.editing with Painting (_, _, _) -> change o "" | _ -> ()); Continue
  | Do_cut -> (match o.editing with Writing d -> copy d; put_text d "" "" | _ -> ()); Continue
  | Do_copy -> (match o.editing with Writing d -> copy d | _ -> ()); Continue
  | Do_paste -> (match o.editing with Writing d -> let (t, st) = !clipboard in put_text d t st | _ -> ()); Continue
  | Do_style bit -> (match o.editing with Writing d -> restyle d bit | _ -> ()); Continue
  | Do_name -> (match o.editing with Cell (_, _, _) -> commit o; o.editing <- Naming "" | _ -> ()); Continue
  | Do_chart -> (match o.editing with Cell (c, _, _) -> commit o; make_chart o c | _ -> ()); Continue

(* the menus, a drawing's tools when one is edited (the one in use
 * marked); the keys at the right *)
let office_menus (o : office) : (string * (string * command) list) list =
  [ ("File", [ ("Save     C-x C-s", Do_save); ("Quit     C-x C-c", Do_quit) ]);
    ("Edit", [ ("Undo       C-_", Do_undo); ("Cut        C-w", Do_cut); ("Copy", Do_copy); ("Paste      C-y", Do_paste); ("Delete box", Do_delete) ]);
    ("Insert", [ ("Text       C-o", Do_add "text"); ("Sheet    C-x t", Do_add "sheet"); ("Drawing  C-x d", Do_add "drawing"); ("Paint    C-x p", Do_add "paint") ]) ]
  @ (match o.editing with
     | Writing d ->
         let mark k s = (if d.typing land k <> 0 then "* " else "  ") ^ s in
         [ ("Format", [ (mark 1 "Bold       C-b", Do_style 1); (mark 2 "Italic     Tab", Do_style 2); (mark 4 "Underline  C-u", Do_style 4);
                        (mark 8 "Large      C-l", Do_style 8); ("  Plain", Do_style 0) ]) ]
     | Cell (_, _, _) -> [ ("Sheet", [ ("Name...", Do_name); ("Chart of this column", Do_chart) ]) ]
     | Painting (ink, brush, _) ->
         let colour k = ((if k = ink then "* " else "  ") ^ List.nth paint_names k ^ "      " ^ string_of_int k, Do_ink k) in
         [ ("Paint", List.init 10 colour @ [ ((if brush = 0 then "* " else "  ") ^ "Thin brush", Do_brush 0);
                                              ((if brush = 1 then "* " else "  ") ^ "Thick brush", Do_brush 1); ("  Clear", Do_clear) ]) ]
     | Sketch (tool, _) ->
         let mark k s = (if k = tool then "* " else "  ") ^ s in
         [ ("Draw", [ (mark 0 "Box", Do_tool 0); (mark 1 "Arrow", Do_tool 1); (mark 2 "Text", Do_tool 2) ]) ]
     | _ -> [])

let key (o : office) (k : int) : request =
  match o.editing with
  | Writing d when not o.prefix && k <> 24 && k <> 31 -> o.message <- ""; write_key o d k; Continue
  | Cell (c, r, typed) when not o.prefix && k <> 24 -> o.message <- ""; cell_key o c r typed k; Continue
  | Sketch (tool, _) when not o.prefix && k <> 24 -> o.message <- ""; sketch_key o tool k; Continue
  | Painting (_, brush, _) when not o.prefix && k <> 24 && k <> 31 -> o.message <- ""; paint_key o brush k; Continue
  | Naming typed when not o.prefix && k <> 24 -> o.message <- ""; name_key o typed k; Continue
  | _ ->
      let was = o.message in
      o.message <- "";
      if o.prefix then begin
        o.prefix <- false;
        if k = 19 then command o Do_save
        else if k = 3 || k = 17 then (o.message <- was; command o Do_quit)
        else if k = 116 then command o (Do_add "sheet")
        else if k = 100 then command o (Do_add "drawing")
        else if k = 112 then command o (Do_add "paint")
        else (o.message <- "C-x: not a command"; Continue)
      end
      else begin
        if k = 24 then o.prefix <- true
        else if k = 15 then ignore (command o (Do_add "text"))
        else if (k = 8 || k = 127) && o.sel >= 0 then ignore (command o Do_delete)
        else if k = 31 then ignore (command o Do_undo)
        else if k = 7 then (o.sel <- -1; o.message <- "Quit")
        else o.message <- help;
        Continue
      end

(* where the selected box is moved by the left button, its tab above
 * it (its kind written in it, or a sheet's name); where it is resized, its corner *)
let tab_text (b : obj) = if b.called <> "" then b.called else b.kind
let tab (b : obj) = (b.x, b.y - 16, (8 * String.length (tab_text b)) + 8, 16)
let corner (b : obj) = (b.x + b.w - 8, b.y + b.h - 8, 8, 8)

let on_handle (o : office) (x : int) (y : int) : bool =
  o.sel >= 0 && (let b = nth_obj o.page o.sel in inside x y (tab b) || inside x y (corner b))

(* box i grabbed by the mouse at (x, y), to move or to resize *)
let grab (o : office) (i : int) (x : int) (y : int) (resizing : bool) =
  keep o;
  o.drag <- Some (i, x, y, nth_obj o.page i, resizing)

(* the grabbed box, the mouse now at (x, y): moved (its tab kept below
 * the menus), or resized *)
let dragged (o : office) (x : int) (y : int) =
  match o.drag with
  | Some (i, mx, my, was, resizing) when x <> mx || y <> my ->
      let moved = if resizing then { was with w = max 32 (was.w + x - mx); h = max 24 (was.h + y - my) }
        else { was with x = max 0 (was.x + x - mx); y = max (bar_height + 16) (was.y + y - my) } in
      o.page <- replace o.page i (Some moved)
  | _ -> ()

(* (x, y) in drawing b, kept inside it *)
let in_drawing (b : obj) (x : int) (y : int) = (max 0 (min (b.w - 2) (x - b.x)), max 0 (min (b.h - 2) (y - b.y)))

(* The mouse on the page, its buttons b, was before. The mouse is a
 * place, not its history: a drag may be seen as a press and a let go
 * far apart, so the let go counts where it is. *)
let page_mouse (o : office) (was : int) (x : int) (y : int) (b : int) =
  let pressed k = b land k <> 0 && was land k = 0 in
  let i = hit o x y in
  match o.editing with
  | _ when pressed 1 && on_handle o x y ->
      (* the selected box's tab or corner: it is moved or resized *)
      let resizing = inside x y (corner (nth_obj o.page o.sel)) in
      finish o;
      grab o o.sel x y resizing
  | Painting (ink, brush, _) when pressed 1 && i >= 0 && i = o.sel ->
      (* in the paint being edited: a stroke begins, kept for undo *)
      let (c, r) = pixel_at (nth_obj o.page i) x y in
      keep o;
      paint o ink brush c r c r;
      o.editing <- Painting (ink, brush, Some (c, r))
  | Painting (ink, brush, Some (c0, r0)) ->
      (* the stroke goes on to where the mouse is, and ends where it is let go *)
      let (c, r) = pixel_at (nth_obj o.page o.sel) x y in
      paint o ink brush c0 r0 c r;
      o.editing <- Painting (ink, brush, if b land 1 <> 0 then Some (c, r) else None)
  | Writing d when pressed 1 && i >= 0 && i = o.sel ->
      (* in the text being edited: the cursor there, a selection from it *)
      let ob = nth_obj o.page i in
      go_to d (index_at (lay_out (ob.w - 8) d.txt d.sty) d.txt d.sty (x - ob.x - 4) (y - ob.y - 2));
      d.selecting <- true
  | Writing d when d.selecting ->
      (* the selection follows the mouse, to where it is let go *)
      let ob = nth_obj o.page o.sel in
      d.cur <- index_at (lay_out (ob.w - 8) d.txt d.sty) d.txt d.sty (x - ob.x - 4) (y - ob.y - 2);
      if b land 1 = 0 then d.selecting <- false
  | Sketch (tool, _) when pressed 1 && i >= 0 && i = o.sel ->
      (* in the drawing being edited: a stroke begins *)
      let (sx, sy) = in_drawing (nth_obj o.page i) x y in
      o.editing <- Sketch (tool, Some (sx, sy, sx, sy))
  | Sketch (tool, Some (x0, y0, _, _)) ->
      (* the stroke follows the mouse; let go, it is a shape *)
      let (ex, ey) = in_drawing (nth_obj o.page o.sel) x y in
      if b land 1 <> 0 then o.editing <- Sketch (tool, Some (x0, y0, ex, ey))
      else (o.editing <- Sketch (tool, None); draw_stroke o tool (x0, y0, ex, ey))
  | _ ->
  if pressed 1 then begin
    (* a click: the editing ends; in a text box, another begins *)
    finish o;
    o.at <- (x, y);
    o.sel <- i;
    if i >= 0 && (nth_obj o.page i).kind = "text" then edit o i x y true
    else if i >= 0 && (nth_obj o.page i).kind = "sheet" then choose o i x y
    else if i >= 0 && (nth_obj o.page i).kind = "drawing" then o.editing <- Sketch (0, None)
    else if i >= 0 && (nth_obj o.page i).kind = "paint" then o.editing <- Painting (1, 0, None)
  end
  else if pressed 4 || pressed 2 then begin
    (* the right button: the box under it grabbed, by its corner to resize *)
    finish o;
    o.sel <- i;
    if i >= 0 then (let b = nth_obj o.page i in grab o i x y (x >= b.x + b.w - 12 && y >= b.y + b.h - 12))
  end
  else if b <> 0 then dragged o x y
  else begin
    (* let go: a box grabbed and not moved is no change to undo *)
    dragged o x y;
    (match o.drag, o.undo with Some _, p :: rest when p == o.page -> o.undo <- rest | _ -> ());
    o.drag <- None
  end

(* the mouse: the menus' first, then the page's *)
let mouse (o : office) (x : int) (y : int) (b : int) : request =
  let was = o.menu.held in
  match menu_mouse (office_menus o) o.menu x y b with
  | Picked c -> o.message <- ""; command o c
  | Taken -> Continue
  | Ignored -> page_mouse o was x y b; Continue

(*****************************************************************************)
(* The view *)
(*****************************************************************************)

(* A text box: a word for each run of characters of a style on a line,
 * at the line's bottom (a line with a large character is taller); the
 * lines that fit. Being edited, the selection under the words in pale
 * blue, a rectangle a line, and the cursor. *)
let text_view (b : obj) (txt : string) (sty : string) (editing : doc option) : shape list =
  let lay = lay_out (b.w - 8) txt sty and n = String.length txt in
  let fits l = lay.top.(l) + lay.tall.(l) <= b.h - 4 in
  let x0 = b.x + 4 and y0 = b.y + 2 in
  let rec runs i acc =
    if i >= n then acc
    else if txt.[i] = '\n' || not (fits lay.ln.(i)) then runs (i + 1) acc
    else begin
      let j = ref (i + 1) and l = lay.ln.(i) and c = Char.code sty.[i] lsl 8 in
      while !j < n && txt.[!j] <> '\n' && lay.ln.(!j) = l && sty.[!j] = sty.[i] do incr j done;
      runs !j (Move (x0 + lay.px.(i), y0 + lay.top.(l) + lay.tall.(l) - char_height c, Words (black lor c, String.sub txt i (!j - i))) :: acc)
    end in
  let marks = match editing with
    | None -> []
    | Some d ->
        let (a, z) = selection d in
        (* the selection's pieces, a line each: its line, its two ends *)
        let rec pieces i acc =
          if i >= z then acc
          else begin
            let l = lay.ln.(i) and w = if txt.[i] = '\n' then 4 else cw sty i in
            match acc with
            | (l', p, q) :: rest when l' = l && q = lay.px.(i) -> pieces (i + 1) ((l, p, q + w) :: rest)
            | _ -> pieces (i + 1) ((l, lay.px.(i), lay.px.(i) + w) :: acc)
          end in
        let l = lay.ln.(d.cur) in
        List.concat (List.map (fun (l, p, q) -> if fits l then [ Move (x0 + p, y0 + lay.top.(l), Rect (pale_blue, q - p, lay.tall.(l))) ] else []) (pieces a []))
        @ (if fits l then [ Move (x0 + lay.px.(d.cur), y0 + lay.top.(l), Rect (black, 2, lay.tall.(l))) ] else []) in
  marks @ List.rev (runs 0 [])

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

(* a box's frame: blue when it is selected, with its tab above it and a
 * small square at its corner, where the mouse moves it and resizes it *)
let frame (b : obj) (selected : bool) : shape list =
  let c = if selected then blue else grey and x1 = b.x + b.w - 1 and y1 = b.y + b.h - 1 in
  let (tx, ty, tw, th) = tab b in
  [ Move (b.x, b.y, Rect (c, b.w, 1)); Move (b.x, y1, Rect (c, b.w, 1)); Move (b.x, b.y, Rect (c, 1, b.h)); Move (x1, b.y, Rect (c, 1, b.h)) ]
  @ (if selected then [ Move (tx, ty, Rect (c, tw, th)); Move (tx + 4, ty, Words (white, tab_text b)); Move (x1 - 7, y1 - 7, Rect (c, 8, 8)) ] else [])

(* the status line: what the box being edited says (a search, M-x), or
 * the page's message, or the file's name *)
let status (o : office) : shape list =
  let file, width, height = o.where in
  let said = match o.editing with
    | Writing d when o.message = "" ->
        let names = List.filter (fun t -> t <> "") (List.init 4 (fun k -> if d.typing land (1 lsl k) <> 0 then List.nth [ "bold"; "italic"; "underlined"; "large" ] k else "")) in
        "text, typing " ^ (if names = [] then "plain" else String.concat " " names) ^ "; the Format menu, or C-b, Tab, C-u, C-l"
    | Cell (c, r, typed) when o.sel >= 0 ->
        (* the formula bar: the cell, what is being typed in it, or what was *)
        name c r ^ ": " ^ (match typed with Some t -> t ^ "_" | None -> typed_in (nth_obj o.page o.sel).data (name c r))
    | Naming typed when o.message = "" -> "the sheet's name: " ^ typed ^ "_ (Enter gives it, C-g not)"
    | Painting (ink, brush, _) -> "paint: " ^ List.nth paint_names ink ^ (if brush = 0 then ", thin" else ", thick") ^ "; the left button paints; the Paint menu, or a digit"
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
         | Writing d when !i = o.sel -> text_view b d.txt d.sty (Some d)
         | Cell (c, r, _) when !i = o.sel -> sheet_view b (Some (c, r))
         | Sketch (tool, stroke) when !i = o.sel -> drawing_view b tool stroke
         | _ ->
             if b.kind = "text" then (let (t, st) = decode b.data in text_view b t st None)
             else if b.kind = "sheet" then sheet_view b None
             else if b.kind = "drawing" then drawing_view b 0 None
             else if b.kind = "paint" then paint_view b
             else if b.kind = "chart" then chart_view o.page b
             else [ Move (b.x + 4, b.y + 2, Words (black, b.kind ^ "?")) ] in
       Group (frame b (!i = o.sel) @ content)) o.page
  @ [ Group (status o) ] @ menu_view width (office_menus o) o.menu
