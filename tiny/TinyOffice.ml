(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyOffice.mli *)

(* The editor's functions this file uses, by names of their own: the
 * office has a create, a key and a view too, and tiny-ml has no
 * modules, one name space for all its files (so: open, and these) *)
open TinyEditorScreen
open TinyLibDraw
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

(* an object of the page: its kind ("text"), its box in pixels, its data *)
type obj = { kind : string; x : int; y : int; w : int; h : int; data : string }

type office = {
  mutable page : obj list;                (* the objects, the bottom one first *)
  mutable undo : obj list list;           (* the pages before, the last first *)
  mutable clean : obj list;               (* the page as it was last saved *)
  mutable sel : int;                      (* the selected object, its place in page; -1 none *)
  mutable editing : editor option;   (* the selected text box, being edited *)
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
  { page; undo = []; clean = page; sel = -1; editing = None; drag = None; at = (16, 16); buttons = 0;
    message = ""; prefix = false; where = (file, width, height) }

let saved (o : office) =
  o.clean <- o.page;
  (match o.editing with Some e -> editor_saved e | None -> ());
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
(* Editing a text box *)
(*****************************************************************************)

(* the edited text put back into its box (a change, for undo, when it is
 * another text) *)
let commit (o : office) =
  match o.editing with
  | Some e when o.sel >= 0 ->
      let b = nth_obj o.page o.sel in
      let data = editor_text e in
      if data <> b.data then (keep o; o.page <- replace o.page o.sel (Some { b with data }))
  | _ -> ()

let finish (o : office) = commit o; o.editing <- None

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
  o.editing <- Some e

(*****************************************************************************)
(* The keys and the mouse *)
(*****************************************************************************)

let help = "C-o new box; click edits; right button moves; C-_ undo"

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

let key (o : office) (k : int) : request =
  match o.editing with
  | Some e -> editing_key o e k
  | None ->
      let was = o.message in
      o.message <- "";
      if o.prefix then begin
        o.prefix <- false;
        if k = 19 then Save
        else if k = 3 || k = 17 then (o.message <- was; quit o)
        else (o.message <- "C-x: not a command"; Continue)
      end
      else begin
        if k = 24 then o.prefix <- true
        else if k = 15 then begin
          (* C-o: a new text box where the last click was *)
          let x, y = o.at in
          keep o;
          o.page <- o.page @ [ { kind = "text"; x; y; w = 200; h = 84; data = "" } ];
          edit o (List.length o.page - 1) x y
        end
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
  if pressed 1 then begin
    (* a click: the editing ends; in a text box, another begins *)
    finish o;
    o.at <- (x, y);
    let i = hit o x y in
    o.sel <- i;
    if i >= 0 && (nth_obj o.page i).kind = "text" then edit o i x y
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
    | Some e -> (match List.rev (editor_view e) with last :: _ -> last | [] -> "")
    | None -> "" in
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
         | Some e when !i = o.sel -> edit_view b e
         | _ -> if b.kind = "text" then text_view b else [ Move (b.x + 4, b.y + 2, Words (black, b.kind ^ "?")) ] in
       Group (frame b (!i = o.sel) @ content)) o.page
  @ [ Group (status o) ]
