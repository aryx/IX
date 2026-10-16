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

(* what is typed on the last line, after a prompt: M-x's command, and
 * the answers some commands ask for *)
type answer = Command | Goto | Replace_from | Replace_to of string

(* the last line's other uses, and the keys the editor gives itself *)
type extra = {
  mutable search : string option;           (* C-s typed: the text looked for *)
  mutable reading : (answer * string) option;   (* a prompt, and what is typed after it *)
  mutable recording : int list option;      (* C-x ( typed: the keys since, the last first *)
  mutable macro : int list;                 (* the last macro, for C-x e *)
  mutable queue : int list;                 (* keys to give back: a macro's, a command's *)
}

(* (three records: tiny-ml makes one of 11 fields at most on tiny-machine) *)
type editor = {
  t : text;
  mutable top : int;             (* the first line shown *)
  mutable killed : string;       (* what C-k took, for C-y *)
  mutable killing : bool;        (* the last key was C-k: the next adds to killed *)
  file : string;
  mutable quitting : bool;       (* a quit was refused: the next is done *)
  mutable message : string;      (* the last line of the screen *)
  mutable prefix : int;          (* C-x or Escape typed, waiting for its key; or 0 *)
  x : extra;
  cols : int;
  rows : int;                    (* the screen: the last two lines are not the text's *)
}

(* what a key asks of the program around the editor *)
type request = Continue | Save | Quit

let create (cols : int) (rows : int) (file : string) (text : string) : editor =
  let first, rest = match String.split_on_char '\n' text with l :: r -> l, r | [] -> "", [] in
  let t = { above = []; line = first; below = rest; col = 0; row = 0; goal = 0; modified = false } in
  { t; top = 0; killed = ""; killing = false; file; quitting = false; message = ""; prefix = 0;
    x = { search = None; reading = None; recording = None; macro = []; queue = [] }; cols; rows }

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
  if k >= 32 && k < 127 then (let sub = sub ^ String.make 1 (Char.chr k) in e.x.search <- Some sub; look e sub (e.t.col - m); true)
  else if k = 19 then (look e sub e.t.col; true)
  else if k = 8 || k = 127 then (e.x.search <- Some (String.sub sub 0 (max 0 (m - 1))); true)
  else (e.x.search <- None; k = 10 || k = 13 || k = 7)

(*****************************************************************************)
(* M-x *)
(*****************************************************************************)

(* the commands by their names in Emacs, each the keys it is: M-x
 * types them. goto-line and replace-string have no key: they are
 * M-x's own (answered) *)
let commands = [
  "forward-char", "\006"; "backward-char", "\002"; "next-line", "\014"; "previous-line", "\016";
  "move-beginning-of-line", "\001"; "move-end-of-line", "\005";
  "scroll-up-command", "\022"; "scroll-down-command", "\027v";
  "beginning-of-buffer", "\027<"; "end-of-buffer", "\027>";
  "delete-char", "\004"; "delete-backward-char", "\127"; "newline", "\n";
  "kill-line", "\011"; "yank", "\025"; "recenter-top-bottom", "\012";
  "isearch-forward", "\019"; "keyboard-quit", "\007";
  "save-buffer", "\024\019"; "save-buffers-kill-terminal", "\024\003";
  "start-kbd-macro", "\024("; "end-kbd-macro", "\024)"; "call-last-kbd-macro", "\024e";
  "execute-extended-command", "\027x";
  "goto-line", ""; "replace-string", "";
]

let prompt = function
  | Command -> "M-x "
  | Goto -> "Goto line: "
  | Replace_from -> "Replace string: "
  | Replace_to from -> "Replace string " ^ from ^ " with: "

let starts (p : string) (s : string) = String.length p <= String.length s && String.sub s 0 (String.length p) = p

(* Tab: what is typed made as long as all the names it starts agree *)
let complete (typed : string) : string =
  match List.filter (starts typed) (List.map fst commands) with
  | [] -> typed
  | first :: rest ->
      let rec common a b i = if i < String.length a && i < String.length b && a.[i] = b.[i] then common a b (i + 1) else i in
      String.sub first 0 (List.fold_left (fun n c -> min n (common first c 0)) (String.length first) rest)

(* s with each from replaced by to_, and how many were *)
let rec replace (from : string) (to_ : string) (s : string) : string * int =
  let i = find from s 0 and m = String.length from in
  if i < 0 then s, 0
  else (let rest, n = replace from to_ (String.sub s (i + m) (String.length s - i - m)) in String.sub s 0 i ^ to_ ^ rest, n + 1)

(* Enter after a prompt: what is typed done *)
let rec answered (e : editor) (what : answer) (typed : string) =
  let t = e.t in
  match what with
  | Command -> (
      match List.assoc_opt typed commands, List.filter (starts typed) (List.map fst commands) with
      | _ when typed = "goto-line" -> e.x.reading <- Some (Goto, "")
      | _ when typed = "replace-string" -> e.x.reading <- Some (Replace_from, "")
      | Some keys, _ -> e.x.queue <- List.init (String.length keys) (fun i -> Char.code keys.[i]) @ e.x.queue
      | None, [ name ] when typed <> "" -> answered e Command name
      | _ -> e.message <- "No command: " ^ typed)
  | Goto -> (
      match int_of_string_opt typed with
      | Some n -> t.goal <- 0; move t (n - 1 - t.row)
      | None -> e.message <- "Not a line: " ^ typed)
  | Replace_from -> if typed = "" then e.message <- "Nothing to replace" else e.x.reading <- Some (Replace_to typed, "")
  | Replace_to from ->
      (* from the cursor to the end: the line's rest, the lines below *)
      let rest, n = replace from typed (after t) in
      let below = List.map (fun l -> replace from typed l) t.below in
      let n = List.fold_left (fun n (_, k) -> n + k) n below in
      if n > 0 then (t.line <- before t ^ rest; t.below <- List.map fst below; t.modified <- true);
      e.message <- "Replaced " ^ string_of_int n ^ " occurrences"

(* a key after a prompt: a character more, Backspace one less, Tab a
 * command's name completed, Enter done, C-g never mind *)
let reading (e : editor) (what : answer) (typed : string) (k : int) =
  let m = String.length typed in
  if k >= 32 && k < 127 then e.x.reading <- Some (what, typed ^ String.make 1 (Char.chr k))
  else if k = 8 || k = 127 then e.x.reading <- Some (what, String.sub typed 0 (max 0 (m - 1)))
  else if k = 9 && what = Command then e.x.reading <- Some (what, complete typed)
  else if k = 7 then (e.x.reading <- None; e.message <- "Quit")
  else if k = 10 || k = 13 then (e.x.reading <- None; answered e what typed)

(*****************************************************************************)
(* Macros *)
(*****************************************************************************)

(* C-x ( C-x ) C-x e. The keys are recorded as they come, C-x ( and
 * the C-x ) that ends them left out, and C-x e gives them back through
 * the queue, read before what is typed: a macro does what its keys
 * did, a save included. C-x e while recording ends the macro first, as
 * in Emacs *)
let macro (e : editor) (k : int) =
  match k, e.x.recording with
  | 40, None -> e.x.recording <- Some []; e.message <- "Defining kbd macro..."
  | 40, Some _ -> e.message <- "Already defining kbd macro"
  | (41 | 101), Some (_ :: _ :: l) ->
      e.x.macro <- List.rev l; e.x.recording <- None;
      if k = 41 then e.message <- "Keyboard macro defined" else e.x.queue <- e.x.macro @ e.x.queue
  | 41, _ -> e.message <- "Not defining kbd macro"
  | _ -> if e.x.macro = [] then e.message <- "No kbd macro has been defined" else e.x.queue <- e.x.macro @ e.x.queue

(* the next key the editor gives itself, before one typed *)
let pending (e : editor) : int option =
  match e.x.queue with k :: rest -> e.x.queue <- rest; Some k | [] -> None

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
  (match e.x.recording with Some l -> e.x.recording <- Some (k :: l) | None -> ());
  (match e.x.reading, e.x.search with
   | Some (what, typed), _ -> reading e what typed k
   | _, Some sub when searching e sub k -> ()
   | _ ->
       let prefix = e.prefix in
       e.prefix <- 0;
       if prefix = 24 then begin
         (* C-x C-s; C-x C-q and C-x C-c; C-x ( ) e, the macros *)
         if k = 19 then request := Save
         else if k = 40 || k = 41 || k = 101 then macro e k
         else if k = 17 || k = 3 then begin
           if t.modified && not quitting then (e.quitting <- true; e.message <- "Not saved: C-x C-s saves, C-x C-q again quits")
           else request := Quit
         end else e.message <- "C-x: not a command"
       end else if prefix = 27 then begin
         (* Escape, then < > v x: Meta *)
         if k = 60 then lines (- t.row)
         else if k = 120 then e.x.reading <- Some (Command, "")
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
       else if k = 19 then e.x.search <- Some ""
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
    "-- " ^ e.file ^ (if t.modified then " (modified)" else "") ^ " -- L" ^ string_of_int (t.row + 1) ^ " C" ^ string_of_int t.col
    ^ (if e.x.recording <> None then " Def " else " ") in
  let mode = if String.length mode < e.cols then mode ^ String.make (e.cols - String.length mode) '-' else String.sub mode 0 e.cols in
  let last =
    match e.x.reading, e.x.search with
    | Some (what, typed), _ -> prompt what ^ typed
    | None, Some sub -> (if e.message = "" then "" else "Failing ") ^ "I-search: " ^ sub
    | None, None -> if e.prefix = 24 then "C-x-" else if e.prefix = 27 then "ESC-" else e.message in
  text @ [ mode; String.sub last 0 (min e.cols (String.length last)) ]

(* where the cursor is on the screen: its column, its line; after a
 * prompt, on the last line *)
let cursor (e : editor) : int * int =
  match e.x.reading with
  | Some (what, typed) -> min (e.cols - 1) (String.length (prompt what ^ typed)), e.rows - 1
  | None -> column e.t.line e.t.col - left e, e.t.row - e.top
