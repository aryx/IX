(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyEditorScreen.mli *)

(*****************************************************************************)
(* The editor *)
(*****************************************************************************)

(* the text is its lines, cut at the cursor's: the ones above it, the
 * nearest first, the cursor's own, the ones below. A key changes the
 * cursor's line, or moves one line from a list to the other *)
type text = {
  mutable above : string list;
  mutable line : string;
  mutable below : string list;
  mutable col : int;             (* the cursor, in its line: 0 to its length *)
  mutable row : int;             (* the cursor's line, from 0: above's length *)
  mutable goal : int;            (* the column C-n and C-p go back to *)
  mutable modified : bool;
}

(* (two records: tiny-ml makes one of 11 fields at most on tiny-machine) *)
type editor = {
  t : text;
  mutable top : int;             (* the first line shown *)
  mutable killed : string;       (* what C-k took, for C-y *)
  mutable killing : bool;        (* the last key was C-k: the next adds to killed *)
  file : string;
  mutable quitting : bool;       (* a quit was refused: the next is done *)
  mutable message : string;      (* the last line of the screen *)
  mutable prefix : int;          (* C-x or Escape typed, waiting for its key; or 0 *)
  mutable search : string option;   (* C-s typed: the text looked for *)
  cols : int;
  rows : int;                    (* the screen: the last two lines are not the text's *)
}

(* what a key asks of the program around the editor *)
type request = Continue | Save | Quit

let create (cols : int) (rows : int) (file : string) (text : string) : editor =
  let first, rest = match String.split_on_char '\n' text with l :: r -> l, r | [] -> "", [] in
  let t = { above = []; line = first; below = rest; col = 0; row = 0; goal = 0; modified = false } in
  { t; top = 0; killed = ""; killing = false; file; quitting = false; message = ""; prefix = 0; search = None; cols; rows }

(* (a text that ends by a newline has an empty last line, which is
 * where one types after it: the lines joined by newlines are the text) *)
let lines (e : editor) : string list = List.rev e.t.above @ (e.t.line :: e.t.below)

let saved (e : editor) = e.t.modified <- false; e.message <- "Wrote " ^ e.file
let say (e : editor) (message : string) = e.message <- message

(*****************************************************************************)
(* Moving *)
(*****************************************************************************)

let up (t : text) =
  match t.above with
  | [] -> false
  | l :: rest -> t.below <- t.line :: t.below; t.line <- l; t.above <- rest; t.row <- t.row - 1; true

let down (t : text) =
  match t.below with
  | [] -> false
  | l :: rest -> t.above <- t.line :: t.above; t.line <- l; t.below <- rest; t.row <- t.row + 1; true

let forward (t : text) = if t.col < String.length t.line then t.col <- t.col + 1 else if down t then t.col <- 0
let backward (t : text) = if t.col > 0 then t.col <- t.col - 1 else if up t then t.col <- String.length t.line

(* n lines down, or up when n is negative; the column the goal, as far
 * as the line goes. (C-v and Escape v move the cursor a screen, and
 * the lines shown with it) *)
let move (t : text) (n : int) =
  for _i = 1 to n do ignore (down t) done;
  for _i = 1 to - n do ignore (up t) done;
  t.col <- min t.goal (String.length t.line)

(*****************************************************************************)
(* Changing *)
(*****************************************************************************)

let before (t : text) = String.sub t.line 0 t.col
let after (t : text) = String.sub t.line t.col (String.length t.line - t.col)

(* a text without a newline, at the cursor *)
let insert (t : text) (s : string) =
  t.line <- before t ^ s ^ after t;
  t.col <- t.col + String.length s;
  t.modified <- true

let newline (t : text) =
  t.above <- before t :: t.above;
  t.line <- after t;
  t.row <- t.row + 1;
  t.col <- 0;
  t.modified <- true

(* the character at the cursor; at a line's end, the line below joined *)
let delete (t : text) =
  if t.col < String.length t.line then begin
    t.line <- before t ^ String.sub t.line (t.col + 1) (String.length t.line - t.col - 1);
    t.modified <- true
  end else
    match t.below with
    | [] -> ()
    | l :: rest -> t.line <- t.line ^ l; t.below <- rest; t.modified <- true

let backspace (t : text) = if t.col > 0 || t.above <> [] then (backward t; delete t)

(* C-k: the rest of the line; at its end, the newline. Several in a
 * row are one text for C-y *)
let kill (e : editor) (again : bool) =
  let t = e.t in
  let took = if t.col < String.length t.line then after t else if t.below = [] then "" else "\n" in
  if took = "\n" then delete t else if took <> "" then (t.line <- before t; t.modified <- true);
  e.killed <- (if again then e.killed ^ took else took);
  e.killing <- true

let yank (e : editor) =
  List.iteri (fun i piece -> if i > 0 then newline e.t; insert e.t piece) (String.split_on_char '\n' e.killed)

(*****************************************************************************)
(* Searching *)
(*****************************************************************************)

(* where sub is in s at from or after; -1 *)
let find (sub : string) (s : string) (from : int) : int =
  let n = String.length s and m = String.length sub in
  let rec same i j = j >= m || (s.[i + j] = sub.[j] && same i (j + 1)) in
  let rec go i = if i + m > n then - 1 else if same i 0 then i else go (i + 1) in
  go (max from 0)

(* the cursor after the next sub, from a column of its line on, then in
 * the lines below; a message when there is none (view says "Failing") *)
let look (e : editor) (sub : string) (from : int) =
  let t = e.t in
  let i = find sub t.line from in
  if i >= 0 then t.col <- i + String.length sub
  else begin
    let rec go n = function [] -> None | l :: rest -> let i = find sub l 0 in if i >= 0 then Some (n, i) else go (n + 1) rest in
    match go 1 t.below with
    | Some (n, i) -> for _i = 1 to n do ignore (down t) done; t.col <- i + String.length sub
    | None -> e.message <- "Failing search: " ^ sub
  end

(* a key while searching: a character more to look for (from where what
 * is found starts), C-s the next one, Backspace a character less; any
 * other key ends the search, and Enter and C-g do nothing more *)
let searching (e : editor) (sub : string) (k : int) : bool =
  let m = String.length sub in
  if k >= 32 && k < 127 then (let sub = sub ^ String.make 1 (Char.chr k) in e.search <- Some sub; look e sub (e.t.col - m); true)
  else if k = 19 then (look e sub e.t.col; true)
  else if k = 8 || k = 127 then (e.search <- Some (String.sub sub 0 (max 0 (m - 1))); true)
  else (e.search <- None; k = 10 || k = 13 || k = 7)

(*****************************************************************************)
(* The keys *)
(*****************************************************************************)

(* a key is a byte: a character, a control character (C-a is 1), and
 * tiny-machine's arrows, 128 to 131: up, down, left, right *)
let key (e : editor) (k : int) : request =
  let t = e.t and again = e.killing and quitting = e.quitting and h = e.rows - 2 in
  e.killing <- false;
  e.quitting <- false;
  e.message <- "";
  let request = ref Continue and vertical = ref false in
  let lines n = vertical := true; move t n in
  (match e.search with
   | Some sub when searching e sub k -> ()
   | _ ->
       let prefix = e.prefix in
       e.prefix <- 0;
       if prefix = 24 then begin
         (* C-x C-s; C-x C-q, and C-x C-c where the system lets it come *)
         if k = 19 then request := Save
         else if k = 17 || k = 3 then begin
           if t.modified && not quitting then (e.quitting <- true; e.message <- "Not saved: C-x C-s saves, C-x C-q again quits")
           else request := Quit
         end else e.message <- "C-x: not a command"
       end else if prefix = 27 then begin
         (* Escape, then < > v *)
         if k = 60 then lines (- t.row)
         else if k = 62 then lines (List.length t.below)
         else if k = 118 then (lines (1 - h); e.top <- max 0 (e.top - (h - 1)))
         else e.message <- "Escape: not a command"
       end
       else if k = 1 then t.col <- 0
       else if k = 5 then t.col <- String.length t.line
       else if k = 6 || k = 131 then forward t
       else if k = 2 || k = 130 then backward t
       else if k = 14 || k = 129 then lines 1
       else if k = 16 || k = 128 then lines (- 1)
       else if k = 22 then (lines (h - 1); e.top <- min (e.top + h - 1) t.row)
       else if k = 4 then delete t
       else if k = 8 || k = 127 then backspace t
       else if k = 10 || k = 13 then newline t
       else if k = 11 then kill e again
       else if k = 25 then yank e
       else if k = 12 then e.top <- max 0 (t.row - h / 2)
       else if k = 19 then e.search <- Some ""
       else if k = 7 then e.message <- "Quit"
       else if k = 24 || k = 27 then e.prefix <- k
       else if k = 9 || (k >= 32 && k < 127) then insert t (String.make 1 (Char.chr k))
       else e.message <- "Not a command");
  if not !vertical then t.goal <- t.col;
  !request

(*****************************************************************************)
(* The screen *)
(*****************************************************************************)

(* a line as it is shown: a tab is the spaces to the next column that
 * is a multiple of 8 *)
let shown (s : string) : string =
  if not (String.contains s '\t') then s
  else begin
    let pieces = String.split_on_char '\t' s in
    List.fold_left (fun acc p -> acc ^ String.make (8 - String.length acc mod 8) ' ' ^ p) (List.hd pieces) (List.tl pieces)
  end

(* the column of the screen where a line's character is *)
let column (s : string) (col : int) : int =
  let rec go i c = if i >= col then c else go (i + 1) (if s.[i] = '\t' then (c / 8 + 1) * 8 else c + 1) in
  go 0 0

(* the lines' first column shown: 0, unless the cursor would be out *)
let left (e : editor) = let c = column e.t.line e.t.col in if c < e.cols then 0 else c - e.cols + 1

let rec take n l = match l with x :: rest when n > 0 -> x :: take (n - 1) rest | _ -> []

(* the screen's lines: the text's that fit (the ones shown follow the
 * cursor), a line that says the file and where the cursor is, and the
 * last one, a message or what is being typed *)
let view (e : editor) : string list =
  let t = e.t and h = e.rows - 2 in
  if t.row < e.top then e.top <- t.row else if t.row >= e.top + h then e.top <- t.row - h + 1;
  let l = left e and y = t.row - e.top in
  let cut s = let s = shown s in let n = String.length s in if l >= n then "" else String.sub s l (min e.cols (n - l)) in
  let text = List.map cut (List.rev (take y t.above) @ (t.line :: take (h - 1 - y) t.below)) in
  let text = text @ List.init (h - List.length text) (fun _ -> "") in
  let mode =
    "-- " ^ e.file ^ (if t.modified then " (modified)" else "") ^ " -- L" ^ string_of_int (t.row + 1) ^ " C" ^ string_of_int t.col ^ " " in
  let mode = if String.length mode < e.cols then mode ^ String.make (e.cols - String.length mode) '-' else String.sub mode 0 e.cols in
  let last =
    match e.search with
    | Some sub -> (if e.message = "" then "" else "Failing ") ^ "I-search: " ^ sub
    | None -> if e.prefix = 24 then "C-x-" else if e.prefix = 27 then "ESC-" else e.message in
  text @ [ mode; String.sub last 0 (min e.cols (String.length last)) ]

(* where the cursor is on the screen: its column, its line *)
let cursor (e : editor) : int * int = column e.t.line e.t.col - left e, e.t.row - e.top
