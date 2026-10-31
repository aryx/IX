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

(* one tree a part: a tuple's part by its first value's hash *)
type tree = { mutable root : node; mutable count : int }
type t = { w : int; part : tree array }

(* the leaf last seen, and its part *)
type hint = { mutable last : node; mutable in_part : int }

(* the tuples of a leaf, the separators of an inner node, at most *)
let cap = 32

(* (not n.kids = [||]: that is the polymorphic compare, a call into the
 * runtime at each node of each descent, 5% of a run's instructions) *)
let is_leaf (n : node) : bool = Array.length n.kids = 0

let leaf (w : int) : node = { size = 0; keys = Array.make (cap * w) 0; kids = [||]; next = None }

let create (w : int) : t = { w; part = Array.init Tuples.parts (fun (_ : int) -> { root = leaf w; count = 0 }) }
let width (t : t) : int = t.w
let count (t : t) : int = Array.fold_left (fun (n : int) (tr : tree) -> n + tr.count) 0 t.part
let hint (t : t) : hint = { last = t.part.(0).root; in_part = -1 }

(* (a multiply and a shift: the bits of v mixed into the 6 taken; in
 * mini-ml's 31 bits of arm too) *)
let part_of_first (w : int) (v : int) : int = if w = 0 then 0 else ((v * 40503) lxor (v lsr 9)) lsr 4 land (Tuples.parts - 1)
let part_of (t : t) (value : int -> int) : int = if t.w = 0 then 0 else part_of_first t.w (value 0)

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
  if is_leaf n then n else leaf_of w n.kids.(child w n value) value

let in_leaf (w : int) (l : node) (value : int -> int) : bool =
  let k = lower w l value in
  k < l.size && compare_at w l.keys k value = 0

let mem_by (t : t) (value : int -> int) : bool =
  in_leaf t.w (leaf_of t.w t.part.(part_of t value).root value) value

(* (the hint first: a leaf holds every tuple of its part between its
 * first and its last, so a tuple in that span is there or nowhere) *)
let mem_hint (t : t) (h : hint) (value : int -> int) : bool =
  let w = t.w and l = h.last and p = part_of t value in
  if h.in_part = p && l.size > 0 && compare_at w l.keys 0 value <= 0 && compare_at w l.keys (l.size - 1) value >= 0 then
    in_leaf w l value
  else begin
    let l = leaf_of w t.part.(p).root value in
    h.last <- l;
    h.in_part <- p;
    in_leaf w l value
  end

(*****************************************************************************)
(* Adding *)
(*****************************************************************************)

(* integers moved within an array or to another, the last first (the
 * ranges may overlap, to the right). Not Array.blit: on an array of the
 * major heap, 4.14's passes each value through the collector's
 * barrier (caml_modify), not knowing they are integers: with the
 * leaves' shifts, 11% of a run *)
let move (src : int array) (from : int) (dst : int array) (into : int) (len : int) : unit =
  for i = len - 1 downto 0 do
    dst.(into + i) <- src.(from + i)
  done

(* the values put at slot k of a node, those from k on moved right *)
let put (w : int) (n : node) (k : int) (value : int -> int) : unit =
  move n.keys (k * w) n.keys ((k + 1) * w) ((n.size - k) * w);
  for i = 0 to w - 1 do
    n.keys.((k * w) + i) <- value i
  done;
  n.size <- n.size + 1

(* an insertion's overflow: the new right half of the node and its
 * first tuple, for the parent *)
type split = { sep : int array; right : node }

(* the searches in a node given (a closure called a node, not a value:
 * a pair's are written out, add2): [low] the first slot at or above
 * the tuple, [at] whether slot k is the tuple, [down] the child *)
let rec insert (w : int) (n : node) (value : int -> int) (fresh : bool ref) (low : node -> int) (at : node -> int -> bool)
    (down : node -> int) : split option =
  if is_leaf n then begin
    let k = low n in
    if k < n.size && at n k then None
    else begin
      fresh := true;
      put w n k value;
      if n.size < cap then None
      else begin
        (* half to a new leaf on the right *)
        let half = cap / 2 in
        let r = leaf w in
        move n.keys (half * w) r.keys 0 ((n.size - half) * w);
        r.size <- n.size - half;
        n.size <- half;
        r.next <- n.next;
        n.next <- Some r;
        Some { sep = Array.sub r.keys 0 w; right = r }
      end
    end
  end
  else begin
    let i = down n in
    match insert w n.kids.(i) value fresh low at down with
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
          move n.keys ((half + 1) * w) r.keys 0 ((n.size - half - 1) * w);
          Array.blit n.kids (half + 1) r.kids 0 (n.size - half);
          r.size <- n.size - half - 1;
          n.size <- half;
          Some { sep; right = r }
        end
  end

let add_in (t : t) (p : int) (value : int -> int) (low : node -> int) (at : node -> int -> bool) (down : node -> int) : bool =
  let w = t.w and tr = t.part.(p) in
  let fresh = ref false in
  (match insert w tr.root value fresh low at down with
   | None -> ()
   | Some s ->
       let root = { size = 1; keys = Array.make (cap * w) 0; kids = Array.make (cap + 1) tr.root; next = None } in
       move s.sep 0 root.keys 0 w;
       root.kids.(1) <- s.right;
       tr.root <- root);
  if !fresh then tr.count <- tr.count + 1;
  !fresh

let add_by (t : t) (value : int -> int) : bool =
  let w = t.w in
  add_in t (part_of t value) value (fun (n : node) -> lower w n value)
    (fun (n : node) (k : int) -> compare_at w n.keys k value = 0)
    (fun (n : node) -> child w n value)

(*****************************************************************************)
(* Ranges *)
(*****************************************************************************)

(* the first n values against the values *)
let same_prefix (keys : int array) (base : int) (n : int) (value : int -> int) : bool =
  let rec go (i : int) : bool = i = n || (keys.(base + i) = value i && go (i + 1)) in
  go 0

(* the leaf and slot of the first tuple at or above the n values *)
let start (t : t) (n : int) (value : int -> int) : node * int =
  let low (i : int) : int = if i < n then value i else min_int in
  let l = leaf_of t.w t.part.(part_of t value).root low in
  (l, lower t.w l low)

(* a range on the first value alone, written out *)
let iter_first (t : t) (v : int) (f : int array -> int -> unit) : unit =
  let w = t.w in
  let rec down (n : node) : node =
    if is_leaf n then n
    else begin
      let lo = ref 0 and hi = ref n.size in
      while !lo < !hi do
        let mid = (!lo + !hi) lsr 1 in
        if n.keys.(mid * w) < v then lo := mid + 1 else hi := mid
      done;
      down n.kids.(!lo)
    end in
  let l = down t.part.(part_of_first w v).root in
  let lo = ref 0 and hi = ref l.size in
  while !lo < !hi do
    let mid = (!lo + !hi) lsr 1 in
    if l.keys.(mid * w) < v then lo := mid + 1 else hi := mid
  done;
  let rec go (l : node) (k : int) : unit =
    if k < l.size then begin
      if l.keys.(k * w) = v then begin
        f l.keys (k * w);
        go l (k + 1)
      end
    end
    else match l.next with Some r -> go r 0 | None -> () in
  go l !lo

let iter_prefix (t : t) (n : int) (value : int -> int) (f : int array -> int -> unit) : unit =
  if n = 1 then iter_first t (value 0) f else
  let w = t.w in
  let rec go (l : node) (k : int) : unit =
    if k < l.size then begin
      if same_prefix l.keys (k * w) n value then begin
        f l.keys (k * w);
        go l (k + 1)
      end
    end
    else match l.next with Some r -> go r 0 | None -> () in
  let l, k = start t n value in
  go l k

let exists_prefix (t : t) (n : int) (value : int -> int) : bool =
  let w = t.w in
  let rec first (l : node) (k : int) : bool =
    if k < l.size then same_prefix l.keys (k * w) n value
    else match l.next with Some r -> first r 0 | None -> false in
  let l, k = start t n value in
  first l k

(*****************************************************************************)
(* Pairs, written out *)
(*****************************************************************************)

(* pairs: the searches with the comparisons inline, no closure called for
 * each value (what Souffle's C++ templates make for each arity;
 * mini-ml has no functors) *)
let lower2 (n : node) (a : int) (b : int) : int =
  let keys = n.keys in
  let lo = ref 0 and hi = ref n.size in
  while !lo < !hi do
    let mid = (!lo + !hi) lsr 1 in
    let x = keys.(2 * mid) in
    if x < a || (x = a && keys.((2 * mid) + 1) < b) then lo := mid + 1 else hi := mid
  done;
  !lo

let child2 (n : node) (a : int) (b : int) : int =
  let keys = n.keys in
  let lo = ref 0 and hi = ref n.size in
  while !lo < !hi do
    let mid = (!lo + !hi) lsr 1 in
    let x = keys.(2 * mid) in
    if x < a || (x = a && keys.((2 * mid) + 1) <= b) then lo := mid + 1 else hi := mid
  done;
  !lo

let rec leaf2 (n : node) (a : int) (b : int) : node = if is_leaf n then n else leaf2 n.kids.(child2 n a b) a b

let mem2_hint (t : t) (h : hint) (a : int) (b : int) : bool =
  let l = h.last and p = part_of_first 2 a in
  let keys = l.keys and s = l.size in
  let l =
    if h.in_part = p && s > 0
       && (keys.(0) < a || (keys.(0) = a && keys.(1) <= b))
       && (keys.(2 * (s - 1)) > a || (keys.(2 * (s - 1)) = a && keys.((2 * (s - 1)) + 1) >= b))
    then l
    else begin
      let l = leaf2 t.part.(p).root a b in
      h.last <- l;
      h.in_part <- p;
      l
    end in
  let k = lower2 l a b in
  k < l.size && l.keys.(2 * k) = a && l.keys.((2 * k) + 1) = b

let add2 (t : t) (a : int) (b : int) : bool =
  add_in t (part_of_first 2 a)
    (fun (i : int) -> if i = 0 then a else b)
    (fun (n : node) -> lower2 n a b)
    (fun (n : node) (k : int) -> n.keys.(2 * k) = a && n.keys.((2 * k) + 1) = b)
    (fun (n : node) -> child2 n a b)
