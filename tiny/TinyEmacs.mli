(* A tiny screen editor, in one file: the text on the screen, a cursor
 * in it, and Emacs's keys. mini-emacs (editors/emacs/) is its twin in
 * m-ix, with buffers, windows, modes and a Lisp; tiny-editor
 * (TinyEditor.ml) is the line editor, sam's command language with no
 * screen. This one is what one wants to change a program with: one
 * text, one window, what is typed goes where the cursor is.
 *
 * The text is its lines, cut at the cursor's line:
 *
 *     above    the lines before the cursor's, the nearest first
 *     line     the cursor's line, and col, the cursor in it
 *     below    the lines after it
 *
 * so a character typed makes one new string, the line's, whatever the
 * text's size, and going a line down moves one string from a list to
 * the other. (Emacs keeps a gap in one array of characters at the
 * place of the last change, for the same reason; a list of lines cut
 * at the cursor is that idea with what tiny-ml has: lists and strings
 * that do not change.)
 *
 * The editor is a state and the keys that change it: [key] takes a
 * byte and says what it asks of the program around (nothing, the file
 * saved, the end); [view] is the screen's lines for the state, made
 * again after each key, of which the screen draws those that changed.
 * It names no system: the program around it reads the keys, shows the
 * lines and writes the file. That program is tiny-kernel's emacs
 * (TinyKernel/user/emacs.ml), in a window of tiny-machine or on its
 * whole screen; on the host the editor is OCaml's to test, as
 * tiny-kernel's games are (no terminal's escapes: a screen is
 * tiny-machine's, where a program draws characters where it wants).
 *
 * The keys, Emacs's:
 *
 *     C-f C-b C-n C-p, the arrows    a character, a line
 *     C-a C-e                        the line's start, its end
 *     C-v, Escape v                  a screen down, up
 *     Escape <, Escape >             the text's start, its end
 *     C-d, Backspace                 the character at, before the cursor
 *     C-k, C-y                       the line's rest taken, put back
 *     C-s                            search, as it is typed; C-s the next
 *     C-l                            the cursor's line in the middle
 *     C-x C-s, C-x C-q               save, quit (C-x C-c too, where it comes)
 *     C-g                            never mind
 *
 * Left out: several buffers and windows, undo, the mark and the
 * region, a search backward, replacing, the line that wraps (a long
 * line is cut at the screen's edge, and the screen follows the
 * cursor), characters beyond ASCII.
 *)

type editor

(* [create cols rows file text]: an editor of the text, the cursor at
 * its start, on a screen of that size; file is its name, to show *)
val create : int -> int -> string -> string -> editor

(* what a key asks of the program around the editor *)
type request = Continue | Save | Quit

(* a key, a byte: a character, a control character (C-a is 1), and
 * tiny-machine's arrows, 128 to 131 (up, down, left, right) *)
val key : editor -> int -> request

(* the screen: rows lines of at most cols characters, the last two a
 * line on the file and the cursor's place, and a message *)
val view : editor -> string list

(* where the cursor is on that screen: its column, its line *)
val cursor : editor -> int * int

(* the text's lines, to write with a newline between two *)
val lines : editor -> string list

(* the program around has written the file *)
val saved : editor -> unit

(* a message, on the screen's last line until the next key *)
val say : editor -> string -> unit
