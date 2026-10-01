(* type-directed fields: r.l and r.l <- v take l in r's type, when it
 * is known: a field of a type not in scope (another module's), and a
 * field two types have *)

module Geo = struct
  type point = { x : int; mutable y : int }
  type box = { min : point; max : point; name : string }
  let origin = { x = 0; y = 0 }
  let box name min max = { min; max; name }
end

module Dev = struct
  type t = { name : string; mutable count : int; read : int -> string }
end

(* two types of this file with the same fields: the last is q *)
type p = { id : int; mutable tag : string }
(* a p made here, before q: a record written { ... } is not type-directed *)
let p id tag = { id; tag }
type q = { id : string; tag : int; more : bool }

(* a parameter's annotation *)
let width (b : Geo.box) = b.max.x - b.min.x
let move (pt : Geo.point) dy = pt.y <- pt.y + dy; pt.y
let name_of (d : Dev.t) = d.name ^ "/" ^ string_of_int d.count

(* what came before: a function's result, a let's annotation, a field's type *)
let area () =
  let b = Geo.box "b" Geo.origin { Geo.x = 3; y = 4 } in
  (b.max.x - b.min.x) * (b.max.y - b.min.y)

let twice (devs : Dev.t list) = List.iter (fun (d : Dev.t) -> d.count <- 2 * d.count) devs

(* the same field in two types: the annotation's, not the last declared *)
let pid (r : p) = r.id + 1
let qid (r : q) = r.id ^ "!"
let retag (r : p) s = r.tag <- s; r.tag
let last r = r.more && r.tag > 0 (* no annotation: q's, the last *)

let () =
  let b = Geo.box "unit" Geo.origin { Geo.x = 5; y = 7 } in
  let pt = { Geo.x = 1; y = 2 } in
  let d = { Dev.name = "tty"; count = 3; read = (fun n -> String.make n 'r') } in
  Printf.printf "%d %d %d %s\n" (width b) (move pt 10) (move pt 0) (name_of d);
  twice [ d; d ];
  Printf.printf "%d %d %s %s\n" (area ()) d.count (d.read 3) b.name;
  let r = p 41 "a" in
  Printf.printf "%d %s %s %s %b\n" (pid r) (qid { id = "q"; tag = 1; more = true }) (retag r "b") r.tag
    (last { id = "q"; tag = 1; more = true })
