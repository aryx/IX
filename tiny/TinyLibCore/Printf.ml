(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Printf.mli *)

let hex n =
  let digit d = String.make 1 (String.get "0123456789abcdef" d) in
  let rec go n acc = if n = 0 then acc else go (n lsr 4) (digit (n land 15) ^ acc) in
  if n = 0 then "0" else go n ""

let quoted s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\t' -> Buffer.add_string b "\\t"
    | '\r' -> Buffer.add_string b "\\r"
    | '\b' -> Buffer.add_string b "\\b"
    | c when c < ' ' || c > '~' ->
        let k = Char.code c in
        Buffer.add_char b '\\';
        Buffer.add_string b
          (string_of_int (k / 100) ^ string_of_int (k / 10 mod 10)
           ^ string_of_int (k mod 10))
    | c -> Buffer.add_char b c) s;
  Buffer.add_char b '"';
  Buffer.contents b

let pad left zero w s =
  let n = String.length s in
  if n >= w then s
  else if left then s ^ String.make (w - n) ' '
  else if not zero then String.make (w - n) ' ' ^ s
  else if n > 0 && s.[0] = '-'
  then "-" ^ String.make (w - n) '0' ^ String.sub s 1 (n - 1)
  else String.make (w - n) '0' ^ s
