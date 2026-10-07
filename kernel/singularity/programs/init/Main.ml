(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity's first process (plan_system_singularity.md, stage
 * 2): it starts the others and waits for them. tick and tock run
 * together, a line each in turn; hello twice, one after the other: a
 * program runs again once its process has ended; ping and pong, given
 * the two ends of a channel. *)

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
  (* ping and pong, an end of a channel each *)
  let a, b = Sip.channel () in
  let ping = create "ping" in
  let pong = create "pong" in
  Sip.give ping a;
  Sip.give pong b;
  (try Sip.close a; say "init: closed an endpoint it gave away\n"
   with Sip.Not_held -> say "init: the endpoints are no longer its own\n");
  Sip.start ping;
  Sip.start pong;
  let a = Sip.join ping in
  let b = Sip.join pong in
  say (Printf.sprintf "init: ping ended with %d, pong with %d\n" a b);
  (* two channels of its own: select says which has a message *)
  let _a, b = Sip.channel () in
  let c, d = Sip.channel () in
  Sip.send c 7 42;
  let i = Sip.select [ b; d ] in
  say (Printf.sprintf "init: of two endpoints, number %d has a message: %d\n" i (Sip.receive d).value);
  (* the costs, last: their lines are not compared *)
  ignore (Sip.join (spawn "bench"));
  exit 0
