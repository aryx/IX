(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's first process (plan_system_singularity.md, stage
 * 2): it starts the others and waits for them. tick and tock run
 * together, a line each in turn; hello twice, one after the other: a
 * program runs again once its process has ended; ping and pong, a
 * client and a server by a contract; rogue, a client that breaks it. *)

(* a line now, not at the end: others write meanwhile *)
let say (s : string) : unit = print_string s; flush stdout

let create (name : string) : Sip.process =
  match Sip.create name with
  | Some p -> p
  | None -> failwith ("init: no " ^ name)

let spawn (name : string) : Sip.process =
  let p = create name in
  Sip.start p;
  p

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
  (* pong is given the serving end of a Pong channel; ping only a
   * channel where it is told: the other end is sent to it *)
  let client, server = Pong.channel () in
  let here, there = Intro.channel () in
  let ping = create "ping" in
  let pong = create "pong" in
  Sip.give pong (Pong.Exp.endpoint server);
  Sip.give ping (Intro.Exp.endpoint there);
  (try Sip.close (Pong.Exp.endpoint server); say "init: closed an endpoint it gave away\n"
   with Sip.Not_held -> say "init: the endpoints given are no longer its own\n");
  (try ignore (Pong.Imp.of_endpoint (Intro.Imp.endpoint here)); say "init: an Intro's end taken for a Pong's\n"
   with Failure why -> say ("init: an Intro's end is " ^ why ^ "\n"));
  Sip.start ping;
  Sip.start pong;
  Intro.Imp.meet here client;
  let a = Sip.join ping in
  let b = Sip.join pong in
  say (Printf.sprintf "init: ping ended with %d, pong with %d\n" a b);
  (* a client that breaks the contract is ended; its server goes on to its end *)
  let client, server = Pong.channel () in
  let rogue = create "rogue" in
  let pong = create "pong" in
  Sip.give rogue (Pong.Imp.endpoint client);
  Sip.give pong (Pong.Exp.endpoint server);
  Sip.start rogue;
  Sip.start pong;
  let a = Sip.join rogue in
  let b = Sip.join pong in
  say (Printf.sprintf "init: rogue ended with %d, pong with %d\n" a b);
  (* two channels of its own: select says which has a message *)
  let quiet, _ = Pong.channel () in
  let busy, server = Pong.channel () in
  Pong.Exp.ready server;
  let i = Sip.select [ Pong.Imp.endpoint quiet; Pong.Imp.endpoint busy ] in
  say (Printf.sprintf "init: of two endpoints, number %d has a message\n" i);
  (* the costs, last: their lines are not compared *)
  ignore (Sip.join (spawn "bench"));
  exit 0
