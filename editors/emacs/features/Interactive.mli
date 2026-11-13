(* M-x asks for a command by its name (Action's names), and runs it.
 * This is efuns' Interactive. *)
val call_interactive : Efuns.action

(* C-g drops what was begun (a sequence of keys), and says "Quit" *)
val keyboard_quit : Efuns.action
