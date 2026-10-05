(* A window (Plan 9's rio; xix's Window and Threads_window): a
 * rectangle of the screen with a border and its text, the process
 * that runs in it, and what goes between the two.
 *
 * A window is a thread (Rob Pike's design for rio: "a window is a
 * process"): it waits for messages on its channel and is the only one
 * to touch its text and its state. The others send it what happens:
 * the window system the keys and the mouse, the file server what the
 * window's process asks of its files. A console's read that finds no
 * line typed is simply not answered yet: the thread keeps its reply
 * and goes on waiting for messages. *)

type message =
  | Keys of string                      (* typed, the window in front *)
  | Moved of Mouse.state                (* the mouse, in the window *)
  | Read of (string -> unit) * int      (* its console read: how to answer, how many bytes at most *)
  | Wrote of string                     (* its console written *)
  | Raw of bool                         (* consctl's rawon, rawoff: the keys as they are typed *)
  | Mouse_file of bool                  (* its mouse file opened, or closed *)
  | Mouse_read of (string -> unit)      (* a read of it: answered at the mouse's next change *)
  | Front of bool                       (* it has the keyboard, or lost it: the border's colour *)
  | Reshape of Rectangle.t              (* moved (the same size), or made another size *)
  | Hide of bool                        (* off the screen, or back *)
  | Quit                                (* deleted: its image freed, its thread ends *)

type t = {
  id : int;
  (* (its image is another when its size changes: the thread's to
   * change, the window system's to read, as [hidden]) *)
  mutable image : Display.image;
  mutable hidden : bool;
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
(* what the menu calls it when hidden *)
val label : t -> string
(* a note for a window's processes (the Delete key: "interrupt"): the
 * window system says how *)
val note : (t -> string -> unit) ref
(* where the mouse is, as the window system last saw it (a mouse file's first read) *)
val pointer : Mouse.state ref
