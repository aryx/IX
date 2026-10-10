(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity: ping, a client of pong's, by the Pong contract
 * (contracts/Pong). It is not given pong's channel, but one where it
 * is told (Intro): the Pong endpoint arrives in a message. Three
 * numbers there and back; then a block of the exchange heap, which is
 * pong's once sent: ping's handle is no longer one. *)

let say (s : string) : unit = print_string s; flush stdout

let () =
  let (Meet pong) = Intro.Exp.receive (Intro.Exp.of_endpoint (Sip.given 0)) in
  (match Pong.Imp.receive pong with
   | Ready -> say "ping: was sent an endpoint, and pong is ready there\n"
   | _ -> ());
  for i = 1 to 3 do
    Pong.Imp.ping pong i;
    match Pong.Imp.receive pong with
    | Pong n -> say (Printf.sprintf "ping: sent %d, got %d back\n" i n)
    | _ -> ()
  done;
  let b = Sip.alloc 32 in
  let s = "bytes that changed hands" in
  Sip.write b 0 s;
  Pong.Imp.text pong b (String.length s);
  (try say (Printf.sprintf "ping: still reads its block: %c\n" (Sip.get b 0))
   with Sip.Not_held -> say "ping: the block is no longer its own\n");
  ignore (Pong.Imp.receive pong);
  Pong.Imp.close pong;
  exit 0
