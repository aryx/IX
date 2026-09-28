(* records: declared, built (fields in any order, evaluated as ocamlopt
 * evaluates them), read, mutable fields set, polymorphic, nested, in
 * lists, compared, holding a closure; annotated parameters *)
type point = { x : int; y : int }
type 'a box = { mutable contents : 'a; mutable count : int }
type proc = { pid : int; name : string; mutable state : state; parent : proc option }
and state = Running | Waiting of int | Zombie of int
type shape = { center : point; radius : int; area : int -> int }
let show p = print_char '('; print_int p.x; print_char ','; print_int p.y; print_char ')'
let add a b = { x = a.x + b.x; y = a.y + b.y }
let put (b : 'a box) v = b.contents <- v; b.count <- b.count + 1
let state_name (p : proc) =
  match p.state with Running -> "running" | Waiting n -> "waiting " ^ string_of_int n | Zombie c -> "zombie " ^ string_of_int c
let say s n = print_string s; n
let () =
  let p = { y = 2; x = 1 } in
  show p; print_char ' '; show (add p { x = 10; y = 20 }); print_newline ();
  (* the fields' expressions: which runs first *)
  let q = { x = say "x " 1; y = say "y " 2 } in
  show q; print_newline ();
  let b = { contents = "a"; count = 0 } in
  put b "b"; put b "c";
  print_string b.contents; print_char ' '; print_int b.count; print_newline ();
  let init = { pid = 1; name = "init"; state = Running; parent = None } in
  let sh = { pid = 2; name = "sh"; state = Waiting 3; parent = Some init } in
  let procs = [ init; sh ] in
  List.iter (fun p -> print_string p.name; print_char ' '; print_string (state_name p); print_newline ()) procs;
  sh.state <- Zombie 0;
  print_string (state_name sh); print_newline ();
  (match sh.parent with Some pp -> print_string pp.name | None -> print_string "none"); print_newline ();
  print_string (if p = { x = 1; y = 2 } then "equal" else "different"); print_char ' ';
  print_string (if p < { x = 1; y = 3 } then "less" else "not less"); print_newline ();
  let c = { center = p; radius = 3; area = (fun r -> 3 * r * r) } in
  print_int (c.area c.radius); print_char ' '; show c.center; print_newline ();
  (* many, for the collector *)
  let rec build n acc = if n = 0 then acc else build (n - 1) ({ x = n; y = n * n } :: acc) in
  print_int (List.fold_left (fun s p -> s + p.y - p.x) 0 (build 1000 [])); print_newline ()
