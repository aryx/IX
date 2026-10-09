(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Dev_wm.mli *)

let winname : Device.t = { Device.default with name = "winname"; perm = 0o444; read = (fun w -> Device.part (Window.name w)) }

let winid : Device.t = { Device.default with name = "winid"; perm = 0o444; read = (fun w -> Device.part (Printf.sprintf "%11d " w.id)) }

let label : Device.t = { Device.default with name = "label";
  read = (fun w -> Device.part w.label);
  write = (fun w data -> Window.send w (Window.Label data)) }

let text : Device.t = { Device.default with name = "text"; perm = 0o444; read = (fun w -> Device.part (Window.text w)) }

let snarf : Device.t = { Device.default with name = "snarf";
  (* (opened to be written: what is written is all of it, as rio's) *)
  opened = (fun _ mode -> if mode land 3 <> 0 then Terminal.snarf := "");
  read = (fun _ -> Device.part !Terminal.snarf);
  write = (fun _ data -> Terminal.snarf := !Terminal.snarf ^ data) }
