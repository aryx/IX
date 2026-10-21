(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See TinyLibSymbols.mli *)

(* a dot, an L, digits *)
let local name =
  match String.rindex_opt name '.' with
  | Some i when i + 2 < String.length name && name.[i + 1] = 'L' ->
      String.for_all (fun c -> c >= '0' && c <= '9')
        (String.sub name (i + 2) (String.length name - i - 2))
  | _ -> false

(* <unit>.f<number>_<name> (old: f<number>_<name><>, a program's
 * functions in one file) *)
let clean name =
  let n = String.length name in
  let digit c = c >= '0' && c <= '9' in
  let rec find i =
    if i + 2 >= n then None
    else if name.[i] = '.' && name.[i + 1] = 'f' && digit name.[i + 2] then
      Some i
    else find (i + 1) in
  match find 0 with
  | Some i ->
      let rec skip j = if j < n && digit name.[j] then skip (j + 1) else j in
      let j = skip (i + 2) in
      if j < n && name.[j] = '_' then
        (let short = String.sub name (j + 1) (n - j - 1) in
         if short = "fun" then name else short)
      else name
  | None -> name

let labels text =
  let l =
    List.filter_map (fun line ->
      match String.split_on_char ' ' line with
      | [ a; l ] when not (local l) ->
          (match int_of_string_opt ("0x" ^ a) with
           | Some a -> Some (l, a)
           | None -> None)
      | _ -> None) (String.split_on_char '\n' text) in
  Array.of_list (List.sort (fun (_, a) (_, b) -> compare a b) l)

(* by halves *)
let find funcs pc =
  let rec go lo hi =
    if hi - lo <= 1 then lo
    else
      let mid = (lo + hi) / 2 in
      if snd funcs.(mid) <= pc then go mid hi else go lo mid in
  if Array.length funcs = 0 || pc < snd funcs.(0) then None
  else
    let name, a = funcs.(go 0 (Array.length funcs)) in
    Some (clean name, a)

let address funcs name =
  let rec go i =
    if i >= Array.length funcs then None
    else
      let l, a = funcs.(i) in
      if l = name || clean l = name then Some a else go (i + 1) in
  go 0
