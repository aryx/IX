(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Bib.mli *)

type entry = { kind : string; key : string; fields : (string * string) list }

let is_name (c : char) : bool = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_' || c = '-' || c = ':' || c = '.' || c = '+' || c = '/'

let read (s : string) : entry list =
  let n = String.length s in
  let rec blanks (i : int) : int = if i < n && (s.[i] = ' ' || s.[i] = '\n' || s.[i] = '\t' || s.[i] = '\r') then blanks (i + 1) else i in
  let rec name (i : int) : int = if i < n && is_name s.[i] then name (i + 1) else i in
  (* s.[i] is after a {: where its } is *)
  let rec closing (i : int) (depth : int) : int =
    if i >= n then n
    else if s.[i] = '\\' then closing (i + 2) depth
    else if s.[i] = '{' then closing (i + 1) (depth + 1)
    else if s.[i] = '}' then (if depth = 0 then i else closing (i + 1) (depth - 1))
    else closing (i + 1) depth in
  let rec quote (i : int) (depth : int) : int =
    if i >= n then n
    else if s.[i] = '\\' then quote (i + 2) depth
    else if s.[i] = '{' then quote (i + 1) (depth + 1)
    else if s.[i] = '}' then quote (i + 1) (depth - 1)
    else if s.[i] = '"' && depth <= 0 then i
    else quote (i + 1) depth in
  (* a field's text, and where it ends *)
  let value (i : int) : string * int =
    if i >= n then ("", n)
    else if s.[i] = '{' then (let e = closing (i + 1) 0 in (String.sub s (i + 1) (e - i - 1), min n (e + 1)))
    else if s.[i] = '"' then (let e = quote (i + 1) 0 in (String.sub s (i + 1) (e - i - 1), min n (e + 1)))
    else (let e = name i in (String.sub s i (e - i), max e (if e = i then i + 1 else e))) in
  let rec fields (i : int) (acc : (string * string) list) : (string * string) list * int =
    let i = blanks i in
    if i >= n then (List.rev acc, n)
    else if s.[i] = '}' || s.[i] = ')' then (List.rev acc, i + 1)
    else if s.[i] = ',' then fields (i + 1) acc
    else
      let e = name i in
      let j = blanks e in
      if e = i || j >= n || s.[j] <> '=' then fields (max (i + 1) e) acc
      else
        let v, after = value (blanks (j + 1)) in
        fields after ((String.lowercase_ascii (String.sub s i (e - i)), v) :: acc) in
  let rec entries (i : int) (acc : entry list) : entry list =
    match String.index_from_opt s (min i n) '@' with
    | None -> List.rev acc
    | Some at ->
        let e = name (at + 1) in
        let kind = String.lowercase_ascii (String.sub s (at + 1) (e - at - 1)) in
        let o = blanks e in
        if o >= n || (s.[o] <> '{' && s.[o] <> '(') then entries (at + 1) acc
        else if kind = "comment" || kind = "string" || kind = "preamble" then entries (closing (o + 1) 0) acc
        else
          let k = blanks (o + 1) in
          let ke = name k in
          let fs, after = fields ke [] in
          entries after ({ kind; key = String.sub s k (ke - k); fields = fs } :: acc) in
  entries 0 []
