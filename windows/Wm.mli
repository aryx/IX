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
(* a window there, in front, rc started in it ([served]:
 * Processes_winshell.start's); said on the console when there are too
 * many *)
val create : < Cap.fork; Cap.exec; Cap.mount; Cap.open_in; Cap.open_out; .. > -> Display.desktop -> Font.t -> Unix.file_descr -> Rectangle.t -> unit
(* in front, and in another rectangle: moved (the same size), or made
 * another size *)
val reshape : Window.t -> Rectangle.t -> unit
(* its processes told to end (hangup), its thread too; the next one in front *)
val delete : < Cap.open_out; .. > -> Window.t -> unit
(* off the screen (the keyboard to the next one that shows), and back *)
val hide : Window.t -> unit
val show : Window.t -> unit
