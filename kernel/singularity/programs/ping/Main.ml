(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: ping, at one end of a channel (programs/init gave
 * it; pong has the other). Three numbers there and back; then a block
 * of the exchange heap, which is pong's once sent: ping's handle is no
 * longer one. The tags are Singularity's smallest contract's
 * (PongContract: Ping there, Pong back), unchecked until stage 4. *)

let ping = 0
let pong = 1
let text = 2

let say (s : string) : unit = print_string s; flush stdout

let () =
  let e = Sip.given 0 in
  for i = 1 to 3 do
    Sip.send e ping i;
    let m = Sip.receive e in
    say (Printf.sprintf "ping: sent %d, got %d back (tag %d)\n" i m.value m.tag)
  done;
  let b = Sip.alloc 32 in
  Sip.write b 0 "bytes that changed hands";
  Sip.send_block e text 0 b;
  (try say ("ping: still reads its block: " ^ Sip.read b ^ "\n")
   with Sip.Not_held -> say "ping: the block is no longer its own\n");
  ignore (Sip.receive e);
  Sip.close e;
  exit 0
