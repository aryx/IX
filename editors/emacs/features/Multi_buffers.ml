(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Multi_buffers.mli *)
open Efuns

let save_buffer (frame : frame) : unit =
  let buf = frame.frm_buffer in
  Ebuffer.save frame.caps buf;
  Top_window.message frame ("Wrote " ^ (match buf.buf_filename with Some f -> f | None -> ""))

let exit (frame : frame) : unit = (Top_window.of_frame frame).top_killed <- true

let () = Action.define_all [ "save_buffer", save_buffer; "exit", exit ]
