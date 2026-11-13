(* A window (Plan 9's rio; xix's Window and Threads_window): a
 * rectangle of the screen with a border and its text, the process
 * that runs in it, and what goes between the two.
 *
 * A window is a thread (Rob Pike's design for rio: each component is
 * a process). It waits for messages on its channel and is the only
 * one to change its text and its state. The others send it what
 * happens: the window system sends the keys and the mouse, and the
 * file server sends what the window's process asks of its files. A
 * console's read that finds no line typed is simply not answered yet:
 * the thread keeps its reply and goes on waiting for messages.
 *
 *     the window system --Keys, Moved, Reshape...--.
 *                                                  v
 *                                    the window's thread
 *     the file server ---Read, Wrote of cons--->   takes one message
 *     (a 9P request of the window's process)       at a time; its text
 *                                                  and state are its own
 *
 * design:
 * There is no lock. A window's state is touched by one thread, and
 * whoever wants it changed sends a message, which is taken when the
 * thread is ready for one. The order the messages are taken in is the
 * order things happen, and there is nothing to forget to protect. A
 * window system written as one loop over all the events must instead
 * be a state machine that remembers, for each window, what it was in
 * the middle of (a read waiting, a menu open, a rectangle being
 * swept). With a thread for each window, that memory is where the
 * thread is in its code. This is Hoare's communicating sequential
 * processes (1978), which Pike carried through his languages
 * (Newsqueak, in which the first such window system was written;
 * Alef, Plan 9's; then Go, 2009, whose goroutines and channels are
 * these) and through the thread library that rio uses in C. Here they
 * are Thread and Event's channels, where a send waits for its receive
 * ([send]). *)

(* Where a window is among the others (this is not rio's; see
 * plan_desktop.md). Most windows are Normal. A Desk is below them all,
 * a Panel is above them all, and a Popup is above the panels and is
 * hidden by a press anywhere else. These three have no border, never
 * have the keyboard, and take the mouse without coming to the front:
 * this is what a desktop's wallpaper, bar and menu need. *)
type layer = Normal | Desk | Panel | Popup

type message =
  | Keys of string list                (* keys typed while the window is in front: characters,
                                          each given as its bytes *)
  | Moved of Mouse.state                (* the mouse in the window: it goes to its program when the
                                           program reads the mouse, else to the text (the scroll
                                           bar, selecting) *)
  | Read of (string -> bool) * int      (* a read of its console: how to answer (false: the reader
                                           is gone, and nothing was taken), and how many bytes at
                                           most *)
  | Wrote of string * (string -> bool)  (* a write of its console: the text, and how to answer the
                                           write (with "") once the text is shown. A window that
                                           does not scroll holds it while its end is not shown. *)
  | Scroll of bool                      (* its text follows what is written, or not (the menu, wctl) *)
  | Raw of bool                         (* consctl's rawon, rawoff: the keys as they are typed *)
  | Mouse_file of bool                  (* its mouse file was opened, or closed *)
  | Mouse_read of (string -> bool)      (* a read of it, answered at the mouse's next change *)
  | Held of string                      (* the keys held down changed (/dev/kbd's message) while
                                           the window is in front *)
  | Held_read of (string -> bool)       (* a read of its kbd file, answered at the next change *)
  | Held_file of bool                   (* its kbd file was opened, or closed: the changes are kept
                                           for it from then on (a key may come before its first
                                           read) *)
  | Label of string                     (* its label was written: its program says its name *)
  | Cursor of Cursor.t option           (* its cursor was written: the mouse's picture while the
                                           mouse is in it *)
  | Front of bool                       (* it got the keyboard, or lost it, which sets the border's
                                           colour *)
  | Reshape of Rectangle.t              (* moved (the same size), or made another size *)
  | Hide of bool                        (* taken off the screen, or put back *)
  | Quit                                (* deleted: its image is freed and its thread ends *)

type t = {
  id : int;
  layer : layer;
  (* (its image is replaced when its size changes; the thread changes
   * it and the window system reads it, as with [hidden]) *)
  mutable image : Display.image;
  (* its text (replaced when its size changes), which the thread
   * changes. The window system calls its menu on the middle button
   * (Terminal.menu, which reads what is selected there), as rio's
   * mouse thread calls button2menu on a window. *)
  mutable text : Terminal.t;
  mutable hidden : bool;
  (* whether it has the keyboard (the thread changes it, at Front) *)
  mutable current : bool;
  (* what the menu calls it when it is hidden: "rc 3", until its program
   * writes its label (the thread changes it, as it does the cursor) *)
  mutable label : string;
  (* its program's cursor, shown while the mouse is in the window. It
   * stays until the program writes another (writing less than a cursor
   * gives the arrow) or closes its mouse file. rio's cursor lasts as
   * long as the cursor file is open; ix's Cursor.set opens the file,
   * writes it and closes it. *)
  mutable cursor : Cursor.t option;
  inbox : message Event.channel;
  mutable pid : int;
  (* whether its program reads the mouse; if so, the window system gives
   * it the mouse in the window, buttons and all (the thread sets it,
   * and the window system reads it) *)
  mutable wants_mouse : bool;
  mutable thread : Thread.t option;
  (* whether it goes away when its console is closed by all who have it
   * open (its command and what that command started), as a window made
   * with a command does *)
  mutable ends : bool;
  (* how many have its console open; only the file server counts them *)
  mutable cons_opens : int;
  (* whether it was deleted; a message for it is then dropped *)
  mutable gone : bool;
}

(* makes a window on the desktop and starts its thread; raises Failure
 * when there are too many threads (Thread.create's) *)
val make : Display.desktop -> int -> Rectangle.t -> Font.t -> layer -> t
(* sends it a message; the sender waits until the thread takes it *)
val send : t -> message -> unit
(* sends Quit, and waits for its thread to end *)
val quit : t -> unit

(* rio's pid, in each window's name (set by Rio.main, which holds Cap.env) *)
val pid : int ref

(* its image's name, for the program in it to draw there (Display.named) *)
val name : t -> string
(* whether a point is in its text's scroll bar: a press there is the
 * window's, not the window system's (rio's mouse thread asks the same
 * of a window's scroll rectangle) *)
val in_bar : t -> Point.t -> bool
(* its text, all of it (its text file) *)
val text : t -> string
(* whether a point is on its border. The border is a handle, and it
 * belongs to the window system even when the window's program reads
 * the mouse (rio's winborder). *)
val on_border : t -> Point.t -> bool
(* sends a note to a window's processes (the Delete key, or Control-C:
 * "interrupt"); the window system says how *)
val note : (t -> string -> unit) ref
(* puts the layers back in order after a window was made another size,
 * since the kernel puts its new image in front of all (Wm says how) *)
val restack : (t -> unit) ref
(* where the mouse is, as the window system last saw it (for a mouse
 * file's first read) *)
val pointer : Mouse.state ref
