(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Virtual_cons.mli *)

let cons : Device.t = { Device.default with name = "cons";
  read = (fun w _ count -> Device.later w (fun reply -> Window.Read (reply, count)));
  write = (fun w data -> Window.send w (Window.Wrote data)) }

let consctl : Device.t = { Device.default with name = "consctl"; perm = 0o222;
  write = (fun w data -> if data = "rawon" then Window.send w (Window.Raw true) else if data = "rawoff" then Window.send w (Window.Raw false));
  (* (the program that had the raw keyboard is done with it) *)
  closed = (fun w -> Window.send w (Window.Raw false)) }

let kbd : Device.t = { Device.default with name = "kbd"; perm = 0o444;
  opened = (fun w _ -> Window.send w (Window.Held_file true));
  read = (fun w _ _ -> Device.later w (fun reply -> Window.Held_read reply));
  closed = (fun w -> Window.send w (Window.Held_file false)) }
