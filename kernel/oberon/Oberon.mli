(* The system's centre (Oberon's Oberon): the loop that asks the mouse
 * and the keyboard and sends what happened to a viewer, the messages
 * it sends, the two cursors, and the display's two tracks.
 * And what a command needs: the log to write in, where it was called
 * from (par), where to open a viewer; the tasks, procedures the loop
 * calls when nothing else happens.
 *
 * Not here: the collector's task (mini-ml's runtime collects when it
 * needs), the user's name and the clock. *)

(* The messages (Display.msg's cases; Oberon's InputMsg and ControlMsg).
 * Track (keys, x, y): the mouse is there, those keys down (Input's
 * set), sent to the viewer under it. Consume ch: a character typed,
 * sent to the focus viewer. Mark (x, y): put the pointer there.
 * Neutralize: forget the marks (the caret, the selection). Defocus:
 * the keyboard goes to another. *)
exception Track of int * int * int
exception Consume of char
exception Mark of int * int
exception Neutralize
exception Defocus

(* The selection: a stretch of a text the user marked, in some viewer.
 * Who wants it broadcasts Selection with a record the frames that
 * have one fill, the latest winning (a message that brings an answer
 * back, Oberon's VAR M: here a record's mutable fields). *)
type selection = { mutable text : Texts.t option; mutable beg : int; mutable end_ : int; mutable time : int }
exception Selection of selection
(* the latest selection: a text, from where to where, and when it was made; or None *)
val get_selection : unit -> (Texts.t * int * int * int) option
(* a number that grows: which of two things came later *)
val time : unit -> int

(* A frame asked for a copy of itself (System.Copy, System.Grow): the
 * answer in the record *)
type copy = { mutable copied : Display.frame option }
exception Copy of copy

(* A cursor is drawn and taken away by its marker's two procedures;
 * the mouse's is the arrow, the pointer (a place marked: where a
 * viewer is to open) the star. Both are drawn by inverting. *)
type marker = { fade : int -> int -> unit; draw : int -> int -> unit }
val arrow : marker
val star : marker
val draw_mouse : marker -> int -> int -> unit
val draw_mouse_arrow : int -> int -> unit
val fade_mouse : unit -> unit
val draw_pointer : int -> int -> unit
(* the viewer the pointer marks (where the star is, or was) *)
val marked_viewer : unit -> Viewers.viewer option
(* the cursors that are in a rectangle, or near, taken away before it is drawn in *)
val remove_marks : int -> int -> int -> int -> unit

(* [open_display uw sw h]: two tracks, the user's and the system's, of
 * those widths, each all its filler's (done when this module starts,
 * for the display's five eighths and three eighths) *)
val open_display : int -> int -> int -> unit
val display_width : int
val display_height : int
(* a track's left edge *)
val user_track : int
val system_track : int
(* a track over the tracks from x, w wide (System.Grow) *)
val open_track : int -> int -> unit
(* where to open a viewer, in the user's track and in the system's:
 * at the pointer if it is set, else by a rule on the heights there *)
val allocate_user_viewer : unit -> int * int
val allocate_system_viewer : unit -> int * int

(* The log: the text the system and the commands write their messages in *)
val log : Texts.t ref
val open_log : Texts.t -> unit

(* Where the command being run was called from: its viewer, the frame
 * and the text its name is in, and the position after its name, where
 * its parameters are read *)
type par = { mutable vwr : Viewers.viewer option; mutable frame : Display.frame option; mutable text : Texts.t; mutable pos : int }
val par : par
val set_par : Display.frame -> Texts.t -> int -> unit
(* a command by its name, M.P: false when there is none. One that
 * raises an exception is abandoned, the exception said in the log *)
val call : string -> bool

(* the looks of what is typed *)
val cur_fnt : Fonts.t ref

(* A task: a procedure the loop calls every [period] of its turns when
 * the mouse and the keyboard say nothing *)
type task
val new_task : (unit -> unit) -> int -> task
val install : task -> unit
val remove : task -> unit
val nof_tasks : unit -> int

(* the viewer the characters typed go to; [pass_focus] tells the one that had them *)
val focus_viewer : Viewers.viewer option ref
val pass_focus : Viewers.viewer option -> unit

(* for ever: the mouse and the keys asked, a message sent *)
val loop : unit -> unit
