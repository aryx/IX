(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See List.mli *)

let length l = let rec len n = function [] -> n | _ :: l -> len (n + 1) l in len 0 l
let rev l = let rec rev acc = function [] -> acc | x :: l -> rev (x :: acc) l in rev [] l
let hd = function [] -> failwith "hd" | x :: _ -> x
let tl = function [] -> failwith "tl" | _ :: l -> l
let rec nth l n = match l with [] -> failwith "nth" | x :: l -> if n = 0 then x else nth l (n - 1)
let rec nth_opt l n = match l with [] -> None | x :: l -> if n = 0 then Some x else nth_opt l (n - 1)
let rec map f = function [] -> [] | x :: l -> let y = f x in y :: map f l
let mapi f l = let rec go i = function [] -> [] | x :: l -> let y = f i x in y :: go (i + 1) l in go 0 l
let rec map2 f l1 l2 =
  match l1, l2 with
  | [], [] -> []
  | x :: l1, y :: l2 -> let z = f x y in z :: map2 f l1 l2
  | _ -> invalid_arg "List.map2"
let rec iter f = function [] -> () | x :: l -> f x; iter f l
let iteri f l = let rec go i = function [] -> () | x :: l -> f i x; go (i + 1) l in go 0 l
let rec fold_left f acc = function [] -> acc | x :: l -> fold_left f (f acc x) l
let rec fold_right f l acc = match l with [] -> acc | x :: l -> f x (fold_right f l acc)
let rec mem x = function [] -> false | y :: l -> x = y || mem x l
let rec assoc x = function [] -> raise Not_found | (a, b) :: l -> if a = x then b else assoc x l
let rec assoc_opt x = function [] -> None | (a, b) :: l -> if a = x then Some b else assoc_opt x l
let rec exists p = function [] -> false | x :: l -> p x || exists p l
let rec for_all p = function [] -> true | x :: l -> p x && for_all p l
let filter p l =
  let rec find acc = function [] -> rev acc | x :: l -> if p x then find (x :: acc) l else find acc l in
  find [] l
let filteri p l =
  let rec go i = function [] -> [] | x :: l -> if p i x then x :: go (i + 1) l else go (i + 1) l in
  go 0 l
let rec concat = function [] -> [] | l :: r -> l @ concat r
let concat_map f l = concat (map f l)
let init n f = let rec go i = if i >= n then [] else let x = f i in x :: go (i + 1) in go 0

(* a merge sort, stable as OCaml's *)
let rec sort cmp l =
  let rec onto acc l = match acc with [] -> l | x :: r -> onto r (x :: l) in
  let rec take n l acc = if n = 0 then onto acc [], l else match l with [] -> onto acc [], [] | x :: r -> take (n - 1) r (x :: acc) in
  let rec merge a b acc =
    match a, b with
    | [], l -> onto acc l
    | l, [] -> onto acc l
    | x :: ra, y :: rb -> if cmp x y <= 0 then merge ra b (x :: acc) else merge a rb (y :: acc) in
  match l with
  | [] -> l
  | [ _ ] -> l
  | _ ->
      let a, b = take (length l / 2) l [] in
      merge (sort cmp a) (sort cmp b) []
