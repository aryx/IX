(* A window (Plan 9's rio; xix's Window): a rectangle of the screen
 * with a border and its text, the process that runs in it, and what
 * goes between the two: the keys typed in it are a line when Enter
 * comes, and the lines wait for the process's reads of its console. *)

type t = {
  id : int;
  image : Display.image;
  term : Terminal.t;
  mutable pid : int;
  (* the line being typed; the lines typed and not read (and what a
   * read left of one); the reads that wait *)
  typing : Buffer.t;
  lines : string Queue.t;
  mutable rest : string;
  readers : ((string -> unit) * int) Queue.t;
  (* a program that draws in the window: the keys as they are typed
   * (consctl's rawon); the mouse, when it has the window's mouse file
   * open: its last change not read yet, the reads that wait *)
  mutable raw : bool;
  mutable mouse_open : bool;
  mutable moved : Mouse.state option;
  mouse_readers : (string -> unit) Queue.t;
}

(* a window on the desktop: its image, a border, its text inside *)
val make : Display.desktop -> int -> Rectangle.t -> Font.t -> t
(* the border, for the window that has the keyboard or for another *)
val border : t -> current:bool -> unit

(* keys typed in it: shown, and kept until Enter makes them a line
 * (Backspace takes one back, Ctrl-U all, Ctrl-D ends the input) *)
val typed : t -> string -> unit
(* a read of its console: answered now if a line waits, or when one does *)
val read : t -> (string -> unit) -> int -> unit
(* what its process wrote *)
val wrote : t -> string -> unit

(* its text drawn again, all the inside of its border (a program drew there) *)
val repaint : t -> unit
(* its image's name, for the program in it to draw there (Display.named) *)
val name : t -> string
(* the mouse moved or a button changed, in it: for its mouse file's reads *)
val mouse : t -> Mouse.state -> unit
(* a read of its mouse file: answered at the next change (at once, the first time) *)
val read_mouse : t -> (string -> unit) -> unit
