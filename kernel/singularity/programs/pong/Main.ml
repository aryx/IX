(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: pong, at the other end of ping's channel: a number
 * received is sent back, one more; a block received is its own, read
 * and freed; the channel closed by ping is its end. *)

let pong = 1
let text = 2

let say (s : string) : unit = print_string s; flush stdout

let () =
  let e = Sip.given 0 in
  let rec serve () =
    let m = Sip.receive e in
    (match m.block with
     | Some b ->
         let s = Sip.read b in
         say (Printf.sprintf "pong: a block of %d bytes: %s\n" (Sip.size b) (String.sub s 0 (String.index s '\000')));
         Sip.free b;
         Sip.send e text 0
     | None -> Sip.send e pong (m.value + 1));
    serve ()
  in
  try serve () with Sip.Closed -> say "pong: the channel is closed\n"; exit 0
