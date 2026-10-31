(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Index.mli *)

(* order.(j): the column at place j, the key's first; at.(c): the place
 * of column c *)
type t = { key : int; order : int array; at : int array; tree : Btree.t }

let create (arity : int) (cols : int array) : t =
  let rest = List.filter (fun (c : int) -> not (Array.mem c cols)) (List.init arity (fun (c : int) -> c)) in
  let order = Array.append cols (Array.of_list rest) in
  let at = Array.make arity 0 in
  Array.iteri (fun (j : int) (c : int) -> at.(c) <- j) order;
  { key = Array.length cols; order; at; tree = Btree.create arity }

let add (t : t) (value : int -> int) : unit =
  if Array.length t.order = 2 then ignore (Btree.add2 t.tree (value t.order.(0)) (value t.order.(1)))
  else ignore (Btree.add_by t.tree (fun (j : int) -> value t.order.(j)))
let iter (t : t) (key : int -> int) (f : int array -> int -> unit) : unit = Btree.iter_prefix t.tree t.key key f
let exists (t : t) (key : int -> int) : bool = Btree.exists_prefix t.tree t.key key
let at (t : t) : int array = t.at
let part_of (t : t) (value : int -> int) : int = Btree.part_of t.tree (fun (j : int) -> value t.order.(j))
