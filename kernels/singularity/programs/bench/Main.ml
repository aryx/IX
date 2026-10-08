(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: the four costs of the paper's table 1 (Hunt and
 * Larus, 2007), here: a call to the kernel, a yield, a message there
 * and back, a process made and ended. Each many times, in the board's
 * microseconds (under mini-qemu a microsecond is a fixed number of
 * instructions: numbers.sh makes them of these lines). pong is the
 * other end: it sends back what it gets. *)

let say (s : string) : unit = print_string s; flush stdout

(* f, n times: its name, n, the microseconds *)
let measure (name : string) (n : int) (f : unit -> unit) : unit =
  let t0 = Sip.time () in
  for _i = 1 to n do f () done;
  say (Printf.sprintf "bench: %s %d %d\n" name n (Sip.time () - t0))

let () =
  let n = 1000 in
  measure "call" n (fun () -> ignore (Sip.time ()));
  measure "yield" n Sip.yield;
  let client, server = Pong.channel () in
  (match Sip.create "pong" with
   | None -> say "bench: no pong\n"
   | Some pong ->
       Sip.give pong (Pong.Exp.endpoint server);
       Sip.start pong;
       ignore (Pong.Imp.receive client);
       measure "message" n (fun () -> Pong.Imp.ping client 1; ignore (Pong.Imp.receive client));
       (* the same with a megabyte that goes with the message, and comes back *)
       let b = ref (Sip.alloc (1024 * 1024)) in
       Sip.set !b 1000000 'x';
       measure "megabyte" n (fun () ->
         Pong.Imp.lend client !b;
         match Pong.Imp.receive client with Return back -> b := back | _ -> ());
       if Sip.get !b 1000000 <> 'x' then say "bench: not the block that was sent\n";
       measure "byte" n (fun () -> Sip.set !b 5 (Sip.get !b 4));
       Sip.free !b;
       Pong.Imp.close client;
       ignore (Sip.join pong));
  measure "process" 10 (fun () ->
    match Sip.create "nothing" with
    | Some p -> Sip.start p; ignore (Sip.join p)
    | None -> ());
  exit 0
