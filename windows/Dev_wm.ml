(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Dev_wm.mli *)

let winname : Device.t = { Device.default with name = "winname"; perm = 0o444; read = (fun w -> Device.part (Window.name w)) }

let winid : Device.t = { Device.default with name = "winid"; perm = 0o444; read = (fun w -> Device.part (Printf.sprintf "%11d " w.id)) }

let label : Device.t = { Device.default with name = "label";
  read = (fun w -> Device.part w.label);
  write = (fun w data -> Window.send w (Window.Label data)) }

let text : Device.t = { Device.default with name = "text"; perm = 0o444; read = (fun w -> Device.part (Window.text w)) }

(* the pictures being read, by their window and file: one is made at a
 * read from the start, and each read is a part of it (a read of 8,000
 * bytes does not ask the screen again) *)
let pictures : (int * string, string) Hashtbl.t = Hashtbl.create 4

let picture name (image : Window.t -> Display.image) : Device.t = { Device.default with name; perm = 0o444;
  read = (fun w offset count ->
    if offset = 0 then Hashtbl.replace pictures (w.id, name) (Display.file (image w));
    match Hashtbl.find_opt pictures (w.id, name) with Some p -> Device.part p offset count | None -> "");
  closed = (fun w -> Hashtbl.remove pictures (w.id, name)) }

let window = picture "window" (fun w -> w.image)
let screen = picture "screen" (fun w -> Display.whole w.image.display)

let snarf : Device.t = { Device.default with name = "snarf";
  (* (opened to be written: what is written is all of it, as rio's) *)
  opened = (fun _ mode -> if mode land 3 <> 0 then Terminal.snarf := "");
  read = (fun _ -> Device.part !Terminal.snarf);
  write = (fun _ data -> Terminal.snarf := !Terminal.snarf ^ data) }
