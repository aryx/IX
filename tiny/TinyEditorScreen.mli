(* A tiny screen editor, in one file: the text on the screen, a cursor
 * in it, and the keys of Emacs.
 *
 * The text is stored as its lines, split at the line of the cursor:
 *
 *     above    the lines before the cursor's line, nearest first
 *     line     the cursor's line, with col, the cursor's position in it
 *     below    the lines after it
 *
 * So typing a character creates only one new string, for the current
 * line, whatever the size of the text, and moving down a line moves
 * one string from one list to the other. Emacs keeps a gap in a single
 * array of characters, at the place of the last change, for the same
 * reason, and tiny-ml's Bytes could hold one. Lines that are never
 * modified give us more:
 * - a line that did not change is the very same string, so the
 *   screen's caches recognize it by == ([faces], below) without any
 *   bookkeeping of what changed;
 * - the screen is made of lines taken from the lists as they are;
 * - an earlier text would share all its lines but one (undo, an
 *   exercise).
 * The price is that a long line is copied at each key, and a far move
 * moves the lines one by one.
 *
 * archi:
 * The editor is a state plus the keys that change it. [key] takes a
 * byte and says what it asks of the surrounding program (nothing, to
 * save the file, or to quit). [view] computes the lines of the screen
 * for a state; it is recomputed after each key, and the screen redraws
 * only the lines that changed. The editor uses no system calls: the
 * surrounding program reads the keys, displays the lines and writes
 * the file. That program is [main], at the end, the only part that
 * makes system calls; it is tiny-kernel's emacs and the host's
 * tiny-emacs (user/emacs.ml is one line). There are no terminal escape
 * sequences: the screen is tiny-machine's, where a program draws
 * characters wherever it wants.
 *
 * The keys, as in Emacs:
 *
 *     C-f C-b C-n C-p, the arrows    move by a character, by a line
 *     C-a C-e                        go to the line's start, its end
 *     C-v, Escape v                  move a screen down, up
 *     Escape <, Escape >             go to the text's start, its end
 *     C-d, Backspace                 delete the character at, before
 *                                    the cursor
 *     C-k, C-y                       kill the rest of the line, yank it
 *     C-s                            search as you type; C-s again for
 *                                    the next match
 *     C-l                            center the cursor's line
 *     C-x C-s, C-x C-c (or C-x C-q)  save, quit
 *     C-g                            never mind
 *     M-x (Escape x, Alt-x, Cmd-x)   run a command by its name, with Tab
 *                                    completing it
 *     C-x (, C-x ), C-x e            start a macro, end it, replay it
 *
 * M-x knows each of these keys by its name in Emacs (kill-line,
 * save-buffer...). It also knows two commands that have no key and ask
 * on the last line for what they need: goto-line, and replace-string,
 * which replaces from the cursor to the end. (How M-x kill-line works
 * is explained in wib:, below.)
 *
 * A macro is the keys typed between C-x ( and C-x ). C-x e gives them
 * to the editor again, which reads them before any new key typed
 * ([pending]). So a macro does everything its keys did: a search, a
 * save, an M-x. That is what a macro is in Emacs, a keyboard macro:
 * there is no language, only keys.
 *
 * A file of OCaml or C is shown in colors: its keywords, its comments
 * and its strings ([faces]). Each line is colored on its own, except
 * for comments, which may span several lines (and nest, in OCaml): how
 * many are open at the first line shown is counted from the start of
 * the text. A string over several lines, or a C macro continued by a
 * backslash, is colored wrong; Emacs's modes get these right, with
 * much more code.
 *
 * twin:
 * mini-emacs (editors/emacs/), its full-size counterpart in m-ix, has
 * buffers, windows, modes and more. tiny-editor (TinyEditorLine.ml)
 * is the line editor, with sam's command language and no screen. This
 * one is what you want for changing a program: one text, one window,
 * and what you type goes where the cursor is.
 *
 * mini-emacs follows efuns (Fabrice Le Fessant's Emacs in OCaml, 1998):
 * its text is a gap buffer (its Text module), and a key is looked up
 * in keymaps to find a command, which is a function on the editor's
 * structure. This editor keeps Emacs's keys and their names, but a key
 * is a case of [key]'s match, with no keymap; a command's name only
 * stands for its keys (M-x, above); and the text is lines (above).
 *
 * dropped:
 * Multiple buffers and windows, undo, the mark and the region,
 * searching backward, replacing with a question at each, a macro's
 * count (C-u), wrapping long lines (a long line is cut at the edge of
 * the screen, and the screen scrolls to follow the cursor), and
 * characters beyond ASCII.
 *
 * wib:
 * A command is just its keys: M-x kill-line gives the editor a C-k,
 * whereas mini-emacs, like efuns, looks each key up in a keymap to find
 * its command. So M-x and a macro both come down to keys queued for the
 * editor ([pending]), and there is no table of commands besides the
 * keys. The price is that a command needs a key; the two that have
 * none, goto-line and replace-string, are special cases ([answered]).
 *
 * exercises:
 * - undo as a list of earlier texts, as the office and mini-office do
 *   (the text's record must become an immutable value, so that an
 *   earlier one can be kept).
 *)

type editor

(* [create cols rows file text]. [file] is the name to show, an Fpath.t
 * so that it cannot be swapped with [text] by mistake. *)
val create : int -> int -> Fpath.t -> string -> editor

(* what a key asks of the program around the editor *)
type request = Continue | Save | Quit

val key : editor -> TinyLibPlayground.key -> request

(* A key the editor gives itself, from a macro or an M-x command. The
 * program around passes it to [key] before the next key typed. *)
val pending : editor -> TinyLibPlayground.key option

(* The screen: rows lines of at most cols characters. The last two are
 * a status line (the file and the cursor's place) and a message. *)
val view : editor -> string list

(* The colors of the text lines of [view] (its first rows - 2), for a
 * file whose name ends in .ml, .mli, .c or .h; [] for other files.
 * Each is a string as long as its line, with one letter per character:
 * k a keyword, c a comment, s a string or a character literal, . the
 * rest. Call it after [view]. *)
val faces : editor -> string list

(* [shapes e n] gives the screen's first n lines as shapes, for a
 * program that draws them (emacs). Each line is a group of pieces of
 * one colour each, also cut at the cursor, so that a key changes only
 * a piece or two. The last shape is the cursor's cell, white on black. *)
val shapes : editor -> int -> TinyLibPlayground.shape list

(* the column and line of the cursor on that screen *)
val cursor : editor -> int * int

(* the lines with a newline between two *)
val text : editor -> string

val lines : editor -> string list

(* tells the editor that the program around has written the file *)
val saved : editor -> unit

(* shows a message on the screen's last line until the next key *)
val say : editor -> string -> unit

(* The program emacs file. It writes the file on each save and prints
 * the usage when argv does not name a file. *)
val main :
  < Cap.open_in; Cap.open_out; Cap.stderr; Cap.clock; Cap.keyboard; .. > ->
  string array -> Exit.t
