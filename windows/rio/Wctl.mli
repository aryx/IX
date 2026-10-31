(* A window's wctl file (rio's wctl.c, Qwctl): a program writes it what
 * the menu does with the mouse, a command a write:
 *
 *   new [-r minx miny maxx maxy] [-at where width height] [-max]
 *       [-hide] [-scroll] [-noscroll] [-label word] [-cd dir] [-hold]
 *       [-desk] [-panel] [-popup] [-edge top|bottom|left|right size]
 *       [command]
 *   resize, move    with -r, or -minx n -miny n -maxx n -maxy n -dx n
 *                   -dy n (a number after + or -: that much more or
 *                   less than it is)
 *   top, bottom, current, hide, unhide, delete, scroll, noscroll
 *   exit            the window system ends, as by its menu's Exit
 *
 * each but new and exit about the window whose file it is, or the one
 * -id n says. -at and -max say a place in what the screen has for
 * windows, whatever its size, which a script cannot compute (rc has no
 * arithmetic): where is nw, n, ne, w, c, e, sw, s or se; new, resize
 * and move take them. new -hold: its window stays when its command
 * ends. new -desk, -panel, -popup: its layer (Window.layer), a desk on
 * the whole screen if nothing else is said. -edge: along that side of
 * what the screen has, that many pixels deep; a panel so placed takes
 * that much from what windows are given. A read is the window's rectangle and what it is: four numbers
 * as the kernel's files say them, then current or notcurrent, hidden
 * or visible, and for a window of a layer, the layer's name: desk,
 * panel or popup.
 *
 * Not rio's: -at, -max, -label, -hold, the layers, -edge, exit. Not here: -pid, set; a read does not wait for the window to
 * change; a command is done after the write is answered, so what it
 * cannot do (a window that is not there, a rectangle too small) is not
 * said to its writer. *)

type verb = New | Resize | Move | Top | Bottom | Current | Hide | Unhide | Delete | Scroll | Noscroll | Exit

type command = {
  verb : verb;
  (* the rectangle wanted, from the one the window has (a new one's:
   * the window system's choice) *)
  place : Rectangle.t -> Rectangle.t;
  (* or (-at, -max) from what the screen has for windows, whatever it had *)
  area : (Rectangle.t -> Rectangle.t) option;
  hidden : bool;                (* new -hide *)
  scrolling : bool option;      (* new -scroll, -noscroll *)
  id : int option;              (* -id: another window than the file's *)
  arg : string;                 (* new's command: "" for rc itself *)
  label : string;               (* new -label: "" for its command's name *)
  cd : string;                  (* new -cd: "" for the window system's directory *)
  hold : bool;                  (* new -hold: it stays when its command ends *)
  layer : Window.layer;         (* new -desk, -panel, -popup *)
}

(* new, nothing else said: what the menu's New asks *)
val plain : command

(* a write's text; P9_server.Error with rio's words when it is no command *)
val parse : string -> command

(* The commands written, for the window system's thread, which alone
 * changes the windows there are: each with the window whose file was
 * written, none for the wctl of no window (the root of the window
 * system's files: Fileserver). The file server does not wait for it (a
 * menu may be open): a thread a command carries it. *)
val requests : (Window.t option * command) Event.channel

(* a write of a wctl file: parsed and given to that thread *)
val written : Window.t option -> string -> unit
(* a window's command ended: asks for its window to be deleted *)
val ended : Window.t -> unit

val wctl : Device.t
