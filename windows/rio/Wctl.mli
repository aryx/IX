(* A window's wctl file (rio's wctl.c, Qwctl). A program writes to it
 * what the menu does with the mouse, one command per write:
 *
 *   new [-r minx miny maxx maxy] [-at where width height] [-max]
 *       [-hide] [-scroll] [-noscroll] [-label word] [-cd dir] [-hold]
 *       [-desk] [-panel] [-popup] [-edge top|bottom|left|right size]
 *       [command]
 *   resize, move    with -r, or -minx n -miny n -maxx n -maxy n -dx n
 *                   -dy n (a number after + or - means that much more
 *                   or less than it is)
 *   top, bottom, current, hide, unhide, delete, scroll, noscroll
 *   exit            ends the window system, as its menu's Exit does
 *
 * Each command but new and exit is about the window whose file it is,
 * or about the one -id n names.
 * - -at and -max give a place in what the screen has for windows,
 *   whatever its size, which a script cannot compute (rc has no
 *   arithmetic). -at's where is nw, n, ne, w, c, e, sw, s or se. new,
 *   resize and move take them.
 * - With new -hold, the window stays when its command ends.
 * - new -desk, -panel and -popup give the window's layer
 *   (Window.layer). A desk covers the whole screen if nothing else is
 *   said.
 * - -edge puts the window along that side of what the screen has, that
 *   many pixels deep. A panel placed so takes that much from what
 *   windows are given.
 * A read gives the window's rectangle and its state: four numbers,
 * written as the kernel's files write them, then current or
 * notcurrent, hidden or visible, and, for a window of a layer, the
 * layer's name (desk, panel or popup).
 *
 * These are not rio's: -at, -max, -label, -hold, the layers, -edge and
 * exit. These of rio's are not here: -pid and set. A read does not wait
 * for the window to change. A command is done after the write is
 * answered, so its writer is not told what it cannot do (a window that
 * is not there, a rectangle too small). *)

type verb = New | Resize | Move | Top | Bottom | Current | Hide | Unhide | Delete | Scroll | Noscroll | Exit

type command = {
  verb : verb;
  (* the rectangle wanted, computed from the one the window has (for a
   * new window, from the window system's choice) *)
  place : Rectangle.t -> Rectangle.t;
  (* or (with -at, -max, -edge) computed from what the screen has for windows,
   * whatever rectangle the window had *)
  area : (Rectangle.t -> Rectangle.t) option;
  hidden : bool;                (* new -hide *)
  scrolling : bool option;      (* new -scroll, -noscroll *)
  id : int option;              (* -id: a window other than the file's *)
  arg : string;                 (* new's command: "" for rc itself *)
  label : string;               (* new -label: "" for its command's name *)
  cd : string;                  (* new -cd: "" for the window system's directory *)
  hold : bool;                  (* new -hold: it stays when its command ends *)
  layer : Window.layer;         (* new -desk, -panel, -popup *)
}

(* new with nothing else said: what the menu's New asks for *)
val plain : command

(* parses a write's text; raises P9_server.Error, with rio's words, when
 * it is not a command *)
val parse : string -> command

(* The commands written, for the window system's thread, which alone
 * changes the windows there are. Each command comes with the window
 * whose file was written, or with none for the wctl of no window (the
 * root of the window system's files: Fileserver). The file server does
 * not wait for that thread (a menu may be open): a new thread carries
 * each command. *)
val requests : (Window.t option * command) Event.channel

(* a write of a wctl file, which is parsed and given to that thread *)
val written : Window.t option -> string -> unit
(* a window's command ended: asks for its window to be deleted *)
val ended : Window.t -> unit

val wctl : Device.t
