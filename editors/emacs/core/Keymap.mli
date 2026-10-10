(* Keys and what they do. A key has Emacs's name:
 *
 *     a  é               a character (its bytes)
 *     C-x  C-@  C-_      Control and a letter; Control-Space, Control-/
 *     M-f  M-C-x         Meta (Alt, or Escape before): M- and the key
 *     RET TAB DEL ESC    Enter, Tab, Backspace, Escape
 *     <up> <down> <left> <right> <home> <end> <prior> <next> <delete>
 *     M-<up> C-<left>    an arrow with Alt, with Control
 *     <mouse-1> <wheel-up> <wheel-down>   the mouse, in a window
 *
 * and a map says what each does: a command, or (C-x) another map for
 * the key after it. The idea is Emacs's, the module efuns' Keymap;
 * here a key is its name, and a map a table from names.
 *
 *     add_binding map "C-x C-s" save      C-x a prefix, C-s in its map
 *     get_binding map [ "C-x" ]         = Some (Prefix _)
 *     get_binding map [ "C-x"; "C-s" ]  = Some (Function save)
 *     get_binding map [ "C-x"; "a" ]    = None
 *
 * A map of maps is a tree whose edges are keys, and a sequence typed
 * a path in it; Top_window keeps the path begun (C-x-) and asks again
 * at each key. A buffer has several maps, looked up in order, the
 * first that knows the keys wins: its own, its minor modes', its
 * major mode's, the editor's. So a mode is mostly a map: Dired binds
 * RET to open the line's file and leaves C-n to the editor's.
 *
 * What a terminal sends, and why some keys cannot be told apart
 * ([of_bytes]). Control and a letter is one byte, the letter's code
 * less 96 (ASCII's first 32 codes): C-a is 1, C-x 24. But Tab is 9,
 * Enter 13 and Escape 27, which are C-i, C-m and C-[: the same
 * bytes, so they are named TAB, RET and ESC and there is no C-i to
 * bind. Meta is no byte at all: a terminal sends Escape, then the
 * key (M-f is 27, 102), which is also what typing Escape then f
 * sends: Top_window makes ESC a prefix for that. The arrows are
 * Escape, [ and a letter (the VT100's), and so M-[ is not a key.
 *
 * cs-history:
 * Control is the Teletype's key, there to type ASCII's control
 * codes. Meta was a key of the keyboards made at Stanford's and
 * MIT's AI laboratories in the 1970s, where EMACS was written, which
 * set one more bit in the character (from memory); the terminals
 * and PCs that came after never had it, and Escape before, then
 * Alt, stood for it. The notation, C-x and M-f, is EMACS's manual's.
 *
 * others:
 * A table from keys to named commands that the user may change is
 * Emacs's, and is now every editor's (a keybindings file, a command
 * palette for M-x). mini-turbopascal's keys are a match in its code
 * (Turbo_update), which is shorter and cannot be rebound. *)

val create : unit -> Efuns.map

(* [add_binding map keys action]: keys a sequence, a space between two
 * (so none with the space's key in it) *)
val add_binding : Efuns.map -> string -> Efuns.action -> unit
(* in the editor's map: for every buffer *)
val add_global_key : string -> Efuns.action -> unit

val get_binding : Efuns.map -> Efuns.key list -> Efuns.binding option

(* the name of a key from the bytes a terminal sends for it (Tui's
 * keys): "\x18" is C-x, "\x1bf" M-f, "\x1b[A" <up>; bytes it has no
 * name for are their own *)
val of_bytes : string -> Efuns.key

(* where the mouse is, if the bytes are its (a click: <mouse-1>, the
 * wheel: <wheel-up>, <wheel-down>): the screen's row and column, from 0 *)
val mouse : string -> (int * int) option

(* a key that is a character, to be typed in; and the name such a key
 * is looked up by when nothing is bound to itself: bound to
 * self_insert_command, in place of a binding a character *)
val is_char : Efuns.key -> bool
val any_char : Efuns.key
