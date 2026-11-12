(* Claude Code
 * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)

(* gui: a counter, two buttons and a number, on TinyLibGUI, which runs
 * a program given as a model, its widgets (view) and the model after a
 * message (update), Elm's way: a button sends its message, the widgets
 * are made again and what changed is drawn. Escape or q quits. It links
 * TinyLibSystem, TinyLibDraw, TinyLibPlayground and TinyLibGUI, from
 * /lib/ml (the Buildfile beside it):
 *
 *	cd /examples; build gui; ./gui
 *)
open TinyLibGUI

type msg = Less | More

let view n =
  Col [ Label "gui: a counter";
        Row [ Button ("-", Less); Label (string_of_int n); Button ("+", More) ] ]

let update msg n = match msg with Less -> n - 1 | More -> n + 1

let counter = { init = 0; view = view; update = update; key = (fun _ -> []) }

let () = TinyLibSystem.main "gui" (fun _ _ -> run counter)
