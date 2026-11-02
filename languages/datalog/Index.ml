(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Index.mli *)

(* a hashed index keeps its key's columns: its key is their values *)
type t = Hashed of int array * Hash_index.t | Sorted of Tree_index.t

(* a column's place in a row: its own *)
let same_place : int array = Array.init 63 (fun (c : int) -> c)

let create ~(sorted : bool) (arity : int) (cols : int array) : t =
  if sorted then Sorted (Tree_index.create arity cols) else Hashed (cols, Hash_index.create (Array.length cols))

let add (t : t) (value : int -> int) (id : int) : unit =
  match t with
  | Hashed (cols, h) -> Hash_index.add h (fun (i : int) -> value cols.(i)) id
  | Sorted s -> Tree_index.add s value

let iter (t : t) (rows : int array) (arity : int) (key : int -> int) (f : int array -> int -> unit) : unit =
  match t with
  | Hashed (_, h) ->
      let id = ref (Hash_index.first h key) in
      while !id >= 0 do
        f rows (!id * arity);
        id := Hash_index.next h !id
      done
  | Sorted s -> Tree_index.iter s key f

(* a hashed index's chain, walked by its caller (mini-datalog -dotnet's
 * compiled loops): the last tuple with the key, the one before *)
let first (t : t) (key : int -> int) : int =
  match t with Hashed (_, h) -> Hash_index.first h key | Sorted _ -> invalid_arg "Index.first: sorted"

let next (t : t) (id : int) : int = match t with Hashed (_, h) -> Hash_index.next h id | Sorted _ -> -1

let exists (t : t) (key : int -> int) : bool =
  match t with Hashed (_, h) -> Hash_index.first h key >= 0 | Sorted s -> Tree_index.exists s key

let at (t : t) : int array = match t with Hashed _ -> same_place | Sorted s -> Tree_index.at s

let part_of (t : t) (value : int -> int) : int =
  match t with Hashed (cols, h) -> Hash_index.part_of h (fun (i : int) -> value cols.(i)) | Sorted s -> Tree_index.part_of s value

let reserve (t : t) (count : int) : unit = match t with Hashed (_, h) -> Hash_index.reserve h count | Sorted _ -> ()
