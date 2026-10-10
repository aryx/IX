(* The mouse (Plan 9's /dev/mouse; libdraw's mouse.c; xix's
 * lib_graphics/input): each change of it a message, its place on the
 * screen and its buttons. The device is read by a Source: a thread
 * receives, and may choose between the mouse and something else.
 *
 * A read of /dev/mouse waits until the mouse has changed, and is 49
 * bytes of text, a letter and four numbers each right in 12
 * characters (shown shorter):
 *
 *     m   412   230     1   83512
 *         x     y       buttons    milliseconds
 *
 * so `cat /dev/mouse' shows the mouse, and a session is recorded and
 * played again with a text editor. A program that wants the mouse
 * and the keyboard and a timer cannot wait in three reads at once:
 * Source gives each file a thread that reads and sends what it read
 * on a channel, and the program waits on the channels together
 * (Event.select). Plan 9's C library does the same with a process a
 * device (initmouse, initkeyboard).
 *
 * Where it stands: the kernel's file when the program has the whole
 * screen; in a window, the file that mini-rio serves in its place
 * (Virtual_mouse), with the same 49 bytes: the mouse's changes while
 * it is over that window and the window is the current one, in the
 * screen's coordinates. A program does not know which it reads.
 *
 * plan9-is-cleaner:
 * No event has a type here, and there is no queue of events with a
 * mask of the ones wanted, as X has (a button pressed, a button
 * released, a motion, an enter, a leave, each a structure): there is
 * the state, sent again when it changes. A press is a state whose
 * buttons differ from the one before; a program that was busy reads
 * the newest state and has lost nothing it needed.
 *
 * design:
 * Three buttons, each with a use that Plan 9's programs agree on:
 * the first selects, the second and third bring a menu (Menu), and
 * two held together are a command (acme's cut and paste). The r in
 * the place of the m is how a window system says, in the stream the
 * program already reads, that its window changed.
 *
 * References: mouse(3) of Plan 9's manual, the file; mouse(2), the
 * library followed here; Rob Pike, "A Concurrent Window System"
 * (Computing Systems, 1989), a window system's devices as channels
 * read by processes. *)

(* buttons: 1 the left one, 2 the middle, 4 the right; their sum when
 * several are down *)
type state = {
  pos : Point.t; buttons : int; msec : int;
  (* the program's window was moved or made another size (a window
   * system's file says so: the read's letter is r): where it draws is
   * to be asked again (Display.screen), and drawn again *)
  resized : bool;
}

type t

val init : < Cap.mouse; Cap.fork; .. > -> t
(* the next change *)
val receive : t -> state Event.event
