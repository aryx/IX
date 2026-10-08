(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* mini-singularity: the console's driver, a process as the others
 * (plan_system_singularity.md, stage 6). Of the machine it has what
 * its manifest asks, the PL011's registers and its interrupt (Given),
 * and nothing else; it serves the Console contract at the endpoint its
 * parent gave it: a text written, a key waited for. *)

(* the PL011's: its data; its flags, the transmit FIFO full, the receive one empty *)
let dr = 0x00
let fr = 0x18
let txff = 0x20
let rxfe = 0x10

let put (c : char) : unit =
  while Sip.io_read Given.uart fr land txff <> 0 do () done;
  Sip.io_write Given.uart dr (Char.code c)

let rec key () : int =
  if Sip.io_read Given.uart fr land rxfe <> 0 then begin Sip.wait Given.keys; key () end
  else Sip.io_read Given.uart dr land 0xff

let () =
  let e = Console.Exp.of_endpoint (Given.endpoint 0) in
  let rec serve () =
    (match Console.Exp.receive e with
     | Write (b, n) ->
         for i = 0 to n - 1 do put (Sip.get b i) done;
         Console.Exp.written e b
     | Read -> Console.Exp.key e (key ()));
    serve ()
  in
  try serve () with Sip.Closed -> exit 0
