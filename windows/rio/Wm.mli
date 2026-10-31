(* The window manager (rio's wm.c and wind.c's lists; xix's Wm and
 * Globals): the windows there are, which is in front, and what the
 * menu does to one. The window system's thread calls these; a
 * window's own state is changed by messages to its thread. *)

(* the windows, the one in front first; the first has the keyboard
 * (the hidden ones are last) *)
val windows : Window.t list ref
(* the one of a number (a mount's spec) *)
val find : int -> Window.t option
(* the one that has the keyboard, when it shows *)
val current : unit -> Window.t option
(* the one a point is in, the one in front of the others there *)
val at : Point.t -> Window.t option
(* the window whose border a point is on, and which of its corners and
 * sides, three by three from the top left (rio's whichcorner: a
 * corner is the 20 pixels at a side's end) *)
val border : Point.t -> (Window.t * int) option
(* the ones off the screen, as the menu lists them *)
val hidden : unit -> Window.t list

(* in front, with the keyboard; the one that had it told *)
val front : Window.t -> unit
(* whether a rectangle is one a window may have (100 by 50, at least) *)
val fits : Rectangle.t -> bool
(* [create caps desk font srv r command]: a window there, in front, rc
 * started in it, or the command ([srv], [command]:
 * Processes_winshell.start's); none, and said on the console, when
 * there are too many *)
val create : < Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> Display.desktop -> Font.t -> string -> Rectangle.t -> string -> Window.t option
(* in front, and in another rectangle: moved (the same size), or made
 * another size *)
val reshape : Window.t -> Rectangle.t -> unit
(* its processes told to end (hangup), its thread too; the next one in front *)
val delete : < Cap.open_out; .. > -> Window.t -> unit
(* off the screen (the keyboard to the next one that shows), and back *)
val hide : Window.t -> unit
val show : Window.t -> unit
(* behind the others, the keyboard to the one then in front *)
val bottom : Window.t -> unit

(* [control caps make screen w c]: a command written to w's wctl file,
 * done ([make]: create, but for the rectangle and the command;
 * [screen]: the screen's rectangle, where a new window with no
 * rectangle said is put, 600 by 400 at most, each a little further
 * than the last, as rio's). What cannot be done is not: a window
 * that is not there, a rectangle too small. top and current are one
 * here: the window in front has the keyboard *)
val control : < Cap.open_out; .. > -> (Rectangle.t -> string -> Window.t option) -> Rectangle.t -> Window.t -> Wctl.command -> unit
