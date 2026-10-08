(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* Picture.ml on the host, by OCaml: the font's bits put in TinyMemory's
 * array, the picture drawn there, the screen written as tiny-machine
 * -screen writes it.
 * usage: Host.exe font1.bin out.ppm *)
let () =
  let font = In_channel.with_open_bin Sys.argv.(1) In_channel.input_all in
  Bytes.blit_string font 0 TinyMemory.mem 0x1000 (String.length font);
  Picture.picture 0x1000;
  Out_channel.with_open_bin Sys.argv.(2) (fun oc -> output_string oc (TinyMemory.ppm ()))
