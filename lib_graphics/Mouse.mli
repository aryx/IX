(* The mouse (Plan 9's /dev/mouse; libdraw's mouse.c; xix's
 * lib_graphics/input). Each change of the mouse is a message, with its
 * place on the screen and its buttons. A Source reads the device: a
 * thread receives the messages, and may choose between the mouse and
 * something else.
 *
 * A read of /dev/mouse waits until the mouse has changed, and returns 49
 * bytes of text: a letter and four numbers, each right-aligned in 12
 * characters (shown shorter here):
 *
 *     m   412   230     1   83512
 *         x     y       buttons    milliseconds
 *
 * So `cat /dev/mouse' shows the mouse, and a session can be recorded
 * and played again with a text editor. A program that wants the mouse,
 * the keyboard and a timer cannot wait in three reads at once. Source
 * gives each file a thread that reads it and sends what it read on a
 * channel, and the program waits on all the channels together
 * (Event.select). Plan 9's C library does the same with a process for
 * each device (initmouse, initkeyboard).
 *
 * Here is where it stands. The file is the kernel's when the program
 * has the whole screen. In a window, it is the file that mini-rio
 * serves in its place (Virtual_mouse), with the same 49 bytes: it gives
 * the mouse's changes while the mouse is over that window and the
 * window is the current one, in the screen's coordinates. A program
 * does not know which file it reads.
 *
 * plan9-is-cleaner:
 * No event has a type here, and there is no queue of events with a
 * mask of the ones wanted, as X has (a button pressed, a button
 * released, a motion, an enter, a leave, each a structure). There is
 * the state, sent again when it changes. A press is a state whose
 * buttons differ from the one before; a program that was busy reads the
 * newest state and has lost nothing it needed.
 *
 * design:
 * There are three buttons, each with a use that Plan 9's programs agree
 * on: the first selects, the second and third bring up a menu (Menu),
 * and two held together are a command (acme's cut and paste). The r in
 * place of the m is how a window system says, in the stream the
 * program already reads, that its window changed.
 *
 * References: mouse(3) of Plan 9's manual, for the file; mouse(2), for
 * the library followed here; Rob Pike, "A Concurrent Window System"
 * (Computing Systems, 1989), on a window system's devices as channels
 * read by processes. *)

(* buttons: 1 is the left one, 2 the middle, 4 the right; when several
 * are down, it is their sum *)
type state = {
  pos : Point.t; buttons : int; msec : int;
  (* the program's window was moved or given another size (a window
   * system's file says so, with r as the read's letter): the program
   * must ask again where it draws (Display.screen), and draw again *)
  resized : bool;
}

type t

val init : < Cap.mouse; Cap.fork; .. > -> t
(* returns the next change *)
val receive : t -> state Event.event
