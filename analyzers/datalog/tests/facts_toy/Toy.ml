(* The example of analyzers/datalog/FACTS.md: each kind of fact mini-ml says. *)
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

(* == with a side made in the comparison: always false (bugs/physeq.dl) *)
let is_one (o : int option) = o == Some 1

(* a chain walked by a call a link; a handler calling back (bugs/stack.dl) *)
type chain = End | Link of int * chain
let rec size (c : chain) = match c with End -> 0 | Link (_, c) -> 1 + size c
let rec retry n = try if n = 0 then 0 else raise Exit with Exit -> retry (n - 1)

(* a primitive that raises, Sys_error; a try silencing it (bugs/swallowed.dl) *)
external remove : string -> unit = "sys_remove" [@@raise Sys_error]
let clean f = try remove f with Sys_error _ -> () | _ -> ()

(* 32 bits, -1 on the Pi 1; a test of the ints' width (bugs/intwidth.dl) *)
let mask = 0xffffffff
let low w = if Sys.int_size >= 63 then Hashtbl.hash (w lsr 32) else w

(* a table walked into a list, marshalled sharing (bugs/order.dl) *)
let names (t : (string, int) Hashtbl.t) = Hashtbl.fold (fun k _ acc -> k :: acc) t []
let saved (l : string list) = Marshal.to_string (List.rev l) []

(* a ref written, a wait in a while (bugs/races.dl) *)
let ready = ref 0
let take m c = while !ready = 0 do Condition.wait c m done; ready := 0

(* a channel closed before one raise, held during another (bugs/pairs.dl) *)
let first_line f =
  let ic = open_in f in
  if f = "" then (close_in ic; failwith "no name")
  else (let l = input_line ic in close_in ic; l)
let line = first_line "Toy.ml"
