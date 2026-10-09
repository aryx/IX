(* A window's wctl file (rio's wctl.c, Qwctl): a program writes it what
 * the menu does with the mouse, a command a write:
 *
 *   new [-r minx miny maxx maxy] [-hide] [-scroll] [-noscroll] [command]
 *   resize, move    with -r, or -minx n -miny n -maxx n -maxy n -dx n
 *                   -dy n (a number after + or -: that much more or
 *                   less than it is)
 *   top, bottom, current, hide, unhide, delete, scroll, noscroll
 *
 * each but new about the window whose file it is, or the one -id n
 * says. A read is the window's rectangle and what it is: four numbers
 * as the kernel's files say them, then current or notcurrent, hidden
 * or visible.
 *
 * Not rio's: -cd and -pid, set; a read does not wait for the window to
 * change; a command is done after the write is answered, so what it
 * cannot do (a window that is not there, a rectangle too small) is not
 * said to its writer. *)

type verb = New | Resize | Move | Top | Bottom | Current | Hide | Unhide | Delete | Scroll | Noscroll

type command = {
  verb : verb;
  (* the rectangle wanted, from the one the window has (a new one's:
   * the window system's choice) *)
  place : Rectangle.t -> Rectangle.t;
  hidden : bool;                (* new -hide *)
  scrolling : bool option;      (* new -scroll, -noscroll *)
  id : int option;              (* -id: another window than the file's *)
  arg : string;                 (* new's command: "" for rc itself *)
}

(* a write's text; P9_server.Error with rio's words when it is no command *)
val parse : string -> command

(* The commands written, for the window system's thread, which alone
 * changes the windows there are: each with the window whose file was
 * written. The file server does not wait for it (a menu may be open):
 * a thread a command carries it. *)
val requests : (Window.t * command) Event.channel

val wctl : Device.t
