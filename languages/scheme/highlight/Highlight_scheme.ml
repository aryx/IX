(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Highlight_scheme.mli *)
open Highlight_code

let control = [ "if"; "cond"; "else"; "case"; "when"; "unless"; "do"; "and"; "or"; "begin" ]
let forms = [ "define"; "lambda"; "let"; "let*"; "letrec"; "set!"; "quote"; "quasiquote"; "unquote"; "define-syntax";
              "syntax-rules"; "let-syntax"; "define-record-type"; "delay"; "named-lambda"; "define-struct"; "require" ]

let delimiter (c : char) : bool = c = '(' || c = ')' || c = '[' || c = ']' || c = '"' || c = ';' || c = ' ' || c = '\t' || c = '\n' || c = '\r'

let lines (src : string) : span list array =
  let n = String.length src in
  let tokens = ref [] in
  (* where a token starts: its line (from 1) and its column *)
  let line = ref 1 and bol = ref 0 in
  let add (start : int) (stop : int) (category : category) : unit =
    tokens := (!line, start - !bol, String.sub src start (stop - start), category) :: !tokens;
    (* (a token of several lines: the lines passed) *)
    for i = start to stop - 1 do if src.[i] = '\n' then begin incr line; bol := i + 1 end done in
  (* [after]: what the name that comes is, by what is before it *)
  let rec go (i : int) (after : category) : unit =
    if i < n then begin
      let c = src.[i] in
      if c = '\n' then begin incr line; bol := i + 1; go (i + 1) after end
      else if c = ' ' || c = '\t' || c = '\r' then go (i + 1) after
      else if c = ';' then begin
        let stop = (match String.index_from_opt src i '\n' with Some j -> j | None -> n) in
        add i stop Comment; go stop after
      end
      else if c = '#' && i + 1 < n && src.[i + 1] = '|' then begin
        let rec close (j : int) : int = if j + 1 >= n then n else if src.[j] = '|' && src.[j + 1] = '#' then j + 2 else close (j + 1) in
        let stop = close (i + 2) in
        add i stop Comment; go stop after
      end
      else if c = '"' then begin
        let rec close (j : int) : int = if j >= n then n else if src.[j] = '\\' then close (j + 2) else if src.[j] = '"' then j + 1 else close (j + 1) in
        let stop = min n (close (i + 1)) in
        add i stop String; go stop Normal
      end
      else if c = '(' || c = '[' then begin
        add i (i + 1) Punctuation;
        (* (define (f x): the name after the second parenthesis is the function's *)
        go (i + 1) (if after = Def_value then Def_function else Keyword)
      end
      else if c = ')' || c = ']' || c = '\'' || c = '`' || c = ',' then begin add i (i + 1) Punctuation; go (i + 1) Normal end
      else begin
        let rec stop (j : int) : int = if j < n && not (delimiter src.[j]) then stop (j + 1) else j in
        let j = stop i in
        let name = String.sub src i (j - i) in
        let category =
          if c = '#' || (c >= '0' && c <= '9') || ((c = '-' || c = '+' || c = '.') && j > i + 1 && src.[i + 1] >= '0' && src.[i + 1] <= '9') then Number
          else if after = Keyword && List.mem name control then Keyword_control
          else if after = Keyword && List.mem name forms then Keyword
          else if after = Def_value || after = Def_function then after
          else Normal in
        add i j category;
        go j (if category = Keyword && (name = "define" || name = "define-syntax") then Def_value else Normal)
      end
    end in
  go 0 Normal;
  Highlight_code.lines src (List.rev !tokens)
