(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Highlight_pascal.mli *)
open Highlight_code

let control = [ "if"; "then"; "else"; "while"; "do"; "for"; "to"; "downto"; "repeat"; "until"; "case"; "of"; "goto"; "with" ]
let keywords = [ "program"; "unit"; "uses"; "interface"; "implementation"; "begin"; "end"; "var"; "const"; "type"; "label";
                 "procedure"; "function"; "forward"; "record"; "array"; "set"; "file"; "packed"; "nil"; "not"; "and"; "or";
                 "div"; "mod"; "in"; "shl"; "shr"; "xor" ]
let types = [ "integer"; "real"; "boolean"; "char"; "string"; "byte"; "word"; "longint"; "text" ]
let constants = [ "true"; "false"; "maxint" ]

let letter (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'
let digit (c : char) : bool = c >= '0' && c <= '9'

let lines (src : string) : span list array =
  let n = String.length src in
  let tokens = ref [] in
  let line = ref 1 and bol = ref 0 in
  let add (start : int) (stop : int) (category : category) : unit =
    tokens := (!line, start - !bol, String.sub src start (stop - start), category) :: !tokens;
    for i = start to stop - 1 do if src.[i] = '\n' then begin incr line; bol := i + 1 end done in
  (* [defines]: the name that comes is what program, procedure or function names *)
  let rec go (i : int) (defines : bool) : unit =
    if i < n then begin
      let c = src.[i] in
      if c = '\n' then begin incr line; bol := i + 1; go (i + 1) defines end
      else if c = '{' then begin
        let stop = (match String.index_from_opt src i '}' with Some j -> j + 1 | None -> n) in
        add i stop Comment; go stop defines
      end
      else if c = '(' && i + 1 < n && src.[i + 1] = '*' then begin
        let rec close (j : int) : int = if j + 1 >= n then n else if src.[j] = '*' && src.[j + 1] = ')' then j + 2 else close (j + 1) in
        let stop = close (i + 2) in
        add i stop Comment; go stop defines
      end
      else if c = '/' && i + 1 < n && src.[i + 1] = '/' then begin
        let stop = (match String.index_from_opt src i '\n' with Some j -> j | None -> n) in
        add i stop Comment; go stop defines
      end
      else if c = '\'' then begin
        let rec close (j : int) : int = if j >= n || src.[j] = '\n' then j else if src.[j] = '\'' then j + 1 else close (j + 1) in
        let stop = close (i + 1) in
        add i stop String; go stop false
      end
      else if digit c || (c = '$' && i + 1 < n && digit src.[i + 1]) then begin
        let rec stop (j : int) : int = if j < n && (digit src.[j] || letter src.[j] || (src.[j] = '.' && j + 1 < n && digit src.[j + 1])) then stop (j + 1) else j in
        let j = stop (i + 1) in
        add i j Number; go j false
      end
      else if letter c then begin
        let rec stop (j : int) : int = if j < n && (letter src.[j] || digit src.[j]) then stop (j + 1) else j in
        let j = stop i in
        let word = String.lowercase_ascii (String.sub src i (j - i)) in
        let category =
          if List.mem word control then Keyword_control
          else if List.mem word keywords then Keyword
          else if List.mem word types then Type
          else if List.mem word constants then Constructor
          else if defines then Def_function
          else Normal in
        add i j category;
        go j (word = "program" || word = "procedure" || word = "function" || word = "unit")
      end
      else go (i + 1) (defines && (c = ' ' || c = '\t' || c = '\r'))
    end in
  go 0 false;
  Highlight_code.lines src (List.rev !tokens)
