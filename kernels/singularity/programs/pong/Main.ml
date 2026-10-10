(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-singularity: pong, the server of the Pong contract
 * (contracts/Pong), at the exporting end it was given: a number
 * received is sent back, one more; a text's block is its own, read and
 * freed; a block lent is returned as it is; the channel closed by its
 * client is its end. *)

let say (s : string) : unit = print_string s; flush stdout

let () =
  let e = Pong.Exp.of_endpoint (Sip.given 0) in
  Pong.Exp.ready e;
  let rec serve () =
    (match Pong.Exp.receive e with
     | Ping n -> Pong.Exp.pong e (n + 1)
     | Text (b, n) ->
         say (Printf.sprintf "pong: a block of %d bytes: %s\n" (Sip.size b) (Sip.sub b 0 n));
         Sip.free b;
         Pong.Exp.thanks e
     | Lend b -> Pong.Exp.return e b);
    serve ()
  in
  try serve () with Sip.Closed -> say "pong: the channel is closed\n"; exit 0
