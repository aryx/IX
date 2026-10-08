(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Kproc.mli *)

open Types

(* Its record is a process's with nothing of a program (no memory, no
 * files); Main's process_start runs its work (Proc.kernel_work, by its
 * slot) where another process would go to user mode. *)
let start (p : proc) name work =
  match Proc.free_slot () with
  | None -> ()
  | Some slot ->
      let pid = !Proc.nextpid in
      incr Proc.nextpid;
      let k = { pid = pid; slot = slot; state = Runnable; parent = 0; nchild = 0; waitq = []; pgdir = 0; segs = [];
                fgrp = Kchan.fgrp_new (); pgrp = { mnt = [] }; egrp = { vars = []; last_path = 0 };
                slash = p.slash; dot = p.dot; notify = 0; noteid = pid;
                errstr = ""; text = name; start = !Proc.ticks; psstate = ""; args = ""; setargs = false;
                notes = []; notepending = false; notified = false; ureg = 0; lastnote = ("", Nuser); alarm = 0;
                rgrp = { rend = [] }; rendtag = 0; rendval = 0 } in
      Proc.kernel_work := (slot, work) :: !Proc.kernel_work;
      Machine.tf_init slot;
      Machine.proc_context slot;
      Proc.procs.(slot) <- Some k;
      Proc.ready k
