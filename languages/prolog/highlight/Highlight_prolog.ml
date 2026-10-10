(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Highlight_prolog.mli *)
open Highlight_code

let declarations = [ "dynamic"; "discontiguous"; "multifile"; "initialization"; "module"; "use_module"; "op"; "ensure_loaded"; "include" ]
let words = [ "is"; "mod"; "rem"; "div"; "xor" ]

let is_lower (c : char) : bool = c >= 'a' && c <= 'z'
let is_upper (c : char) : bool = (c >= 'A' && c <= 'Z') || c = '_'
let is_digit (c : char) : bool = c >= '0' && c <= '9'
let is_alnum (c : char) : bool = is_lower c || is_upper c || is_digit c
let is_symbol (c : char) : bool = String.contains "+-*/\\^<>=~:.?@#&$" c
let is_blank (c : char) : bool = c = ' ' || c = '\t' || c = '\n' || c = '\r'

let lines (src : string) : span list array =
  let n = String.length src in
  let tokens = ref [] in
  (* where a token starts: its line (from 1) and its column *)
  let line = ref 1 and bol = ref 0 in
  let add (start : int) (stop : int) (category : category) : unit =
    tokens := (!line, start - !bol, String.sub src start (stop - start), category) :: !tokens;
    (* (a token of several lines: the lines passed) *)
    for i = start to stop - 1 do if src.[i] = '\n' then begin incr line; bol := i + 1 end done in
  let rec while_ (p : char -> bool) (j : int) : int = if j < n && p src.[j] then while_ p (j + 1) else j in
  (* a quoted text's end, the quote doubled or after a \ not its end *)
  let rec quoted (q : char) (j : int) : int =
    if j >= n then n
    else if src.[j] = '\\' then quoted q (j + 2)
    else if src.[j] = q then (if j + 1 < n && src.[j + 1] = q then quoted q (j + 2) else j + 1)
    else quoted q (j + 1) in
  (* [head]: a clause starts here, the name that comes is what it
   * defines; [directive]: after a clause's first :-, a declaration's word *)
  let rec go (i : int) (head : bool) (directive : bool) : unit =
    if i < n then begin
      let c = src.[i] in
      if c = '\n' then begin incr line; bol := i + 1; go (i + 1) head directive end
      else if is_blank c then go (i + 1) head directive
      else if c = '%' then begin
        let stop = (match String.index_from_opt src i '\n' with Some j -> j | None -> n) in
        add i stop Comment; go stop head directive
      end
      else if c = '/' && i + 1 < n && src.[i + 1] = '*' then begin
        let rec close (j : int) : int = if j + 1 >= n then n else if src.[j] = '*' && src.[j + 1] = '/' then j + 2 else close (j + 1) in
        let stop = close (i + 2) in
        add i stop Comment; go stop head directive
      end
      else if c = '"' || c = '`' then begin
        let stop = min n (quoted c (i + 1)) in
        add i stop String; go stop false false
      end
      else if c = '\'' then begin
        let stop = min n (quoted c (i + 1)) in
        add i stop (if head then Def_function else String); go stop false false
      end
      else if is_digit c then begin
        (* 0'c is a character's code; 0x1F, 0b101, 0o17 *)
        let stop =
          if c = '0' && i + 2 < n && src.[i + 1] = '\'' then i + 3
          else if c = '0' && i + 1 < n && (src.[i + 1] = 'x' || src.[i + 1] = 'b' || src.[i + 1] = 'o') then while_ is_alnum (i + 2)
          else while_ is_digit i in
        add i stop Number; go stop false false
      end
      else if is_upper c then begin
        let stop = while_ is_alnum i in
        add i stop Local; go stop false false
      end
      else if is_lower c then begin
        let stop = while_ is_alnum i in
        let name = String.sub src i (stop - i) in
        let category =
          if head then Def_function
          else if directive && List.mem name declarations then Keyword_module
          else if List.mem name words then Operator
          else Normal in
        add i stop category; go stop false false
      end
      else if c = '!' then begin add i (i + 1) Keyword_control; go (i + 1) false false end
      else if c = ';' then begin add i (i + 1) Keyword_control; go (i + 1) false false end
      else if c = ',' || c = '|' || c = '(' || c = ')' || c = '[' || c = ']' || c = '{' || c = '}' then begin
        add i (i + 1) Punctuation; go (i + 1) false false
      end
      else if is_symbol c then begin
        let stop = while_ is_symbol i in
        let name = String.sub src i (stop - i) in
        (* a full stop ends the clause: the next name is a head again;
         * so does Datalog's question mark at a line's end *)
        let ends = (name = "." || name = "?") && (stop >= n || is_blank src.[stop] || src.[stop] = '%') in
        if ends then begin add i stop Punctuation; go stop true false end
        else if name = ":-" || name = "-->" || name = "?-" then begin add i stop Keyword; go stop false head end
        else if name = "->" || name = "\\+" then begin add i stop Keyword_control; go stop false false end
        else begin add i stop Operator; go stop false false end
      end
      else begin add i (i + 1) Normal; go (i + 1) false false end
    end in
  go 0 true false;
  Highlight_code.lines src (List.rev !tokens)
