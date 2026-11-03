(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tuples.mli *)

(* the parts, a power of two: a tuple's is its hash's low bits *)
let parts = 64
let part_bits = 6

(* slot k of a part is cells.(k * arity) to cells.(k * arity + arity - 1);
 * a free one has -1 first (a symbol is not negative). An arity 0 has
 * one tuple or none: part 0's [count] says. *)
type part = { mutable cells : int array; mutable size : int; mutable count : int }
type t = { arity : int; part : part array }

let create (arity : int) : t =
  { arity; part = Array.init parts (fun (_ : int) -> { cells = Array.make (8 * arity) (-1); size = 8; count = 0 }) }

let arity (t : t) : int = t.arity
let count (t : t) : int = Array.fold_left (fun (n : int) (p : part) -> n + p.count) 0 t.part

(* each column's value in turn, then the high bits brought down, so
 * that the slots' low bits depend on all of them (the constants fit
 * in mini-ml's 31 bits of arm) *)
let hash (arity : int) (value : int -> int) : int =
  let h = ref arity in
  for i = 0 to arity - 1 do
    h := (!h * 1000003) + value i
  done;
  let h = (!h lxor (!h lsr 16)) * 73244475 in
  (h lxor (h lsr 16)) land max_int

(* hash and find of a tuple in an array, written out: no closure called
 * for each value (mem2's measure, for any arity; on .NET a closure is
 * an object and a delegate's call: mini-datalog -dotnet's loops) *)
let hash_array (n : int) (a : int array) : int =
  let h = ref n in
  for i = 0 to n - 1 do
    h := (!h * 1000003) + a.(i)
  done;
  let h = (!h lxor (!h lsr 16)) * 73244475 in
  (h lxor (h lsr 16)) land max_int

(* (loops: a local rec function of the free cells, n and a was a closure
 * made at each call, the most allocated words of mini-prolog's -exn;
 * old: let rec same base i = ... and walk k = ... in walk start) *)
let find_array (n : int) (p : part) (h : int) (a : int array) : int =
  let mask = p.size - 1 and cells = p.cells in
  let k = ref ((h lsr part_bits) land mask) and found = ref false in
  while not !found do
    let base = !k * n in
    if cells.(base) < 0 then found := true
    else begin
      let i = ref 0 in
      while !i < n && cells.(base + !i) = a.(!i) do
        incr i
      done;
      if !i = n then found := true else k := (!k + 1) land mask
    end
  done;
  !k

let part_of (t : t) (value : int -> int) : int = if t.arity = 0 then 0 else hash t.arity value land (parts - 1)

(* in part p, the slot of the tuple, or the free one where it would go *)
let find (n : int) (p : part) (h : int) (value : int -> int) : int =
  let mask = p.size - 1 and cells = p.cells in
  let rec same (base : int) (i : int) : bool = i = n || (cells.(base + i) = value i && same base (i + 1)) in
  let rec walk (k : int) : int = if cells.(k * n) < 0 || same (k * n) 0 then k else walk ((k + 1) land mask) in
  walk ((h lsr part_bits) land mask)

let mem_by (t : t) (value : int -> int) : bool =
  if t.arity = 0 then t.part.(0).count > 0
  else
    let h = hash t.arity value in
    let p = t.part.(h land (parts - 1)) in
    p.cells.(find t.arity p h value * t.arity) >= 0

(* old: mem_by t (fun (i : int) -> tuple.(i)) *)
let mem (t : t) (tuple : int array) : bool =
  if t.arity = 0 then t.part.(0).count > 0
  else
    let h = hash_array t.arity tuple in
    let p = t.part.(h land (parts - 1)) in
    p.cells.(find_array t.arity p h tuple * t.arity) >= 0

let put (n : int) (p : part) (k : int) (value : int -> int) : unit =
  for i = 0 to n - 1 do
    p.cells.((k * n) + i) <- value i
  done

(* twice the part's slots, each tuple put again *)
let grow (n : int) (p : part) : unit =
  let old = p.cells and size = p.size in
  p.size <- 2 * size;
  p.cells <- Array.make (p.size * n) (-1);
  for k = 0 to size - 1 do
    if old.(k * n) >= 0 then begin
      let value (i : int) : int = old.((k * n) + i) in
      put n p (find n p (hash n value) value) value
    end
  done

let add (t : t) (tuple : int array) : bool =
  if t.arity = 0 then begin
    let p = t.part.(0) in
    let fresh = p.count = 0 in
    p.count <- 1;
    fresh
  end
  else begin
    (* (old: through a closure of the tuple, hash and find's) *)
    let n = t.arity in
    let h = hash_array n tuple in
    let p = t.part.(h land (parts - 1)) in
    let k = find_array n p h tuple in
    if p.cells.(k * n) >= 0 then false
    else begin
      Array.blit tuple 0 p.cells (k * n) n;
      p.count <- p.count + 1;
      if 2 * p.count > p.size then grow n p;
      true
    end
  end

(* mem_by for pairs, written out (Btree.mem2_hint's measure: what a
 * test costs with no closure called for each value) *)
let mem2 (t : t) (a : int) (b : int) : bool =
  let h = (((2 * 1000003) + a) * 1000003) + b in
  let h = (h lxor (h lsr 16)) * 73244475 in
  let h = (h lxor (h lsr 16)) land max_int in
  let p = t.part.(h land (parts - 1)) in
  let mask = p.size - 1 and cells = p.cells in
  let rec walk (k : int) : bool =
    let x = cells.(2 * k) in
    if x < 0 then false else if x = a && cells.((2 * k) + 1) = b then true else walk ((k + 1) land mask) in
  walk ((h lsr part_bits) land mask)
