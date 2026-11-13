(* The minibuffer: a question asked on the screen's last line, with
 * its answer typed in a buffer of one line, where every command of
 * the editor works (you can kill a word, or yank a file's name). This
 * is Emacs's idea, and efuns' Minibuffer and Select. The buffer's own
 * map has the keys that end it: RET gives the answer, and C-g gives
 * no answer.
 *
 *     Find file: editors/em_          TAB makes what is typed longer,
 *     Find file: editors/emacs/_      as far as the names that start
 *     Find file: editors/emacs/ [Config.ml Config.mli core/ ...]
 *                                     with it agree; then it lists
 *                                     them
 *
 * There is one question at a time: a command that asks while a
 * question is asked fails.
 *
 * A command that asks does not wait. [read] makes the frame, binds
 * RET in its buffer's map to a function that calls [action] with the
 * answer, and returns. The answer comes later, as a key like any
 * other (Top_window.mli says why). So C-x C-f is two commands: the
 * one that asks, and the one RET runs.
 *
 * others:
 * A question is where most programs stop being themselves: it is a
 * dialog box with an editing of its own, poorer than the program's.
 * mini-turbopascal's question is like that (Turbo_menus.input_key
 * knows a character, Backspace, Enter, Escape), as Turbo Pascal's
 * was. vi asks on its last line too, with ex's line editing and not
 * vi's. Emacs's answer, a buffer like the others, costs one frame
 * more, and gives completion, the kill ring and the search in every
 * question. *)

(* [create frame prompt] makes the minibuffer's frame, which now gets
 * the keys. Its buffer's map is for the caller to bind keys in (C-g
 * is bound already). *)
val create : Efuns.frame -> string -> Efuns.frame

(* makes the cursor shown be the asking frame's and not the
 * minibuffer's: for a search, which moves that frame's point as one
 * types *)
val cursor_back : Efuns.frame -> unit

(* removes the minibuffer, gives the keys back to the frame that
 * asked, and returns that frame *)
val kill : Efuns.frame -> Efuns.frame

(* [read frame prompt initial complete action] asks the question. At
 * RET, it calls action with the frame that asked and the answer.
 * complete gives, for what is typed, the answers that start with it
 * (for TAB). *)
val read : Efuns.frame -> string -> string -> (string -> string list) -> (Efuns.frame -> string -> unit) -> unit

(* completions for [read]: [among] completes from the names of a
 * list, and [no_completion] gives none *)
val among : string list -> string -> string list
val no_completion : string -> string list

(* [yes_or_no frame question action] runs action if "yes" is answered.
 * If [y_or_n] is set, the key y is the answer, with no RET (Emacs's
 * y-or-n-p in place of yes-or-no-p). *)
val yes_or_no : Efuns.frame -> string -> Efuns.action -> unit
val y_or_n : bool ref
