(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* See Smalltalk_mode.mli *)

let mode : Efuns.major_mode = Highlight.mode "Smalltalk" Highlight_st.lines

let () =
  Keymap.add_binding mode.maj_map "TAB" Indent.indent_line;
  mode.maj_hooks <- [ (fun (buf : Efuns.buffer) -> buf.buf_minor_modes <- [ Paren_mode.mode ]) ]
