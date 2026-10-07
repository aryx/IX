(* Elm's subscriptions: what a program asks to be told of (a frame,
 * a key, the mouse), each with the function that makes its message of
 * it. A platform has the events; [event_to_msgopt] is the meeting. *)
(* ix: the playground has no interface for this module; ix has one for
 * each (what the .ml gives, no more). *)

type 'msg onesub =  
  | SubTick of (Time.posix -> 'msg)
  | SubMouseMove of (float * float -> 'msg)
  (* pad: not in Elm: relative motion, dx and dy (y up) *)
  | SubMouseMoveBy of (float * float -> 'msg)
  | SubMouseDown of (unit -> 'msg)
  | SubMouseUp of (unit -> 'msg)
  (* pad: not in Elm (its onMouseDown gives the event, with its button) *)
  | SubRightMouseDown of (unit -> 'msg)
  | SubRightMouseUp of (unit -> 'msg)
  (* claude: the middle button (the wheel pressed), as the right one *)
  | SubMiddleMouseDown of (unit -> 'msg)
  | SubMiddleMouseUp of (unit -> 'msg)
  | SubKeyDown of (string -> 'msg)
  | SubKeyUp of (string -> 'msg)
  (* claude: the three an application needs and a game never did (see
   * docs/claude_notes/plans/plan_gui_teaching.md, phase 0): the
   * characters a key press produces (a key name is not a character:
   * shift, dead keys and layouts are the platform's business), the
   * wheel, and the double click *)
  | SubTyped of (string -> 'msg)
  | SubMouseWheel of (float -> 'msg)
  | SubMouseDouble of (unit -> 'msg)
  (* claude: the program's screen, its width and height, when the platform
   * gives it one other than the default (Playground_platform.run_app's
   * Playground.window's screen_size) *)
  | SubResize of (int -> int -> 'msg)


type 'msg t = 'msg onesub list

val none : 'msg t
val batch : 'msg t list -> 'msg t

val on_animation_frame : (Time.posix -> 'msg) -> 'msg t
val on_mouse_move : (float * float -> 'msg) -> 'msg t
val on_mouse_move_by : (float * float -> 'msg) -> 'msg t
val on_mouse_down : (unit -> 'msg) -> 'msg t
val on_mouse_up : (unit -> 'msg) -> 'msg t
val on_right_mouse_down : (unit -> 'msg) -> 'msg t
val on_right_mouse_up : (unit -> 'msg) -> 'msg t
val on_middle_mouse_down : (unit -> 'msg) -> 'msg t
val on_middle_mouse_up : (unit -> 'msg) -> 'msg t
val on_key_down : (string -> 'msg) -> 'msg t
val on_key_up : (string -> 'msg) -> 'msg t
val on_typed : (string -> 'msg) -> 'msg t
val on_mouse_wheel : (float -> 'msg) -> 'msg t
val on_mouse_double : (unit -> 'msg) -> 'msg t
val on_resize : (int -> int -> 'msg) -> 'msg t

(* what a platform saw happen *)
type event = 
  | ETick of float
  | EMouseMove of (int * int)
  | EMouseMoveBy of (float * float) (* dx, dy, y up *)
  | EMouseButton of bool (* is_down = true *)
  | ERightMouseButton of bool (* is_down = true *)
  | EMiddleMouseButton of bool (* claude: the same, for the middle button *)
  | EKeyChanged of (bool (* down = true *) * string)
  (* claude: the characters typed, not the keys pressed *)
  | ETyped of string
  (* claude: notches up (positive) or down since the last frame *)
  | EMouseWheel of float
  | EMouseDouble
  | EResized of (int * int)

(* the message of the first subscription that asked for this event *)
val event_to_msgopt : event -> 'msg t -> 'msg option
