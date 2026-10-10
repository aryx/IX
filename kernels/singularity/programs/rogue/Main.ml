(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity: a client that does not keep the Pong contract: a
 * second Ping before the first's Pong. It compiles (the state is not
 * the compiler's to see) and the kernel ends it there; pong sees its
 * channel closed, and the system goes on. *)

let () =
  let pong = Pong.Imp.of_endpoint (Sip.given 0) in
  ignore (Pong.Imp.receive pong);
  Pong.Imp.ping pong 1;
  Pong.Imp.ping pong 2;
  print_string "rogue: still here\n";
  exit 0
