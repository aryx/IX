(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Hashtbl.mli *)

external hash : 'a -> int = "ml_hash"

type ('a, 'b) t = { mutable hashtbl_size : int; mutable hashtbl_data : ('a * 'b) list array }

let create n = { hashtbl_size = 0; hashtbl_data = Array.make (max 8 (min n 1024)) [] }
let length h = h.hashtbl_size
let index h k = hash k mod Array.length h.hashtbl_data

(* twice as many buckets, each binding moved to its new one *)
let resize h =
  let old = h.hashtbl_data in
  let data = Array.make (2 * Array.length old) [] in
  h.hashtbl_data <- data;
  for i = 0 to Array.length old - 1 do
    List.iter (fun (k, v) -> let j = index h k in data.(j) <- (k, v) :: data.(j)) (List.rev old.(i))
  done

let find_opt h k = List.assoc_opt k h.hashtbl_data.(index h k)
let find h k = List.assoc k h.hashtbl_data.(index h k)
let mem h k = List.exists (fun (a, _) -> a = k) h.hashtbl_data.(index h k)
let remove h k =
  let i = index h k in
  let rec drop = function [] -> [] | (a, v) :: l -> if a = k then (h.hashtbl_size <- h.hashtbl_size - 1; l) else (a, v) :: drop l in
  h.hashtbl_data.(i) <- drop h.hashtbl_data.(i)
let add h k v =
  let i = index h k in
  h.hashtbl_data.(i) <- (k, v) :: h.hashtbl_data.(i);
  h.hashtbl_size <- h.hashtbl_size + 1;
  if h.hashtbl_size > 2 * Array.length h.hashtbl_data then resize h
let replace h k v = remove h k; add h k v
let fold f h acc =
  let acc = ref acc in
  for i = 0 to Array.length h.hashtbl_data - 1 do
    List.iter (fun (k, v) -> acc := f k v !acc) h.hashtbl_data.(i)
  done;
  !acc
let iter f h = fold (fun k v () -> f k v) h ()
