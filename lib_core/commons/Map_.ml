(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Map_.mli *)

(* a node: its left tree (the smaller keys), its binding, its right
 * tree, and its height *)
type ('k, 'v) t = Empty | Node of ('k, 'v) t * 'k * 'v * ('k, 'v) t * int

let empty = Empty
let height (m : ('k, 'v) t) : int = match m with Empty -> 0 | Node (_, _, _, _, h) -> h
let node (l : ('k, 'v) t) (k : 'k) (v : 'v) (r : ('k, 'v) t) : ('k, 'v) t = Node (l, k, v, r, 1 + max (height l) (height r))

(* a node whose two sides' heights differ by 2 at most, made one where
 * they differ by 1 at most: a rotation, or two *)
let balance (l : ('k, 'v) t) (k : 'k) (v : 'v) (r : ('k, 'v) t) : ('k, 'v) t =
  if height l > height r + 1 then
    match l with
    | Node (ll, lk, lv, lr, _) when height ll >= height lr -> node ll lk lv (node lr k v r)
    | Node (ll, lk, lv, Node (lrl, lrk, lrv, lrr, _), _) -> node (node ll lk lv lrl) lrk lrv (node lrr k v r)
    | _ -> node l k v r
  else if height r > height l + 1 then
    match r with
    | Node (rl, rk, rv, rr, _) when height rr >= height rl -> node (node l k v rl) rk rv rr
    | Node (Node (rll, rlk, rlv, rlr, _), rk, rv, rr, _) -> node (node l k v rll) rlk rlv (node rlr rk rv rr)
    | _ -> node l k v r
  else node l k v r

let rec add (k : 'k) (v : 'v) (m : ('k, 'v) t) : ('k, 'v) t =
  match m with
  | Empty -> Node (Empty, k, v, Empty, 1)
  | Node (l, k', v', r, h) ->
      let c = compare k k' in
      if c = 0 then Node (l, k, v, r, h) else if c < 0 then balance (add k v l) k' v' r else balance l k' v' (add k v r)

let rec find_opt (k : 'k) (m : ('k, 'v) t) : 'v option =
  match m with
  | Empty -> None
  | Node (l, k', v, r, _) ->
      let c = compare k k' in
      if c = 0 then Some v else find_opt k (if c < 0 then l else r)

let find (k : 'k) (m : ('k, 'v) t) : 'v = match find_opt k m with Some v -> v | None -> raise Not_found

(* the smallest binding of a tree that is not empty, and the tree
 * without it *)
let rec take_min (l : ('k, 'v) t) (k : 'k) (v : 'v) (r : ('k, 'v) t) : ('k * 'v) * ('k, 'v) t =
  match l with
  | Empty -> ((k, v), r)
  | Node (ll, lk, lv, lr, _) ->
      let least, l = take_min ll lk lv lr in
      (least, balance l k v r)

let rec remove (k : 'k) (m : ('k, 'v) t) : ('k, 'v) t =
  match m with
  | Empty -> Empty
  | Node (l, k', v', r, _) ->
      let c = compare k k' in
      if c < 0 then balance (remove k l) k' v' r
      else if c > 0 then balance l k' v' (remove k r)
      else (
        match r with
        | Empty -> l
        | Node (rl, rk, rv, rr, _) ->
            (* the next key takes its place *)
            let (nk, nv), r = take_min rl rk rv rr in
            balance l nk nv r)

let bindings (m : ('k, 'v) t) : ('k * 'v) list =
  let rec go (m : ('k, 'v) t) (acc : ('k * 'v) list) : ('k * 'v) list =
    match m with Empty -> acc | Node (l, k, v, r, _) -> go l ((k, v) :: go r acc) in
  go m []
