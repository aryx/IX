(* A tiny screen editor, in one file: the text on the screen, a cursor
 * in it, and the keys of Emacs.
 *
 * Its full-size counterpart in m-ix is
 * mini-emacs (editors/emacs/), with buffers, windows, modes and a
 * Lisp. tiny-editor (TinyEditorLine.ml) is the line editor, with sam's
 * command language and no screen. This one is what you want for
 * changing a program: one text, one window, and what you type goes
 * where the cursor is.
 *
 * The text is stored as its lines, split at the line of the cursor:
 *
 *     above    the lines before the cursor's line, nearest first
 *     line     the cursor's line, with col, the cursor's position in it
 *     below    the lines after it
 *
 * So typing a character creates only one new string, for the current
 * line, whatever the size of the text, and moving down a line moves
 * one string from one list to the other. (Emacs keeps a gap in a
 * single array of characters, at the place of the last change, for
 * the same reason. A list of lines split at the cursor is the same
 * idea, built from what tiny-ml has: lists, and strings that cannot
 * be modified.)
 *
 * The editor is a state plus the keys that change it. [key] takes a
 * byte and says what it asks of the surrounding program (nothing, to
 * save the file, or to quit). [view] computes the lines of the screen
 * for a state; it is recomputed after each key, and the screen redraws
 * only the lines that changed. The editor uses no system calls: the
 * surrounding program reads the keys, displays the lines and writes
 * the file. That program is tiny-kernel's emacs
 * (TinyKernel/user/emacs.ml), running in a window of tiny-machine or
 * on its whole screen. On the host, OCaml compiles the editor only to
 * test it, as for tiny-kernel's games (there are no terminal escape
 * sequences: the screen is tiny-machine's, where a program draws
 * characters wherever it wants).
 *
 * The keys, as in Emacs:
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
 * What is left out: multiple buffers and windows, undo, the mark and
 * the region, searching backward, replacing, wrapping long lines (a
 * long line is cut at the edge of the screen, and the screen scrolls
 * to follow the cursor), and characters beyond ASCII.
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
