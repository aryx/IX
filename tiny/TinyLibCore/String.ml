(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See String.mli *)

external length : string -> int = "ml_string_length"
external get : string -> int -> char = "ml_string_get"
external make : int -> char -> string = "ml_string_make"
external unsafe_sub : string -> int -> int -> string = "ml_string_sub"

(* (get s i, not s.[i], which is String.get: this module's own name
 * is get until it ends) *)
let sub s ofs len = if ofs < 0 || len < 0 || ofs > length s - len then invalid_arg "String.sub" else unsafe_sub s ofs len
let index_from_opt s i c =
  let n = length s in
  let rec go i = if i >= n then None else if get s i = c then Some i else go (i + 1) in
  if i < 0 || i > n then invalid_arg "String.index_from_opt" else go i
let index_opt s c = index_from_opt s 0 c
let index_from s i c = match index_from_opt s i c with Some j -> j | None -> raise Not_found
let rindex_opt s c =
  let rec go i = if i < 0 then None else if get s i = c then Some i else go (i - 1) in
  go (length s - 1)
let contains s c = match index_opt s c with Some _ -> true | None -> false
let exists p s = let n = length s in let rec go i = i < n && (p (get s i) || go (i + 1)) in go 0
let for_all p s = let n = length s in let rec go i = i >= n || (p (get s i) && go (i + 1)) in go 0
let iter f s = for i = 0 to length s - 1 do f (get s i) done
let iteri f s = for i = 0 to length s - 1 do f i (get s i) done

(* the strings joined by pairs, so that a long list is copied log n
 * times, not n *)
let concat sep l =
  let two a b = if sep = "" then a ^ b else a ^ sep ^ b in
  let rec pairs = function a :: b :: rest -> two a b :: pairs rest | l -> l in
  let rec join = function [] -> "" | [ s ] -> s | l -> join (pairs l) in
  join l
let init n f = concat "" (List.init n (fun i -> make 1 (f i)))
let map f s = init (length s) (fun i -> f (get s i))
let lowercase_ascii s =
  let upper c = c >= 'A' && c <= 'Z' in
  if exists upper s then map (fun c -> if upper c then Char.chr (Char.code c + 32) else c) s else s
let capitalize_ascii s =
  if length s > 0 && get s 0 >= 'a' && get s 0 <= 'z' then make 1 (Char.chr (Char.code (get s 0) - 32)) ^ sub s 1 (length s - 1) else s
let trim s =
  let blank c = c = ' ' || c = '\t' || c = '\n' || c = '\r' || c = '\012' in
  let n = length s in
  let rec first i = if i < n && blank (get s i) then first (i + 1) else i in
  let rec last j = if j > 0 && blank (get s (j - 1)) then last (j - 1) else j in
  let i = first 0 in
  sub s i (max 0 (last n - i))
let split_on_char c s =
  let rec go j i acc =
    if i < 0 then sub s 0 j :: acc
    else if get s i = c then go i (i - 1) (sub s (i + 1) (j - i - 1) :: acc)
    else go j (i - 1) acc
  in
  go (length s) (length s - 1) []
