(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Pervasives' externals (Lower's %revapply, %apply, %ignore, %lnot):
 * x |> f and f @@ x the call f x, x |> g a the call g a x; a known
 * function, a closure, a primitive, more arguments than the function
 * takes, a chain; each as a value too (List.map's function); the
 * arguments' effects in OCaml's order *)

let add a b = a + b
let add3 a b c = a * 100 + b * 10 + c
let twice f x = f (f x)
let trace s x = print_string s; x

let () =
  Printf.printf "%d %d %d\n" (1 |> add 2) (add 2 @@ 3) (5 |> succ |> twice succ);
  Printf.printf "%d %d\n" (3 |> add3 1 2) (add3 1 2 @@ 3);
  let f = if Sys.argv.(0) = "" then add 1 else add 2 in
  Printf.printf "%d %d\n" (10 |> f) (f @@ 10);
  Printf.printf "%d\n" (4 |> ( + ) 5);
  Printf.printf "%d\n" ((1 |> add3) 2 3);
  Printf.printf "%d\n" ((fun x -> x * 7) @@ 6);
  let r = trace "a" 1 |> trace "g" (add 1) in
  Printf.printf " %d\n" r;
  let r = trace "g" (add 1) @@ trace "a" 1 in
  Printf.printf " %d\n" r;
  Printf.printf "%s\n" (String.concat "," (List.map (( |> ) 3) [ succ; add 4; twice (add 2) ] |> List.map string_of_int));
  Printf.printf "%d\n" (List.fold_left (fun a f -> f @@ a) 0 [ succ; add 5 ] + List.fold_left (+) 0 (List.map (( @@ ) succ) [ 1; 2 ]));
  ignore (trace "ignored " 5);
  List.iter ignore [ 1; 2 ];
  print_newline ();
  Printf.printf "%d %d %d %d\n" (lnot 0) (lnot (-1)) (lnot 12345) (lnot (-70000));
  Printf.printf "%d\n" (List.fold_left (fun a x -> a + lnot x) 0 [ 1; 2; 3 ] + (List.map lnot [ 7 ] |> List.hd))
