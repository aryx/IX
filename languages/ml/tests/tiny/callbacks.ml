(* C calls ML (the runtime's callback and callback2, a kernel's way
 * into its OCaml: plan_kernel_mini_ml.md). Here ML calls the C that
 * calls back: the argument and the result through, a closure's
 * variables, a collection inside the function called (its argument and
 * the caller's values are moved), two arguments one at a time, an
 * exception raised inside coming out to the handler around. mini-ml's
 * only: the names are its runtime's. *)
external call : ('a -> 'b) -> 'a -> 'b = "callback"
external call2 : ('a -> 'b -> 'c) -> 'a -> 'b -> 'c = "callback2"
(* (not Gc.full_major: gc.ml, beside this file, is the module Gc here) *)
external collect : unit -> unit = "gc_full_major"

let rec upto i acc = if i < 0 then acc else upto (i - 1) (i :: acc)
let sum l = List.fold_left ( + ) 0 l

let () =
  print_int (call (fun x -> x + 1) 41); print_newline ();
  let k = 10 in
  print_int (call (fun x -> x * k) 4); print_newline ();
  print_string (call (fun s -> s ^ ", and back") "into ML"); print_newline ();
  (* a collection inside: the list given, and the one kept here *)
  let mine = upto 1000 [] in
  let n = call (fun l -> collect (); ignore (upto 5000 []); collect (); sum l) (upto 100 []) in
  print_int n; print_string " "; print_int (sum mine); print_newline ();
  (* two arguments: a function of two, and one that gives a function *)
  print_int (call2 (fun a b -> a - b) 50 8); print_newline ();
  print_string (call2 (fun a -> collect (); fun b -> a ^ b) "one " (String.make 3 '2')); print_newline ();
  (* a callback in a callback *)
  print_int (call (fun x -> call (fun y -> x + y) 2) 40); print_newline ();
  (* an exception from inside *)
  (try print_int (call (fun x -> if x > 0 then raise Not_found else x) 1) with Not_found -> print_string "Not_found, through C");
  print_newline ();
  print_int (call (fun x -> x) 7); print_newline ()
