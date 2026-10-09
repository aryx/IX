(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Config.mli *)

let keys () : unit =
  List.iter (fun ((keys, action) : string * Efuns.action) -> Keymap.add_global_key keys action) [
    Keymap.any_char, Edit.self_insert_command;
    "RET", Edit.insert_return;
    "TAB", Edit.insert_tab;
    "C-d", Edit.delete_char;
    "<delete>", Edit.delete_char;
    "DEL", Edit.delete_backspace_char;

    "C-f", Move.move_forward;
    "<right>", Move.move_forward;
    "C-b", Move.move_backward;
    "<left>", Move.move_backward;
    "C-n", Move.forward_line;
    "<down>", Move.forward_line;
    "C-p", Move.backward_line;
    "<up>", Move.backward_line;
    "C-a", Move.beginning_of_line;
    "<home>", Move.beginning_of_line;
    "C-e", Move.end_of_line;
    "<end>", Move.end_of_line;
    "M-f", Move.forward_word;
    "M-b", Move.backward_word;
    "M-<", Move.begin_of_file;
    "M->", Move.end_of_file;

    "C-v", Scroll.forward_screen;
    "<next>", Scroll.forward_screen;
    "M-v", Scroll.backward_screen;
    "<prior>", Scroll.backward_screen;
    "C-l", Scroll.recenter;

    "C-x C-s", Multi_buffers.save_buffer;
    "C-x C-c", Multi_buffers.exit;
  ]
