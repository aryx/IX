(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* mini-emacs's types (docs/plans/plan_emacs.md): the editor, its
 * buffers, the frames that show them, the windows that place the
 * frames on a screen, and the keymaps. One structure, changed in
 * place, as in efuns (Fabrice Le Fessant, INRIA, 1998), whose names
 * these are:
 *
 *     editor --- buffers: a text, its file, its modes
 *        |           ^
 *        |           | frm_buffer
 *     top windows: a screen --- a tree of windows --- frames:
 *       a key in, cells out       (the screen split)    a buffer seen from a
 *                                                       line on, a cursor
 *
 * Not efuns': a window is the tree alone (a frame, or two windows side
 * by side or one over the other), with no link upward and no place of
 * its own: the places are the frames', given from the top each time
 * the tree or the screen changes (Window.place).
 *
 * The same text in two frames is one buffer and two points: what is
 * typed in one shows in the other, and each keeps its own place.
 * That is why the cursor is the frame's (frm_point) and not the
 * buffer's, and why a position that must follow the text is a
 * Text.point, which the text itself moves, and not a number.
 *
 *     C-x 2 on f.ml, C-x o to the lower frame, C-x b g.ml there:
 *
 *     top.window = VComb (WFrame a, WFrame b)
 *     a.frm_buffer --> f.ml's buffer <-- (b's, before C-x b)
 *     b.frm_buffer --> g.ml's buffer; f.ml's keeps where b was
 *                      (buf_point, buf_start), for a frame to come
 *
 * terminology:
 * Window and frame are each other's in Emacs. There, a window is a
 * buffer seen in a part of the screen, with its mode line (here a
 * frame, and its status line), and a frame is what the window system
 * calls a window (here a top window). Emacs's words are older than
 * window systems: its windows were tiles of a terminal's screen, and
 * when it ran under X the outer thing needed another name. efuns
 * took the window system's meaning for the top window, kept window
 * for the tiling, and called frame the view; these are its names.
 * The other words are Emacs's: the point is where one types, a
 * place between two characters; the mark another such place, set
 * and left behind; the region the text between the two; to kill is
 * to take text out and keep it, to yank to put it back (Copy_paste).
 *
 * design:
 * One record a concept and every field mutable, where the rest of
 * ix's programs for a terminal (mini-turbopascal's Turbo_model) are a
 * value an update replaces. An editor's commands are many and each
 * touches little: a function frame -> unit that changes one field
 * is the shortest way to write one, and it is efuns' and Emacs's
 * (a command there changes the current buffer). The cost is at the
 * edge: Tui wants a model that is another value when something
 * changed (Top_window.model). *)

(* what the commands may do: read and write files, list a directory *)
type caps = < Cap.open_in ; Cap.open_out ; Cap.readdir >

(* a key by Emacs's name: "a", "C-x", "M-f", "RET", "<up>" (Keymap) *)
type key = string

(* a text's colors, computed from it (a mode's highlighter), not kept
 * with it: for each line, the pieces that are not plain, each the byte
 * it starts at in the line, its length, how it is shown *)
type colors = (int * int * Vt.attrs) list array

(* a command *)
type action = frame -> unit

(* what a key does in a map: a command, or it starts a sequence (C-x) *)
and binding = Function of action | Prefix of map
and map = (key, binding) Hashtbl.t

and buffer = {
  buf_text : Text.t;
  (* its own among the editor's buffers *)
  mutable buf_name : string;
  mutable buf_filename : string option;
  (* the text's version when it was read or written: modified since
   * if it is another *)
  mutable buf_last_saved : int;
  (* where the last frame that showed it was, and its first line: a
   * frame that shows it again starts there *)
  buf_point : Text.point;
  buf_start : Text.point;
  (* the other end of the region (C-w), the point being one *)
  mutable buf_mark : Text.point option;
  (* the keys: the buffer's own, then its modes', then the editor's *)
  buf_map : map;
  mutable buf_major_mode : major_mode;
  mutable buf_minor_modes : minor_mode list;
  (* the colors last asked of the mode (Ebuffer.colors): the text's
   * version then, the part of it they are of (its first position, the
   * one after its last), and its lines' colors *)
  mutable buf_colors : (int * int * int * colors) option;
}

(* a buffer's one major mode: its name, its keys, the colors of a text
 * (none: plain), and what is done to a buffer that takes the mode (its
 * minor modes set) *)
and major_mode = {
  maj_name : string;
  maj_map : map;
  maj_colors : (string -> colors) option;
  mutable maj_hooks : (buffer -> unit) list;
}

and minor_mode = { min_name : string; min_map : map }

(* a buffer seen through a rectangle of the screen: its text from
 * frm_start's line, then a status line (none: the minibuffer's frame) *)
and frame = {
  mutable frm_buffer : buffer;
  (* where one types: the cursor *)
  mutable frm_point : Text.point;
  (* the start of the first line shown *)
  mutable frm_start : Text.point;
  (* the column a move to the next line asks for and the position it
   * left the point at: the column is kept while the point is there
   * (a short line passed does not lose it) *)
  mutable frm_goal : (int * int) option;
  mutable frm_xpos : int;
  mutable frm_ypos : int;
  mutable frm_width : int;
  (* with the status line *)
  mutable frm_height : int;
  mutable frm_has_status_line : bool;
  (* what it last showed (Frame: an optimization) *)
  mutable frm_shown : shown option;
  caps : caps;
}

(* a frame's rows of text as they were last made, and what they were
 * made of: while that is the same (the text, the first line, the size,
 * the colors), they are not made again *)
and shown = {
  sh_text : Text.t;
  sh_version : int;
  sh_start : int;
  sh_width : int;
  sh_height : int;
  sh_mode : major_mode;
  sh_reversed : (int * int) list;
  sh_plain : Vt.attrs;
  (* each row's pieces (a column, a text, how it is shown), the last first *)
  sh_rows : (int * string * Vt.attrs) list array;
  (* the position each row starts at (max_int: a row after the text's
   * end), and the first one that is not shown (the text's length and
   * one, if its end is) *)
  sh_starts : int array;
  sh_stop : int;
  (* the start of the last line that starts in the rows; the first line's number *)
  sh_last : int;
  sh_line : int;
  (* the screen the rows were last written on, and where: its rows are
   * taken again, not written *)
  mutable sh_screen : (Curses.t * int * int) option;
}

and window = WFrame of frame | HComb of window * window | VComb of window * window

(* a question asked on the screen's last line: a frame of one row on
 * a buffer of its own, the answer's, after the prompt; the keys go to
 * it until it is answered, then to the frame that asked *)
type minibuffer = {
  mini_frame : frame;
  mini_prompt : string;
  mini_back : frame;
  (* the cursor shown is the asking frame's (a search: where the match is) *)
  mutable mini_cursor_back : bool;
}

type top_window = {
  mutable top_width : int;
  (* with the minibuffer's line, the last *)
  mutable top_height : int;
  mutable window : window;
  (* the frame the keys go to *)
  mutable top_active_frame : frame;
  (* the keys of a sequence begun, the last first: C-x typed, and what
   * follows awaited *)
  mutable top_prefix : key list;
  (* the key that ran the command: what self_insert_command inserts *)
  mutable top_key : key;
  (* where the mouse was when it last did something: the screen's row
   * and column (a host with a mouse says a click as a key, Emouse) *)
  mutable top_mouse : int * int;
  (* said on the last line, the minibuffer's *)
  mutable top_message : string;
  mutable top_mini : minibuffer option;
  (* the keys typed since a keyboard macro's start, the last first;
   * None: none is being recorded (Macros) *)
  mutable top_recorded : key list option;
  mutable top_killed : bool;
}

type editor = {
  mutable edt_buffers : buffer list;
  edt_map : map;
  (* how a cell of plain text is shown, and the screen where there is
   * none: the text's color and the ground's (a theme: Config_pad's) *)
  mutable edt_plain : Vt.attrs;
  (* a file's mode by the end of its name (".ml") *)
  mutable edt_modes : (string * major_mode) list;
  (* what is shown in reverse in a frame, asked when it is drawn: each
   * says the places (a start, an end) it wants so: the parenthesis
   * that matches, what a search found *)
  mutable edt_highlights : (frame -> (int * int) list) list;
  (* (one, until a host has several screens) *)
  mutable top_windows : top_window list;
}
