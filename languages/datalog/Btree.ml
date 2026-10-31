(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Btree.mli *)

(* a node: in a leaf, [size] tuples sorted, flat in [keys] (w values
 * each); in an inner node, [size] separators and size + 1 children,
 * child i's tuples below separator i, at or above separator i - 1 *)
type node = {
  mutable size : int;
  keys : int array;
  kids : node array;          (* [||] in a leaf *)
  mutable next : node option; (* a leaf's right neighbour *)
}

type t = { w : int; mutable root : node; mutable count : int }
type hint = { mutable last : node }

(* the tuples of a leaf, the separators of an inner node, at most *)
let cap = 64

let leaf (w : int) : node = { size = 0; keys = Array.make (cap * w) 0; kids = [||]; next = None }

let create (w : int) : t = { w; root = leaf w; count = 0 }
let count (t : t) : int = t.count
let hint (t : t) : hint = { last = t.root }

(* the slot's tuple against the values: -1, 0, 1 *)
let compare_at (w : int) (keys : int array) (slot : int) (value : int -> int) : int =
  let base = slot * w in
  let rec go (i : int) : int =
    if i = w then 0
    else
      let a = keys.(base + i) and b = value i in
      if a < b then -1 else if a > b then 1 else go (i + 1) in
  go 0

(* the first slot whose tuple is at or above the values (lower bound) *)
let lower (w : int) (n : node) (value : int -> int) : int =
  let lo = ref 0 and hi = ref n.size in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if compare_at w n.keys mid value < 0 then lo := mid + 1 else hi := mid
  done;
  !lo

(* the child of an inner node where the values are: past the
 * separators at or below them *)
let child (w : int) (n : node) (value : int -> int) : int =
  let lo = ref 0 and hi = ref n.size in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if compare_at w n.keys mid value <= 0 then lo := mid + 1 else hi := mid
  done;
  !lo

let rec leaf_of (w : int) (n : node) (value : int -> int) : node =
  if n.kids = [||] then n else leaf_of w n.kids.(child w n value) value

let in_leaf (w : int) (l : node) (value : int -> int) : bool =
  let k = lower w l value in
  k < l.size && compare_at w l.keys k value = 0

(* (the hint first: a leaf holds every tuple between its first and its
 * last, so a tuple in that span is there or nowhere) *)
let mem_hint (t : t) (h : hint) (value : int -> int) : bool =
  let w = t.w and l = h.last in
  if l.kids = [||] && l.size > 0 && compare_at w l.keys 0 value <= 0 && compare_at w l.keys (l.size - 1) value >= 0 then
    in_leaf w l value
  else begin
    let l = leaf_of w t.root value in
    h.last <- l;
    in_leaf w l value
  end

let mem_by (t : t) (value : int -> int) : bool = in_leaf t.w (leaf_of t.w t.root value) value

(* the values put at slot k of a node, those from k on moved right *)
let put (w : int) (n : node) (k : int) (value : int -> int) : unit =
  Array.blit n.keys (k * w) n.keys ((k + 1) * w) ((n.size - k) * w);
  for i = 0 to w - 1 do
    n.keys.((k * w) + i) <- value i
  done;
  n.size <- n.size + 1

(* an insertion: None, or the new right half of the node and its
 * first tuple, for the parent *)
type split = { sep : int array; right : node }

let rec insert (w : int) (n : node) (value : int -> int) (fresh : bool ref) : split option =
  if n.kids = [||] then begin
    let k = lower w n value in
    if k < n.size && compare_at w n.keys k value = 0 then None
    else begin
      fresh := true;
      put w n k value;
      if n.size < cap then None
      else begin
        (* half to a new leaf on the right *)
        let half = cap / 2 in
        let r = leaf w in
        Array.blit n.keys (half * w) r.keys 0 ((n.size - half) * w);
        r.size <- n.size - half;
        n.size <- half;
        r.next <- n.next;
        n.next <- Some r;
        Some { sep = Array.sub r.keys 0 w; right = r }
      end
    end
  end
  else begin
    let i = child w n value in
    match insert w n.kids.(i) value fresh with
    | None -> None
    | Some s ->
        Array.blit n.kids (i + 1) n.kids (i + 2) (n.size - i);
        n.kids.(i + 1) <- s.right;
        put w n i (fun (j : int) -> s.sep.(j));
        if n.size < cap then None
        else begin
          (* the middle separator goes up; those after it and their
           * children to a new node *)
          let half = cap / 2 in
          let r = { size = 0; keys = Array.make (cap * w) 0; kids = Array.make (cap + 1) n; next = None } in
          let sep = Array.sub n.keys (half * w) w in
          Array.blit n.keys ((half + 1) * w) r.keys 0 ((n.size - half - 1) * w);
          Array.blit n.kids (half + 1) r.kids 0 (n.size - half);
          r.size <- n.size - half - 1;
          n.size <- half;
          Some { sep; right = r }
        end
  end

let add_by (t : t) (value : int -> int) : bool =
  let fresh = ref false in
  (match insert t.w t.root value fresh with
   | None -> ()
   | Some s ->
       let root = { size = 1; keys = Array.make (cap * t.w) 0; kids = Array.make (cap + 1) t.root; next = None } in
       Array.blit s.sep 0 root.keys 0 t.w;
       root.kids.(1) <- s.right;
       t.root <- root);
  if !fresh then t.count <- t.count + 1;
  !fresh

(* each tuple at or above the values, in order, while [f] says go on *)
let iter_from (t : t) (value : int -> int) (f : int array -> int -> bool) : unit =
  let l = leaf_of t.w t.root value in
  let rec go (l : node) (k : int) : unit =
    if k < l.size then (if f l.keys (k * t.w) then go l (k + 1))
    else match l.next with Some r -> go r 0 | None -> () in
  go l (lower t.w l value)

(* mem_hint for pairs, written out: the comparisons inline, no closure
 * called for each value (what Souffle's C++ templates make for each
 * arity; mini-ml has no functors) *)
let lower2 (n : node) (a : int) (b : int) : int =
  let keys = n.keys in
  let lo = ref 0 and hi = ref n.size in
  while !lo < !hi do
    let mid = (!lo + !hi) lsr 1 in
    let x = keys.(2 * mid) in
    if x < a || (x = a && keys.((2 * mid) + 1) < b) then lo := mid + 1 else hi := mid
  done;
  !lo

let rec leaf2 (n : node) (a : int) (b : int) : node =
  if n.kids = [||] then n
  else begin
    let keys = n.keys in
    let lo = ref 0 and hi = ref n.size in
    while !lo < !hi do
      let mid = (!lo + !hi) lsr 1 in
      let x = keys.(2 * mid) in
      if x < a || (x = a && keys.((2 * mid) + 1) <= b) then lo := mid + 1 else hi := mid
    done;
    leaf2 n.kids.(!lo) a b
  end

let mem2_hint (t : t) (h : hint) (a : int) (b : int) : bool =
  let l = h.last in
  let keys = l.keys and s = l.size in
  let l =
    if s > 0 && l.kids = [||]
       && (keys.(0) < a || (keys.(0) = a && keys.(1) <= b))
       && (keys.(2 * (s - 1)) > a || (keys.(2 * (s - 1)) = a && keys.((2 * (s - 1)) + 1) >= b))
    then l
    else begin
      let l = leaf2 t.root a b in
      h.last <- l;
      l
    end in
  let k = lower2 l a b in
  k < l.size && l.keys.(2 * k) = a && l.keys.((2 * k) + 1) = b
