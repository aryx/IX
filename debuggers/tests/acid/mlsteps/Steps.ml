(* the program mini-acid steps through (debuggers/tests/acid_proc.sh): a
 * function of several statements, each its own line in the tables
 * (plan_debugger.md's stage 1b), next going a line at a time *)
let total = ref 0

let rec add_all l =
  match l with
  | [] -> !total
  | x :: rest ->
      total := !total + x;
      let doubled = 2 * x in
      total := !total + doubled;
      add_all rest

let () =
  let r = add_all [ 1; 2; 3 ] in
  print_int r
