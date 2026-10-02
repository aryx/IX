(* mini-xv6's scheduler's pass (kernel/xv6/Proc.ml's all: the table's
 * processes as a list, by Array.to_list and List.fold_right with a
 * closure), where the kernel is when it waits: an array of options
 * turned into a list, a fold with a function of two arguments, the
 * list walked. What it weighs: allocation, a closure's call through
 * the stdlib, a match. docs/plans/plan_mini_toolchain_optimization.md's first target. *)
type proc = { pid : int; mutable state : int }

let procs : proc option array = Array.make 64 None
let all () = List.fold_right (fun o acc -> match o with Some p -> p :: acc | None -> acc) (Array.to_list procs) []

let () =
  for i = 0 to 7 do procs.(i * 8) <- Some { pid = i; state = 0 } done;
  let n = ref 0 in
  for _i = 1 to 2000 do List.iter (fun p -> n := !n + p.pid) (all ()) done;
  print_int !n; print_newline ()
