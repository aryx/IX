(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOfficeSheet.mli *)
open TinyLibPlayground
open TinyOfficeModel

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

let name (c : int) (r : int) =
  String.make 1 (Char.chr (97 + c)) ^ string_of_int (r + 1)

(* the cells typed in: their names and what was typed *)
let cells (data : string) : (string * string) list =
  List.concat_map (fun l ->
    match String.index_opt l ' ' with
    | Some i ->
      [ String.sub l 0 i, String.sub l (i + 1) (String.length l - i - 1) ]
    | None -> []) (String.split_on_char '\n' data)

let typed_in (data : string) (n : string) =
  match List.assoc_opt n (cells data) with Some s -> s | None -> ""

(* the data with what is typed in cell n changed ("": the cell emptied) *)
let set_cell (data : string) (n : string) (input : string) : string =
  let others = List.filter (fun (m, _) -> m <> n) (cells data) in
  String.concat ""
    (List.map (fun (m, s) -> m ^ " " ^ s ^ "\n")
       (if input = "" then others else others @ [ n, input ]))

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

let peek_char (p : reader) =
  if p.pos < String.length p.src then p.src.[p.pos] else '\000'
let rec blanks (p : reader) =
  if peek_char p = ' ' then (p.pos <- p.pos + 1; blanks p)
let digit (c : char) = c >= '0' && c <= '9'
let expect (p : reader) (c : char) =
  blanks p;
  if peek_char p = c then p.pos <- p.pos + 1 else raise (Bad "SYNTAX")
let rec number (p : reader) (k : int) =
  if digit (peek_char p) then
    (let d = Char.code (peek_char p) - 48 in
     p.pos <- p.pos + 1; number p ((k * 10) + d))
  else k

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
  match v with
  | Num k -> k
  | Str "" -> 0
  | Str _ -> raise (Bad "TEXT")
  | Err e -> raise (Bad e)

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
  else if c = '/' then
    (p.pos <- p.pos + 1;
     let d = factor p in
     if d = 0 then raise (Bad "DIV0") else product p (v / d))
  else v

and factor (p : reader) : int =
  blanks p;
  let c = peek_char p in
  if digit c then number p 0
  else if c = '-' then (p.pos <- p.pos + 1; - (factor p))
  else if c = '(' then
    (p.pos <- p.pos + 1; let v = expr p in expect p ')'; v)
  else if p.pos + 4 <= String.length p.src
          && String.sub p.src p.pos 4 = "sum(" then begin
    p.pos <- p.pos + 4;
    let c0, r0 = cell p in
    expect p ':';
    let c1, r1 = cell p in
    expect p ')';
    let total = ref 0 in
    for c = min c0 c1 to max c0 c1 do
      for r = min r0 r1 to max r0 r1 do
        total := !total + int_of (p.fetch (name c r))
      done
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
        let input =
          match List.assoc_opt n typed with Some s -> s | None -> "" in
        let v =
          if input <> "" && input.[0] = '=' then
            formula (String.sub input 1 (String.length input - 1)) value
          else
            match int_of_string_opt input with
            | Some k -> Num k
            | None -> Str input in
        Hashtbl.replace memo n v;
        v in
  value


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

(* what is typed in cell (c, r) of the selected sheet put in it *)
let put_cell (o : office) (c : int) (r : int) (t : string) =
  change o (set_cell (List.nth o.page o.sel).data (name c r) t);
  o.editing <- Cell (c, r, None)

(* the cell of box i under (x, y): chosen, nothing typed yet *)
let choose (o : office) (i : int) (x : int) (y : int) =
  let b = List.nth o.page i in
  let c = (x - sheet_left b) / cell_w and r = (y - sheet_top b) / 16 in
  o.sel <- i;
  o.editing <-
    (if x >= sheet_left b && y >= sheet_top b && c < sheet_cols b
        && r < sheet_rows b then Cell (c, r, None)
     else Nothing)

(* A key at a cell, as in a spreadsheet: a character starts what is
 * typed there, which replaces what was; Enter puts it in the cell and
 * goes down; an arrow puts it and goes that way; C-g forgets it.
 * Enter on a cell where nothing is typed brings back what was typed
 * there, to change it; Backspace there empties the cell. *)
let cell_key (o : office) (c : int) (r : int) (typed : string option)
    (k : int) =
  let b = List.nth o.page o.sel in
  let move dc dr =
    o.editing <-
      Cell (max 0 (min 25 (c + dc)), max 0 (min 98 (r + dr)), None) in
  let arrow () =
    if k = 128 then move 0 (-1)
    else if k = 129 then move 0 1
    else if k = 130 then move (-1) 0
    else move 1 0 in
  match typed with
  | None ->
      if k >= 32 && k < 127 then
        o.editing <- Cell (c, r, Some (String.make 1 (Char.chr k)))
      else if k = 10 || k = 13 then
        o.editing <- Cell (c, r, Some (typed_in b.data (name c r)))
      else if k >= 128 && k <= 131 then arrow ()
      else if k = 8 || k = 127 then change o (set_cell b.data (name c r) "")
      else if k = 7 then o.editing <- Nothing
      else o.message <- "a cell: type, Enter, the arrows; C-g"
  | Some t ->
      if k >= 32 && k < 127 then
        o.editing <- Cell (c, r, Some (t ^ String.make 1 (Char.chr k)))
      else if k = 8 || k = 127 then
        o.editing <-
          Cell (c, r, Some (if t = "" then ""
                            else String.sub t 0 (String.length t - 1)))
      else if k = 10 || k = 13 then (put_cell o c r t; move 0 1)
      else if k >= 128 && k <= 131 then (put_cell o c r t; arrow ())
      else if k = 7 then o.editing <- Cell (c, r, None)


(*****************************************************************************)
(* The view *)
(*****************************************************************************)

(* A sheet: the columns' letters and the rows' numbers in grey, the
 * grid's lines, each cell's value, a number at the cell's right, text
 * at its left (cut at the cell's edge), an error as #WHY; the chosen
 * cell in a blue frame. The values are computed again at each view: a
 * sheet is small, and it has no other place for them. *)
let sheet_view (b : obj) (chosen : (int * int) option) : shape list =
  let value = values b.data
  and ncols = min 26 (sheet_cols b)
  and nrows = min 99 (sheet_rows b) in
  let x0 = sheet_left b and y0 = sheet_top b in
  let heads =
    List.init ncols (fun c ->
      Move (x0 + (c * cell_w) + 28, b.y + 1,
            Words (grey, String.make 1 (Char.chr (97 + c)))))
    @ List.init nrows (fun r ->
        let n = string_of_int (r + 1) in
        Move (b.x + 2 + (8 * (2 - String.length n)), y0 + (16 * r),
              Words (grey, n))) in
  let lines =
    List.init (ncols + 1) (fun c ->
      Move (x0 + (c * cell_w) - 1, b.y + 1, Rect (light_grey, 1, b.h - 2)))
    @ List.init (nrows + 1) (fun r ->
        Move (b.x + 1, y0 + (16 * r) - 1, Rect (light_grey, b.w - 2, 1))) in
  let shown c r =
    let n = name c r in
    match (if typed_in b.data n = "" then Str "" else value n) with
    | Str "" -> []
    | v ->
        let t, right =
          match v with
          | Num k -> string_of_int k, true
          | Str t -> t, false
          | Err e -> "#" ^ e, false in
        let t = if String.length t > 7 then String.sub t 0 7 else t in
        let x =
          if right then x0 + (c * cell_w) + cell_w - 4 - (8 * String.length t)
          else x0 + (c * cell_w) + 2 in
        [ Move (x, y0 + (16 * r),
                Words ((match v with Err _ -> 160 | _ -> black), t)) ] in
  let cells_shown =
    List.concat_map (fun c ->
      List.concat_map (fun r -> shown c r) (List.init nrows (fun r -> r)))
      (List.init ncols (fun c -> c)) in
  let frame = match chosen with
    | Some (c, r) when c < ncols && r < nrows ->
        let x = x0 + (c * cell_w) - 1 and y = y0 + (16 * r) - 1 in
        [ Move (x, y, Rect (blue, cell_w + 1, 2));
          Move (x, y + 15, Rect (blue, cell_w + 1, 2));
          Move (x, y, Rect (blue, 2, 17));
          Move (x + cell_w - 1, y, Rect (blue, 2, 17)) ]
    | _ -> [] in
  lines @ heads @ cells_shown @ frame
