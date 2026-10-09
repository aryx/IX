(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
(* See Config.mli *)

let modes () : unit =
  Globals.editor.edt_modes <- [
    ".ml", Ocaml_mode.mode; ".mli", Ocaml_mode.mode; ".mll", Ocaml_mode.mode; ".mly", Ocaml_mode.mode;
    ".c", C_mode.mode; ".h", C_mode.mode;
    ".s", Asm_mode.mode;
    ".st", Smalltalk_mode.mode;
    ".scm", Scheme_mode.mode; ".ss", Scheme_mode.mode;
    ".pas", Pascal_mode.mode;
  ]

let keys () : unit =
  List.iter (fun ((keys, action) : string * Efuns.action) -> Keymap.add_global_key keys action) [
    Keymap.any_char, Edit.self_insert_command;
    "RET", Edit.insert_return;
    "TAB", Edit.insert_tab;
    "C-j", Indent.newline_and_indent;
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

    "C-_", Edit.undo;
    "C-x u", Edit.undo;

    "C-@", Copy_paste.mark_at_point;
    "C-x C-x", Copy_paste.point_at_mark;
    "C-w", Copy_paste.kill_region;
    "M-w", Copy_paste.copy_region;
    "C-k", Copy_paste.kill_end_of_line;
    "M-d", Copy_paste.kill_forward_word;
    "M-DEL", Copy_paste.kill_backward_word;
    "C-y", Copy_paste.insert_killed;
    "M-y", Copy_paste.insert_next_killed;

    "C-s", Search.isearch_forward;
    "C-r", Search.isearch_backward;
    "M-C-s", Search.isearch_forward_regexp;
    "M-%", Search.query_replace_string;

    "M-x", Interactive.call_interactive;
    "C-g", Interactive.keyboard_quit;

    "C-x C-f", Multi_buffers.load_buffer;
    "C-x C-s", Multi_buffers.save_buffer;
    "C-x C-w", Multi_buffers.write_buffer;
    "C-x b", Multi_buffers.change_buffer;
    "C-x k", Multi_buffers.kill_buffer;
    "C-x C-c", Multi_buffers.exit;

    "C-x 2", Multi_frames.vertical_cut_frame;
    "C-x 3", Multi_frames.horizontal_cut_frame;
    "C-x o", Multi_frames.next_frame;
    "C-x 0", Multi_frames.delete_frame;
    "C-x 1", Multi_frames.one_frame;
  ]
