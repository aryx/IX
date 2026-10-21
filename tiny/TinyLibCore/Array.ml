(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Array.mli *)

external make : int -> 'a -> 'a array = "ml_array_make"
external length : 'a array -> int = "ml_array_length"
external get : 'a array -> int -> 'a = "ml_array_get"
external set : 'a array -> int -> 'a -> unit = "ml_array_set"

(* (no [||] in tiny-ml: an empty array is made of no element) *)
external empty : int -> unit -> 'a array = "ml_array_make"
let of_list l =
  match l with
  | [] -> empty 0 ()
  | x :: _ ->
    let a = make (List.length l) x in
    List.iteri (fun i y -> set a i y) l;
    a
let to_list a =
  let rec go i acc = if i < 0 then acc else go (i - 1) (get a i :: acc) in
  go (length a - 1) []
let init n f =
  if n = 0 then empty 0 ()
  else (let a = make n (f 0) in for i = 1 to n - 1 do set a i (f i) done; a)
let sub a off n =
  if off < 0 || n < 0 || off + n > length a then invalid_arg "Array.sub"
  else init n (fun i -> get a (off + i))
let copy a = sub a 0 (length a)
let map f a = init (length a) (fun i -> f (get a i))
let append a b =
  let n = length a in
  init (n + length b) (fun i -> if i < n then get a i else get b (i - n))
let concat l = of_list (List.concat_map to_list l)
let iter f a = for i = 0 to length a - 1 do f (get a i) done
let to_seq a = Seq.init (length a) (get a)
