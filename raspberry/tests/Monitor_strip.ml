(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* Monitor's strip (mini-qemu -meters) drawn from made-up samples: a
 * boot (the kernel alone, busy), a program running, a wait, a
 * download; written as a PPM file, to look at it without a window.
 * usage: Monitor_strip.exe WIDTH out.ppm; the title's last line is
 * printed *)

let () =
  let width = int_of_string Sys.argv.(1) in
  let m = Monitor.create ~period:0.5 in
  let net = ref { Usernet.from_guest = 0; to_guest = 0; tcp = 0; udp = 0; events = [] } in
  ignore (Monitor.tick m ~host:1. ~board:0 ~net:!net);
  for i = 1 to 150 do
    let busy, user, inb, outb =
      if i < 30 then (100, 0, 0, 0)
      else if i < 60 then (60 + (i mod 7 * 5), 40, 0, 0)
      else if i < 90 then (4, 1, 0, 0)
      else if i < 130 then (70, 45, 20_000 * (i - 89), 1500)
      else (5, 1, 40, 40) in
    Monitor.sample m [ { Status.pc = 0L; user = false; label = "svc"; ran = (busy - user) * 1000; waited = (100 - busy) * 1000 };
                       { Status.pc = 0L; user = true; label = "usr"; ran = user * 1000; waited = 0 } ];
    net := { !net with to_guest = !net.to_guest + (inb / 2); from_guest = !net.from_guest + (outb / 2); tcp = (if inb > 0 then 1 else 0);
                       events = (if i = 90 then [ "tcp 10.0.2.2:8123" ] else !net.events) };
    ignore (Monitor.tick m ~host:(1. +. (0.5 *. float_of_int i)) ~board:(i * 400_000) ~net:!net)
  done;
  let oc = open_out_bin Sys.argv.(2) in
  Printf.fprintf oc "P6\n%d %d\n255\n" width Monitor.height;
  output_string oc (Monitor.strip m ~width);
  close_out oc;
  print_endline (Monitor.line m)
