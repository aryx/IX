(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Index.mli *)

(* slot k of a part is cells.(k * (n + 1)) to cells.(k * (n + 1) + n):
 * the key's n values, then the last tuple's number, -1 when the slot is
 * free. The parts are Tuples's: a key's by its hash's low bits. *)
type part = { mutable cells : int array; mutable size : int; mutable keys : int }

type t = {
  n : int;
  part : part array;
  mutable chain : int array;     (* by tuple: the one before with its key *)
}

let create (n : int) : t =
  { n; part = Array.init Tuples.parts (fun (_ : int) -> { cells = Array.make (8 * (n + 1)) (-1); size = 8; keys = 0 });
    chain = Array.make 64 (-1) }

let part_of (t : t) (value : int -> int) : int = Tuples.hash t.n value land (Tuples.parts - 1)

(* in part p, the slot of the key, or the free one where it would go *)
let find (n : int) (p : part) (h : int) (value : int -> int) : int =
  let mask = p.size - 1 and w = n + 1 and cells = p.cells in
  let rec same (base : int) (i : int) : bool = i = n || (cells.(base + i) = value i && same base (i + 1)) in
  let rec walk (k : int) : int = if cells.((k * w) + n) < 0 || same (k * w) 0 then k else walk ((k + 1) land mask) in
  walk ((h lsr Tuples.part_bits) land mask)

let first (t : t) (value : int -> int) : int =
  let h = Tuples.hash t.n value in
  let p = t.part.(h land (Tuples.parts - 1)) in
  p.cells.((find t.n p h value * (t.n + 1)) + t.n)

let next (t : t) (id : int) : int = t.chain.(id)

(* room in the chain for the tuples numbered below [count] *)
let reserve (t : t) (count : int) : unit =
  if count > Array.length t.chain then begin
    let larger = Array.make (max count (2 * Array.length t.chain)) (-1) in
    Array.blit t.chain 0 larger 0 (Array.length t.chain);
    t.chain <- larger
  end

(* twice the part's slots, each key put again *)
let grow (n : int) (p : part) : unit =
  let old = p.cells and w = n + 1 and size = p.size in
  p.size <- 2 * size;
  p.cells <- Array.make (p.size * w) (-1);
  for k = 0 to size - 1 do
    if old.((k * w) + n) >= 0 then begin
      let value (i : int) : int = old.((k * w) + i) in
      Array.blit old (k * w) p.cells (find n p (Tuples.hash n value) value * w) w
    end
  done

let add (t : t) (value : int -> int) (id : int) : unit =
  reserve t (id + 1);
  let n = t.n and w = t.n + 1 in
  let h = Tuples.hash n value in
  let p = t.part.(h land (Tuples.parts - 1)) in
  let k = find n p h value in
  let head = p.cells.((k * w) + n) in
  t.chain.(id) <- head;
  if head < 0 then begin
    for i = 0 to n - 1 do
      p.cells.((k * w) + i) <- value i
    done;
    p.keys <- p.keys + 1
  end;
  p.cells.((k * w) + n) <- id;
  if head < 0 && 2 * p.keys > p.size then grow n p
