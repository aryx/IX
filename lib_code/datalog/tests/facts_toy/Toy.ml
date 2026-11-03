(* The example of lib_code/datalog/FACTS.md: each kind of fact mini-ml says. *)
type shape = Circle of int | Empty
type box = { mutable fn : int -> int; label : string }

let inc n = n + 1
let add a b = a + b

let apply f x = f x

let make f = { fn = f; label = "box" }

let area s = match s with Circle r -> r * r | Empty -> 0

let say (caps : < Cap.stdout; .. >) s = Console.print caps s

let safe f = try f 1 with Not_found -> 0

(* the -flow facts are shown of this one *)
let rec sum n acc = if n = 0 then acc else sum (n - 1) (acc + n)

let pair = (inc, 2)
let (first, _) = pair
let counter = ref 0

let () =
  let b = make inc in
  b.fn <- add 1;
  counter := apply b.fn (first 2);
  ignore (List.map (fun n -> n * 2) [ area (Circle 1); area Empty; safe inc ]);
  ignore (Sys.getenv "HOME"); ignore (sum 3 0);
  Cap.main (fun caps -> say caps "done")

(* an array, its elements one field of it; raise and what a handler catches *)
let table = [| inc; add 1 |]
let lookup k = if k < 2 then table.(k) else raise Not_found
let found = try lookup 0 with e -> raise e

(* a capability held in a record's field *)
type env = { caps : < Cap.stdout; .. >; name : string }
let greet (e : env) = Console.print e.caps e.name

(* == with a side made in the comparison: always false (physeq.dl) *)
let is_one (o : int option) = o == Some 1
