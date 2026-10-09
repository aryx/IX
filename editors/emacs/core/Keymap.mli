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
 *)

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
