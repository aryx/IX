(* The window manager (rio's wm.c and the lists of its wind.c; xix's Wm
 * and Globals). It keeps the windows there are and which one is in
 * front, and it does what the menu does to a window. The window
 * system's thread calls these functions; a window's own state is
 * changed by messages to its thread. *)

(* the windows, the one in front first; the first has the keyboard
 * (the hidden ones are last) *)
val windows : Window.t list ref
(* all the windows, those of a layer too (Window.layer), which
 * [windows] does not have *)
val all : unit -> Window.t list
(* the window with a number (a mount's spec) *)
val find : int -> Window.t option
(* the window that has the keyboard, when it is shown *)
val current : unit -> Window.t option
(* the normal window a point is in, the one in front of the others
 * there; none when a popup or a panel is over it there *)
val at : Point.t -> Window.t option
(* the window of a layer that a point is in: a popup, a panel, or a desk
 * when no window is there *)
val layer_at : Point.t -> Window.t option
(* the popups that are shown *)
val popups : unit -> Window.t list
(* puts the layers back in order when a window has a new image *)
val restack : Window.t -> unit
(* [work_of screen taken] is what is left of the screen for windows
 * when the rectangles [taken] are panels. A panel along a whole side
 * takes its depth off that side; any other panel takes nothing. *)
val work_of : Rectangle.t -> Rectangle.t list -> Rectangle.t
(* the window whose border a point is on, and which of its corners and
 * sides the point is on, numbered three by three from the top left
 * (rio's whichcorner; a corner is the 20 pixels at a side's end) *)
val border : Point.t -> (Window.t * int) option
(* the windows off the screen, as the menu lists them *)
val hidden : unit -> Window.t list

(* puts a window in front, with the keyboard; the one that had the
 * keyboard is told *)
val front : Window.t -> unit
(* whether a rectangle is one a window may have (100 by 50, at least) *)
val fits : Rectangle.t -> bool
(* [create caps desk font srv r c] makes a window at r, in front, and
 * starts rc in it, or new's command, as [c] says ([srv] is
 * Processes_winshell.start's). It returns none, and says so on the
 * console, when there are too many. *)
val create : < Cap.chdir; Cap.fork; Cap.exec; Cap.mount; Cap.bind; Cap.open_in; Cap.open_out; .. > -> Display.desktop -> Font.t -> string -> Rectangle.t -> Wctl.command -> Window.t option
(* puts a window in front, in another rectangle: it is moved (the same
 * size), or made another size *)
val reshape : Window.t -> Rectangle.t -> unit
(* tells a window's processes to end (hangup), ends its thread too, and
 * puts the next window in front *)
val delete : < Cap.open_out; .. > -> Window.t -> unit
(* takes a window off the screen (the keyboard goes to the next one that
 * is shown), and puts it back *)
val hide : Window.t -> unit
val show : Window.t -> unit
(* puts a window behind the others; the keyboard goes to the one then in
 * front *)
val bottom : Window.t -> unit

(* [control caps make screen w c] does a command written to w's wctl
 * file (w is none for the root's). [make] is [create] given all but
 * the rectangle and the command. [screen] is the screen's rectangle;
 * less what the panels take, it is where a new window with no
 * rectangle said is put, 600 by 400 at most, each one a little further
 * than the last, as in rio. What cannot be done is not done: a window
 * that is not there, a rectangle too small. top and current are the
 * same here, because the window in front has the keyboard. *)
val control : < Cap.open_out; .. > -> (Rectangle.t -> Wctl.command -> Window.t option) -> Rectangle.t -> Window.t option -> Wctl.command -> unit
