(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's first process (plan_system_singularity.md, stage
 * 6): the system's own wiring. It starts the console's driver and the
 * shell, each at one end of a Console channel, and waits for the
 * shell's end; then the driver is stopped, and the system has no
 * process left. *)

let create (name : string) : Sip.process =
  match Sip.create name with
  | Some p -> p
  | None -> failwith ("init: no " ^ name)

let () =
  let client, server = Console.channel () in
  let console = create "console" in
  let shell = create "shell" in
  Sip.give console (Console.Exp.endpoint server);
  Sip.give shell (Console.Imp.endpoint client);
  Sip.start console;
  Sip.start shell;
  let status = Sip.join shell in
  Sip.stop console;
  ignore (Sip.join console);
  exit status
