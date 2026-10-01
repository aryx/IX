(* type-directed constructors and records: a constructor, or a record
 * written or matched whole, of the type expected there, when that type
 * is written: an annotation, a val's or a function's parameter, a
 * field's or a constructor's argument *)

module Obj = struct
  type kind = Commit | Tree | Blob of int | Tag of string * int
  type t = { kind : kind; size : int; name : string }
  type 'a entry = Leaf of 'a | Node of 'a entry list
  let code (k : kind) = match k with Commit -> 1 | Tree -> 2 | Blob n -> 3 + n | Tag (_, n) -> 100 + n
  let make (kind : kind) (size : int) : t = { kind; size; name = "o" }
  let kind_of (o : t) : kind = o.kind
  let depth (e : kind entry) : int = match e with Leaf _ -> 0 | Node l -> List.length l
end

(* two types of this file with the same constructors and fields; the
 * last declared is the scope's *)
type color = Red | Green | Other of string
type light = Red | Amber | Green
type point = { x : int; y : int }
type pixel = { x : int; y : int; c : color }

(* a parameter's annotation, a function's result's *)
let name (k : Obj.kind) : string = match k with Commit -> "commit" | Tree -> "tree" | Blob _ -> "blob" | Tag (s, _) -> s
let default () : Obj.kind = Tree
let pick b : Obj.kind = if b then Blob 4 else (print_string ""; Tag ("t", 2))

(* a function's annotation: its clauses' patterns, its results *)
let next : Obj.kind -> Obj.kind = function Commit -> Tree | Tree -> Blob 0 | Blob n -> Blob (n + 1) | Tag _ as t -> t

(* an argument: the parameter's type, of a val or of an annotated function *)
let codes () = [ Obj.code Commit; Obj.code (Blob 2); Obj.code (Tag ("v", 1)); String.length (name Tree) ]

(* a record written under its type, its fields' values under theirs *)
let o1 : Obj.t = { kind = Blob 7; size = 3; name = "b" }
let mk size : Obj.t = { kind = Commit; size; name = "c" }

(* a record matched, a field's type, a tuple's, an option's and a list's *)
let describe (o : Obj.t) = match o with { kind = Tag (s, _); _ } -> s | { kind = Blob n; size; _ } -> string_of_int (n + size) | { name; _ } -> name
let both (p : Obj.kind * Obj.kind) = match p with Commit, Commit -> 0 | Tree, _ -> 1 | _, Blob n -> n | _ -> -1
let first (l : Obj.kind list) = match l with Commit :: _ -> "c" | [ Tree; Tree ] -> "tt" | Blob _ :: Tag _ :: _ -> "bt" | _ -> "?"
let opt (k : Obj.kind option) = match k with Some Commit -> 1 | Some (Blob n) -> n | Some _ -> 2 | None -> 0
let all : Obj.kind list = [ Commit; Tree; Blob 1 ]
let pair : Obj.kind * int = (Tree, 1)

(* what is written before: a call's result, a field, a let's annotation *)
let via (o : Obj.t) =
  let n = match Obj.kind_of o with Commit -> 1 | Tree -> 2 | _ -> 3 in
  let m = match o.kind with Blob n -> n | _ -> 0 in
  let k : Obj.kind = Blob (n + m) in
  let j = Obj.kind_of o in
  n + m + Obj.code k + (match j with Blob _ -> 1000 | _ -> 0)

(* a type's parameter given by the expected type *)
let tree : Obj.kind Obj.entry = Node [ Leaf Commit; Leaf (Blob 1); Node [] ]

(* an earlier argument's type: = and List.mem's 'a, ! and := 's 'a ref *)
let is_tree (o : Obj.t) = o.kind = Tree || List.mem o.kind [ Commit; Tag ("m", 0) ]
let bump (r : Obj.kind ref) = (match !r with Blob n -> r := Blob (n + 1) | Commit | Tree -> r := Tree | Tag _ -> ()); Obj.code !r

(* a tuple matched, of a field and a call; a clause's M.C for the next ones *)
let shape (o : Obj.t) = match o.kind, Obj.kind_of o with Commit, _ -> "c" | Blob a, Blob b -> string_of_int (a + b) | _, Tree -> "t" | _ -> "-"
let short = function Obj.Commit -> 'c' | Tree -> 't' | Blob _ -> 'b' | Tag _ -> 'g'

(* a field assigned, under the field's type; { M.l = ...; l' } of M.l's
 * type though this file has an x and a size too *)
type shelf = { mutable kinds : Obj.kind list; mutable size : int }
let shelve (sh : shelf) = sh.kinds <- Blob sh.size :: Tree :: sh.kinds; sh.size <- List.length sh.kinds
let o2 = { Obj.kind = Tree; size = 2; name = "o2" }

(* [ M.C; C'; ... ]: M.C's type for the elements after *)
let kinds = [ Obj.Commit; Tree; Blob 3; Tag ("l", 1) ]

(* this file's own: color's Red and Green, though light's are the scope's *)
let paint (c : color) = match c with Red -> "red" | Green -> "green" | Other s -> s
let stop : color = Red
let go () : light = Green
let lights (l : light) = match l with Red -> 0 | Amber -> 1 | Green -> 2
let origin : point = { x = 0; y = 0 }
let px : pixel = { x = 1; y = 2; c = Green }
let sum (p : point) = match p with { x; y } -> x + y
let last = { x = 5; y = 6; c = Other "o" } (* no type written: pixel, the scope's *)

let () =
  Printf.printf "%s %s %s %s\n" (name (default ())) (name (pick true)) (name (pick false)) (name (next (next Commit)));
  print_endline (String.concat " " (List.map string_of_int (codes ())));
  Printf.printf "%s %s %s %d %d\n" (describe o1) (describe (mk 9)) (describe (Obj.make (Tag ("tag", 0)) 1)) (both (Tree, Commit)) (both (Commit, Blob 8));
  Printf.printf "%s %s %s %d %d %d\n" (first all) (first [ Tree; Tree ]) (first [ Blob 1; Tag ("x", 1) ]) (opt (Some (Blob 6))) (opt None) (opt (Some Tree));
  Printf.printf "%d %d %d %d\n" (via o1) (via (mk 0)) (Obj.depth tree) (Obj.code (fst pair) + snd pair);
  let r = ref (Obj.Blob 1) and sh = { kinds = []; size = 5 } in
  shelve sh;
  Printf.printf "%b %b %d %d %s %s %c%c %d %s\n" (is_tree o1) (is_tree (mk 1)) (bump r) (bump (ref (Obj.Tag ("t", 9)))) (shape o1) (shape o2)
    (short Tree) (short (Tag ("", 0))) sh.size (String.concat "" (List.map name sh.kinds));
  print_endline (String.concat " " (List.map name kinds));
  Printf.printf "%s %s %d %d %d %d %s\n" (paint stop) (paint px.c) (lights (go ())) (sum origin) (sum { x = 3; y = 4 }) last.x (paint last.c)

(* a let rec under its annotation; a function given under its parameter's
 * type: its own parameter's fields and constructors *)
let rec count : Obj.kind list -> int = function [] -> 0 | Blob n :: rest -> n + count rest | _ :: rest -> 1 + count rest
let each (f : Obj.t -> int) (l : Obj.t list) = List.fold_left (fun n o -> n + f o) 0 l
let () =
  Printf.printf "%d %d %d\n" (count kinds) (each (fun o -> o.size + String.length o.name) [ o1; o2 ])
    (each (fun o -> match o.kind with Blob n -> n | Tree -> 100 | _ -> 0) [ o1; o2 ])
