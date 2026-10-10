(* Turbo_model: the types of Turbo Pascal's IDE (Tui_turbo), and nothing
   else. The IDE is a Tui program, Model-View-Update with a screen of
   characters, so the model is all of it: the text and the cursor, the
   floppy's files, what is on the screen above the editor (a menu, a
   dialog, the user screen), and the program being run or debugged. Its
   parts open this module: Turbo_edit (the text), Turbo_debug (compiling,
   running, stepping), Turbo_menus (the commands), Turbo_update (the
   keys) and Turbo_view (the screen drawn).

   What is on the screen is one field, [mode], and a mode's own state
   is in its constructor (the menu open and its item, a dialog's text):
   a dialog cannot be half open, and update and view are each a match
   on it.

   design:
   One record that is a value, replaced at each key, where mini-emacs's
   editor (its Efuns) is records changed in place. It buys this: a
   text that changed is an array that is another one, seen without
   comparing texts; a session is a fold of update over its keys, which
   the tests replay with no screen (Keys); nothing can be shown that
   the model does not say. It costs writing every command as a model
   returned, and passing the model through all of them. *)

(*****************************************************************************)
(* The commands *)
(*****************************************************************************)

(* what a menu's item or a function key does *)
type action =
  | Open | New | Save | Save_as | Exit
  | Find | Find_again | Goto_line
  | Run | Go_to_cursor | Trace_into | Step_over | Reset | User_screen
  | Compile | Pcode_listing
  | Call_stack | Add_watch | Toggle_breakpoint | Clear_watches
  | Keys | About

(* a menu's item: its label, the letter that chooses it, its key *)
type item = { label : string; hot : char; shortcut : string; action : action }

(*****************************************************************************)
(* What is on the screen *)
(*****************************************************************************)

(* what an input dialog's line is for *)
type purpose = Saving_as | Finding | Going_to | Watching

type mode =
  | Editing
  | Menu of int * int (* the bar's menu open, the item selected *)
  | Open_dialog of int (* the file selected *)
  | Input of { title : string; label : string; text : string; purpose : purpose }
  | Info of string * string list (* a box: its title and lines; a key closes it *)
  | Executing (* the session's machine running towards its goal *)
  | Finished of Vt.t * (int * string) option (* the user screen, and a run-time error's line and message *)
  | Showing of Vt.t (* the user screen again: Alt-F5 *)
  | Listing of int (* the P-code, from this instruction *)
  | Stack (* the call stack's window *)

(*****************************************************************************)
(* A program started *)
(*****************************************************************************)

(* A program started: run, stepped, paused at its execution bar. Its
   machine is Pmachine's, driven a slice a frame towards its goal
   (Pdebug.step), its output on the user screen, which the IDE shows
   only when the program writes or reads (Turbo Pascal's "smart" swap:
   a step that prints nothing doesn't flash the screen) *)
type session = {
  program : Pcode.program;
  machine : Pmachine.machine;
  user : Vt.t;
  typing : string option; (* a line the program reads, being typed *)
  goal : Pdebug.step option; (* None: paused *)
  pause : Pmachine.machine -> bool; (* the goal's predicate, made when the step began *)
  seed : Lehmer.t; (* random(n)'s *)
  swapped : bool; (* the user screen shown *)
}

(*****************************************************************************)
(* The model *)
(*****************************************************************************)

type model = {
  (* ix: the screen's size (the playground's is 80 by 24); a Tui.Resize changes it *)
  rows : int;
  cols : int;
  lines : string array; (* never changed in place *)
  row : int;
  col : int;
  top : int; (* the first line in the window, and the first column *)
  left : int;
  file : string;
  modified : bool;
  overwrite : bool;
  disk : (string * string) list;
  mode : mode;
  error : string option; (* the red bar *)
  compiled : Pcode.program option; (* the text's code, while the text is unchanged *)
  last_screen : Vt.t option;
  search : string;
  runs : int; (* each run's seed: another game *)
  session : session option;
  breakpoints : int list; (* lines, from 1 *)
  watches : string list;
  quit : bool;
  escaped : bool; (* a lone Esc just typed in the editor: a digit next is an F key *)
}
