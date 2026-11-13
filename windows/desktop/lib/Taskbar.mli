(* What the panel knows and decides, computed without a screen: the
 * windows as rio describes them, where each button goes, and what a
 * press on one asks for.
 *
 *     /dev/wsys/N/{wctl,label} --window_of--> window --layout--> buttons
 *                                                        |
 *                 a press at a point --at--> part --press--> wctl's words
 *
 * design:
 * The panel is a program like another, in a window, and rio knows nothing
 * of buttons. All it asks of rio is what any program may: read a directory
 * and two files, and write a line to a wctl. A window opened by a program
 * that never heard of a panel gets a button, because what the panel lists
 * is rio's own account of its windows.
 *
 * cs-history:
 * A list of the open programs always on the screen is Windows 95's taskbar
 * (1995), which is where the start button is from too. NeXTSTEP's Dock
 * (1989) came first with a strip of running programs, as icons. Plan 9's
 * rio has neither: its open windows are on the screen, and the hidden ones
 * are names in the right button's menu.
 *
 * others:
 * Under X a panel is also a client, but learns the windows through
 * properties a window manager agrees to set (EWMH's _NET_CLIENT_LIST and
 * _NET_ACTIVE_WINDOW), and asks by sending it client messages. Here that
 * agreement is a directory and a command file. *)

type window = {
  id : int;
  label : string;
  current : bool;
  hidden : bool;
  (* wctl's last word: "" for a normal window, else desk, panel or popup *)
  layer : string;
}

(* [window_of id label wctl] is the window, from what its wctl file
 * reads *)
val window_of : int -> string -> string -> window option

(* the windows that get a button: the normal ones *)
val tasks : window list -> window list
(* the window of the start button: a popup labelled startmenu *)
val menu : window list -> window option

type part = Start | Overview | Task of window | Clock

(* [layout r tasks clock_width] cuts the panel's rectangle into buttons:
 * the start button on the left, with the overview's beside it (expose:
 * all the windows at once), the clock on the right, and between them a
 * button for each task. Those buttons all have the same width, which is
 * narrower when there are many. *)
val layout : Rectangle.t -> window list -> int -> (part * Rectangle.t) list
val at : (part * Rectangle.t) list -> Point.t -> part option

(* [shorten width_of room text] is as much of the text as fits, followed
 * by ... when not all of it does *)
val shorten : (string -> int) -> int -> string -> string

(* [press windows part] is what a press on a part asks: the lines for
 * wctl, and the windows as they will be, so that the button changes at
 * once and not at the next look at rio's files.
 * - A press on a task brings it to the front, or hides it when it has
 *   the keyboard already, or brings it back when it is hidden.
 * - A press on the overview's button starts expose, in a popup that
 *   takes all the room.
 * - When the menu is shown, a press on anything but the start button
 *   hides it; the start button shows or hides it. *)
val press : window list -> part -> string list * window list
