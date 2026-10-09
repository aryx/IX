(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Virtual_mouse.mli *)

let mouse : Device.t = { Device.default with name = "mouse";
  opened = (fun w _ -> Window.send w (Window.Mouse_file true));
  read = (fun w _ _ -> Device.later w (fun reply -> Window.Mouse_read reply));
  closed = (fun w -> Window.send w (Window.Mouse_file false)) }

let cursor : Device.t = { Device.default with name = "cursor"; perm = 0o222;
  write = (fun w data ->
    let c : Cursor.t option =
      if String.length data < 72 then None
      else
        let long o = Int32.to_int (String.get_int32_le data o) in
        Some { offset = Point.v (long 0) (long 4); clr = String.sub data 8 32; set = String.sub data 40 32 } in
    Window.send w (Window.Cursor c)) }
