(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: tick, one of two processes that run together
 * (programs/init): a line, then the other's turn. *)

let () =
  for i = 1 to 3 do
    print_string (Printf.sprintf "tick %d\n" i);
    flush stdout;
    Sip.yield ()
  done;
  exit 1
