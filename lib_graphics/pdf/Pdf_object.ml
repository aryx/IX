(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* ix: mini-chrome's libs/pdf/Pdf_object.ml; parse's optional length is parse_with's, said; parse is with none (docs/plans/plan_pdf.md) *)

(* See Pdf_object.mli *)

type t =
  | Null
  | Bool of bool
  | Int of int
  | Real of float
  | String of string
  | Name of string
  | Array of t list
  | Dict of dict
  | Stream of dict * string
  | Ref of int

and dict = (string * t) list

let is_space (c : char) : bool = c = ' ' || c = '\n' || c = '\r' || c = '\t' || c = '\012' || c = '\000'
let is_delimiter (c : char) : bool = String.contains "()<>[]{}/%" c
let is_regular (c : char) : bool = not (is_space c || is_delimiter c)

(* past spaces and comments *)
let rec skip (s : string) (i : int) : int =
  if i >= String.length s then i
  else if is_space s.[i] then skip s (i + 1)
  else if s.[i] = '%' then skip s (match String.index_from_opt s i '\n', String.index_from_opt s i '\r' with Some a, Some b -> min a b | Some a, None | None, Some a -> a | None, None -> String.length s)
  else i

(* a run of regular characters: a number or a keyword *)
let word (s : string) (i : int) : string * int =
  let j = ref i in
  while !j < String.length s && is_regular s.[!j] do incr j done;
  (String.sub s i (!j - i), !j)

let hex (c : char) : int = match c with '0' .. '9' -> Char.code c - 48 | 'a' .. 'f' -> Char.code c - 87 | 'A' .. 'F' -> Char.code c - 55 | _ -> 0

let number (w : string) : t option =
  match int_of_string_opt w with
  | Some n when w <> "" && (w.[0] = '-' || w.[0] = '+' || (w.[0] >= '0' && w.[0] <= '9')) -> Some (Int n)
  | _ -> if w <> "" && String.for_all (fun c -> (c >= '0' && c <= '9') || c = '.' || c = '-' || c = '+') w then Option.map (fun f -> Real f) (float_of_string_opt (if w.[String.length w - 1] = '.' then w ^ "0" else w)) else None

(* (a string), its escapes undone, its parentheses balanced *)
let literal (s : string) (i : int) : t * int =
  let b = Buffer.create 32 and n = String.length s in
  let rec go i depth =
    if i >= n then i
    else
      match s.[i] with
      | ')' when depth = 0 -> i + 1
      | ')' -> Buffer.add_char b ')'; go (i + 1) (depth - 1)
      | '(' -> Buffer.add_char b '('; go (i + 1) (depth + 1)
      | '\\' when i + 1 < n -> (
          match s.[i + 1] with
          | 'n' -> Buffer.add_char b '\n'; go (i + 2) depth
          | 'r' -> Buffer.add_char b '\r'; go (i + 2) depth
          | 't' -> Buffer.add_char b '\t'; go (i + 2) depth
          | 'b' -> Buffer.add_char b '\b'; go (i + 2) depth
          | 'f' -> Buffer.add_char b '\012'; go (i + 2) depth
          | '\r' -> go (if i + 2 < n && s.[i + 2] = '\n' then i + 3 else i + 2) depth
          | '\n' -> go (i + 2) depth
          | '0' .. '7' ->
              let j = ref (i + 1) and v = ref 0 in
              while !j < n && !j < i + 4 && s.[!j] >= '0' && s.[!j] <= '7' do v := (!v * 8) + Char.code s.[!j] - 48; incr j done;
              Buffer.add_char b (Char.chr (!v land 255));
              go !j depth
          | c -> Buffer.add_char b c; go (i + 2) depth)
      | c -> Buffer.add_char b c; go (i + 1) depth
  in
  let stop = go i 0 in
  (String (Buffer.contents b), stop)

let name (s : string) (i : int) : string * int =
  let w, j = word s i in
  if not (String.contains w '#') then (w, j)
  else (
    let b = Buffer.create 16 and k = ref 0 in
    while !k < String.length w do
      if w.[!k] = '#' && !k + 2 < String.length w then (Buffer.add_char b (Char.chr ((hex w.[!k + 1] * 16) + hex w.[!k + 2])); k := !k + 3)
      else (Buffer.add_char b w.[!k]; incr k)
    done;
    (Buffer.contents b, j))

(* [parse_with ~length s i]: the object at i, and where it ends. A stream's
 * bytes are as many as its /Length, which [length] finds when it is a
 * reference; failing that, up to "endstream" *)
let rec parse_with ~(length : t -> int option) (s : string) (i : int) : t * int =
  let n = String.length s in
  let i = skip s i in
  if i >= n then (Null, i)
  else
    match s.[i] with
    | '(' -> literal s (i + 1)
    | '/' -> let w, j = name s (i + 1) in (Name w, j)
    | '[' ->
        let rec items i acc =
          let i = skip s i in
          if i >= n then (Array (List.rev acc), i) else if s.[i] = ']' then (Array (List.rev acc), i + 1) else let v, j = parse_with ~length s i in items (max j (i + 1)) (v :: acc)
        in
        items (i + 1) []
    | '<' when i + 1 < n && s.[i + 1] = '<' ->
        let rec entries i acc =
          let i = skip s i in
          if i + 1 >= n then (List.rev acc, n)
          else if s.[i] = '>' && s.[i + 1] = '>' then (List.rev acc, i + 2)
          else if s.[i] = '/' then (
            let key, j = name s (i + 1) in
            let v, j = parse_with ~length s j in
            entries j ((key, v) :: acc))
          else entries (i + 1) acc
        in
        let d, j = entries (i + 2) [] in
        let k = skip s j in
        if k + 6 <= n && String.sub s k 6 = "stream" then (
          (* the bytes start after the line's end *)
          let start = if k + 6 < n && s.[k + 6] = '\r' then (if k + 7 < n && s.[k + 7] = '\n' then k + 8 else k + 7) else k + 7 in
          let said = match List.assoc_opt "Length" d with Some (Int l) -> Some l | Some r -> length r | None -> None in
          let found l = start + l <= n && (let e = skip s (start + l) in e + 9 <= n && String.sub s e 9 = "endstream") in
          match said with
          | Some l when found l -> (Stream (d, String.sub s start l), skip s (start + l) + 9)
          | _ ->
              let rec search from = match String.index_from_opt s from 'e' with Some e when e + 9 <= n && String.sub s e 9 = "endstream" -> e | Some e -> search (e + 1) | None -> n in
              let e = search (min start n) in
              (Stream (d, String.sub s (min start n) (max 0 (e - min start n))), min n (e + 9)))
        else (Dict d, j)
    | '<' ->
        let b = Buffer.create 16 and j = ref (i + 1) and high = ref (-1) in
        while !j < n && s.[!j] <> '>' do
          if not (is_space s.[!j]) then if !high < 0 then high := hex s.[!j] else (Buffer.add_char b (Char.chr ((!high * 16) + hex s.[!j])); high := -1);
          incr j
        done;
        if !high >= 0 then Buffer.add_char b (Char.chr (!high * 16));
        (String (Buffer.contents b), !j + 1)
    | _ -> (
        let w, j = word s i in
        match w with
        | "true" -> (Bool true, j)
        | "false" -> (Bool false, j)
        | "null" -> (Null, j)
        | "" -> (Null, i + 1)
        | _ -> (
            match number w with
            | Some (Int a) -> (
                (* a reference is two numbers and R *)
                let w2, j2 = word s (skip s j) in
                match int_of_string_opt w2 with
                | Some _ when w2 <> "" && w2.[0] >= '0' && w2.[0] <= '9' ->
                    let k = skip s j2 in
                    if k < n && s.[k] = 'R' && (k + 1 >= n || not (is_regular s.[k + 1])) then (Ref a, k + 1) else (Int a, j)
                | _ -> (Int a, j))
            | Some v -> (v, j)
            | None -> (Name ("\000" ^ w), j)))

(* what a file's own syntax cannot be: a word that is no value, as an
 * operator of a page's content is *)
let parse (s : string) (i : int) : t * int = parse_with ~length:(fun _ -> None) s i

let keyword (v : t) : string option = match v with Name w when w <> "" && w.[0] = '\000' -> Some (String.sub w 1 (String.length w - 1)) | _ -> None

let to_float (v : t) : float = match v with Int n -> float_of_int n | Real f -> f | _ -> 0.
let to_int (v : t) : int = match v with Int n -> n | Real f -> int_of_float f | _ -> 0
