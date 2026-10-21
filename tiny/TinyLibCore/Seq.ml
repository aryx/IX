(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Seq.mli *)

type 'a t = unit -> 'a node
and 'a node = Nil | Cons of 'a * 'a t

let empty () = Nil
let init n f =
  let rec go i () = if i >= n then Nil else Cons (f i, go (i + 1)) in
  go 0
let rec map f s () = match s () with Nil -> Nil | Cons (x, r) -> Cons (f x, map f r)
let rec filter p s () =
  match s () with
  | Nil -> Nil
  | Cons (x, r) -> if p x then Cons (x, filter p r) else filter p r ()
let rec filter_map f s () =
  match s () with
  | Nil -> Nil
  | Cons (x, r) ->
    (match f x with
     | Some y -> Cons (y, filter_map f r)
     | None -> filter_map f r ())

let rec append a b () =
  match a () with Nil -> b () | Cons (x, r) -> Cons (x, append r b)
let rec concat_map f s () =
  match s () with
  | Nil -> Nil
  | Cons (x, r) -> append (f x) (concat_map f r) ()

let rec iter f s = match s () with Nil -> () | Cons (x, r) -> f x; iter f r
let rec fold_left f acc s =
  match s () with Nil -> acc | Cons (x, r) -> fold_left f (f acc x) r
let rec take n s () =
  if n <= 0 then Nil
  else match s () with Nil -> Nil | Cons (x, r) -> Cons (x, take (n - 1) r)
let rec take_while p s () =
  match s () with Cons (x, r) when p x -> Cons (x, take_while p r) | _ -> Nil
let rec drop_while p s () =
  match s () with Cons (x, r) when p x -> drop_while p r () | n -> n
