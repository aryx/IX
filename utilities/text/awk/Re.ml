(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Re.mli *)

(* what matches the empty string only: re.c writes []*, a class of no
 * character, which libregexp takes and Regex does not; here the class
 * of what is no character at all *)
let nothing = let b = Buffer.create 8 in Buffer.add_string b "[^\001-"; Utf8.add b 0x10FFFF; Buffer.add_string b "]*"; Buffer.contents b

(* re.c's compre: the pattern's text rewritten for libregexp *)
let rewrite pat =
  let n = String.length pat in
  let b = Buffer.create (n + 8) in
  let at k = if k < n then pat.[k] else '\000' in
  let octal c = c >= '0' && c <= '7' in
  let hex c = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') in
  (* after a \: awk's own escapes are their characters, any other one
   * stays quoted (a \. is not a metacharacter, nor is \056) *)
  let quoted k =
    match at k with
    | 't' -> Buffer.add_char b '\t'; k + 1
    | 'n' -> Buffer.add_char b '\n'; k + 1
    | 'f' -> Buffer.add_char b '\012'; k + 1
    | 'r' -> Buffer.add_char b '\r'; k + 1
    | 'b' -> Buffer.add_char b '\b'; k + 1
    | 'x' ->
        let rec digits j v = if j < k + 5 && hex (at j) then digits (j + 1) ((16 * v) + int_of_string ("0x" ^ String.make 1 (at j))) else (j, v) in
        let j, v = digits (k + 1) 0 in
        Buffer.add_char b '\\'; Utf8.add b v; j
    | c when octal c ->
        let rec digits j v = if j < k + 3 && octal (at j) then digits (j + 1) ((8 * v) + Char.code (at j) - 48) else (j, v) in
        let j, v = digits k 0 in
        Buffer.add_char b '\\'; Utf8.add b v; j
    | c -> Buffer.add_char b '\\'; if k < n then Buffer.add_char b c; k + 1 in
  let rec go k in_class =
    if k < n then begin
      let c = pat.[k] in
      let add s = Buffer.add_string b s in
      if c = '\\' then go (quoted (k + 1)) in_class
      else if (not in_class) && c = '(' && at (k + 1) = ')' then (add nothing; go (k + 2) in_class)
      else if c = '[' then begin
        if at (k + 1) = '-' then (add "[\\-"; go (k + 2) true)
        else if at (k + 1) = '^' && at (k + 2) = '-' then (add "[^\\-"; go (k + 3) true)
        else if at (k + 1) = '[' then (add "[["; go (k + 2) true)
        else if at (k + 1) = '^' && at (k + 2) = '[' then (add "[^["; go (k + 3) true)
        else if at (k + 1) = ']' then (add nothing; go (k + 2) false)
        else (add "["; go (k + 1) true)
      end
      else if c = '-' && at (k + 1) = ']' then (add "\\-"; go (k + 1) in_class)
      else (Buffer.add_char b c; go (k + 1) (in_class && c <> ']'))
    end in
  go 0 false;
  Buffer.contents b

let compile pat = Regex.compile (if pat = "" then nothing else rewrite pat)

let find re s from =
  match Regex.exec re s from with
  | Some groups -> let a, z = groups.(0) in Some (a, z - a)
  | None -> None

let find_nonempty re s from = match find re s from with Some (_, 0) -> None | found -> found

let matches re s = Regex.exec re s 0 <> None
