(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Start.mli *)

let editor (caps : Efuns.caps) ~(pad : bool) (file : string option) : Efuns.top_window Tui.program =
  Config.keys ();
  Config.modes ();
  if pad then Config_pad.config ();
  let directory = (match file with Some f -> Multi_buffers.is_directory caps f | None -> false) in
  let buf = (match file with
    | Some f when not directory -> Ebuffer.read caps f
    | _ -> Ebuffer.create "*scratch*" None (Text.create "")) in
  let top = Top_window.create caps 24 80 buf in
  (match file with Some f when directory -> Multi_buffers.open_file top.top_active_frame f | _ -> ());
  Top_window.program top
