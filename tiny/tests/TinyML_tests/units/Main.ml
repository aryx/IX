(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* The other unit of TinyML_test.sh's separate compilation: Shapes's
 * names, its constructors, its labels and its exception used *)

open Shapes

let () =
  List.iter (fun b -> print_string b.name; print_string " "; print_int (area (scaled 2 b.shape)); print_newline ()) boxes;
  print_string (largest boxes).name; print_newline ();
  (try ignore (largest []) with Empty m -> print_string m; print_newline ());
  print_int (area Dot); print_newline ()
