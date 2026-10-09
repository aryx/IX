(* M-x: a command asked by its name (Action's), and run. efuns'
 * Interactive. *)
val call_interactive : Efuns.action

(* C-g: what was begun (a sequence of keys) is dropped, "Quit" said *)
val keyboard_quit : Efuns.action
