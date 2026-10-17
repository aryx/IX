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
 *     C-x C-s, C-x C-c (or C-x C-q)  save, quit
 *     C-g                            never mind
 *     M-x (Escape x, or Alt-x)       a command by its name, Tab completing
 *     C-x (, C-x ), C-x e            a macro started, ended, done again
 *
 * M-x knows each of these keys by its name in Emacs (kill-line,
 * save-buffer...), and two commands that have no key and ask on the
 * last line what they need: goto-line, and replace-string, from the
 * cursor to the end. A command is the keys it is: M-x kill-line gives
 * the editor a C-k.
 *
 * A macro is the keys typed between C-x ( and C-x ). C-x e gives them
 * again to the editor, which reads them before the keys typed
 * ([pending]): a macro does all its keys did, a search, a save, an
 * M-x. That is what a macro is in Emacs, a keyboard macro: no language,
 * the keys only.
 *
 * A file of OCaml or of C is in colors: its keywords, its comments
 * and its strings ([faces]). Each line is read on its own, but for the
 * comments, which may go on for several lines (OCaml's nest): how many
 * are open at the first line shown is counted from the text's start.
 * A string over several lines, or a C macro continued by a backslash,
 * is colored wrong; Emacs's modes get them right, with much more.
 *
 * What is left out: multiple buffers and windows, undo, the mark and
 * the region, searching backward, replacing with a question at each,
 * a macro's count (C-u), wrapping long lines (a long line is cut at
 * the edge of the screen, and the screen scrolls to follow the
 * cursor), and characters beyond ASCII.
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

(* a key the editor gives itself, a macro's or an M-x command's: the
 * program around gives it to [key] before the next one typed *)
val pending : editor -> int option

(* the screen: rows lines of at most cols characters, the last two a
 * line on the file and the cursor's place, and a message *)
val view : editor -> string list

(* the colors of view's text lines (its first rows - 2), for a file
 * whose name ends in .ml, .mli, .c or .h: each a string as long as its
 * line, a letter a character, k a keyword, c a comment, s a string or
 * a character, . the rest; [] for another file. After view *)
val faces : editor -> string list

(* [shapes e n]: the screen's first n lines as shapes, for a program
 * that draws it (emacs): each line a group of its pieces of one colour,
 * cut at the cursor too, so that a key changes a piece or two; then the
 * cursor's cell, white on black *)
val shapes : editor -> int -> TinyLibPlayground.shape list

(* where the cursor is on that screen: its column, its line *)
val cursor : editor -> int * int

(* the text, its lines with a newline between two: what is saved *)
val text : editor -> string

(* the text's lines, to write with a newline between two *)
val lines : editor -> string list

(* the program around has written the file *)
val saved : editor -> unit

(* a message, on the screen's last line until the next key *)
val say : editor -> string -> unit
