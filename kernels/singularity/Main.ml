(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity's boot (plan_system_singularity.md, stage 2: the
 * processes). The kernel starts one process, init, and runs what can
 * run until nothing can: init starts the others. *)

let () =
  Machine.print "mini-singularity\n";
  ignore (Process.start false (Process.create false "init"));
  Process.schedule ();
  Machine.print "mini-singularity: no process left.\n";
  Machine.halt ()
