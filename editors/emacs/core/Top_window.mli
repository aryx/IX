(* The top window: a screen of the editor's. A key comes in, is looked
 * up in the keymaps and runs a command on the active frame; the frames
 * and the minibuffer's line, the last, go out as a screen of cells.
 * efuns' Top_window, which is a window of X's.
 *
 * {b A key's way.} Its name is made (Keymap.of_bytes); after ESC it is
 * M- and the key. With the keys of a sequence begun before it, it is
 * looked up in the buffer's map, its minor modes', its major mode's,
 * then the editor's:
 *
 *     C-x          a prefix: kept, "C-x-" shown, the next key awaited
 *     C-x C-s      a command: run on the active frame
 *     a            nothing bound: a character, so what <char> is bound to
 *     C-x a        nothing: "C-x a is undefined"
 *
 * A command that raises is not the editor's end: the exception is the
 * message shown (Failure "End of buffer"). After a command, the
 * buffer's undo has a boundary; not after a character typed, but a
 * space: undo takes back a word.
 *
 * {b The minibuffer.} While a question is asked (Efuns.minibuffer;
 * the Minibuffer module asks), the last line is its prompt and its
 * frame, the keys go to that frame, and what is said shows after the
 * answer, in brackets.
 *
 * {b The loop} that waits for a key is not here but in a host
 * (Tty_unix's select on the terminal, a window's events), and
 * [program] is this module as the three functions a host wants
 * (Tui.mli): update, which is [handle_key] or [resize]; view, which
 * is [display]; and over.
 *
 *     a host:   loop   key = wait ()
 *                      model = program.update (Key key) model
 *                      show (program.view model)     what changed
 *
 * design:
 * Read a key, find its command, run it, show the result, again: an
 * editor is this loop and a table (Emacs calls it the command
 * loop). It has no state but the keys of a sequence begun; a
 * question asked is not a wait inside a command, which would be a
 * second loop, but a frame the keys go to for a while and a function
 * kept for the answer (Minibuffer.read's action). So one loop
 * serves, and a host that cannot block (a window that must repaint)
 * is no different from one that can.
 *
 * others:
 * GNU Emacs does it the other way: a command that asks calls the
 * command loop again from inside itself (a recursive edit; the
 * minibuffer is one), the C stack holding what is to be done with
 * the answer. efuns, as here, keeps a function. *)

(* [create caps rows cols buf]: a screen with one frame, on buf; it is
 * the editor's first top window *)
val create : Efuns.caps -> int -> int -> Efuns.buffer -> Efuns.top_window

(* the top window a frame is in *)
val of_frame : Efuns.frame -> Efuns.top_window

(* said on the minibuffer's line, until the next key *)
val message : Efuns.frame -> string -> unit

(* [set_window top window active]: the screen's tree changed (a window
 * split, or one taken out), the frames placed again, the keys to
 * active *)
val set_window : Efuns.top_window -> Efuns.window -> Efuns.frame -> unit

val handle_key : Efuns.top_window -> Efuns.key -> unit
val resize : Efuns.top_window -> int -> int -> unit
val display : Efuns.top_window -> Curses.t

(* the editor as lib_terminal's hosts run it. The top window is
 * changed in place; a host is given a model that is another value
 * after a key or a new size, and the same after time alone: a host
 * may paint only when the model is another (lib_terminal/hosts/draw
 * does: with the top window itself as the model, nothing was painted
 * after the first screen on mini-9pi) *)
type model = { top : Efuns.top_window }
val program : Efuns.top_window -> model Tui.program
