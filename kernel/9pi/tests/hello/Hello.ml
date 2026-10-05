(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* The first program of ix's on mini-9pi (plan_rio.md, stage 1): OCaml,
 * by mini-ml, a Plan 9 a.out (mini-mk O=5 OS=plan9), in the bootdir
 * (../../Makefile's check-ix). Its arguments, a float and an exit
 * status: the start, the VFP and exits, as the kernel gives them. *)

let () =
  print_string "hello from OCaml on Plan 9\n";
  Printf.printf "%d arguments: %s; pi is %.4f\n" (Array.length Sys.argv - 1)
    (String.concat " " (List.tl (Array.to_list Sys.argv))) (4.0 *. atan 1.0);
  if Array.length Sys.argv > 1 then exit 3
