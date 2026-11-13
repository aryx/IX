(* Keys and what they do. A key has its Emacs name:
 *
 *     a  é               a character (its bytes)
 *     C-x  C-@  C-_      Control and a letter; Control-Space, Control-/
 *     M-f  M-C-x         Meta (Alt, or Escape before): M- and the key
 *     RET TAB DEL ESC    Enter, Tab, Backspace, Escape
 *     <up> <down> <left> <right> <home> <end> <prior> <next> <delete>
 *     M-<up> C-<left>    an arrow with Alt, with Control
 *     <mouse-1> <wheel-up> <wheel-down>   the mouse, in a window
 *
 * A map says what each key does: it runs a command, or (as C-x does)
 * it leads to another map for the key after it. The idea is Emacs's,
 * and the module is efuns' Keymap. Here a key is its name, and a map
 * is a table from names.
 *
 *     add_binding map "C-x C-s" save      C-x is a prefix, C-s is in
 *                                         its map
 *     get_binding map [ "C-x" ]         = Some (Prefix _)
 *     get_binding map [ "C-x"; "C-s" ]  = Some (Function save)
 *     get_binding map [ "C-x"; "a" ]    = None
 *
 * A map of maps is a tree whose edges are keys, and a sequence typed
 * is a path in it. Top_window keeps the path begun (C-x-) and looks
 * it up again at each key. A buffer has several maps, looked up in
 * order, and the first that knows the keys wins: the buffer's own,
 * its minor modes', its major mode's, then the editor's. So a mode is
 * mostly a map: Dired binds RET to open the line's file, and leaves
 * C-n to the editor's map.
 *
 * What a terminal sends, and why some keys cannot be told apart
 * ([of_bytes]). Control and a letter is one byte, the letter's code
 * less 96 (one of ASCII's first 32 codes): C-a is 1, C-x is 24. But
 * Tab is 9, Enter is 13 and Escape is 27, and these are also C-i, C-m
 * and C-[. The bytes are the same, so they are named TAB, RET and ESC,
 * and there is no C-i to bind. Meta is no byte at all: a terminal
 * sends Escape, then the key (M-f is 27, 102), which is also what
 * typing Escape then f sends; Top_window makes ESC a prefix for that.
 * The arrows are Escape, [ and a letter (as on the VT100), and so M-[
 * is not a key.
 *
 * cs-history:
 * Control is the Teletype's key, there to type ASCII's control
 * codes. Meta was a key of the keyboards made at the AI laboratories
 * of Stanford and MIT in the 1970s, where EMACS was written; it set
 * one more bit in the character. The terminals and PCs that came
 * after never had it, and Escape typed before, then Alt, stood for
 * it. The notation, C-x and M-f, comes from EMACS's manual.
 *
 * others:
 * A table from keys to named commands that the user may change was
 * Emacs's idea, and every editor has one now (a keybindings file, a
 * command palette for M-x). mini-turbopascal's keys are a match in
 * its code (Turbo_update), which is shorter but cannot be rebound. *)

val create : unit -> Efuns.map

(* [add_binding map keys action]: keys is a sequence, with a space
 * between two keys (so no key in it can be the space key) *)
val add_binding : Efuns.map -> string -> Efuns.action -> unit
(* binds in the editor's map, for every buffer *)
val add_global_key : string -> Efuns.action -> unit

val get_binding : Efuns.map -> Efuns.key list -> Efuns.binding option

(* the name of a key, from the bytes a terminal sends for it (Tui's
 * keys): "\x18" is C-x, "\x1bf" is M-f, "\x1b[A" is <up>. Bytes that
 * it has no name for are their own name. *)
val of_bytes : string -> Efuns.key

(* where the mouse is, if the bytes are the mouse's (a click is
 * <mouse-1>, the wheel is <wheel-up> or <wheel-down>): the screen's
 * row and column, from 0 *)
val mouse : string -> (int * int) option

(* [is_char] says whether a key is a character, to be typed in.
 * [any_char] is the name such a key is looked up by when nothing is
 * bound to the key itself: it is bound to self_insert_command, in
 * place of a binding for each character. *)
val is_char : Efuns.key -> bool
val any_char : Efuns.key
