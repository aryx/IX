(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity's first process (plan_system_singularity.md, stage
 * 1): an OCaml program as any other, which does not know where it
 * runs. Its lines go by the standard library to the kernel's debug
 * line; its lists are in its own heap, collected by its own collector
 * (a million cells for a heap of 256k words). *)

let runs = ref 0

let rec sum (n : int) (acc : int) : int =
  if n = 0 then acc else sum (n - 1) (acc + List.length (List.init 100 (fun i -> i + n)))

let () =
  incr runs;
  print_string "hello: a process in the kernel's address space\n";
  Printf.printf "hello: run %d, %d cells\n" !runs (sum 10000 0);
  exit 3
