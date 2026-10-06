(* The system's centre (Oberon's Oberon): the loop that asks the mouse
 * and the keyboard and sends what happened to a viewer, the messages
 * it sends, the two cursors, and the display's two tracks.
 *
 * Not here yet: the log, the commands and their parameters (Par,
 * Call), the tasks. *)

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
(* the latest selection: a text and where, or None *)
val get_selection : unit -> (Texts.t * int * int) option
(* a number that grows: which of two things came later *)
val time : unit -> int

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
(* the cursors that are in a rectangle, or near, taken away before it is drawn in *)
val remove_marks : int -> int -> int -> int -> unit

(* [open_display uw sw h]: two tracks, the user's and the system's, of
 * those widths, each all its filler's *)
val open_display : int -> int -> int -> unit
val display_width : int
val display_height : int
(* a track's left edge *)
val user_track : int
val system_track : int

(* the viewer the characters typed go to; [pass_focus] tells the one that had them *)
val focus_viewer : Viewers.viewer option ref
val pass_focus : Viewers.viewer option -> unit

(* for ever: the mouse and the keys asked, a message sent *)
val loop : unit -> unit
