(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See C_mode.mli *)

let mode : Efuns.major_mode = Highlight.mode "C" Highlight_c.lines

let () =
  mode.maj_hooks <- [ (fun (buf : Efuns.buffer) -> buf.buf_minor_modes <- [ Paren_mode.mode ]) ]
