(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Ixdoc.mli *)

open Ixdoc_syntax

(* a line and its number in the file *)
type line = int * string

type t = {
  paper : bool;
  load : string -> string option;
  (* \title{name}{section} was read: a manual page, with its look *)
  mutable manual : bool;
  mutable header : string * string * string;
  mutable said : (int * string) list;
  (* the line being read: where a complaint is *)
  mutable at : int;
  (* \newcommand's: a name and its text *)
  mutable commands : (string * string) list;
  (* \label's: a name, whether it is a figure's, and what \ref writes
   * (the figure's number, the section's title) *)
  mutable labels : (string * (bool * string)) list;
  mutable notes : int;
  mutable figures : int;
  (* the footnotes of the paragraph being read, the last first *)
  mutable feet : Doc.block list;
  (* a filled text is being read: a line's end is a space *)
  mutable filled : bool;
}

let mono : Doc.style = { font = Doc.Mono; size = 0; shift = 0 }
let bold : Doc.style = { font = Doc.Bold; size = 0; shift = 0 }

(* the document's lengths are in ens, the source's in a terminal's
 * columns, ten to the inch: 1.44 ens of a text of 10 points *)
let cols (t : t) (n : float) : float = if t.paper then n *. 1.44 else n

(* what a blank line is: a line on a terminal, less on paper (the
 * manual's 0.4, a paper's 0.3) *)
let gap (t : t) : float = if not t.paper then 1. else if t.manual then 0.4 else 0.3

let say (t : t) (what : string) = t.said <- (t.at, what) :: t.said

let para (fill : bool) (body : Doc.inline list) : Doc.block =
  let p : Doc.par = { fill; first = 0.; short = 0.; tabs = []; center = false; body } in
  Doc.Para p

(* ---------------------------------------------------------------- *)
(* A line's text *)
(* ---------------------------------------------------------------- *)

let rec inlines (t : t) (style : Doc.style) (s : string) : Doc.inline list =
  let out = ref [] and b = Buffer.create 64 in
  let flush () = if Buffer.length b > 0 then begin out := Doc.Text (style, Buffer.contents b) :: !out; Buffer.clear b end in
  let add (l : Doc.inline list) = flush (); out := List.rev_append l !out in
  let n = String.length s in
  let rec go (i : int) =
    if i < n then begin
      let c = s.[i] in
      if c = '\\' && i + 1 < n && is_letter s.[i + 1] then begin
        let name, options, args, stop = command_at s i in
        add (command t style name options args); go stop
      end
      else if c = '\\' && i + 1 < n && s.[i + 1] = '\n' then begin add [ Doc.Break ]; go (i + 2) end
      else if c = '\\' && i + 1 < n && Char.code s.[i + 1] < 128 then begin Buffer.add_char b s.[i + 1]; go (i + 2) end
      else if c = '`' then begin
        let run = ref 0 in
        while i + !run < n && s.[i + !run] = '`' do incr run done;
        let ticks = String.make !run '`' in
        let from = i + !run in
        (* (the same number of back quotes closes it) *)
        let rec find (j : int) : int option =
          if j + !run > n then None
          else if String.sub s j !run = ticks && (j + !run >= n || s.[j + !run] <> '`') && s.[j - 1] <> '`' then Some j
          else find (j + 1) in
        (match if from < n then find (from + 1) else None with
         | Some j ->
             let inner = String.map (fun ch -> if ch = '\n' then ' ' else ch) (String.sub s from (j - from)) in
             (* (two of them: a space on each side is not the text's) *)
             let inner = if !run > 1 && String.length inner > 2 && inner.[0] = ' ' && ends_with inner ' ' then String.sub inner 1 (String.length inner - 2) else inner in
             add [ Doc.Text ({ style with font = Doc.Mono }, inner) ]; go (j + !run)
         | None -> Buffer.add_string b ticks; go from)
      end
      else if (c = '*' || c = '_') && i + 1 < n then begin
        let k = if s.[i + 1] = c then 2 else 1 in
        let opens = i + k < n && s.[i + k] <> ' ' && s.[i + k] <> '\n' && (c = '*' || i = 0 || not (is_alnum s.[i - 1])) in
        match if opens then find_close s (i + k) c k else None with
        | Some j ->
            add (inlines t { style with font = (if k = 2 then Doc.Bold else Doc.Italic) } (String.sub s (i + k) (j - i - k)));
            go (j + k)
        | None -> Buffer.add_string b (String.make k c); go (i + k)
      end
      else if c = '!' && i + 1 < n && s.[i + 1] = '[' then begin
        (* a picture in a file: its words in its place, and said *)
        match closing s (i + 1) '[' ']' with
        | Some j when j + 1 < n && s.[j + 1] = '(' ->
            let e = match String.index_from_opt s (j + 1) ')' with Some e -> e | None -> n - 1 in
            say t ("![" ^ String.sub s (i + 2) (j - i - 2) ^ "] (a picture in a file)");
            add (inlines t style (String.sub s (i + 2) (j - i - 2))); go (e + 1)
        | _ -> Buffer.add_char b c; go (i + 1)
      end
      else if c = '[' then begin
        (* [words](where): the words; a terminal and paper go nowhere *)
        match closing s i '[' ']' with
        | Some j when j + 1 < n && s.[j + 1] = '(' ->
            let e = match closing s (j + 1) '(' ')' with Some e -> e | None -> n - 1 in
            add (inlines t style (String.sub s (i + 1) (j - i - 1))); go (e + 1)
        | _ -> Buffer.add_char b c; go (i + 1)
      end
      else if c = '<' && i + 8 < n && (String.sub s (i + 1) 7 = "http://" || String.sub s (i + 1) 8 = "https://") then begin
        match String.index_from_opt s i '>' with
        | Some j -> add [ Doc.Text ({ style with font = Doc.Mono }, String.sub s (i + 1) (j - i - 1)) ]; go (j + 1)
        | None -> Buffer.add_char b c; go (i + 1)
      end
      else if c = '$' && i + 1 < n && s.[i + 1] <> ' ' && s.[i + 1] <> '\n' then begin
        (* $mathematics$: closed after what is not a space and before
         * what is not a digit (a price is not an equation) *)
        let rec find (j : int) : int option =
          if j >= n || s.[j] = '\n' then None
          else if s.[j] = '$' && s.[j - 1] <> ' ' && (j + 1 >= n || not (is_digit s.[j + 1])) then Some j
          else find (j + 1) in
        match find (i + 2) with
        | Some j -> add [ Doc.Text ({ style with font = Doc.Italic }, String.sub s (i + 1) (j - i - 1)) ]; go (j + 1)
        | None -> Buffer.add_char b c; go (i + 1)
      end
      else if c = '\n' && t.filled then begin
        Buffer.add_char b ' ';
        let j = ref (i + 1) in
        while !j < n && s.[!j] = ' ' do incr j done;
        go !j
      end
      else begin Buffer.add_char b c; go (i + 1) end
    end in
  go 0; flush (); List.rev !out

(* \name[options]{text} in a line: what it is put for *)
and command (t : t) (style : Doc.style) (name : string) (options : string) (args : string list) : Doc.inline list =
  let arg (k : int) : string = match List.nth_opt args k with Some a -> a | None -> "" in
  let within (st : Doc.style) : Doc.inline list = inlines t st (arg 0) in
  match name with
  | "emph" -> within { style with font = Doc.Italic }
  | "strong" -> within { style with font = Doc.Bold }
  | "code" -> within { style with font = Doc.Mono }
  | "roman" -> within { style with font = Doc.Roman }
  | "small" -> within { style with size = style.size - 1 }
  | "big" -> within { style with size = style.size + 1 }
  | "up" -> within { style with shift = style.shift + 1 }
  | "down" -> within { style with shift = style.shift - 1 }
  (* another page of the manual: rc(1) *)
  | "man" -> inlines t { style with font = Doc.Italic } (arg 0) @ [ Doc.Text (style, "(" ^ arg 1 ^ ")") ]
  | "label" -> []
  | "ref" ->
      (match List.assoc_opt (arg 0) t.labels with
       | Some (true, number) -> [ Doc.Text (style, number) ]
       | Some (false, title) -> [ Doc.Text ({ style with font = Doc.Italic }, title) ]
       | None -> say t ("\\ref{" ^ arg 0 ^ "} (no such label)"); [ Doc.Text (style, "??") ])
  | "cite" -> [ Doc.Text (style, "[" ^ arg 0 ^ "]") ]
  | "footnote" ->
      (* its number where it is said, a size smaller and half a line
       * up; its text after the paragraph, for the sheet's foot *)
      t.notes <- t.notes + 1;
      let number = string_of_int t.notes in
      let filled = t.filled in
      t.filled <- true;
      let text = inlines t Doc.plain (arg 0) in
      t.filled <- filled;
      t.feet <- Doc.Footnote [ para true (Doc.Text (Doc.plain, number ^ ". ") :: text) ] :: t.feet;
      [ Doc.Text ({ style with size = style.size - 2; shift = style.shift + 1 }, number) ]
  | _ ->
      (match List.assoc_opt name t.commands with
       | Some body -> inlines t style (substitute body args)
       (* a name that is not known: with a text, said, and the text
        * written; alone, the backslash and the letters as they are
        * (a \n in a sentence about C) *)
       | None when args = [] && options = "" -> [ Doc.Text (style, "\\" ^ name) ]
       | None ->
           say t ("\\" ^ name ^ (if List.mem name block_commands then " (in a line: it starts one)" else ""));
           List.concat_map (fun a -> inlines t style a) args)

(* ---------------------------------------------------------------- *)
(* The lines *)
(* ---------------------------------------------------------------- *)

(* the lines that are an item's, after its first: those set in, and
 * the blank ones between them; and the lines left *)
let inside (least : int) (col : int) (lines : line list) : line list * line list =
  let rec take (acc : line list) (blanks : line list) (ls : line list) : line list * line list =
    match ls with
    | (n, r) :: more when blank r -> take acc ((n, "") :: blanks) more
    | (n, r) :: more when indent_of r >= least -> take ((n, drop r (min (indent_of r) col)) :: (blanks @ acc)) [] more
    | _ -> (List.rev acc, List.rev_append blanks ls) in
  take [] [] lines

(* a table's row: what is between its bars *)
let cells_of (s : string) : string list =
  let s = String.trim s in
  let n = String.length s in
  let out = ref [] and b = Buffer.create 32 in
  let rec go (i : int) (code : bool) =
    if i < n then
      if s.[i] = '\\' && i + 1 < n && s.[i + 1] = '|' then begin Buffer.add_char b '|'; go (i + 2) code end
      else if s.[i] = '`' then begin Buffer.add_char b '`'; go (i + 1) (not code) end
      else if s.[i] = '|' && not code then begin out := String.trim (Buffer.contents b) :: !out; Buffer.clear b; go (i + 1) code end
      else begin Buffer.add_char b s.[i]; go (i + 1) code end in
  go (if n > 0 && s.[0] = '|' then 1 else 0) false;
  if String.trim (Buffer.contents b) <> "" then out := String.trim (Buffer.contents b) :: !out;
  List.rev !out

(* |:---|--:|: each column's side *)
let aligns_of (cells : string list) : Doc.align list option =
  let one (c : string) : Doc.align option =
    let n = String.length c in
    if n = 0 || not (String.contains c '-') then None
    else begin
      let ok = ref true in
      String.iteri (fun i ch -> if not (ch = '-' || (ch = ':' && (i = 0 || i = n - 1))) then ok := false) c;
      if not !ok then None
      else if c.[0] = ':' && c.[n - 1] = ':' then Some Doc.Center
      else if c.[n - 1] = ':' then Some Doc.Right
      else Some Doc.Left
    end in
  let l = List.map one cells in
  if l <> [] && List.for_all (fun a -> a <> None) l then Some (List.map (fun a -> match a with Some a -> a | None -> Doc.Left) l) else None

let table (t : t) (rows : string list) : Doc.table =
  let rows = List.map cells_of rows in
  let head, aligns, data =
    match rows with
    | h :: a :: rest -> (match aligns_of a with Some al -> (Some h, al, rest) | None -> (None, [], rows))
    | _ -> (None, [], rows) in
  let count = List.fold_left (fun n r -> max n (List.length r)) 0 rows in
  (* a column of long texts is filled in what the line has left, when
   * the table would not fit on it *)
  let longest = Array.make (max 1 count) 0 in
  List.iter (fun r -> List.iteri (fun k c -> if k < count then longest.(k) <- max longest.(k) (Utf8.length c)) r) (match head with Some h -> h :: data | None -> data);
  let total = Array.fold_left (fun s w -> s + w) (3 * (count - 1)) longest in
  let room = if t.manual then 60 else 60 in
  let filled (k : int) : bool = total > room && longest.(k) > room / (count + 1) in
  (* (what the short columns leave, shared between the long ones) *)
  let long = ref 0 and short = ref (3 * (count - 1)) in
  Array.iteri (fun k w -> if filled k then incr long else short := !short + w) longest;
  let share = if !long = 0 then 0 else max 10 ((room - !short) / !long) in
  let row (style : Doc.style) (r : string list) : Doc.table_row =
    Doc.Cells (List.mapi (fun k c ->
      let align = match List.nth_opt aligns k with Some a -> a | None -> Doc.Left in
      let cell : Doc.cell = { align = (if filled k then Doc.Left else align); span = 1; filled = filled k; body = inlines t style c } in
      cell) r) in
  t.filled <- true;
  let empty = match head with Some h -> List.for_all (fun c -> c = "") h | None -> true in
  { centered = false; boxed = false; widths = List.init count (fun k -> if filled k then cols t (float_of_int share) else 0.);
    rows = (match head with Some h when not empty -> [ row bold h; Doc.Rule ] | _ -> []) @ List.map (row Doc.plain) data }

(* a program's lines, as they are *)
let verbatim (t : t) (lines : string list) : Doc.block =
  let body = List.concat (List.mapi (fun k l -> (if k > 0 then [ Doc.Break ] else []) @ (if l = "" then [] else [ Doc.Text (mono, l) ])) lines) in
  let stop = if t.paper then 9.6 else 8. in
  let p : Doc.par = { fill = false; first = 0.; short = 0.; tabs = List.init 20 (fun k -> stop *. float_of_int (k + 1)); center = false; body } in
  Doc.Para p

let rec blocks (t : t) (nested : bool) (lines : line list) : Doc.block list =
  let out = ref [] and space = ref false in
  let emit (b : Doc.block) =
    if !space && (nested || !out <> []) then out := Doc.Space (gap t) :: !out;
    space := false; out := b :: !out in
  let paragraph (ls : line list) =
    t.filled <- true;
    let text = String.concat "\n" (List.map (fun ((_, r) : line) -> String.trim r) ls) in
    (* (a backslash alone: a paragraph of nothing) *)
    emit (para true (if text = "\\" then [] else inlines t Doc.plain text));
    out := t.feet @ !out; t.feet <- [] in
  let rec go (lines : line list) =
    match lines with
    | [] -> ()
    | (num, raw) :: rest ->
        t.at <- num;
        let ind = indent_of raw in
        let s = drop raw ind in
        (match classify raw with
         | Blank -> space := true; go rest
         | Code ->
             let more, rest = inside 4 4 rest in
             emit (Doc.Indent (cols t 4., [ verbatim t (drop raw 4 :: List.map snd more) ])); go rest
         | Fence (ticks, word) ->
             let rec take (acc : string list) (ls : line list) : string list * line list =
               match ls with
               | [] -> (List.rev acc, [])
               | (_, r) :: more ->
                   let r' = String.trim r in
                   if String.length r' >= String.length ticks && String.sub r' 0 (String.length ticks) = ticks && blank (drop r' (String.length ticks)) && r'.[String.length r' - 1] = '`' then (List.rev acc, more)
                   else take (drop r (min ind (indent_of r)) :: acc) more in
             let body, rest = take [] rest in
             (match word with
              | "pic" ->
                  (match Pic.read t.load 0. (fun w -> t.filled <- true; inlines t Doc.plain w) (String.concat "\n" body) with
                   | Ok p -> emit (Doc.Picture p)
                   | Error why -> say t ("```pic (a picture, " ^ why ^ ")"))
              | "eqn" -> say t "```eqn (an equation)"; emit (verbatim t body)
              | "lines" ->
                  t.filled <- false;
                  emit (para false (List.concat (List.mapi (fun k l -> (if k > 0 then [ Doc.Break ] else []) @ inlines t Doc.plain l) body)))
              | _ -> emit (verbatim t body));
             go rest
         | Head (level, text) ->
             t.filled <- true;
             (* (what a \label at its end leaves: no space there) *)
             let rec ended (l : Doc.inline list) : Doc.inline list =
               match l with
               | [ Doc.Text (st, w) ] -> let n = ref (String.length w) in while !n > 0 && w.[!n - 1] = ' ' do decr n done; if !n = 0 then [] else [ Doc.Text (st, String.sub w 0 !n) ]
               | x :: more -> x :: ended more
               | [] -> [] in
             emit (Doc.Heading (level, ended (inlines t bold text))); go rest
         | Row ->
             let rec take (acc : string list) (ls : line list) : string list * line list =
               match ls with
               | (_, r) :: more when classify r = Row -> take (r :: acc) more
               | _ -> (List.rev acc, ls) in
             let rows, rest = take [ raw ] rest in
             emit (Doc.Table (table t rows)); go rest
         | Quote ->
             let strip (r : string) : string = let r = drop (drop r (indent_of r)) 1 in if r <> "" && r.[0] = ' ' then drop r 1 else r in
             let rec take (acc : line list) (ls : line list) : line list * line list =
               match ls with
               | (n, r) :: more when classify r = Quote -> take ((n, strip r) :: acc) more
               | _ -> (List.rev acc, ls) in
             let inner, rest = take [ (num, strip raw) ] rest in
             emit (Doc.Indent (cols t 5., blocks t true inner)); go rest
         | Item (mark, col) ->
             let more, rest = inside (ind + 2) col rest in
             let body = blocks t true ((num, drop raw col) :: more) in
             emit (Doc.Tagged { tag = [ Doc.Text (Doc.plain, mark) ]; width = cols t (float_of_int (col - ind)); body }); go rest
         | Command name -> go (command_block num s name rest)
         | Html -> say t (s ^ " (HTML)"); go rest
         (* (a colon with no term before it) *)
         | Define _ | Words ->
             let continues (r : string) : bool =
               match classify r with
               | Words | Code -> true
               | Item (mark, _) -> is_digit mark.[0] && mark <> "1." && mark <> "1)"
               | _ -> false in
             let rec take (acc : line list) (ls : line list) : line list * line list =
               match ls with
               | (n, r) :: more when continues r -> take ((n, r) :: acc) more
               | _ -> (acc, ls) in
             let reversed, rest = take [ (num, raw) ] rest in
             (match (rest, reversed) with
              | (dnum, d) :: after, (_, term) :: before when (match classify d with Define _ -> true | _ -> false) ->
                  (* the last line is a term, what follows the colon
                   * its text: a paragraph that hangs from it *)
                  if before <> [] then paragraph (List.rev before);
                  let col = match classify d with Define c -> c | _ -> 4 in
                  let more, rest = inside 1 col after in
                  t.filled <- true;
                  let tag = inlines t Doc.plain (String.trim term) in
                  let body = blocks t true ((dnum, drop d col) :: more) in
                  emit (Doc.Tagged { tag; width = cols t (float_of_int (col - indent_of d)); body }); go rest
              | _ -> paragraph (List.rev reversed); go rest))
  (* a line that starts with \name: its text is on the line, or is the
   * lines after a { that ends it, to a } alone on its line *)
  and command_block (num : int) (s : string) (name : string) (rest : line list) : line list =
    let s = String.trim s in
    let long = ends_with s '{' in
    let _, options, args, _ = command_at (if long then String.sub s 0 (String.length s - 1) else s) 0 in
    let body, rest =
      if not long then ((match args with [] -> [] | _ -> [ (num, List.nth args (List.length args - 1)) ]), rest)
      else begin
        let rec take (acc : line list) (depth : int) (fenced : string) (ls : line list) : line list * line list =
          match ls with
          | [] -> (List.rev acc, [])
          | (n, r) :: more ->
              let r' = String.trim r in
              if fenced <> "" then take ((n, r) :: acc) depth (if r' = fenced then "" else fenced) more
              else (match classify r with
                    | Fence (ticks, _) -> take ((n, r) :: acc) depth ticks more
                    | _ ->
                        if r' = "}" then (if depth = 0 then (List.rev acc, more) else take ((n, r) :: acc) (depth - 1) "" more)
                        else take ((n, r) :: acc) (if ends_with r' '{' && r'.[0] = '\\' then depth + 1 else depth) "" more) in
        take [] 0 "" rest
      end in
    let arg (k : int) : string = match List.nth_opt args k with Some a -> a | None -> "" in
    let number (default : float) : float = match float_of_string_opt (String.trim options) with Some v -> v | None -> default in
    let centered (bs : Doc.block list) : Doc.block list =
      List.map (fun (b : Doc.block) -> match b with Doc.Para p -> Doc.Para { p with center = true } | _ -> b) bs in
    t.filled <- true;
    (match name with
     | "title" when List.length args >= 2 ->
         let title = arg 0 ^ "(" ^ arg 1 ^ ")" in
         t.manual <- true; t.header <- (title, "", title)
     | "title" -> emit (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = inlines t { bold with size = 2 } (arg 0) })
     | "author" -> emit (Doc.Para { fill = true; first = 0.; short = 0.; tabs = []; center = true; body = inlines t { Doc.plain with font = Doc.Italic } (arg 0) })
     | "newcommand" -> t.commands <- ((let a = arg 0 in if a <> "" && a.[0] = '\\' then drop a 1 else a), arg 1) :: t.commands
     | "include" ->
         (match t.load (arg 0) with
          | Some text -> List.iter emit (blocks t nested (List.mapi (fun k l -> (k + 1, l)) (String.split_on_char '\n' text)))
          | None -> say t ("\\include{" ^ arg 0 ^ "} (no such file)"))
     | "space" -> out := Doc.Space (number 1.) :: !out
     | "keep" -> emit (Doc.Keep (blocks t true body))
     | "center" -> List.iter emit (centered (blocks t nested body))
     | "indent" -> emit (Doc.Indent (cols t (number 5.), blocks t true body))
     | "footnote" -> emit (Doc.Footnote (blocks t true body))
     | "figure" ->
         (* what it shows, then its legend: the last paragraph *)
         t.figures <- t.figures + 1;
         let label = Doc.Text (bold, "Figure " ^ string_of_int t.figures ^ ". ") in
         let rec legend (bs : Doc.block list) : Doc.block list =
           match bs with
           | [ Doc.Para p ] -> [ Doc.Para { p with center = true; body = label :: p.body } ]
           | b :: more -> b :: legend more
           | [] -> [] in
         emit (Doc.Keep (legend (blocks t true body)))
     | _ -> ());
    rest in
  go lines; List.rev !out

(* a first pass, for a \ref that is before its \label: each label
 * with the heading it is under, or the number of the figure it is
 * in *)
let labels (t : t) (lines : string list) =
  let fenced = ref "" and under = ref (false, "") and figures = ref 0 in
  let find (s : string) (sub : string) (from : int) : int option =
    let n = String.length s and m = String.length sub in
    let rec go (i : int) : int option = if i + m > n then None else if String.sub s i m = sub then Some i else go (i + 1) in
    go from in
  List.iter (fun raw ->
    let s = String.trim raw in
    if !fenced <> "" then (if s = !fenced then fenced := "")
    else
      match classify raw with
      | Fence (ticks, _) -> fenced := ticks
      | kind ->
          let named (name : string) = t.labels <- (name, !under) :: t.labels in
          (match kind with
           | Head (_, text) ->
               let text = match find text "\\label{" 0 with Some i -> String.trim (String.sub text 0 i) | None -> text in
               t.filled <- true;
               under := (false, Doc.words (inlines t Doc.plain text))
           | Command "figure" ->
               incr figures; under := (true, string_of_int !figures);
               (match find s "label=" 0 with
                | Some i ->
                    let j = ref (i + 6) in
                    while !j < String.length s && s.[!j] <> ']' && s.[!j] <> ',' do incr j done;
                    named (String.sub s (i + 6) (!j - i - 6))
                | None -> ())
           | _ -> ());
          let rec all (from : int) =
            match find s "\\label{" from with
            | Some i -> (match String.index_from_opt s i '}' with Some e -> named (String.sub s (i + 7) (e - i - 7)); all e | None -> ())
            | None -> () in
          all 0) lines;
  t.said <- []

let read (paper : bool) (load : string -> string option) (source : string) : Doc.t * (int * string) list =
  let t = { paper; load; manual = false; header = ("", "", ""); said = []; at = 0; commands = []; labels = []; notes = 0; figures = 0; feet = []; filled = true } in
  let lines = String.split_on_char '\n' source in
  labels t lines;
  let body = blocks t false (List.mapi (fun k l -> (k + 1, l)) lines) in
  let step = if paper then 7.2 else 5. in
  let d : Doc.t =
    if t.manual then { header = t.header; width = (if paper then 93.6 else 65.); margin = step; sub = 3.; body }
    else { header = ("", "", ""); width = (if paper then 86.4 else 60.); margin = 0.; sub = 0.; body } in
  (d, List.rev t.said)
