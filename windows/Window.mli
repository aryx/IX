(* A window (Plan 9's rio; xix's Window and Threads_window): a
 * rectangle of the screen with a border and its text, the process
 * that runs in it, and what goes between the two.
 *
 * A window is a thread (Rob Pike's design for rio: "a window is a
 * process"): it waits for messages on its channel and is the only one
 * to change its text and its state. The others send it what happens:
 * the window system the keys and the mouse, the file server what the
 * window's process asks of its files. A console's read that finds no
 * line typed is simply not answered yet: the thread keeps its reply
 * and goes on waiting for messages.
 *
 *     the window system --Keys, Moved, Reshape...--.
 *                                                  v
 *                                    the window's thread:
 *     the file server ---Read, Wrote of cons--->   one message at a
 *     (a 9P request of the window's process)       time, its text and
 *                                                  state its own
 *
 * design:
 * No lock. A window's state is touched by one thread, and whoever
 * wants it changed sends a message, taken when the thread is ready
 * for one: the order the messages are taken in is the order things
 * happen, and there is nothing to forget to protect. A window
 * system written as one loop over all the events must instead be a
 * state machine that remembers, for each window, what it was in the
 * middle of (a read waiting, a menu open, a rectangle being swept);
 * with a thread a window, that memory is where the thread is in its
 * code. This is Hoare's communicating sequential processes (1978), which Pike
 * took through his languages (Newsqueak, where the first such
 * window system was written; Alef, Plan 9's; then Go, 2009, whose
 * goroutines and channels are these) and the thread library rio
 * uses in C. Here they are Thread and Event's channels, a send
 * waiting for its receive ([send]). *)

type message =
  | Keys of string list                 (* typed, the window in front: characters, each its bytes *)
  | Moved of Mouse.state                (* the mouse, in the window: its program's when it reads
                                           the mouse, else the text's (the scroll bar, selecting) *)
  | Read of (string -> bool) * int      (* its console read: how to answer (false: the reader is
                                           gone, nothing was taken), how many bytes at most *)
  | Wrote of string * (string -> bool)  (* its console written: the text, and how to answer the
                                           write (with "") once it is shown: a window that does
                                           not scroll holds it while its end is not shown *)
  | Scroll of bool                      (* its text follows what is written, or not (the menu, wctl) *)
  | Raw of bool                         (* consctl's rawon, rawoff: the keys as they are typed *)
  | Mouse_file of bool                  (* its mouse file opened, or closed *)
  | Mouse_read of (string -> bool)      (* a read of it: answered at the mouse's next change *)
  | Held of string                      (* the keys down changed (/dev/kbd's message), the window in front *)
  | Held_read of (string -> bool)       (* a read of its kbd file: answered at the next change *)
  | Held_file of bool                   (* its kbd file opened, or closed: the changes are kept
                                           for it from then (a key may come before its first read) *)
  | Label of string                     (* its label written: its name is its program's to say *)
  | Cursor of Cursor.t option           (* its cursor written: the mouse's picture while in it *)
  | Front of bool                       (* it has the keyboard, or lost it: the border's colour *)
  | Reshape of Rectangle.t              (* moved (the same size), or made another size *)
  | Hide of bool                        (* off the screen, or back *)
  | Quit                                (* deleted: its image freed, its thread ends *)

type t = {
  id : int;
  (* (its image is another when its size changes: the thread's to
   * change, the window system's to read, as [hidden]) *)
  mutable image : Display.image;
  (* its text (another when its size changes): the thread's to change;
   * the window system calls its menu on the middle button
   * (Terminal.menu, which reads what is selected there), as rio's
   * mouse thread calls button2menu on a window *)
  mutable text : Terminal.t;
  mutable hidden : bool;
  (* it has the keyboard (the thread's to change: Front) *)
  mutable current : bool;
  (* what the menu calls it when hidden: "rc 3", until its program
   * writes its label (the thread's to change, as its cursor) *)
  mutable label : string;
  (* its program's cursor, shown while the mouse is in the window: the
   * program's until it writes another (less than a cursor: the arrow)
   * or closes its mouse file. rio's lasts as long as the cursor file
   * is open; ix's Cursor.set opens, writes and closes *)
  mutable cursor : Cursor.t option;
  inbox : message Event.channel;
  mutable pid : int;
  (* its program reads the mouse: the window system gives it the mouse
   * in the window, buttons and all (said by the thread, read by the
   * window system) *)
  mutable wants_mouse : bool;
  mutable thread : Thread.t option;
}

(* a window on the desktop, and its thread started; Failure when there
 * are too many threads (Thread.create's) *)
val make : Display.desktop -> int -> Rectangle.t -> Font.t -> t
(* a message for it: the sender waits until the thread takes it *)
val send : t -> message -> unit
(* Quit sent, and its thread ended *)
val quit : t -> unit

(* its image's name, for the program in it to draw there (Display.named) *)
val name : t -> string
(* whether a point is in its text's scroll bar: a press there is the
 * window's, not the window system's (rio's mouse thread asks the same
 * of a window's scroll rectangle) *)
val in_bar : t -> Point.t -> bool
(* its text, all of it (its text file) *)
val text : t -> string
(* whether a point is on its border: a handle, the window system's
 * even when the window's program reads the mouse (rio's winborder) *)
val on_border : t -> Point.t -> bool
(* a note for a window's processes (the Delete key: "interrupt"): the
 * window system says how *)
val note : (t -> string -> unit) ref
(* where the mouse is, as the window system last saw it (a mouse file's first read) *)
val pointer : Mouse.state ref
