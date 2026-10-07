(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: a program that fails: its process ends, with what
 * its run-time system says of the exception; the system goes on. *)

let () =
  print_string "crash: about to fail\n";
  flush stdout;
  ignore (List.hd (List.filter (fun (n : int) -> n > 3) [ 1; 2; 3 ]))
