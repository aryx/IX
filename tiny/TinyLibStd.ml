(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* TinyLibStd: what a tool names of OCaml's standard library beyond
 * TinyLibCore, in tiny-ml's ML, for a tool built for tiny-machine
 * (tiny-shell): List's and String's other functions, Buffer, Hashtbl.
 * The same names and the same results as OCaml's, so that one file of
 * a tool is built by OCaml on its own library for the host, and by
 * tiny-ml with this file given before it:
 *
 *   tiny-ml -tm -o sh.tm TinyLibStd.ml ... TinyShell.ml
 *
 * A file a program asks for, as TinyLibGUI, and not in the prelude,
 * which is compiled whole in every program: the calculator has no use
 * for a Hashtbl. Not OCaml's to compile (List.init is one name here),
 * so no .mli beside it.
 *
 * Simple before fast: a Buffer is a string that grows by ^ (the
 * runtime has no string to write in), a Hashtbl a list of pairs. A
 * shell's lines and variables are few and short.
 *)

(*****************************************************************************)
(* Option, List *)
(*****************************************************************************)

let Option.get = function Some x -> x | None -> invalid_arg "option is None"

(* Common's: the option's value, or a default *)
let ( ||| ) o default = match o with Some x -> x | None -> default

let List.concat_map f l = List.concat (List.map f l)
let List.filteri p l =
  let rec go i = function [] -> [] | x :: l -> if p i x then x :: go (i + 1) l else go (i + 1) l in
  go 0 l
let List.init n f = let rec go i = if i >= n then [] else let x = f i in x :: go (i + 1) in go 0
let rec List.assoc_opt x = function [] -> None | (a, b) :: l -> if a = x then Some b else List.assoc_opt x l
let rec List.nth_opt l n = match l with [] -> None | x :: l -> if n = 0 then Some x else List.nth_opt l (n - 1)
let rec List.map2 f l1 l2 =
  match l1, l2 with
  | [], [] -> []
  | x :: l1, y :: l2 -> let z = f x y in z :: List.map2 f l1 l2
  | _ -> invalid_arg "List.map2"

(*****************************************************************************)
(* String *)
(*****************************************************************************)

let String.index_from_opt s i c =
  let n = String.length s in
  let rec go i = if i >= n then None else if s.[i] = c then Some i else go (i + 1) in
  if i < 0 || i > n then invalid_arg "String.index_from_opt" else go i
let String.index_opt s c = String.index_from_opt s 0 c
let String.index_from s i c = match String.index_from_opt s i c with Some j -> j | None -> raise Not_found
let String.contains s c = match String.index_opt s c with Some _ -> true | None -> false
let String.exists p s = let n = String.length s in let rec go i = i < n && (p s.[i] || go (i + 1)) in go 0
let String.for_all p s = let n = String.length s in let rec go i = i >= n || (p s.[i] && go (i + 1)) in go 0
let String.iter f s = for i = 0 to String.length s - 1 do f s.[i] done
let String.concat sep = function [] -> "" | x :: l -> List.fold_left (fun acc y -> acc ^ sep ^ y) x l

(* from the end, so that the list is in order: j is where the piece
 * being read ends *)
let String.split_on_char c s =
  let rec go j i acc =
    if i < 0 then String.sub s 0 j :: acc
    else if s.[i] = c then go i (i - 1) (String.sub s (i + 1) (j - i - 1) :: acc)
    else go j (i - 1) acc
  in
  go (String.length s) (String.length s - 1) []

(*****************************************************************************)
(* Buffer *)
(*****************************************************************************)

type Buffer.t = { mutable buffer_text : string }

let Buffer.create _ = { buffer_text = "" }
let Buffer.add_string b s = b.buffer_text <- b.buffer_text ^ s
let Buffer.add_char b c = b.buffer_text <- b.buffer_text ^ String.make 1 c
let Buffer.contents b = b.buffer_text
let Buffer.length b = String.length b.buffer_text
let Buffer.clear b = b.buffer_text <- ""

(*****************************************************************************)
(* Hashtbl *)
(*****************************************************************************)

(* a key once: replace is the only way in (no add, which would hide) *)
type ('a, 'b) Hashtbl.t = { mutable table_pairs : ('a * 'b) list }

let Hashtbl.create _ = { table_pairs = [] }
let Hashtbl.find_opt h k = List.assoc_opt k h.table_pairs
let Hashtbl.find h k = List.assoc k h.table_pairs
let Hashtbl.mem h k = List.exists (fun (a, _) -> a = k) h.table_pairs
let Hashtbl.remove h k = h.table_pairs <- List.filter (fun (a, _) -> a <> k) h.table_pairs
let Hashtbl.replace h k v = Hashtbl.remove h k; h.table_pairs <- (k, v) :: h.table_pairs
let Hashtbl.fold f h acc = List.fold_left (fun acc (k, v) -> f k v acc) acc h.table_pairs
