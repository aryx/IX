(* The top window is one of the editor's screens. A key comes in, is
 * looked up in the keymaps, and runs a command on the active frame;
 * the frames and the minibuffer's line (the last line) go out as a
 * screen of cells. It is efuns' Top_window, which is an X window.
 *
 * {b A key's way.} The key's name is made (Keymap.of_bytes); after
 * ESC it is M- and the key. Together with the keys of a sequence begun
 * before it, the key is looked up in the buffer's map, its minor
 * modes' maps, its major mode's map, then the editor's:
 *
 *     C-x          a prefix: it is kept, "C-x-" is shown, and the
 *                  next key is awaited
 *     C-x C-s      a command: it is run on the active frame
 *     a            nothing is bound to it, but it is a character, so
 *                  what <char> is bound to is run
 *     C-x a        nothing: "C-x a is undefined"
 *
 * A command that raises an exception does not end the editor: the
 * exception becomes the message shown (Failure "End of buffer").
 * After a command, the buffer's undo gets a boundary. It does not get
 * one after a character typed, except a space, so that undo takes
 * back a word.
 *
 * {b The minibuffer.} While a question is asked (Efuns.minibuffer;
 * the Minibuffer module asks it), the last line shows its prompt and
 * its frame, the keys go to that frame, and a message shows after the
 * answer, in brackets.
 *
 * {b The loop} that waits for a key is not here but in a host
 * (Tty_unix's select on the terminal, or a window's events). [program]
 * is this module as the three functions a host wants (Tui.mli):
 * update, which is [handle_key] or [resize]; view, which is
 * [display]; and over.
 *
 *     a host:   loop   key = wait ()
 *                      model = program.update (Key key) model
 *                      show (program.view model)     what changed
 *
 * design:
 * Read a key, find its command, run it, show the result, and again:
 * an editor is this loop and a table (Emacs calls it the command
 * loop). The loop has no state but the keys of a sequence begun. A
 * question asked is not a wait inside a command, which would be a
 * second loop; it is a frame the keys go to for a while, and a
 * function kept for the answer (Minibuffer.read's action). So one
 * loop serves, and a host that cannot block (a window that must
 * repaint) is no different from one that can.
 *
 * others:
 * GNU Emacs does it the other way: a command that asks calls the
 * command loop again from inside itself (a recursive edit; the
 * minibuffer is one), and the C stack holds what is to be done with
 * the answer. efuns, like this module, keeps a function. *)

(* [create caps rows cols buf] makes a screen with one frame, on buf.
 * It becomes the first of the editor's top windows. *)
val create : Efuns.caps -> int -> int -> Efuns.buffer -> Efuns.top_window

(* the top window a frame is in *)
val of_frame : Efuns.frame -> Efuns.top_window

(* says a message on the minibuffer's line, until the next key *)
val message : Efuns.frame -> string -> unit

(* [set_window top window active]: the screen's tree has changed (a
 * window was split, or one was taken out). The frames are placed
 * again, and the keys go to active. *)
val set_window : Efuns.top_window -> Efuns.window -> Efuns.frame -> unit

val handle_key : Efuns.top_window -> Efuns.key -> unit
val resize : Efuns.top_window -> int -> int -> unit
val display : Efuns.top_window -> Curses.t

(* the editor as lib_terminal's hosts run it. The top window is
 * changed in place, but a host is given a model that is another value
 * after a key or a new size, and the same value after time alone. So
 * a host may paint only when the model is another one, and
 * lib_terminal/hosts/draw does so. With the top window itself as the
 * model, nothing was painted after the first screen on mini-9pi. *)
type model = { top : Efuns.top_window }
val program : Efuns.top_window -> model Tui.program
