(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Tuples.mli *)

(* slot k is cells.(k * arity) to cells.(k * arity + arity - 1); a free
 * one has -1 first (a symbol is not negative). An arity 0 has one tuple
 * or none: [count] says. *)
type t = { arity : int; mutable cells : int array; mutable size : int; mutable count : int }

let create (arity : int) : t = { arity; cells = Array.make (64 * arity) (-1); size = 64; count = 0 }
let count (t : t) : int = t.count

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

(* the slot of the tuple, or the free one where it would go *)
let find (t : t) (value : int -> int) : int =
  let mask = t.size - 1 and n = t.arity and cells = t.cells in
  let rec same (base : int) (i : int) : bool = i = n || (cells.(base + i) = value i && same base (i + 1)) in
  let rec walk (k : int) : int = if cells.(k * n) < 0 || same (k * n) 0 then k else walk ((k + 1) land mask) in
  walk (hash n value land mask)

let mem_by (t : t) (value : int -> int) : bool =
  if t.arity = 0 then t.count > 0 else t.cells.(find t value * t.arity) >= 0

let mem (t : t) (tuple : int array) : bool = mem_by t (fun (i : int) -> tuple.(i))

let put (t : t) (k : int) (value : int -> int) : unit =
  for i = 0 to t.arity - 1 do
    t.cells.((k * t.arity) + i) <- value i
  done

(* twice the slots, each tuple put again *)
let grow (t : t) : unit =
  let old = t.cells and n = t.arity and size = t.size in
  t.size <- 2 * size;
  t.cells <- Array.make (t.size * n) (-1);
  for k = 0 to size - 1 do
    if old.(k * n) >= 0 then begin
      let value (i : int) : int = old.((k * n) + i) in
      put t (find t value) value
    end
  done

let add (t : t) (tuple : int array) : bool =
  if t.arity = 0 then begin
    let fresh = t.count = 0 in
    t.count <- 1;
    fresh
  end
  else begin
    let value (i : int) : int = tuple.(i) in
    let k = find t value in
    if t.cells.(k * t.arity) >= 0 then false
    else begin
      put t k value;
      t.count <- t.count + 1;
      if 2 * t.count > t.size then grow t;
      true
    end
  end
