(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Relset.mli *)

type t = Hashed of Tuples.t | Sorted of Btree.t

let create ~(sorted : bool) (n : int) : t = if sorted then Sorted (Btree.create n) else Hashed (Tuples.create n)
let sorted (t : t) : bool = match t with Sorted _ -> true | Hashed _ -> false

let mem_by (t : t) (value : int -> int) : bool =
  match t with Hashed s -> Tuples.mem_by s value | Sorted b -> Btree.mem_by b value

(* the same of a tuple in an array (a hashed set's: no closure) *)
let mem_array (t : t) (tuple : int array) : bool =
  match t with Hashed s -> Tuples.mem s tuple | Sorted b -> Btree.mem_by b (fun (i : int) -> tuple.(i))

(* (a hashed set's: none) *)
type hint = Btree.hint option

let hint (t : t) : hint = match t with Sorted b -> Some (Btree.hint b) | Hashed _ -> None

let mem_hint (t : t) (h : hint) (value : int -> int) : bool =
  match (t, h) with
  | Sorted b, Some h -> if Btree.width b = 2 then Btree.mem2_hint b h (value 0) (value 1) else Btree.mem_hint b h value
  | Hashed s, _ -> if Tuples.arity s = 2 then Tuples.mem2 s (value 0) (value 1) else Tuples.mem_by s value
  | Sorted b, None -> Btree.mem_by b value

let add (t : t) (tuple : int array) : bool =
  match t with
  | Hashed s -> Tuples.add s tuple
  | Sorted b -> if Btree.width b = 2 then Btree.add2 b tuple.(0) tuple.(1) else Btree.add_by b (fun (i : int) -> tuple.(i))

let part_of (t : t) (value : int -> int) : int =
  match t with Hashed s -> Tuples.part_of s value | Sorted b -> Btree.part_of b value
