(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's boot (plan_system_singularity.md, stage 1: a
 * second program in the image). The kernel, then hello, a process in
 * the kernel's address space with its own run-time system: run twice,
 * the second from the pristine copy as the first was. *)

(* the mkfile's PROGRAMS, by their order *)
let hello = 0

let () =
  Machine.print "mini-singularity\n";
  for _run = 1 to 2 do
    let status = Process.run hello in
    Machine.print (Printf.sprintf "mini-singularity: hello ended, status %d.\n" status)
  done;
  Machine.print "mini-singularity: no process left.\n";
  Machine.halt ()
