(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's first process (plan_system_singularity.md, stage
 * 2): it starts the others and waits for them. tick and tock run
 * together, a line each in turn; hello twice, one after the other: a
 * program runs again once its process has ended. *)

(* a line now, not at the end: others write meanwhile *)
let say (s : string) : unit = print_string s; flush stdout

let spawn (name : string) : Sip.process =
  match Sip.create name with
  | Some p -> Sip.start p; p
  | None -> failwith ("init: no " ^ name)

let () =
  say "init: started\n";
  let tick = spawn "tick" in
  let tock = spawn "tock" in
  (match Sip.create "tick" with
   | None -> say "init: no second tick while one runs\n"
   | Some _ -> say "init: a second tick\n");
  (match Sip.create "nobody" with
   | None -> say "init: no program nobody\n"
   | Some _ -> say "init: a program nobody\n");
  let a = Sip.join tick in
  let b = Sip.join tock in
  say (Printf.sprintf "init: tick ended with %d, tock with %d\n" a b);
  for i = 1 to 2 do
    let hello = spawn "hello" in
    say (Printf.sprintf "init: hello %d ended with %d\n" i (Sip.join hello))
  done;
  exit 0
