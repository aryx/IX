(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Latex_input.mli *)

open Latex_state

(* where the reading is: the file's frame nearest the top *)
let place (t : t) : string * int =
  let rec find (l : frame list) : string * int = match l with [] -> ("", 0) | f :: rest -> if f.counts then (f.file, f.line) else find rest in
  find t.input

let push (t : t) (s : string) = if s <> "" then t.input <- { s; i = 0; stop = false; file = ""; line = 1; counts = false } :: t.input

let rec peek (t : t) : char option =
  match t.input with
  | [] -> None
  | f :: rest -> if f.i < String.length f.s then Some f.s.[f.i] else if f.stop then None else begin t.input <- rest; peek t end

let advance (t : t) =
  match t.input with
  | f :: _ -> if f.i < String.length f.s then begin (if f.s.[f.i] = '\n' then f.line <- f.line + 1); f.i <- f.i + 1 end
  | [] -> ()

(* the character k after the next, in the same text *)
let ahead (t : t) (k : int) : char option =
  match t.input with f :: _ -> if f.i + k < String.length f.s then Some f.s.[f.i + k] else None | [] -> None

let looking (t : t) (what : string) : bool =
  match t.input with
  | f :: _ -> let n = String.length what in f.i + n <= String.length f.s && String.sub f.s f.i n = what
  | [] -> false

let skip (t : t) (n : int) = for _k = 1 to n do advance t done

let at_line_start (t : t) : bool = match t.input with f :: _ -> f.counts && (f.i = 0 || f.s.[f.i - 1] = '\n') | [] -> false

(* the rest of the line, and past its end *)
let rest_of_line (t : t) : string =
  match peek t, t.input with
  | Some _, f :: _ ->
      let e = match String.index_from_opt f.s f.i '\n' with Some e -> e | None -> String.length f.s in
      let l = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + 1);
      l
  | _ -> ""

let is_letter (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')

let is_digit (c : char) : bool = c >= '0' && c <= '9'

let is_blank (c : char) : bool = c = ' ' || c = '\t' || c = '\n' || c = '\r'

let rec blanks (t : t) = match peek t with Some c when is_blank c -> advance t; blanks t | _ -> ()

(* the spaces after a command's name are not text: to the next line's
 * first letter, but not past a blank line, which ends a paragraph *)
let after_name (t : t) =
  let rec spaces () = match peek t with Some (' ' | '\t') -> advance t; spaces () | _ -> () in
  spaces ();
  if peek t = Some '\n' && ahead t 1 <> Some '\n' then begin
    let rec blank_next (k : int) : bool = match ahead t k with Some (' ' | '\t') -> blank_next (k + 1) | Some '\n' | None -> true | Some _ -> false in
    if not (blank_next 1) then begin advance t; spaces () end
  end

(* s.[from] is after a [[: where the code quoted ends, past its ]] (on
 * the same line: a [[ that is not noweb's is left alone) *)
let quoted (s : string) (from : int) : int =
  let n = String.length s in
  let rec go (j : int) : int =
    if j + 1 >= n || s.[j] = '\n' then from
    else if s.[j] = ']' && s.[j + 1] = ']' then (let rec more (k : int) : int = if k < n && s.[k] = ']' then more (k + 1) else k in more (j + 2))
    else go (j + 1) in
  go from

(* s.[from] is after an opening: where the closing [c] is; a comment,
 * a quoted code and what follows a backslash are not looked at *)
let closing (s : string) (from : int) (o : char) (c : char) : int =
  let n = String.length s in
  let rec go (j : int) (depth : int) : int =
    if j >= n then n
    else if s.[j] = '\\' then go (j + 2) depth
    else if s.[j] = '[' && j + 1 < n && s.[j + 1] = '[' then go (quoted s (j + 2)) depth
    else if s.[j] = '%' then (match String.index_from_opt s j '\n' with Some e -> go (e + 1) depth | None -> n)
    else if s.[j] = c && depth = 0 then j
    else if s.[j] = '{' then go (j + 1) (depth + 1)
    else if s.[j] = '}' then go (j + 1) (depth - 1)
    else if s.[j] = o then go (j + 1) (depth + 1)
    else if s.[j] = c then go (j + 1) (depth - 1)
    else go (j + 1) depth in
  go from 0

(* what is between the next character, an opening, and its closing *)
let between (t : t) (o : char) (c : char) : string =
  match t.input with
  | f :: _ ->
      let e = closing f.s (f.i + 1) o c in
      let inner = String.sub f.s (f.i + 1) (min e (String.length f.s) - f.i - 1) in
      skip t (e - f.i + 1);
      inner
  | [] -> ""

(* a command's name, the backslash read: letters, or one character *)
let name (t : t) : string =
  match t.input with
  | f :: _ ->
      let n = String.length f.s in
      let rec letters (j : int) : int = if j < n && (is_letter f.s.[j] || f.s.[j] = '@') then letters (j + 1) else j in
      let e = letters f.i in
      let e = if e = f.i then min n (f.i + 1) else e in
      let w = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i);
      w
  | [] -> ""

(* an argument as it is written: what is between braces, or a command,
 * or a character *)
let arg (t : t) : string =
  blanks t;
  match peek t with
  | Some '{' -> between t '{' '}'
  | Some '\\' -> advance t; "\\" ^ name t
  | Some c ->
      let n = if Char.code c < 0x80 then 1 else if Char.code c < 0xe0 then 2 else if Char.code c < 0xf0 then 3 else 4 in
      let b = Buffer.create 4 in
      for _k = 1 to n do (match peek t with Some c -> Buffer.add_char b c; advance t | None -> ()) done;
      Buffer.contents b
  | None -> ""

(* an argument that may not be there: [text] (not [[code]], which is
 * noweb's, nor [<name>]) *)
let opt (t : t) : string option =
  let rec first (k : int) : int = match ahead t k with Some (' ' | '\t') -> first (k + 1) | _ -> k in
  match peek t with
  | None -> None
  | Some _ ->
      let k = first 0 in
      if ahead t k = Some '[' && ahead t (k + 1) <> Some '[' && ahead t (k + 1) <> Some '<' then begin blanks t; Some (between t '[' ']') end else None

let star (t : t) : bool = if peek t = Some '*' then begin advance t; true end else false

(* what is to the next [mark], and past it *)
let until (t : t) (mark : string) : string =
  match t.input with
  | f :: _ ->
      let n = String.length f.s and m = String.length mark in
      let rec find (j : int) : int = if j + m > n then n else if String.sub f.s j m = mark then j else find (j + 1) in
      let e = find f.i in
      let inner = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + m);
      inner
  | [] -> ""

(* a false branch passed over: to its \else (when [to_else]) or its
 * \fi, the conditionals inside it counted *)
let skip_branch (t : t) (to_else : bool) =
  match t.input with
  | [] -> ()
  | f :: _ ->
      let n = String.length f.s in
      let word (j : int) : int = let rec go (k : int) : int = if k < n && (is_letter f.s.[k] || f.s.[k] = '@') then go (k + 1) else k in go j in
      let rec go (j : int) (depth : int) : int =
        if j >= n then n
        else if f.s.[j] = '[' && j + 1 < n && f.s.[j + 1] = '[' then go (quoted f.s (j + 2)) depth
        else if f.s.[j] = '%' then (match String.index_from_opt f.s j '\n' with Some e -> go (e + 1) depth | None -> n)
        else if f.s.[j] <> '\\' then go (j + 1) depth
        else
          let e = word (j + 1) in
          let w = String.sub f.s (j + 1) (e - j - 1) in
          if w = "" then go (j + 2) depth
          else if w = "newif" then go (if e < n && f.s.[e] = '\\' then word (e + 1) else e) depth
          else if w = "fi" then (if depth = 0 then e else go e (depth - 1))
          else if w = "else" && depth = 0 && to_else then e
          else if String.length w > 2 && String.sub w 0 2 = "if" then go e (depth + 1)
          else go e depth in
      let e = go f.i 0 in
      skip t (e - f.i)

(* what is written to the \end of an environment, as it is; the
 * environments of the same name inside it counted when [nested] *)
let to_end (t : t) (env : string) (nested : bool) : string =
  match t.input with
  | [] -> ""
  | f :: _ ->
      let n = String.length f.s in
      let opening = "\\begin{" ^ env ^ "}" and ending = "\\end{" ^ env ^ "}" in
      let at (j : int) (w : string) : bool = j + String.length w <= n && String.sub f.s j (String.length w) = w in
      let rec go (j : int) (depth : int) : int =
        match String.index_from_opt f.s (min j n) '\\' with
        | None -> n
        | Some j -> if at j ending then (if depth = 0 then j else go (j + 1) (depth - 1)) else if nested && at j opening then go (j + 1) (depth + 1) else go (j + 1) depth in
      let e = go f.i 0 in
      let inner = String.sub f.s f.i (e - f.i) in
      skip t (e - f.i + String.length ending);
      inner

(* text put for #1, #2...; ## is a # *)
let substitute (body : string) (args : string list) : string =
  let b = Buffer.create (String.length body + 16) in
  let n = String.length body in
  let rec go (i : int) =
    if i < n then
      if body.[i] = '#' && i + 1 < n && body.[i + 1] = '#' then begin Buffer.add_char b '#'; go (i + 2) end
      else if body.[i] = '#' && i + 1 < n && is_digit body.[i + 1] then begin
        (match List.nth_opt args (Char.code body.[i + 1] - Char.code '1') with Some a -> Buffer.add_string b a | None -> ());
        go (i + 2)
      end else begin Buffer.add_char b body.[i]; go (i + 1) end in
  go 0;
  Buffer.contents b

(* what a command names: \x, or {\x} *)
let named (s : string) : string =
  let s = String.trim s in
  if s <> "" && s.[0] = '\\' then String.sub s 1 (String.length s - 1) else s
