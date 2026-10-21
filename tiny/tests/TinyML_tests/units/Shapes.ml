(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* A unit for TinyML_test.sh's separate compilation: a variant, a record,
 * an exception, a function of two arguments, a value computed at its
 * init, a type's second name with a parameter, and a function nothing
 * uses (left out by tiny-linker) *)

type shape = Square of int | Rect of int * int | Dot
type box = { name : string; shape : shape }
exception Empty of string
type 'a pair = 'a * 'a

let area s = match s with Square n -> n * n | Rect (w, h) -> w * h | Dot -> 0
let scaled k s =
  match s with
  | Square n -> Square (k * n)
  | Rect (w, h) -> Rect (k * w, k * h)
  | Dot -> Dot
let boxes = [ { name = "a"; shape = Square 3 }; { name = "b"; shape = Rect (2, 5) } ]
let largest l =
  match l with
  | [] -> raise (Empty "no box")
  | b :: l ->
    List.fold_left (fun m b -> if area b.shape > area m.shape then b else m) b l
let sides s : int pair =
  match s with Square n -> n, n | Rect (w, h) -> w, h | Dot -> 0, 0
let unused x = x + 41
