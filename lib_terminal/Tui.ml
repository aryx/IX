(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* ix: the author's playground's libs/terminal/Tui.ml; an event more, Resize: the host's screen has another size (docs/plans/plan_pascal.md) *)

(* See Tui.mli *)

type event = Key of string | Tick of float | Resize of int * int

type 'model program = {
  init : 'model;
  update : event -> 'model -> 'model;
  view : 'model -> Curses.t;
  over : 'model -> bool;
}
