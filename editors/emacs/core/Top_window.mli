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
 * answer, in brackets. *)

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

(* the editor as lib_terminal's hosts run it: the model is the top
 * window, changed in place *)
val program : Efuns.top_window -> Efuns.top_window Tui.program
